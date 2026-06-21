import Foundation
import Testing
@testable import Murmur

@MainActor
@Suite("OnboardingModel")
struct OnboardingModelTests {
    /// An isolated UserDefaults domain so tests never touch real preferences.
    private func freshSettings() -> (Settings, UserDefaults, () -> Void) {
        let name = "murmur.tests.onboarding.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        return (Settings(defaults: defaults), defaults, { defaults.removePersistentDomain(forName: name) })
    }

    /// A keychain in a throwaway service so API-key tests don't collide.
    private func freshKeychain() -> KeychainStore {
        KeychainStore(service: "com.murmur.tests.onboarding.\(UUID().uuidString)", account: "api-key")
    }

    private func model(settings: Settings,
                       keychain: KeychainStore? = nil,
                       downloader: ModelDownloader = .stub(),
                       trusted: @escaping @Sendable () -> Bool = { false },
                       startAt: OnboardingStep = .welcome) -> OnboardingModel {
        OnboardingModel(settings: settings, keychain: keychain ?? freshKeychain(),
                        downloader: downloader, isAccessibilityTrusted: trusted, startAt: startAt)
    }

    // MARK: first-launch flag

    @Test("onboarding has not run on a fresh profile")
    func freshProfileNeedsOnboarding() {
        let (settings, _, cleanup) = freshSettings(); defer { cleanup() }
        #expect(settings.onboardingCompleted == false)
    }

    @Test("finishing marks onboarding complete and it persists")
    func finishPersists() {
        let (settings, defaults, cleanup) = freshSettings(); defer { cleanup() }
        model(settings: settings).finish()
        #expect(settings.onboardingCompleted)
        #expect(Settings(defaults: defaults).onboardingCompleted)
    }

    // MARK: navigation

    @Test("advance walks forward and finishes on the last step")
    func advanceFinishes() {
        let (settings, _, cleanup) = freshSettings(); defer { cleanup() }
        let m = model(settings: settings, startAt: .tryIt)
        #expect(m.isLast)
        m.advance()
        #expect(settings.onboardingCompleted)
    }

    @Test("back walks backward and stops at the first step")
    func backStops() {
        let (settings, _, cleanup) = freshSettings(); defer { cleanup() }
        let m = model(settings: settings, startAt: .microphone)
        m.back()
        #expect(m.step == .welcome)
        #expect(m.isFirst)
        m.back()
        #expect(m.step == .welcome)
    }

    // MARK: model download

    @Test("download reports progress then becomes ready")
    func downloadProgressThenReady() async {
        let (settings, _, cleanup) = freshSettings(); defer { cleanup() }
        let m = model(settings: settings, downloader: .stub(fractions: [0.25, 0.75]))
        await m.downloadModel()
        #expect(m.modelPhase == .ready)
    }

    @Test("an already-downloaded model skips straight to ready")
    func alreadyDownloaded() async {
        let (settings, _, cleanup) = freshSettings(); defer { cleanup() }
        let m = model(settings: settings, downloader: .stub(ready: true))
        await m.downloadModel()
        #expect(m.modelPhase == .ready)
    }

    @Test("a failed download surfaces the error and can be retried")
    func failedThenRetry() async {
        let (settings, _, cleanup) = freshSettings(); defer { cleanup() }
        let m = model(settings: settings, downloader: .stub(error: "boom"))
        await m.downloadModel()
        if case .failed(let message) = m.modelPhase {
            #expect(message.contains("boom"))
        } else {
            Issue.record("expected .failed, got \(m.modelPhase)")
        }
        // Retry with a downloader that now succeeds.
        let retry = OnboardingModel(settings: settings, keychain: freshKeychain(),
                                    downloader: .stub(fractions: [1.0]),
                                    isAccessibilityTrusted: { false }, startAt: .model)
        await retry.downloadModel()
        #expect(retry.modelPhase == .ready)
    }

    // MARK: accessibility auto-advance

    @Test("accessibility step auto-advances once the grant is detected")
    func accessibilityAutoAdvances() {
        let (settings, _, cleanup) = freshSettings(); defer { cleanup() }
        let granted = LockedFlag()
        let m = model(settings: settings, trusted: { granted.value }, startAt: .accessibility)
        m.pollAccessibility()
        #expect(m.step == .accessibility)  // not yet granted
        granted.value = true
        m.pollAccessibility()
        #expect(m.step == .apiKey)
    }

    @Test("polling on other steps does nothing")
    func pollIgnoredOffStep() {
        let (settings, _, cleanup) = freshSettings(); defer { cleanup() }
        let m = model(settings: settings, trusted: { true }, startAt: .welcome)
        m.pollAccessibility()
        #expect(m.step == .welcome)
    }

    // MARK: API key

    @Test("a key entered in the wizard lands in the Keychain")
    func apiKeySaved() {
        let (settings, _, cleanup) = freshSettings(); defer { cleanup() }
        let keychain = freshKeychain(); defer { keychain.delete() }
        let m = model(settings: settings, keychain: keychain, startAt: .apiKey)
        m.apiKey = "  sk-live-123  "
        m.advance()
        #expect(keychain.read() == "sk-live-123")
    }

    @Test("skipping the key step leaves no Keychain entry")
    func apiKeySkipped() {
        let (settings, _, cleanup) = freshSettings(); defer { cleanup() }
        let keychain = freshKeychain(); defer { keychain.delete() }
        let m = model(settings: settings, keychain: keychain, startAt: .apiKey)
        m.advance()
        #expect(keychain.read() == nil)
    }
}

/// A tiny mutable flag usable from a `@Sendable` probe closure in tests.
final class LockedFlag: @unchecked Sendable {
    var value = false
}

extension ModelDownloader {
    /// A deterministic in-memory downloader for tests.
    static func stub(ready: Bool = false, fractions: [Double] = [], error: String? = nil) -> ModelDownloader {
        ModelDownloader(
            isReady: { ready },
            progress: {
                AsyncThrowingStream { continuation in
                    for fraction in fractions { continuation.yield(fraction) }
                    if let error {
                        continuation.finish(throwing: StubError(message: error))
                    } else {
                        continuation.finish()
                    }
                }
            })
    }
}

private struct StubError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
