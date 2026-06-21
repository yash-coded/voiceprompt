import Foundation
import Testing
@testable import Murmur

@MainActor
@Suite("Settings")
struct SettingsTests {
    /// An isolated UserDefaults domain so tests never touch real preferences.
    private func freshDefaults() -> (UserDefaults, () -> Void) {
        let name = "murmur.tests.settings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        return (defaults, { defaults.removePersistentDomain(forName: name) })
    }

    @Test("ships with the locked-in defaults")
    func defaults() {
        let (d, cleanup) = freshDefaults(); defer { cleanup() }
        let settings = Settings(defaults: d)
        #expect(settings.hotkeyModifier == .rightOption)
        #expect(settings.holdThreshold == holdThreshold)
        #expect(settings.cleanupEnabled)
        #expect(settings.historyRetention == .thirtyDays)
        #expect(settings.inputDeviceUID == nil)
    }

    @Test("every setting persists across instances")
    func persistsAcrossInstances() {
        let (d, cleanup) = freshDefaults(); defer { cleanup() }
        let settings = Settings(defaults: d)
        settings.hotkeyModifier = .fn
        settings.holdThreshold = 0.8
        settings.cleanupEnabled = false
        settings.historyRetention = .sevenDays
        settings.inputDeviceUID = "device-123"

        let reloaded = Settings(defaults: d)
        #expect(reloaded.hotkeyModifier == .fn)
        #expect(reloaded.holdThreshold == 0.8)
        #expect(reloaded.cleanupEnabled == false)
        #expect(reloaded.historyRetention == .sevenDays)
        #expect(reloaded.inputDeviceUID == "device-123")
    }

    @Test("clearing the input device returns to the system default")
    func clearingDeviceReverts() {
        let (d, cleanup) = freshDefaults(); defer { cleanup() }
        let settings = Settings(defaults: d)
        settings.inputDeviceUID = "device-123"
        settings.inputDeviceUID = nil
        #expect(Settings(defaults: d).inputDeviceUID == nil)
    }
}
