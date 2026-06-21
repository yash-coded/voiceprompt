import AppKit
import Foundation
import Observation

/// A modifier key that can be held to dictate. The flagsChanged monitor reports
/// which physical key changed (`keyCode`) and the currently active modifier
/// flags; `pressState` turns that into pressed/released for the chosen key.
enum HotkeyModifier: String, CaseIterable, Sendable {
    case rightOption, leftOption, rightCommand, rightControl, fn

    var keyCode: UInt16 {
        switch self {
        case .rightOption: 61
        case .leftOption: 58
        case .rightCommand: 54
        case .rightControl: 62
        case .fn: 63
        }
    }

    var flag: NSEvent.ModifierFlags {
        switch self {
        case .rightOption, .leftOption: .option
        case .rightCommand: .command
        case .rightControl: .control
        case .fn: .function
        }
    }

    var label: String {
        switch self {
        case .rightOption: "Right ⌥"
        case .leftOption: "Left ⌥"
        case .rightCommand: "Right ⌘"
        case .rightControl: "Right ⌃"
        case .fn: "Fn"
        }
    }

    /// `true`/`false` if a flagsChanged event for this modifier means it was
    /// just pressed/released; `nil` if the event is for some other key.
    func pressState(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool? {
        guard keyCode == self.keyCode else { return nil }
        return flags.contains(flag)
    }
}

/// How long dictation history is kept. `days` is the prune cutoff slice 05 will
/// enforce: `0` keeps nothing, `nil` keeps everything.
enum HistoryRetention: String, CaseIterable, Sendable {
    case off, sevenDays, thirtyDays, forever

    var days: Int? {
        switch self {
        case .off: 0
        case .sevenDays: 7
        case .thirtyDays: 30
        case .forever: nil
        }
    }

    var label: String {
        switch self {
        case .off: "Off"
        case .sevenDays: "7 days"
        case .thirtyDays: "30 days"
        case .forever: "Forever"
        }
    }
}

/// Picks the audio device to record from: the chosen device when it is still
/// connected, otherwise `nil` to mean "use the system default".
enum AudioDeviceResolver {
    static func resolve(chosen: String?, available: [String]) -> String? {
        guard let chosen, available.contains(chosen) else { return nil }
        return chosen
    }
}

/// Single source of truth for user preferences, observable for SwiftUI and
/// write-through persisted to UserDefaults. The API key lives in the Keychain
/// (`KeychainStore.openAIKey`), not here. Every change takes effect on the next
/// dictation without restarting because the controller reads these live.
@MainActor
@Observable
final class Settings {
    static let shared = Settings()

    var inputDeviceUID: String? { didSet { defaults.set(inputDeviceUID, forKey: Keys.inputDeviceUID) } }
    var hotkeyModifier: HotkeyModifier { didSet { defaults.set(hotkeyModifier.rawValue, forKey: Keys.hotkeyModifier) } }
    var holdThreshold: TimeInterval { didSet { defaults.set(holdThreshold, forKey: Keys.holdThreshold) } }
    var cleanupEnabled: Bool { didSet { defaults.set(cleanupEnabled, forKey: Keys.cleanupEnabled) } }
    var historyRetention: HistoryRetention { didSet { defaults.set(historyRetention.rawValue, forKey: Keys.historyRetention) } }
    /// `false` until the onboarding wizard finishes, so it auto-runs on the
    /// first launch only and can be re-run on demand from Settings.
    var onboardingCompleted: Bool { didSet { defaults.set(onboardingCompleted, forKey: Keys.onboardingCompleted) } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        inputDeviceUID = defaults.string(forKey: Keys.inputDeviceUID)
        hotkeyModifier = defaults.string(forKey: Keys.hotkeyModifier)
            .flatMap(HotkeyModifier.init) ?? .rightOption
        holdThreshold = defaults.object(forKey: Keys.holdThreshold) as? TimeInterval ?? Murmur.holdThreshold
        cleanupEnabled = defaults.object(forKey: Keys.cleanupEnabled) as? Bool ?? true
        historyRetention = defaults.string(forKey: Keys.historyRetention)
            .flatMap(HistoryRetention.init) ?? .thirtyDays
        onboardingCompleted = defaults.bool(forKey: Keys.onboardingCompleted)
    }

    private enum Keys {
        static let inputDeviceUID = "inputDeviceUID"
        static let hotkeyModifier = "hotkeyModifier"
        static let holdThreshold = "holdThreshold"
        static let cleanupEnabled = "cleanupEnabled"
        static let historyRetention = "historyRetention"
        static let onboardingCompleted = "onboardingCompleted"
    }
}
