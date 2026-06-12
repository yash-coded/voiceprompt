import AppKit

/// Cleanup style derived from the frontmost application at key-press time.
enum CleanMode: String, CaseIterable, Sendable {
    case technical      // Claude, terminals, code editors — preserve every detail
    case professional   // Teams, Slack, email — polished but friendly
    case casual         // iMessage, WhatsApp, Discord — light touch, keep voice
    case general        // everything else — balanced cleanup
}

/// Bundle identifier → CleanMode, with an app-name substring fallback.
/// Mirrors the Python reference (`src/voiceprompt/context.py`).
enum CleanModeDetector {
    static let bundleMap: [String: CleanMode] = [
        // Claude
        "com.anthropic.claudefordesktop": .technical,
        // Terminals
        "com.apple.Terminal": .technical,
        "com.googlecode.iterm2": .technical,
        "dev.warp.desktop": .technical,
        "com.github.wez.wezterm": .technical,
        "net.kovidgoyal.kitty": .technical,
        "com.mitchellh.ghostty": .technical,
        // Code editors / IDEs
        "com.microsoft.VSCode": .technical,
        "com.microsoft.VSCodeInsiders": .technical,
        "com.todesktop.230313mzl4w4u92": .technical,  // Cursor
        "com.jetbrains.intellij": .technical,
        "com.jetbrains.pycharm": .technical,
        "com.jetbrains.webstorm": .technical,
        "com.apple.dt.Xcode": .technical,
        // Work chat / email
        "com.microsoft.teams2": .professional,
        "com.microsoft.teams": .professional,
        "com.tinyspeck.slackmacgap": .professional,
        "com.apple.mail": .professional,
        "com.microsoft.Outlook": .professional,
        // Casual messaging
        "com.apple.MobileSMS": .casual,
        "com.apple.iChat": .casual,
        "com.discord": .casual,
        "ru.keepcoder.Telegram": .casual,
        "WhatsApp": .casual,
        "net.whatsapp.WhatsApp": .casual,
    ]

    private static let technicalNames = ["terminal", "iterm", "warp", "wezterm", "kitty",
                                         "ghostty", "code", "cursor", "claude", "xcode",
                                         "vim", "nvim", "emacs"]
    private static let professionalNames = ["teams", "slack", "mail", "outlook"]
    private static let casualNames = ["messages", "whatsapp", "telegram", "discord", "signal"]

    /// Pure mapping used by tests; `frontmostMode()` feeds it live values.
    static func mode(forBundleID bundleID: String, appName: String) -> CleanMode {
        if let mode = bundleMap[bundleID] { return mode }
        let name = appName.lowercased()
        if technicalNames.contains(where: name.contains) { return .technical }
        if professionalNames.contains(where: name.contains) { return .professional }
        if casualNames.contains(where: name.contains) { return .casual }
        return .general
    }

    @MainActor
    static func frontmostMode() -> CleanMode {
        guard let app = NSWorkspace.shared.frontmostApplication else { return .general }
        return mode(forBundleID: app.bundleIdentifier ?? "", appName: app.localizedName ?? "")
    }
}
