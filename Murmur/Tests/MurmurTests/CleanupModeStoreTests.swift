import Foundation
import Testing
@testable import Murmur

@MainActor
@Suite("CleanupModeStore")
struct CleanupModeStoreTests {

    /// A fresh store backed by a throwaway file.
    private func tempStore() -> (CleanupModeStore, URL) {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("murmur-modes-\(UUID().uuidString).json")
        return (CleanupModeStore(url: url), url)
    }

    @Test("built-in mappings are exposed for the UI")
    func builtInsVisible() {
        let (store, _) = tempStore()
        let terminal = store.builtIns.first { $0.bundleID == "com.apple.Terminal" }
        #expect(terminal?.mode == .technical)
        #expect(store.builtIns.contains { $0.mode == .professional })
        #expect(store.builtIns.contains { $0.mode == .casual })
    }

    @Test("overriding a built-in changes its effective mode and persists")
    func overrideBuiltIn() {
        let (store, url) = tempStore()
        #expect(store.mode(forBundleID: "com.apple.Terminal", appName: "Terminal") == .technical)

        store.setMode(.casual, forBundleID: "com.apple.Terminal", appName: "Terminal")
        #expect(store.mode(forBundleID: "com.apple.Terminal", appName: "Terminal") == .casual)

        let reopened = CleanupModeStore(url: url)
        #expect(reopened.mode(forBundleID: "com.apple.Terminal", appName: "Terminal") == .casual)
    }

    @Test("clearing an override reverts to the built-in default")
    func clearOverrideReverts() {
        let (store, _) = tempStore()
        store.setMode(.casual, forBundleID: "com.apple.Terminal", appName: "Terminal")
        store.clearOverride(bundleID: "com.apple.Terminal")
        #expect(store.mode(forBundleID: "com.apple.Terminal", appName: "Terminal") == .technical)
    }

    @Test("a custom app entry can be added and removed, behaving like a built-in")
    func customAppAddRemove() {
        let (store, url) = tempStore()
        // Unknown app falls back to general before any override.
        #expect(store.mode(forBundleID: "com.example.notes", appName: "Notes") == .general)

        store.setMode(.professional, forBundleID: "com.example.notes", appName: "Notes")
        #expect(store.mode(forBundleID: "com.example.notes", appName: "Notes") == .professional)
        #expect(store.customApps.contains { $0.bundleID == "com.example.notes" })

        let reopened = CleanupModeStore(url: url)
        #expect(reopened.mode(forBundleID: "com.example.notes", appName: "Notes") == .professional)

        reopened.clearOverride(bundleID: "com.example.notes")
        #expect(reopened.mode(forBundleID: "com.example.notes", appName: "Notes") == .general)
        #expect(!reopened.customApps.contains { $0.bundleID == "com.example.notes" })
    }

    @Test("body returns the built-in default when no prompt override is set")
    func bodyDefaults() {
        let (store, _) = tempStore()
        for mode in CleanMode.allCases {
            #expect(store.body(for: mode) == CleanupPrompts.defaultBody(for: mode))
            #expect(!store.hasPromptOverride(mode))
        }
    }

    @Test("a per-mode prompt override is used, persists, and can be reset")
    func promptOverridePersistsAndResets() {
        let (store, url) = tempStore()
        store.setPrompt("Custom technical instructions.", for: .technical)
        #expect(store.body(for: .technical) == "Custom technical instructions.")
        #expect(store.hasPromptOverride(.technical))

        let reopened = CleanupModeStore(url: url)
        #expect(reopened.body(for: .technical) == "Custom technical instructions.")

        reopened.resetPrompt(for: .technical)
        #expect(reopened.body(for: .technical) == CleanupPrompts.defaultBody(for: .technical))
        #expect(!reopened.hasPromptOverride(.technical))
    }
}
