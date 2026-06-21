import Testing
@testable import Murmur

@Suite("AudioRecorder.level")
struct AudioLevelTests {

    @Test("empty buffer has zero level")
    func emptyIsZero() {
        #expect(AudioRecorder.level(of: []) == 0)
    }

    @Test("silence has zero level")
    func silenceIsZero() {
        #expect(AudioRecorder.level(of: [Float](repeating: 0, count: 512)) == 0)
    }

    @Test("full-scale signal has level 1")
    func fullScaleIsOne() {
        #expect(AudioRecorder.level(of: [Float](repeating: 1, count: 256)) == 1)
        // Sign does not matter — RMS squares the samples.
        #expect(AudioRecorder.level(of: [Float](repeating: -1, count: 256)) == 1)
    }

    @Test("half-amplitude signal sits between silence and full scale")
    func halfAmplitudeIsBetween() {
        let level = AudioRecorder.level(of: [Float](repeating: 0.5, count: 256))
        #expect(level > 0 && level < 1)
    }

    @Test("louder signal yields a higher level")
    func louderIsHigher() {
        let quiet = AudioRecorder.level(of: [Float](repeating: 0.2, count: 256))
        let loud = AudioRecorder.level(of: [Float](repeating: 0.8, count: 256))
        #expect(loud > quiet)
    }

    @Test("out-of-range samples are clamped to 1")
    func clampsAboveOne() {
        #expect(AudioRecorder.level(of: [Float](repeating: 3, count: 64)) == 1)
    }
}
