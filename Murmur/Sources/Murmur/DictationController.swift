import AppKit
import Foundation
import Observation

/// Wires the hotkey state machine to the real world: NSEvent right-Option
/// monitoring, the hold-threshold timer, audio capture, transcription, and
/// paste. All event handling happens on the main thread.
@MainActor
@Observable
final class DictationController {
    private(set) var state: HotkeyState = .idle

    private let stateMachine = HotkeyStateMachine()
    private let recorder = AudioRecorder()
    private let transcriber = Transcriber()
    private let paster = TranscriptPaster()
    private let cleaner: TranscriptCleaner = OpenAICleaner()
    private let pill = WaveformPillController()

    private var monitor: Any?
    private var holdTimer: DispatchWorkItem?

    /// Cleanup context captured at key-press time, while the target app
    /// still has focus and the clipboard is untouched.
    private var capturedMode: CleanMode = .general
    private var capturedClipboard: String = ""

    /// Recordings shorter than this are accidental taps — discard, no paste.
    static let minimumClipDuration: TimeInterval = 1.0

    private static let rightOptionKeyCode: UInt16 = 61

    func start() {
        pill.installFloatingPanel()
        stateMachine.onStateChange = { [weak self] newState in
            Task { @MainActor in
                self?.state = newState
                self?.pill.update(for: newState)
            }
        }
        recorder.onLevel = { [weak self] level in
            Task { @MainActor in self?.pill.push(level: level) }
        }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard event.keyCode == Self.rightOptionKeyCode else { return }
            let pressed = event.modifierFlags.contains(.option)
            Task { @MainActor in
                self?.dispatch(pressed ? .pressed : .released)
            }
        }
        // Warm up the model in the background so the first dictation is fast.
        Task.detached(priority: .utility) { [transcriber] in
            _ = try? await transcriber.transcribe([Float](repeating: 0, count: 16000))
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        holdTimer?.cancel()
    }

    private func dispatch(_ event: HotkeyEvent) {
        if event == .pressed {
            capturedMode = CleanModeDetector.frontmostMode()
            capturedClipboard = NSPasteboard.general.string(forType: .string) ?? ""
        }
        let actions = stateMachine.handle(event, at: ProcessInfo.processInfo.systemUptime)
        for action in actions {
            perform(action)
        }
    }

    private func perform(_ action: HotkeyAction) {
        switch action {
        case .startHoldTimer:
            let timer = DispatchWorkItem { [weak self] in
                self?.dispatch(.holdTimerFired)
            }
            holdTimer = timer
            DispatchQueue.main.asyncAfter(deadline: .now() + holdThreshold, execute: timer)
        case .cancelHoldTimer:
            holdTimer?.cancel()
            holdTimer = nil
        case .startRecording:
            do {
                try recorder.start()
            } catch {
                NSLog("Murmur: failed to start recording: \(error)")
                stateMachine.setIdle()
            }
        case .stopRecording(let duration):
            finishRecording(heldFor: duration)
        }
    }

    private func finishRecording(heldFor duration: TimeInterval) {
        let samples = recorder.stop()
        let clipDuration = Double(samples.count) / AudioRecorder.sampleRate
        guard duration >= Self.minimumClipDuration,
              clipDuration >= Self.minimumClipDuration else {
            stateMachine.setIdle()
            return
        }
        stateMachine.setProcessing()
        let mode = capturedMode
        let clipboard = capturedClipboard
        Task { [transcriber, paster, cleaner] in
            defer { stateMachine.setIdle() }
            do {
                let text = try await transcriber.transcribe(samples)
                guard !text.isEmpty else { return }
                let cleaned = await cleaner.clean(text, mode: mode, clipboardContext: clipboard)
                paster.paste(cleaned)
            } catch {
                NSLog("Murmur: transcription failed: \(error)")
            }
        }
    }
}
