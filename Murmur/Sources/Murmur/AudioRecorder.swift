import AVFoundation
import AudioToolbox

/// Captures microphone audio via AVAudioEngine from the default input device,
/// converting to 16kHz mono Float32 — the format Parakeet expects.
final class AudioRecorder {
    static let sampleRate: Double = 16000

    /// Called on the audio thread with a 0...1 loudness for each captured chunk,
    /// driving the live waveform. Hop to the main actor before touching UI.
    var onLevel: ((Float) -> Void)?

    /// UID of the input device to capture from. When nil — or when the device
    /// has disconnected — recording uses the system default input.
    var preferredDeviceUID: String?

    /// Whether microphone access is granted. Injectable for tests; defaults to
    /// the live TCC status. Recording without authorization would crash the
    /// audio engine with an uncatchable Obj-C exception, so start() refuses it.
    var isMicAuthorized: () -> Bool = {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    private let engine = AVAudioEngine()
    private var samples: [Float] = []
    private let samplesLock = NSLock()
    private var converter: AVAudioConverter?

    /// Root-mean-square loudness of a chunk, clamped to 0...1 — a perceptual
    /// enough signal for the waveform without per-bar peak spikiness.
    static func level(of samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let meanSquare = samples.reduce(Float(0)) { $0 + $1 * $1 } / Float(samples.count)
        return min(1, meanSquare.squareRoot())
    }

    func start() throws {
        // Without mic permission the input node still reports a plausible format,
        // but installTap/engine.start then raises an uncatchable Obj-C exception.
        // Authorization is the reliable signal, so bail before touching the engine.
        guard isMicAuthorized() else {
            throw NSError(
                domain: "Murmur", code: 3,
                userInfo: [NSLocalizedDescriptionKey:
                    "Microphone access not granted — enable Murmur under System Settings → Privacy & Security → Microphone."])
        }
        samplesLock.withLock { samples = [] }

        let input = engine.inputNode
        applyPreferredDevice(to: input)
        let inputFormat = input.outputFormat(forBus: 0)
        guard
            let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: Self.sampleRate,
                channels: 1,
                interleaved: false
            ),
            let converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        else {
            throw NSError(
                domain: "Murmur", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Cannot create audio converter"])
        }
        self.converter = converter

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.append(buffer, from: inputFormat, to: targetFormat)
        }
        engine.prepare()
        try engine.start()
    }

    /// Stops the engine and returns everything captured since start().
    func stop() -> [Float] {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil
        return samplesLock.withLock { samples }
    }

    /// Point the engine's input at the chosen device when it is still connected;
    /// otherwise leave the engine on the system default.
    private func applyPreferredDevice(to input: AVAudioInputNode) {
        let available = AudioDevices.inputDevices().map(\.uid)
        guard let uid = AudioDeviceResolver.resolve(chosen: preferredDeviceUID, available: available),
              var deviceID = AudioDevices.deviceID(forUID: uid),
              let unit = input.audioUnit else { return }
        AudioUnitSetProperty(
            unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
            &deviceID, UInt32(MemoryLayout<AudioDeviceID>.size))
    }

    private func append(_ buffer: AVAudioPCMBuffer, from inputFormat: AVAudioFormat, to targetFormat: AVAudioFormat) {
        guard let converter else { return }
        let ratio = targetFormat.sampleRate / inputFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var consumed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, let channel = out.floatChannelData else { return }
        let chunk = Array(UnsafeBufferPointer(start: channel[0], count: Int(out.frameLength)))
        samplesLock.withLock { samples.append(contentsOf: chunk) }
        onLevel?(Self.level(of: chunk))
    }
}
