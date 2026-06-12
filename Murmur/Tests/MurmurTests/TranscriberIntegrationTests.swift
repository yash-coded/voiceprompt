import AVFoundation
import Testing
@testable import Murmur

/// End-to-end Parakeet check: downloads the model on first run (~600MB), so
/// it only runs when explicitly requested via MURMUR_INTEGRATION=1.
@Suite("Transcriber integration", .enabled(if: ProcessInfo.processInfo.environment["MURMUR_INTEGRATION"] == "1"))
struct TranscriberIntegrationTests {

    @Test("transcribes a known 16kHz mono WAV")
    func transcribesKnownAudio() async throws {
        let path = ProcessInfo.processInfo.environment["MURMUR_TEST_WAV"] ?? "/tmp/murmur_test.wav"
        let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length))!
        try file.read(into: buffer)
        let samples = Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))

        let text = try await Transcriber().transcribe(samples)
        let normalized = text.lowercased()
        #expect(normalized.contains("hello world"))
        #expect(normalized.contains("murmur") || normalized.contains("dictation"))
    }
}
