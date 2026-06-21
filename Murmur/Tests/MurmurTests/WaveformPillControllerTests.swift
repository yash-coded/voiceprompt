import Testing
@testable import Murmur

@MainActor
@Suite("WaveformPillController")
struct WaveformPillControllerTests {

    @Test("recording state shows the pill in recording phase")
    func recordingShowsPill() {
        let controller = WaveformPillController()
        controller.update(for: .recording)
        #expect(controller.model.isVisible)
        #expect(controller.model.phase == .recording)
    }

    @Test("processing state keeps the pill up and switches phase")
    func processingSwitchesPhase() {
        let controller = WaveformPillController()
        controller.update(for: .recording)
        controller.update(for: .processing)
        #expect(controller.model.isVisible)
        #expect(controller.model.phase == .processing)
    }

    @Test("returning to idle hides the pill")
    func idleHidesPill() {
        let controller = WaveformPillController()
        controller.update(for: .recording)
        controller.update(for: .idle)
        #expect(controller.model.isVisible == false)
    }

    @Test("waiting keeps the pill hidden")
    func waitingStaysHidden() {
        let controller = WaveformPillController()
        controller.update(for: .waiting)
        #expect(controller.model.isVisible == false)
    }

    @Test("levels are recorded only while the pill is visible")
    func levelsGatedOnVisibility() {
        let controller = WaveformPillController()
        controller.push(level: 0.5) // dropped — pill hidden
        controller.update(for: .recording)
        controller.push(level: 0.6)
        #expect(controller.model.levels == [0.6])
    }

    @Test("a cancelled hold (recording then idle) leaves nothing behind")
    func cancelLeavesCleanState() {
        let controller = WaveformPillController()
        controller.update(for: .recording)
        controller.push(level: 0.9)
        controller.update(for: .idle)
        #expect(controller.model.isVisible == false)
        #expect(controller.model.levels.isEmpty)
    }
}
