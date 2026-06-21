import ApplicationServices
import FluidAudio
import Foundation
import Observation

/// Downloads the Parakeet model, reporting fractional progress. Injectable so
/// the wizard's download state machine can be tested without touching the
/// network; `live` wraps FluidAudio's cached, idempotent downloader.
struct ModelDownloader: Sendable {
    /// `true` when the model is already on disk, so the step can skip straight
    /// to ready instead of re-downloading.
    var isReady: @Sendable () -> Bool
    /// Yields fractions in [0, 1] as the download proceeds, then finishes. A
    /// thrown error finishes the stream with that error.
    var progress: @Sendable () -> AsyncThrowingStream<Double, Error>

    static let live = ModelDownloader(
        isReady: { AsrModels.modelsExist(at: AsrModels.defaultCacheDirectory(for: .v3)) },
        progress: {
            AsyncThrowingStream { continuation in
                let task = Task {
                    do {
                        _ = try await AsrModels.downloadAndLoad(version: .v3) { snapshot in
                            continuation.yield(snapshot.fractionCompleted)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        })
}

/// Drives the onboarding wizard: step navigation, the model-download state
/// machine with retry, accessibility-grant detection, and persisting the
/// entered API key. Side effects (permission prompts, the real download) are
/// injected so the whole flow is unit-testable.
@MainActor
@Observable
final class OnboardingModel {
    /// Where the model-download step is in its lifecycle.
    enum ModelPhase: Equatable {
        case idle
        case downloading(Double)
        case ready
        case failed(String)
    }

    private(set) var step: OnboardingStep
    private(set) var modelPhase: ModelPhase = .idle
    /// Mirrors the key field; persisted to the Keychain when the step advances.
    var apiKey: String

    private let settings: Settings
    private let keychain: KeychainStore
    private let downloader: ModelDownloader
    private let isAccessibilityTrusted: @Sendable () -> Bool

    init(settings: Settings = .shared,
         keychain: KeychainStore = .openAIKey,
         downloader: ModelDownloader = .live,
         isAccessibilityTrusted: @escaping @Sendable () -> Bool = { AXIsProcessTrustedShim() },
         startAt: OnboardingStep = .welcome) {
        self.settings = settings
        self.keychain = keychain
        self.downloader = downloader
        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.step = startAt
        self.apiKey = keychain.read() ?? ""
    }

    var isFirst: Bool { step.previous == nil }
    var isLast: Bool { step.next == nil }

    func back() {
        if let previous = step.previous { step = previous }
    }

    /// Advance to the next step, committing the API key when leaving that step;
    /// on the last step this finishes the wizard.
    func advance() {
        if step == .apiKey { commitAPIKey() }
        if let next = step.next {
            step = next
        } else {
            finish()
        }
    }

    /// Mark onboarding complete so it never auto-runs again.
    func finish() {
        settings.onboardingCompleted = true
    }

    /// Download the model (or recognise it is already present), driving
    /// `modelPhase`. Safe to call again to retry after a failure.
    func downloadModel() async {
        if downloader.isReady() {
            modelPhase = .ready
            return
        }
        modelPhase = .downloading(0)
        do {
            for try await fraction in downloader.progress() {
                modelPhase = .downloading(fraction)
            }
            modelPhase = .ready
        } catch {
            modelPhase = .failed(error.localizedDescription)
        }
    }

    /// On the accessibility step, advance as soon as the grant is detected.
    /// Driven by a poll timer in the view.
    func pollAccessibility() {
        guard step == .accessibility, isAccessibilityTrusted() else { return }
        advance()
    }

    private func commitAPIKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            keychain.delete()
        } else {
            keychain.write(trimmed)
        }
    }
}

/// Thin wrapper so the default accessibility probe is a plain `@Sendable`
/// function; `AXIsProcessTrusted` is the system check for the Accessibility
/// permission that paste (`CGEvent ⌘V`) requires.
func AXIsProcessTrustedShim() -> Bool {
    AXIsProcessTrusted()
}
