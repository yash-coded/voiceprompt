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
            // Temporary debug mechanism until the slice-04 settings UI ships.
            Button("Set OpenAI API Key…") {
                promptForAPIKey()
            }
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

    /// Modal prompt that stores the key in the Keychain. Replaced by the
    /// settings window in slice 04.
    private func promptForAPIKey() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "OpenAI API Key"
        alert.informativeText = "Stored in the macOS Keychain. Leave empty to remove."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.stringValue = KeychainStore.openAIKey.read() ?? ""
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let key = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty {
            KeychainStore.openAIKey.delete()
        } else {
            KeychainStore.openAIKey.write(key)
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
