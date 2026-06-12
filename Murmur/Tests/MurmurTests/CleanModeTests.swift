import Testing
@testable import Murmur

@Suite struct CleanModeTests {
    @Test func bundleIDMapping() {
        #expect(CleanModeDetector.mode(forBundleID: "com.apple.Terminal", appName: "Terminal") == .technical)
        #expect(CleanModeDetector.mode(forBundleID: "com.mitchellh.ghostty", appName: "Ghostty") == .technical)
        #expect(CleanModeDetector.mode(forBundleID: "com.tinyspeck.slackmacgap", appName: "Slack") == .professional)
        #expect(CleanModeDetector.mode(forBundleID: "com.apple.MobileSMS", appName: "Messages") == .casual)
    }

    @Test func nameSubstringFallback() {
        #expect(CleanModeDetector.mode(forBundleID: "org.alacritty", appName: "Alacritty Terminal") == .technical)
        #expect(CleanModeDetector.mode(forBundleID: "com.example.x", appName: "SuperMail Pro") == .professional)
        #expect(CleanModeDetector.mode(forBundleID: "org.whispersystems.signal-desktop", appName: "Signal") == .casual)
    }

    @Test func unknownAppFallsBackToGeneral() {
        #expect(CleanModeDetector.mode(forBundleID: "com.example.unknown", appName: "Safari") == .general)
        #expect(CleanModeDetector.mode(forBundleID: "", appName: "") == .general)
    }

    @Test func bundleIDWinsOverName() {
        // Bundle map hit takes precedence over a name-substring match.
        #expect(CleanModeDetector.mode(forBundleID: "com.apple.mail", appName: "Mail") == .professional)
    }
}
