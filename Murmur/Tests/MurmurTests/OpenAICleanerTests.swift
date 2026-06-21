import Foundation
import Testing
@testable import Murmur

private func okResponse(content: String) -> (Data, URLResponse) {
    let json: [String: Any] = [
        "choices": [["message": ["role": "assistant", "content": content]]]
    ]
    let data = try! JSONSerialization.data(withJSONObject: json)
    let response = HTTPURLResponse(
        url: OpenAICleaner.endpoint, statusCode: 200, httpVersion: nil, headerFields: nil)!
    return (data, response)
}

@Suite struct OpenAICleanerTests {
    @Test func returnsCleanedTextOnSuccess() async {
        var cleaner = OpenAICleaner()
        cleaner.apiKeyProvider = { "sk-test" }
        cleaner.transport = { _ in okResponse(content: "Fix the login bug.") }
        let result = await cleaner.clean("um fix the uh login bug", mode: .technical, clipboardContext: "")
        #expect(result == "Fix the login bug.")
    }

    @Test func stripsLLMPreamble() async {
        var cleaner = OpenAICleaner()
        cleaner.apiKeyProvider = { "sk-test" }
        cleaner.transport = { _ in okResponse(content: "Here is the cleaned text:\n\nFix the bug.") }
        let result = await cleaner.clean("fix bug", mode: .general, clipboardContext: "")
        #expect(result == "Fix the bug.")
    }

    @Test func requestCarriesModeAndClipboard() async throws {
        let captured = Captured()
        var cleaner = OpenAICleaner()
        cleaner.apiKeyProvider = { "sk-test" }
        cleaner.transport = { request in
            await captured.set(request)
            return okResponse(content: "ok")
        }
        _ = await cleaner.clean("hello", mode: .casual, clipboardContext: "clip text")

        let request = await captured.get()
        let body = try JSONSerialization.jsonObject(with: request!.httpBody!) as! [String: Any]
        #expect(body["model"] as? String == "gpt-5-mini")
        let messages = body["messages"] as! [[String: String]]
        #expect(messages[0]["role"] == "system")
        #expect(messages[0]["content"] == CleanupPrompts.systemPrompt(for: .casual))
        #expect(messages[1]["role"] == "user")
        #expect(messages[1]["content"]!.contains("clip text"))
        #expect(request!.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
        #expect(request!.timeoutInterval == 2.0)
    }

    @Test func personalTermsFlowIntoSystemPrompt() async throws {
        let captured = Captured()
        var cleaner = OpenAICleaner()
        cleaner.apiKeyProvider = { "sk-test" }
        cleaner.transport = { request in
            await captured.set(request)
            return okResponse(content: "ok")
        }
        _ = await cleaner.clean("hello", mode: .technical, clipboardContext: "",
                                personalTerms: ["Murmur", "Parakeet"])

        let request = await captured.get()
        let body = try JSONSerialization.jsonObject(with: request!.httpBody!) as! [String: Any]
        let messages = body["messages"] as! [[String: String]]
        #expect(messages[0]["content"]!.contains("Murmur, Parakeet"))
    }

    @Test func customPromptBodyFlowsIntoSystemPrompt() async throws {
        let captured = Captured()
        var cleaner = OpenAICleaner()
        cleaner.apiKeyProvider = { "sk-test" }
        cleaner.transport = { request in
            await captured.set(request)
            return okResponse(content: "ok")
        }
        _ = await cleaner.clean("hello", mode: .technical, clipboardContext: "",
                                personalTerms: [], promptBody: "Custom mode instructions.")

        let request = await captured.get()
        let body = try JSONSerialization.jsonObject(with: request!.httpBody!) as! [String: Any]
        let messages = body["messages"] as! [[String: String]]
        #expect(messages[0]["content"]!.contains("Custom mode instructions."))
    }

    @Test func noKeyReturnsRawTranscript() async {
        var cleaner = OpenAICleaner()
        cleaner.apiKeyProvider = { nil }
        cleaner.transport = { _ in
            Issue.record("transport must not be called without a key")
            return okResponse(content: "x")
        }
        let result = await cleaner.clean("raw text", mode: .general, clipboardContext: "")
        #expect(result == "raw text")
    }

    @Test func transportErrorReturnsRawTranscript() async {
        var cleaner = OpenAICleaner()
        cleaner.apiKeyProvider = { "sk-test" }
        cleaner.transport = { _ in throw URLError(.notConnectedToInternet) }
        let result = await cleaner.clean("raw text", mode: .general, clipboardContext: "")
        #expect(result == "raw text")
    }

    @Test func timeoutReturnsRawTranscript() async {
        var cleaner = OpenAICleaner()
        cleaner.apiKeyProvider = { "sk-test" }
        cleaner.transport = { _ in throw URLError(.timedOut) }
        let result = await cleaner.clean("raw text", mode: .general, clipboardContext: "")
        #expect(result == "raw text")
    }

    @Test func httpErrorReturnsRawTranscript() async {
        var cleaner = OpenAICleaner()
        cleaner.apiKeyProvider = { "sk-test" }
        cleaner.transport = { _ in
            let response = HTTPURLResponse(
                url: OpenAICleaner.endpoint, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (Data("{}".utf8), response)
        }
        let result = await cleaner.clean("raw text", mode: .general, clipboardContext: "")
        #expect(result == "raw text")
    }

    @Test func emptyResponseReturnsRawTranscript() async {
        var cleaner = OpenAICleaner()
        cleaner.apiKeyProvider = { "sk-test" }
        cleaner.transport = { _ in okResponse(content: "   ") }
        let result = await cleaner.clean("raw text", mode: .general, clipboardContext: "")
        #expect(result == "raw text")
    }

    @Test func emptyTranscriptSkipsAPICall() async {
        var cleaner = OpenAICleaner()
        cleaner.apiKeyProvider = { "sk-test" }
        cleaner.transport = { _ in
            Issue.record("transport must not be called for empty transcript")
            return okResponse(content: "x")
        }
        let result = await cleaner.clean("  ", mode: .general, clipboardContext: "")
        #expect(result == "  ")
    }
}

private actor Captured {
    private var request: URLRequest?
    func set(_ r: URLRequest) { request = r }
    func get() -> URLRequest? { request }
}
