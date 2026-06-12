import Foundation

/// Hold-to-talk state machine, ported from the Python hotkey module.
///
/// IDLE ──(press)──► WAITING ──(hold timer fires)──► RECORDING ──(release)──► PROCESSING
///                      │
///                (release early)
///                      ▼
///                    IDLE
///
/// The machine is pure and synchronous: callers feed it events with timestamps
/// and execute the returned actions (start/cancel the real hold timer, start
/// or stop recording). Release while recording emits `.stopRecording`; the
/// pipeline then calls `setProcessing()` or `setIdle()` (short-clip discard).
enum HotkeyState {
    case idle, waiting, recording, processing
}

enum HotkeyEvent {
    case pressed, released, holdTimerFired
}

enum HotkeyAction: Equatable {
    case startHoldTimer
    case cancelHoldTimer
    case startRecording
    case stopRecording(duration: TimeInterval)
}

/// Minimum hold before recording starts; brief accidental presses are ignored.
let holdThreshold: TimeInterval = 0.5

final class HotkeyStateMachine {
    private(set) var state: HotkeyState = .idle
    var onStateChange: ((HotkeyState) -> Void)?

    private var pressTime: TimeInterval = 0

    func handle(_ event: HotkeyEvent, at now: TimeInterval) -> [HotkeyAction] {
        switch (state, event) {
        case (.idle, .pressed):
            pressTime = now
            transition(to: .waiting)
            return [.startHoldTimer]
        case (.waiting, .holdTimerFired):
            transition(to: .recording)
            return [.startRecording]
        case (.waiting, .released):
            transition(to: .idle)
            return [.cancelHoldTimer]
        case (.recording, .released):
            return [.stopRecording(duration: now - pressTime)]
        default:
            return []
        }
    }

    func setProcessing() {
        transition(to: .processing)
    }

    func setIdle() {
        transition(to: .idle)
    }

    private func transition(to newState: HotkeyState) {
        guard newState != state else { return }
        state = newState
        onStateChange?(newState)
    }
}
