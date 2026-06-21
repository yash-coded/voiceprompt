import Testing
@testable import Murmur

@Suite("AudioDeviceResolver")
struct AudioDeviceResolverTests {

    @Test("uses the chosen device when it is still connected")
    func chosenPresent() {
        #expect(AudioDeviceResolver.resolve(chosen: "b", available: ["a", "b"]) == "b")
    }

    @Test("falls back to the system default when the chosen device disconnects")
    func chosenDisconnected() {
        #expect(AudioDeviceResolver.resolve(chosen: "z", available: ["a", "b"]) == nil)
    }

    @Test("no choice means the system default")
    func noChoice() {
        #expect(AudioDeviceResolver.resolve(chosen: nil, available: ["a"]) == nil)
    }
}
