import AppKit
import Testing
@testable import Murmur

@MainActor
@Suite("FloatingPanel")
struct FloatingPanelTests {

    @Test("never becomes key or main, so it cannot steal focus")
    func neverTakesFocus() {
        let panel = FloatingPanel()
        #expect(panel.canBecomeKey == false)
        #expect(panel.canBecomeMain == false)
    }

    @Test("is a non-activating panel")
    func isNonActivating() {
        let panel = FloatingPanel()
        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(panel.isFloatingPanel)
    }

    @Test("floats above normal and floating windows")
    func floatsAboveOtherWindows() {
        let panel = FloatingPanel()
        #expect(panel.level.rawValue >= NSWindow.Level.floating.rawValue)
    }

    @Test("joins all spaces and shows over full-screen apps")
    func spansSpacesAndFullScreen() {
        let panel = FloatingPanel()
        #expect(panel.collectionBehavior.contains(.canJoinAllSpaces))
        #expect(panel.collectionBehavior.contains(.fullScreenAuxiliary))
    }

    @Test("lets clicks pass through to the app underneath")
    func clickThrough() {
        let panel = FloatingPanel()
        #expect(panel.ignoresMouseEvents)
    }

    @Test("stays visible when the app is deactivated")
    func staysVisibleOnDeactivate() {
        let panel = FloatingPanel()
        #expect(panel.hidesOnDeactivate == false)
    }
}
