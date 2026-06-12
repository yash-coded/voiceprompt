import AVFoundation
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let controller = DictationController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        Self.controller.start()
    }
}

@main
struct MurmurApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private var controller = AppDelegate.controller

    var body: some Scene {
        MenuBarExtra("Murmur", systemImage: menubarSymbol) {
            Text(statusLabel)
            Divider()
            Button("Quit Murmur") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
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
        case .idle, .waiting: "Hold Right ⌥ to dictate"
        case .recording: "Recording…"
        case .processing: "Transcribing…"
        }
    }
}
