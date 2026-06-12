import AppKit

protocol Pasteboard {
    func readString() -> String?
    func writeString(_ string: String)
    func clear()
}

struct SystemPasteboard: Pasteboard {
    func readString() -> String? {
        NSPasteboard.general.string(forType: .string)
    }
    func writeString(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
    func clear() {
        NSPasteboard.general.clearContents()
    }
}

/// Pastes text into the frontmost app: save clipboard → set transcript →
/// synthesize Cmd-V → restore the prior clipboard contents.
struct TranscriptPaster {
    var pasteboard: Pasteboard = SystemPasteboard()
    var sendCmdV: () -> Void = synthesizeCmdV
    /// Delay between firing Cmd-V and restoring the clipboard, so the target
    /// app reads the transcript before it is swapped back.
    var restoreDelay: TimeInterval = 0.3

    func paste(_ text: String) {
        let prior = pasteboard.readString()
        pasteboard.writeString(text)
        // Give the pasteboard a beat to settle before the keystroke lands.
        Thread.sleep(forTimeInterval: min(restoreDelay, 0.05))
        sendCmdV()
        Thread.sleep(forTimeInterval: restoreDelay)
        if let prior {
            pasteboard.writeString(prior)
        } else {
            pasteboard.clear()
        }
    }
}

/// Synthesizes Cmd-V via CGEvent. Requires the Accessibility permission.
func synthesizeCmdV() {
    let source = CGEventSource(stateID: .combinedSessionState)
    let keyVDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
    let keyVUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
    keyVDown?.flags = .maskCommand
    keyVUp?.flags = .maskCommand
    keyVDown?.post(tap: .cghidEventTap)
    keyVUp?.post(tap: .cghidEventTap)
}
