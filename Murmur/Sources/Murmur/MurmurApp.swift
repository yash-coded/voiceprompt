import AVFoundation
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let controller = DictationController()
    static let onboarding = OnboardingWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.controller.start()
        // First launch runs the wizard, which requests mic/accessibility itself;
        // afterwards it only appears when re-run from Settings.
        if !Settings.shared.onboardingCompleted {
            Self.onboarding.show()
        } else {
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
        }
    }
}

@main
struct MurmurApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    private var controller = AppDelegate.controller

    var body: some Scene {
        MenuBarExtra("Murmur", systemImage: menubarSymbol) {
            Text(statusLabel)
            Divider()
            Button("Open Murmur") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            Divider()
            Button("Quit Murmur") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }

        Window("Murmur", id: "main") {
            MainWindow(settings: .shared)
        }
        .windowResizability(.contentSize)
    }

    private var menubarSymbol: String {
        switch controller.state {
        case .idle, .waiting: "mic"
        case .recording: "mic.fill"
        case .processing: "hourglass"
        }
    }

    private var statusLabel: String {
        switch controller.state {
        case .idle, .waiting: "Hold \(Settings.shared.hotkeyModifier.label) to dictate"
        case .recording: "Recording…"
        case .processing: "Transcribing…"
        }
    }
}
