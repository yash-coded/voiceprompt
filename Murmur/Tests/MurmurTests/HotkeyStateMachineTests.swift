import Testing
@testable import Murmur

@Suite("HotkeyStateMachine")
struct HotkeyStateMachineTests {

    @Test("starts idle")
    func startsIdle() {
        let sm = HotkeyStateMachine()
        #expect(sm.state == .idle)
    }

    @Test("press from idle enters waiting and starts hold timer")
    func pressStartsWaiting() {
        let sm = HotkeyStateMachine()
        let actions = sm.handle(.pressed, at: 10.0)
        #expect(sm.state == .waiting)
        #expect(actions == [.startHoldTimer])
    }

    @Test("hold timer firing while still held starts recording")
    func holdConfirmedStartsRecording() {
        let sm = HotkeyStateMachine()
        _ = sm.handle(.pressed, at: 10.0)
        let actions = sm.handle(.holdTimerFired, at: 10.5)
        #expect(sm.state == .recording)
        #expect(actions == [.startRecording])
    }

    @Test("release before threshold cancels silently back to idle")
    func earlyReleaseCancels() {
        let sm = HotkeyStateMachine()
        _ = sm.handle(.pressed, at: 10.0)
        let actions = sm.handle(.released, at: 10.3)
        #expect(sm.state == .idle)
        #expect(actions == [.cancelHoldTimer])
    }

    @Test("hold timer firing after early release does nothing")
    func staleTimerIgnored() {
        let sm = HotkeyStateMachine()
        _ = sm.handle(.pressed, at: 10.0)
        _ = sm.handle(.released, at: 10.3)
        let actions = sm.handle(.holdTimerFired, at: 10.5)
        #expect(sm.state == .idle)
        #expect(actions.isEmpty)
    }

    @Test("release while recording stops with duration measured from press")
    func releaseStopsRecording() {
        let sm = HotkeyStateMachine()
        _ = sm.handle(.pressed, at: 10.0)
        _ = sm.handle(.holdTimerFired, at: 10.5)
        let actions = sm.handle(.released, at: 12.0)
        #expect(actions == [.stopRecording(duration: 2.0)])
    }

    @Test("press during processing is a no-op")
    func pressDuringProcessingIgnored() {
        let sm = HotkeyStateMachine()
        _ = sm.handle(.pressed, at: 10.0)
        _ = sm.handle(.holdTimerFired, at: 10.5)
        _ = sm.handle(.released, at: 12.0)
        sm.setProcessing()
        let actions = sm.handle(.pressed, at: 13.0)
        #expect(sm.state == .processing)
        #expect(actions.isEmpty)
    }

    @Test("setIdle returns to idle after processing")
    func setIdleResets() {
        let sm = HotkeyStateMachine()
        sm.setProcessing()
        sm.setIdle()
        #expect(sm.state == .idle)
        // a fresh press works again
        let actions = sm.handle(.pressed, at: 20.0)
        #expect(actions == [.startHoldTimer])
    }

    @Test("release while idle is a no-op")
    func releaseWhileIdleIgnored() {
        let sm = HotkeyStateMachine()
        let actions = sm.handle(.released, at: 10.0)
        #expect(sm.state == .idle)
        #expect(actions.isEmpty)
    }

    @Test("state changes are reported to the observer")
    func observerNotified() {
        let sm = HotkeyStateMachine()
        var seen: [HotkeyState] = []
        sm.onStateChange = { seen.append($0) }
        _ = sm.handle(.pressed, at: 10.0)
        _ = sm.handle(.holdTimerFired, at: 10.5)
        _ = sm.handle(.released, at: 12.0)
        sm.setProcessing()
        sm.setIdle()
        #expect(seen == [.waiting, .recording, .processing, .idle])
    }
}
