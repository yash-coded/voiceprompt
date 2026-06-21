import AppKit
import SwiftUI

/// Observable state behind the floating waveform pill: whether it is on screen,
/// whether it is recording or processing, and the recent loudness samples that
/// drive the live waveform bars.
@MainActor
@Observable
final class WaveformPillModel {
    enum Phase {
        case recording, processing
    }

    /// Number of waveform bars kept on screen; older samples scroll off.
    static let maxBars = 48

    private(set) var isVisible = false
    private(set) var phase: Phase = .recording
    private(set) var levels: [Float] = []

    func beginRecording() {
        phase = .recording
        levels = []
        isVisible = true
    }

    func beginProcessing() {
        phase = .processing
        isVisible = true
    }

    func pushLevel(_ level: Float) {
        levels.append(level)
        if levels.count > Self.maxBars {
            levels.removeFirst(levels.count - Self.maxBars)
        }
    }

    func hide() {
        isVisible = false
        levels = []
    }
}

/// Always-on-top panel that never activates the app or steals keyboard focus,
/// so dictated text still pastes into whatever app was frontmost. It also
/// ignores mouse events, joins every Space, and floats over full-screen apps.
final class FloatingPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 140, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        ignoresMouseEvents = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Owns the floating panel and keeps it in sync with the dictation state
/// machine. The model transitions are pure and testable; the actual panel is
/// wired up lazily via `installFloatingPanel()` at app start.
@MainActor
final class WaveformPillController {
    let model = WaveformPillModel()

    private var showPanel: () -> Void = {}
    private var hidePanel: () -> Void = {}

    /// Drive the pill from the hotkey state machine.
    func update(for state: HotkeyState) {
        switch state {
        case .recording:
            model.beginRecording()
            showPanel()
        case .processing:
            model.beginProcessing()
        case .idle, .waiting:
            model.hide()
            hidePanel()
        }
    }

    /// Feed a fresh loudness sample; ignored unless the pill is recording.
    func push(level: Float) {
        guard model.isVisible, model.phase == .recording else { return }
        model.pushLevel(level)
    }

    /// Build the real floating panel hosting the SwiftUI waveform and wire the
    /// show/hide hooks. Call once at app launch (not exercised in unit tests).
    func installFloatingPanel() {
        let panel = FloatingPanel()
        panel.contentView = NSHostingView(rootView: WaveformPillView(model: model))
        showPanel = { [weak panel] in
            guard let panel else { return }
            if let screen = NSScreen.main {
                let frame = screen.visibleFrame
                let size = panel.frame.size
                panel.setFrameOrigin(
                    NSPoint(x: frame.midX - size.width / 2, y: frame.minY + 120))
            }
            panel.orderFrontRegardless()
        }
        hidePanel = { [weak panel] in panel?.orderOut(nil) }
    }
}

/// The pill itself: a frosted capsule showing live waveform bars while
/// recording and a pulsing indicator while the transcript is processed.
struct WaveformPillView: View {
    let model: WaveformPillModel

    var body: some View {
        ZStack {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
            switch model.phase {
            case .recording:
                WaveformBars(levels: model.levels)
            case .processing:
                ProcessingDots()
            }
        }
        .frame(width: 140, height: 44)
        .padding(4)
    }
}

private struct WaveformBars: View {
    let levels: [Float]

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                Capsule()
                    .fill(.white.opacity(0.85))
                    .frame(width: 2, height: barHeight(for: level))
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .frame(height: 28)
        .padding(.horizontal, 14)
        .animation(.linear(duration: 0.08), value: levels.count)
    }

    /// Map loudness to a visible bar; RMS rarely nears 1, so amplify and floor
    /// it so quiet speech still reads as movement and silence stays a sliver.
    private func barHeight(for level: Float) -> CGFloat {
        let scaled = min(1, level * 3)
        return 3 + CGFloat(scaled) * 25
    }
}

private struct ProcessingDots: View {
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(.white.opacity(0.85))
                    .frame(width: 7, height: 7)
                    .scaleEffect(pulsing ? 1 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever().delay(Double(index) * 0.15),
                        value: pulsing)
            }
        }
        .onAppear { pulsing = true }
    }
}
