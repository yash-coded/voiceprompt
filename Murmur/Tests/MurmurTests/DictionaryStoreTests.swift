import Foundation
import Testing
@testable import Murmur

@MainActor
@Suite("DictionaryStore")
struct DictionaryStoreTests {

    /// A fresh store backed by throwaway files; legacy points nowhere by default.
    private func tempStore(legacy: URL? = nil) -> (DictionaryStore, URL) {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("murmur-dict-\(UUID().uuidString).json")
        let legacyURL = legacy ?? URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).json")
        return (DictionaryStore(url: url, legacyConfig: legacyURL), url)
    }

    @Test("adds and removes terms, persisting across reopen")
    func addRemovePersist() {
        let (store, url) = tempStore()
        store.add(term: "JSON")
        store.add(term: "kubectl")
        #expect(store.terms.map(\.term) == ["JSON", "kubectl"])

        let reopened = DictionaryStore(url: url)
        #expect(reopened.terms.map(\.term) == ["JSON", "kubectl"])

        reopened.remove(reopened.terms[0].id)
        let again = DictionaryStore(url: url)
        #expect(again.terms.map(\.term) == ["kubectl"])
    }

    @Test("blank terms are ignored")
    func blankIgnored() {
        let (store, _) = tempStore()
        store.add(term: "   ")
        #expect(store.terms.isEmpty)
    }

    @Test("duplicate term (case-insensitive) merges and updates its replacement")
    func duplicatesMerge() {
        let (store, _) = tempStore()
        store.add(term: "JSON")
        store.add(term: "json", spokenAs: "jason")
        #expect(store.terms.count == 1)
        #expect(store.terms[0].term == "JSON")
        #expect(store.terms[0].spokenAs == "jason")
    }

    @Test("promptTerms returns only plain terms")
    func promptTermsPlainOnly() {
        let (store, _) = tempStore()
        store.add(term: "Kubernetes")
        store.add(term: "JSON", spokenAs: "jason")
        #expect(store.promptTerms == ["Kubernetes"])
    }
}

@Suite("PersonalDictionary replacements")
struct PersonalDictionaryTests {
    private func term(_ term: String, _ spokenAs: String = "") -> DictionaryTerm {
        DictionaryTerm(term: term, spokenAs: spokenAs)
    }

    @Test("rewrites a whole-word match, leaving partial matches alone")
    func wholeWord() {
        let out = PersonalDictionary.applyReplacements(
            [term("JSON", "jason")], to: "the jason file, not jasonical")
        #expect(out == "the JSON file, not jasonical")
    }

    @Test("matching is case-insensitive")
    func caseInsensitive() {
        let out = PersonalDictionary.applyReplacements(
            [term("JSON", "jason")], to: "Jason and JASON")
        #expect(out == "JSON and JSON")
    }

    @Test("plain terms never rewrite text")
    func plainTermsNoRewrite() {
        let out = PersonalDictionary.applyReplacements([term("JSON")], to: "a json blob")
        #expect(out == "a json blob")
    }

    @Test("multiple pairs all apply")
    func multiplePairs() {
        let out = PersonalDictionary.applyReplacements(
            [term("JSON", "jason"), term("C#", "see sharp")],
            to: "parse jason in see sharp")
        #expect(out == "parse JSON in C#")
    }
}

@MainActor
@Suite("DictionaryStore legacy migration")
struct DictionaryMigrationTests {

    private func writeLegacy(_ vocabulary: [String]) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("murmur-legacy-\(UUID().uuidString).json")
        let json: [String: Any] = [
            "openai_api_key": "sk-legacy", "restricted_mode": false, "vocabulary": vocabulary,
        ]
        try JSONSerialization.data(withJSONObject: json).write(to: url)
        return url
    }

    @Test("imports legacy vocabulary as plain terms on first launch")
    func importsLegacy() throws {
        let legacy = try writeLegacy(["Murmur", "Parakeet"])
        let dict = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("murmur-dict-\(UUID().uuidString).json")
        let store = DictionaryStore(url: dict, legacyConfig: legacy)
        #expect(store.terms.map(\.term) == ["Murmur", "Parakeet"])
        #expect(store.terms.allSatisfy { !$0.isReplacement })
    }

    @Test("leaves the legacy config file untouched")
    func legacyUntouched() throws {
        let legacy = try writeLegacy(["Murmur"])
        let before = try Data(contentsOf: legacy)
        let dict = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("murmur-dict-\(UUID().uuidString).json")
        _ = DictionaryStore(url: dict, legacyConfig: legacy)
        #expect(try Data(contentsOf: legacy) == before)
    }

    @Test("migrates only once — later launches read the saved dictionary")
    func migratesOnce() throws {
        let legacy = try writeLegacy(["Murmur", "Parakeet"])
        let dict = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("murmur-dict-\(UUID().uuidString).json")

        let first = DictionaryStore(url: dict, legacyConfig: legacy)
        first.remove(first.terms[0].id)  // user deletes "Murmur"

        let second = DictionaryStore(url: dict, legacyConfig: legacy)
        #expect(second.terms.map(\.term) == ["Parakeet"])  // not re-imported
    }
}
