import AVFoundation

/// Captures microphone audio via AVAudioEngine from the default input device,
/// converting to 16kHz mono Float32 — the format Parakeet expects.
final class AudioRecorder {
    static let sampleRate: Double = 16000

    private let engine = AVAudioEngine()
    private var samples: [Float] = []
    private let samplesLock = NSLock()
    private var converter: AVAudioConverter?

    func start() throws {
        samplesLock.withLock { samples = [] }

        let input = engine.inputNode
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
    }
}
