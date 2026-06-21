import AppKit

/// Cleanup style derived from the frontmost application at key-press time.
enum CleanMode: String, CaseIterable, Codable, Sendable {
    case technical      // Claude, terminals, code editors — preserve every detail
    case professional   // Teams, Slack, email — polished but friendly
    case casual         // iMessage, WhatsApp, Discord — light touch, keep voice
    case general        // everything else — balanced cleanup

    var label: String {
        switch self {
        case .technical: "Technical"
        case .professional: "Professional"
        case .casual: "Casual"
        case .general: "General"
        }
    }
}

/// An app → cleanup-mode assignment: a built-in default, a user override of a
/// built-in, or a custom entry the user added for an app not in the built-ins.
struct AppModeMapping: Identifiable, Equatable, Codable, Sendable {
    var bundleID: String
    var appName: String
    var mode: CleanMode

    var id: String { bundleID }
}

/// Bundle identifier → CleanMode, with an app-name substring fallback.
/// Mirrors the Python reference (`src/voiceprompt/context.py`).
enum CleanModeDetector {
    /// The shipped app → mode assignments, in display order, each with a
    /// human-readable name for the Cleanup Modes UI.
    static let builtIns: [AppModeMapping] = [
        // Claude + terminals + editors → technical
        .init(bundleID: "com.anthropic.claudefordesktop", appName: "Claude", mode: .technical),
        .init(bundleID: "com.apple.Terminal", appName: "Terminal", mode: .technical),
        .init(bundleID: "com.googlecode.iterm2", appName: "iTerm", mode: .technical),
        .init(bundleID: "dev.warp.desktop", appName: "Warp", mode: .technical),
        .init(bundleID: "com.github.wez.wezterm", appName: "WezTerm", mode: .technical),
        .init(bundleID: "net.kovidgoyal.kitty", appName: "kitty", mode: .technical),
        .init(bundleID: "com.mitchellh.ghostty", appName: "Ghostty", mode: .technical),
        .init(bundleID: "com.microsoft.VSCode", appName: "VS Code", mode: .technical),
        .init(bundleID: "com.microsoft.VSCodeInsiders", appName: "VS Code Insiders", mode: .technical),
        .init(bundleID: "com.todesktop.230313mzl4w4u92", appName: "Cursor", mode: .technical),
        .init(bundleID: "com.jetbrains.intellij", appName: "IntelliJ IDEA", mode: .technical),
        .init(bundleID: "com.jetbrains.pycharm", appName: "PyCharm", mode: .technical),
        .init(bundleID: "com.jetbrains.webstorm", appName: "WebStorm", mode: .technical),
        .init(bundleID: "com.apple.dt.Xcode", appName: "Xcode", mode: .technical),
        // Work chat / email → professional
        .init(bundleID: "com.microsoft.teams2", appName: "Microsoft Teams", mode: .professional),
        .init(bundleID: "com.microsoft.teams", appName: "Microsoft Teams (classic)", mode: .professional),
        .init(bundleID: "com.tinyspeck.slackmacgap", appName: "Slack", mode: .professional),
        .init(bundleID: "com.apple.mail", appName: "Mail", mode: .professional),
        .init(bundleID: "com.microsoft.Outlook", appName: "Outlook", mode: .professional),
        // Casual messaging → casual
        .init(bundleID: "com.apple.MobileSMS", appName: "Messages", mode: .casual),
        .init(bundleID: "com.apple.iChat", appName: "Messages (legacy)", mode: .casual),
        .init(bundleID: "com.discord", appName: "Discord", mode: .casual),
        .init(bundleID: "ru.keepcoder.Telegram", appName: "Telegram", mode: .casual),
        .init(bundleID: "net.whatsapp.WhatsApp", appName: "WhatsApp", mode: .casual),
    ]

    static let bundleMap: [String: CleanMode] =
        Dictionary(uniqueKeysWithValues: builtIns.map { ($0.bundleID, $0.mode) })

    private static let technicalNames = ["terminal", "iterm", "warp", "wezterm", "kitty",
                                         "ghostty", "code", "cursor", "claude", "xcode",
                                         "vim", "nvim", "emacs"]
    private static let professionalNames = ["teams", "slack", "mail", "outlook"]
    private static let casualNames = ["messages", "whatsapp", "telegram", "discord", "signal"]

    /// Pure mapping; `CleanupModeStore` feeds it live frontmost-app values and
    /// the user's `overrides` (bundle id → mode), which take precedence over the
    /// built-in map and the name-substring fallback.
    static func mode(forBundleID bundleID: String, appName: String,
                     overrides: [String: CleanMode] = [:]) -> CleanMode {
        if let mode = overrides[bundleID] { return mode }
        if let mode = bundleMap[bundleID] { return mode }
        let name = appName.lowercased()
        if technicalNames.contains(where: name.contains) { return .technical }
        if professionalNames.contains(where: name.contains) { return .professional }
        if casualNames.contains(where: name.contains) { return .casual }
        return .general
    }
}
