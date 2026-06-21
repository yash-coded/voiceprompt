import AppKit
import SwiftUI

/// Owns the onboarding window. Shown automatically on first launch and
/// re-runnable from Settings; closing it leaves the app fully usable with no
/// restart, since the dictation pipeline is already running.
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    /// Show the wizard, reusing the existing window if it is still open.
    @MainActor
    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = OnboardingView(model: OnboardingModel()) { [weak self] in self?.window?.close() }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 460),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false)
        window.title = "Welcome to Murmur"
        window.contentView = NSHostingView(rootView: view)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Dismissing the wizard by any means counts as having seen it, so it never
    /// auto-runs again; it stays reachable from Settings.
    @MainActor
    func windowWillClose(_ notification: Notification) {
        Settings.shared.onboardingCompleted = true
        window = nil
    }
}
