import Testing
@testable import Murmur

final class FakePasteboard: Pasteboard {
    var contents: String?
    var history: [String?] = []

    func readString() -> String? { contents }
    func writeString(_ string: String) {
        contents = string
        history.append(string)
    }
    func clear() {
        contents = nil
        history.append(nil)
    }
}

@Suite("TranscriptPaster")
struct TranscriptPasterTests {

    @Test("sets transcript, sends Cmd-V, restores prior clipboard")
    func restoresPriorClipboard() {
        let pb = FakePasteboard()
        pb.contents = "prior contents"
        var pasted = false
        let paster = TranscriptPaster(pasteboard: pb, sendCmdV: { pasted = true }, restoreDelay: 0)
        paster.paste("hello world")
        #expect(pasted)
        #expect(pb.history.first == "hello world")
        #expect(pb.contents == "prior contents")
    }

    @Test("empty prior clipboard is cleared back to empty after paste")
    func emptyPriorClipboard() {
        let pb = FakePasteboard()
        pb.contents = nil
        let paster = TranscriptPaster(pasteboard: pb, sendCmdV: {}, restoreDelay: 0)
        paster.paste("hello")
        #expect(pb.contents == nil)
    }
}
