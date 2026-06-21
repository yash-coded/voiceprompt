import Foundation

/// One personal-vocabulary entry. A plain term (empty `spokenAs`) is injected
/// into the cleanup prompt so the LLM preserves its exact spelling. A term with
/// a `spokenAs` source is a replacement pair (e.g. "jason" → "JSON") that is
/// rewritten into the transcript deterministically, so it works offline too.
struct DictionaryTerm: Identifiable, Equatable, Codable, Sendable {
    var id = UUID()
    var term: String
    var spokenAs: String = ""

    var isReplacement: Bool {
        !spokenAs.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Pure dictionary logic, isolated from persistence and the main actor so it
/// can run inside the dictation Task and be unit-tested directly.
enum PersonalDictionary {
    /// Plain terms (no replacement) for the cleanup prompt's personal-vocab line.
    static func promptTerms(_ terms: [DictionaryTerm]) -> [String] {
        terms.filter { !$0.isReplacement }.map(\.term).filter { !$0.isEmpty }
    }

    /// Rewrite every replacement source to its term: whole-word, case-insensitive.
    static func applyReplacements(_ terms: [DictionaryTerm], to text: String) -> String {
        terms.reduce(text) { acc, t in
            t.isReplacement ? replaceWholeWord(t.spokenAs, with: t.term, in: acc) : acc
        }
    }

    private static func replaceWholeWord(_ source: String, with replacement: String,
                                         in text: String) -> String {
        let pattern = "\\b" + NSRegularExpression.escapedPattern(for: source) + "\\b"
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        else { return text }
        return re.stringByReplacingMatches(
            in: text, range: NSRange(text.startIndex..., in: text),
            withTemplate: NSRegularExpression.escapedTemplate(for: replacement))
    }
}

/// JSON-backed personal dictionary, observable for the UI. On first launch it
/// migrates plain terms from the legacy Python config once (the legacy file is
/// only read, never modified); thereafter it is the single source of truth.
@MainActor
@Observable
final class DictionaryStore {
    static let shared = DictionaryStore()

    private(set) var terms: [DictionaryTerm] = []
    private let url: URL

    init(url: URL = DictionaryStore.defaultURL, legacyConfig: URL = DictionaryStore.legacyConfigURL) {
        self.url = url
        if let loaded = Self.load(from: url) {
            terms = loaded
        } else {
            terms = Self.migrateLegacy(from: legacyConfig)
            save()
        }
    }

    /// Add a term, optionally with a replacement source. A term that already
    /// exists (case-insensitively) is merged: its replacement source is updated.
    func add(term: String, spokenAs: String = "") {
        let term = term.trimmingCharacters(in: .whitespacesAndNewlines)
        let spoken = spokenAs.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        if let i = terms.firstIndex(where: { $0.term.caseInsensitiveCompare(term) == .orderedSame }) {
            terms[i].spokenAs = spoken
        } else {
            terms.append(DictionaryTerm(term: term, spokenAs: spoken))
        }
        save()
    }

    func remove(_ id: UUID) {
        terms.removeAll { $0.id == id }
        save()
    }

    var promptTerms: [String] { PersonalDictionary.promptTerms(terms) }

    func applyReplacements(to text: String) -> String {
        PersonalDictionary.applyReplacements(terms, to: text)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(terms) else { return }
        try? data.write(to: url)
    }

    private static func load(from url: URL) -> [DictionaryTerm]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([DictionaryTerm].self, from: data)
    }

    /// Import the legacy `vocabulary` string list as plain terms, deduped.
    private static func migrateLegacy(from configURL: URL) -> [DictionaryTerm] {
        guard let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let vocab = json["vocabulary"] as? [String] else { return [] }
        var seen = Set<String>()
        return vocab
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
            .map { DictionaryTerm(term: $0) }
    }

    static var defaultURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Murmur", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("dictionary.json")
    }

    static var legacyConfigURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/voiceprompt/config.json")
    }
}
