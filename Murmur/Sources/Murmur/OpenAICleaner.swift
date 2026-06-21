import Foundation

/// Seam for transcript cleanup so a local-LLM cleaner can be slotted in later.
/// Implementations never throw: on any failure they return the raw transcript.
protocol TranscriptCleaner: Sendable {
    func clean(_ transcript: String, mode: CleanMode, clipboardContext: String,
               personalTerms: [String]) async -> String
}

/// Cleans transcripts via OpenAI gpt-5-mini. Gracefully degrades: missing
/// key, offline, timeout (2s), API error, or empty response all return the
/// raw transcript unchanged.
struct OpenAICleaner: TranscriptCleaner {
    static let model = "gpt-5-mini"
    static let timeout: TimeInterval = 2.0
    static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    /// Reads the API key on every call so a newly set key takes effect
    /// without restarting. Returns nil for "no key configured".
    var apiKeyProvider: @Sendable () -> String? = { KeychainStore.openAIKey.read() }
    /// Injectable transport for tests.
    var transport: @Sendable (URLRequest) async throws -> (Data, URLResponse) = { request in
        try await URLSession.shared.data(for: request)
    }

    func clean(_ transcript: String, mode: CleanMode, clipboardContext: String,
               personalTerms: [String] = []) async -> String {
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let apiKey = apiKeyProvider(), !apiKey.isEmpty else {
            return transcript
        }

        var request = URLRequest(url: Self.endpoint, timeoutInterval: Self.timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "model": Self.model,
            "messages": [
                ["role": "system", "content": CleanupPrompts.systemPrompt(for: mode, personalTerms: personalTerms)],
                ["role": "user", "content": CleanupPrompts.userMessage(
                    transcript: transcript, clipboardContext: clipboardContext)],
            ],
            "max_completion_tokens": 1024,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await transport(request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                NSLog("Murmur: OpenAI cleanup failed (HTTP %ld) – using raw transcript",
                      (response as? HTTPURLResponse)?.statusCode ?? -1)
                return transcript
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String,
                  !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                NSLog("Murmur: OpenAI returned empty/invalid response – using raw transcript")
                return transcript
            }
            let cleaned = CleanupPrompts.stripPreamble(content)
            return cleaned.isEmpty ? transcript : cleaned
        } catch {
            NSLog("Murmur: OpenAI cleanup failed (\(error)) – using raw transcript")
            return transcript
        }
    }
}
