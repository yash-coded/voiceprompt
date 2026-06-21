import Testing
@testable import Murmur

@MainActor
@Suite("WaveformPillModel")
struct WaveformPillModelTests {

    @Test("starts hidden with no levels")
    func startsHidden() {
        let model = WaveformPillModel()
        #expect(model.isVisible == false)
        #expect(model.levels.isEmpty)
    }

    @Test("beginRecording shows the pill in recording phase with a clean slate")
    func beginRecordingShows() {
        let model = WaveformPillModel()
        model.pushLevel(0.5)
        model.beginRecording()
        #expect(model.isVisible)
        #expect(model.phase == .recording)
        #expect(model.levels.isEmpty)
    }

    @Test("pushLevel appends levels for the waveform")
    func pushLevelAppends() {
        let model = WaveformPillModel()
        model.beginRecording()
        model.pushLevel(0.3)
        model.pushLevel(0.7)
        #expect(model.levels == [0.3, 0.7])
    }

    @Test("levels are capped, keeping the most recent samples")
    func levelsAreCapped() {
        let model = WaveformPillModel()
        model.beginRecording()
        let total = WaveformPillModel.maxBars + 10
        for i in 0..<total {
            model.pushLevel(Float(i))
        }
        #expect(model.levels.count == WaveformPillModel.maxBars)
        #expect(model.levels.last == Float(total - 1))
        #expect(model.levels.first == Float(total - WaveformPillModel.maxBars))
    }

    @Test("beginProcessing keeps the pill visible and switches phase")
    func beginProcessingSwitchesPhase() {
        let model = WaveformPillModel()
        model.beginRecording()
        model.beginProcessing()
        #expect(model.isVisible)
        #expect(model.phase == .processing)
    }

    @Test("hide clears visibility and levels")
    func hideClears() {
        let model = WaveformPillModel()
        model.beginRecording()
        model.pushLevel(0.4)
        model.hide()
        #expect(model.isVisible == false)
        #expect(model.levels.isEmpty)
    }
}
