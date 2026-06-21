import AppKit
import Testing
@testable import Murmur

@Suite("HotkeyModifier")
struct HotkeyModifierTests {

    @Test("matches its own key code and flag")
    func matchesOwnEvent() {
        #expect(HotkeyModifier.rightOption.pressState(keyCode: 61, flags: .option) == true)
        #expect(HotkeyModifier.rightOption.pressState(keyCode: 61, flags: []) == false)
    }

    @Test("ignores events for other keys")
    func ignoresOtherKeys() {
        #expect(HotkeyModifier.rightOption.pressState(keyCode: 54, flags: .option) == nil)
    }

    @Test("fn uses the function flag")
    func fnUsesFunctionFlag() {
        #expect(HotkeyModifier.fn.pressState(keyCode: HotkeyModifier.fn.keyCode, flags: .function) == true)
        #expect(HotkeyModifier.fn.pressState(keyCode: HotkeyModifier.fn.keyCode, flags: []) == false)
    }

    @Test("every modifier has a distinct key code and a label")
    func distinctAndLabelled() {
        let codes = HotkeyModifier.allCases.map(\.keyCode)
        #expect(Set(codes).count == codes.count)
        #expect(HotkeyModifier.allCases.allSatisfy { !$0.label.isEmpty })
    }
}
