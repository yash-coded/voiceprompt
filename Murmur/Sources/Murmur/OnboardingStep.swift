import Foundation

/// The ordered steps of the first-launch onboarding wizard. The raw values fix
/// the order; `next`/`previous` walk it and return `nil` at the ends.
enum OnboardingStep: Int, CaseIterable, Identifiable, Sendable {
    case welcome, microphone, model, accessibility, apiKey, tryIt

    var id: Int { rawValue }

    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }

    var title: String {
        switch self {
        case .welcome: "Welcome to Murmur"
        case .microphone: "Microphone Access"
        case .model: "Download the Speech Model"
        case .accessibility: "Accessibility Access"
        case .apiKey: "Cleanup with OpenAI"
        case .tryIt: "Try It Now"
        }
    }

    var systemImage: String {
        switch self {
        case .welcome: "waveform"
        case .microphone: "mic"
        case .model: "arrow.down.circle"
        case .accessibility: "accessibility"
        case .apiKey: "wand.and.stars"
        case .tryIt: "checkmark.seal"
        }
    }
}
