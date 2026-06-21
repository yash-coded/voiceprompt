import Foundation

/// Builds the OpenAI messages for transcript cleanup. The static parts
/// (vocabulary block + mode instructions) go in the system message so
/// OpenAI's automatic prompt caching kicks in; the variable parts
/// (clipboard context, transcript) go in the user message.
/// Ported from the Python reference (`src/voiceprompt/cleaner.py`).
enum CleanupPrompts {
    static let clipboardContextLimit = 500

    /// Casual mode skips the engineering vocabulary — no kubectl in iMessage.
    private static let modesWithVocabulary: Set<CleanMode> = [.technical, .professional, .general]

    static let vocabularyBlock: String =
        "Software engineering vocabulary — preserve exact spelling and casing "
        + "for all of the following terms:\n"
        + Vocabulary.byCategory
            .map { "  \($0.category): \($0.terms.joined(separator: ", "))" }
            .joined(separator: "\n")
        + "\n\n"

    private static let promptBodies: [CleanMode: String] = [
        .technical: """
            Clean the voice transcript the user provides. It will be used as a \
            technical prompt or command.

            Rules:
            - Remove filler words (uh, um, like, you know, so) and verbal tics
            - If the speaker corrects themselves mid-sentence, include only the corrected version
            - Preserve ALL technical details exactly: variable names, CLI flags, model names, code identifiers, numbers, file paths, and exact wording
            - Fix punctuation and capitalisation only — do NOT rephrase, simplify, or reword anything
            - This is a cleanup task, not a rewriting task

            Return only the cleaned text, nothing else.
            """,
        .professional: """
            Clean the voice transcript the user provides. It will be sent as a \
            work message (Slack, Teams, or email).

            Rules:
            - Remove filler words (uh, um, like, you know, so) and verbal tics
            - If the speaker corrects themselves mid-sentence, include only the corrected version
            - Fix grammar and punctuation
            - Keep the tone professional yet friendly and natural — do not make it overly formal or stiff
            - Preserve the original meaning completely — do NOT add new ideas or expand on what was said
            - This is a cleanup task, not a rewriting task

            Return only the cleaned text, nothing else.
            """,
        .casual: """
            Lightly clean the voice transcript the user provides. It will be sent \
            as a casual message (iMessage, WhatsApp, or Discord).

            Rules:
            - Remove only mechanical filler words (uh, um, hmm) — preserve natural speech patterns like 'you know', 'I mean', 'right?'
            - If the speaker corrects themselves mid-sentence, include only the corrected version
            - Fix obvious typos but preserve the speaker's style, contractions, and informal phrasing
            - Do NOT restructure sentences or make them sound formal
            - Replace any spoken emoji descriptions (e.g. 'laughing face') with the actual emoji

            Return only the cleaned text, nothing else.
            """,
        .general: """
            Clean the voice transcript the user provides.

            Rules:
            - Remove filler words (uh, um, like, you know)
            - If the speaker corrects themselves mid-sentence, include only the corrected version
            - Fix grammar and punctuation, preserve technical terms exactly as spoken

            Return only the cleaned text, nothing else.
            """,
    ]

    /// The shipped instruction text for a mode, used as the editor's reset
    /// target and the default when the user hasn't customised the mode.
    static func defaultBody(for mode: CleanMode) -> String { promptBodies[mode]! }

    /// Static per-mode system message (identical across requests → cacheable).
    /// `personalTerms` are the user's plain dictionary entries; they are listed
    /// in every mode so their spelling and casing survive cleanup. `promptBody`
    /// overrides the mode's built-in instructions when the user has edited them.
    static func systemPrompt(for mode: CleanMode, personalTerms: [String] = [],
                             promptBody: String? = nil) -> String {
        var parts: [String] = []
        if modesWithVocabulary.contains(mode) {
            parts.append(vocabularyBlock)
        }
        if !personalTerms.isEmpty {
            parts.append("Also preserve these personal terms exactly as written: "
                + personalTerms.joined(separator: ", ") + ".\n\n")
        }
        parts.append(promptBody ?? promptBodies[mode]!)
        return parts.joined()
    }

    /// Variable user message: optional clipboard context (truncated) + transcript.
    static func userMessage(transcript: String, clipboardContext: String) -> String {
        var parts: [String] = []
        if !clipboardContext.isEmpty {
            let truncated = String(clipboardContext.prefix(clipboardContextLimit))
            parts.append(
                "Context the user is working with (use this to align terminology, "
                + "do NOT include it in the output):\n---\n\(truncated)\n---\n\n")
        }
        parts.append("Transcript: " + transcript)
        return parts.joined()
    }

    private static let preamblePrefixes = [
        "sure,", "here is", "here's", "certainly,", "of course,",
        "cleaned text:", "corrected text:", "transcript:",
    ]

    /// Remove a common LLM preamble line from the start of `text`.
    static func stripPreamble(_ text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        if let first = lines.first {
            let lowered = first.lowercased().trimmingCharacters(in: .whitespaces)
            if preamblePrefixes.contains(where: lowered.hasPrefix) {
                lines.removeFirst()
                while let next = lines.first,
                      next.trimmingCharacters(in: .whitespaces).isEmpty {
                    lines.removeFirst()
                }
            }
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
