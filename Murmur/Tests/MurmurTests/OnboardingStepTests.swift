import Testing
@testable import Murmur

@Suite("OnboardingStep")
struct OnboardingStepTests {
    @Test("steps are ordered welcome → tryIt")
    func order() {
        #expect(OnboardingStep.allCases == [
            .welcome, .microphone, .model, .accessibility, .apiKey, .tryIt,
        ])
    }

    @Test("next walks forward and stops at the end")
    func next() {
        #expect(OnboardingStep.welcome.next == .microphone)
        #expect(OnboardingStep.apiKey.next == .tryIt)
        #expect(OnboardingStep.tryIt.next == nil)
    }

    @Test("previous walks back and stops at the start")
    func previous() {
        #expect(OnboardingStep.tryIt.previous == .apiKey)
        #expect(OnboardingStep.microphone.previous == .welcome)
        #expect(OnboardingStep.welcome.previous == nil)
    }
}
