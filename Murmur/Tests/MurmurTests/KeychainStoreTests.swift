import Testing
@testable import Murmur

@Suite struct KeychainStoreTests {
    @Test func writeReadUpdateDeleteRoundtrip() {
        let store = KeychainStore(service: "com.murmur.tests", account: "roundtrip")
        defer { store.delete() }

        #expect(store.read() == nil)
        #expect(store.write("sk-first"))
        #expect(store.read() == "sk-first")
        #expect(store.write("sk-second"))
        #expect(store.read() == "sk-second")
        #expect(store.delete())
        #expect(store.read() == nil)
    }
}
