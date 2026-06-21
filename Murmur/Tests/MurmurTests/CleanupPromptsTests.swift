import Testing
@testable import Murmur

@Suite struct CleanupPromptsTests {
    @Test func vocabularyIncludedForTechnicalProfessionalGeneral() {
        for mode in [CleanMode.technical, .professional, .general] {
            let prompt = CleanupPrompts.systemPrompt(for: mode)
            #expect(prompt.contains("Software engineering vocabulary"))
            #expect(prompt.contains("Kubernetes"))
        }
    }

    @Test func personalTermsAppearInPrompt() {
        let prompt = CleanupPrompts.systemPrompt(for: .casual, personalTerms: ["Murmur", "Parakeet"])
        #expect(prompt.contains("preserve these personal terms exactly as written: Murmur, Parakeet."))
    }

    @Test func emptyPersonalTermsMatchBasePrompt() {
        #expect(CleanupPrompts.systemPrompt(for: .technical, personalTerms: [])
            == CleanupPrompts.systemPrompt(for: .technical))
    }

    @Test func vocabularyOmittedForCasual() {
        let prompt = CleanupPrompts.systemPrompt(for: .casual)
        #expect(!prompt.contains("Software engineering vocabulary"))
        #expect(prompt.contains("iMessage"))
    }

    @Test func systemPromptIsStablePerMode() {
        // Identical across calls so OpenAI prompt caching can hit.
        #expect(CleanupPrompts.systemPrompt(for: .technical) == CleanupPrompts.systemPrompt(for: .technical))
    }

    @Test func userMessageWithoutClipboard() {
        let msg = CleanupPrompts.userMessage(transcript: "hello world", clipboardContext: "")
        #expect(msg == "Transcript: hello world")
    }

    @Test func userMessageIncludesClipboardContext() {
        let msg = CleanupPrompts.userMessage(transcript: "hi", clipboardContext: "some context")
        #expect(msg.contains("some context"))
        #expect(msg.contains("do NOT include it in the output"))
        #expect(msg.hasSuffix("Transcript: hi"))
    }

    @Test func clipboardContextTruncatedTo500Chars() {
        let long = String(repeating: "a", count: 800)
        let msg = CleanupPrompts.userMessage(transcript: "hi", clipboardContext: long)
        #expect(msg.contains(String(repeating: "a", count: 500)))
        #expect(!msg.contains(String(repeating: "a", count: 501)))
    }

    @Test func stripPreambleRemovesKnownPrefixLines() {
        #expect(CleanupPrompts.stripPreamble("Here is the cleaned text:\n\nFix the bug.") == "Fix the bug.")
        #expect(CleanupPrompts.stripPreamble("Cleaned text:\nDeploy it.") == "Deploy it.")
        #expect(CleanupPrompts.stripPreamble("Sure, happy to help!\nDone.") == "Done.")
    }

    @Test func stripPreambleLeavesNormalTextAlone() {
        #expect(CleanupPrompts.stripPreamble("Fix the login bug.") == "Fix the login bug.")
        #expect(CleanupPrompts.stripPreamble("Line one.\nLine two.") == "Line one.\nLine two.")
    }
}
