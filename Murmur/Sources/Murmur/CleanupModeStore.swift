import Foundation

/// JSON-backed store for the user's Cleanup Modes customisation: per-app mode
/// overrides (including custom apps) and per-mode prompt edits. Observable for
/// the UI; the dictation controller reads it live so changes take effect on the
/// next dictation without a restart.
@MainActor
@Observable
final class CleanupModeStore {
    static let shared = CleanupModeStore()

    /// User overrides of built-ins plus custom app entries, keyed by bundle id.
    private(set) var overrides: [AppModeMapping] = []
    /// Per-mode instruction overrides; an absent mode uses the built-in default.
    private(set) var promptOverrides: [CleanMode: String] = [:]

    private let url: URL

    init(url: URL = CleanupModeStore.defaultURL) {
        self.url = url
        if let state = Self.load(from: url) {
            overrides = state.overrides
            promptOverrides = Dictionary(uniqueKeysWithValues:
                state.promptOverrides.compactMap { key, value in
                    CleanMode(rawValue: key).map { ($0, value) }
                })
        }
    }

    // MARK: App → mode mappings

    /// The shipped mappings, shown in the UI as the built-in rows.
    var builtIns: [AppModeMapping] { CleanModeDetector.builtIns }

    /// Overrides for apps that are not built-ins — the user's custom entries.
    var customApps: [AppModeMapping] {
        let builtInIDs = Set(builtIns.map(\.bundleID))
        return overrides.filter { !builtInIDs.contains($0.bundleID) }
    }

    private var overrideMap: [String: CleanMode] {
        Dictionary(uniqueKeysWithValues: overrides.map { ($0.bundleID, $0.mode) })
    }

    /// The mode for an app, honouring overrides over built-ins and the fallback.
    func mode(forBundleID bundleID: String, appName: String) -> CleanMode {
        CleanModeDetector.mode(forBundleID: bundleID, appName: appName, overrides: overrideMap)
    }

    /// The effective mode shown for a built-in row: its override or its default.
    func effectiveMode(for mapping: AppModeMapping) -> CleanMode {
        overrideMap[mapping.bundleID] ?? mapping.mode
    }

    func isOverridden(_ bundleID: String) -> Bool {
        overrides.contains { $0.bundleID == bundleID }
    }

    func setMode(_ mode: CleanMode, forBundleID bundleID: String, appName: String) {
        if let i = overrides.firstIndex(where: { $0.bundleID == bundleID }) {
            overrides[i].mode = mode
            overrides[i].appName = appName
        } else {
            overrides.append(AppModeMapping(bundleID: bundleID, appName: appName, mode: mode))
        }
        save()
    }

    /// Drop an override: a built-in reverts to its default, a custom app is removed.
    func clearOverride(bundleID: String) {
        overrides.removeAll { $0.bundleID == bundleID }
        save()
    }

    // MARK: Per-mode prompts

    /// The instruction text used for a mode: the user's edit or the built-in.
    func body(for mode: CleanMode) -> String {
        promptOverrides[mode] ?? CleanupPrompts.defaultBody(for: mode)
    }

    func hasPromptOverride(_ mode: CleanMode) -> Bool { promptOverrides[mode] != nil }

    func setPrompt(_ text: String, for mode: CleanMode) {
        promptOverrides[mode] = text
        save()
    }

    func resetPrompt(for mode: CleanMode) {
        promptOverrides[mode] = nil
        save()
    }

    // MARK: Persistence

    private struct State: Codable {
        var overrides: [AppModeMapping] = []
        var promptOverrides: [String: String] = [:]
    }

    private func save() {
        let state = State(
            overrides: overrides,
            promptOverrides: Dictionary(uniqueKeysWithValues:
                promptOverrides.map { ($0.key.rawValue, $0.value) }))
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: url)
    }

    private static func load(from url: URL) -> State? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(State.self, from: data)
    }

    static var defaultURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Murmur", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("cleanup-modes.json")
    }
}
