import Foundation
import Testing
@testable import Murmur

@MainActor
@Suite("HistoryStore")
struct HistoryStoreTests {

    /// A fresh store backed by a throwaway file so restart-survival is testable.
    private func tempStore() -> (HistoryStore, String) {
        let path = NSTemporaryDirectory() + "murmur-history-\(UUID().uuidString).sqlite"
        return (HistoryStore(path: path), path)
    }

    @Test("records a dictation with all fields and reads it back")
    func recordsAllFields() {
        let (store, _) = tempStore()
        let now = Date(timeIntervalSince1970: 1_000_000)
        store.record(raw: "hello world", cleaned: "Hello, world.",
                     targetApp: "Slack", mode: .professional,
                     retention: .forever, now: now)

        #expect(store.entries.count == 1)
        let e = store.entries[0]
        #expect(e.raw == "hello world")
        #expect(e.cleaned == "Hello, world.")
        #expect(e.targetApp == "Slack")
        #expect(e.mode == .professional)
        #expect(e.timestamp == now)
    }

    @Test("cleaned is nil when cleanup was skipped")
    func cleanedNilWhenSkipped() {
        let (store, _) = tempStore()
        store.record(raw: "raw only", cleaned: nil, targetApp: "Notes",
                     mode: .general, retention: .forever)
        #expect(store.entries[0].cleaned == nil)
    }

    @Test("lists newest first")
    func reverseChronological() {
        let (store, _) = tempStore()
        store.record(raw: "first", cleaned: nil, targetApp: "A", mode: .general,
                     retention: .forever, now: Date(timeIntervalSince1970: 10))
        store.record(raw: "second", cleaned: nil, targetApp: "A", mode: .general,
                     retention: .forever, now: Date(timeIntervalSince1970: 20))
        #expect(store.entries.map(\.raw) == ["second", "first"])
    }

    @Test("retention off writes nothing")
    func retentionOffWritesNothing() {
        let (store, _) = tempStore()
        store.record(raw: "ignored", cleaned: nil, targetApp: "A", mode: .general,
                     retention: .off)
        #expect(store.entries.isEmpty)
    }

    @Test("switching retention off does not delete existing rows")
    func switchingOffKeepsExisting() {
        let (store, _) = tempStore()
        store.record(raw: "kept", cleaned: nil, targetApp: "A", mode: .general,
                     retention: .forever)
        // A later dictation while retention is off must not wipe history.
        store.record(raw: "dropped", cleaned: nil, targetApp: "A", mode: .general,
                     retention: .off)
        #expect(store.entries.map(\.raw) == ["kept"])
    }

    @Test("timed retention prunes rows older than the window")
    func prunesOldRows() {
        let (store, _) = tempStore()
        let now = Date(timeIntervalSince1970: 100 * 86_400)
        let old = now.addingTimeInterval(-31 * 86_400)
        store.record(raw: "old", cleaned: nil, targetApp: "A", mode: .general,
                     retention: .forever, now: old)
        // Recording under a 30-day window prunes the 31-day-old row.
        store.record(raw: "new", cleaned: nil, targetApp: "A", mode: .general,
                     retention: .thirtyDays, now: now)
        #expect(store.entries.map(\.raw) == ["new"])
    }

    @Test("forever never prunes")
    func foreverKeepsEverything() {
        let (store, _) = tempStore()
        let now = Date(timeIntervalSince1970: 1_000 * 86_400)
        let ancient = now.addingTimeInterval(-9_999 * 86_400)
        store.record(raw: "ancient", cleaned: nil, targetApp: "A", mode: .general,
                     retention: .forever, now: ancient)
        store.prune(retention: .forever, now: now)
        #expect(store.entries.count == 1)
    }

    @Test("delete removes a single row")
    func deleteRow() {
        let (store, _) = tempStore()
        store.record(raw: "a", cleaned: nil, targetApp: "A", mode: .general, retention: .forever)
        store.record(raw: "b", cleaned: nil, targetApp: "A", mode: .general, retention: .forever)
        store.delete(store.entries[0].id)
        #expect(store.entries.map(\.raw) == ["a"])
    }

    @Test("clear all empties the history")
    func clearAll() {
        let (store, _) = tempStore()
        store.record(raw: "a", cleaned: nil, targetApp: "A", mode: .general, retention: .forever)
        store.record(raw: "b", cleaned: nil, targetApp: "A", mode: .general, retention: .forever)
        store.clearAll()
        #expect(store.entries.isEmpty)
    }

    @Test("history survives reopening the same file")
    func survivesRestart() {
        let (store, path) = tempStore()
        store.record(raw: "persisted", cleaned: "Persisted.", targetApp: "A",
                     mode: .general, retention: .forever)
        let reopened = HistoryStore(path: path)
        #expect(reopened.entries.map(\.raw) == ["persisted"])
    }
}

@Suite("HistoryEntry search")
struct HistoryEntrySearchTests {

    private func entry(raw: String, cleaned: String?) -> HistoryEntry {
        HistoryEntry(id: 1, timestamp: Date(), raw: raw, cleaned: cleaned,
                     targetApp: "A", mode: .general)
    }

    @Test("empty query matches everything")
    func emptyMatches() {
        #expect(entry(raw: "anything", cleaned: nil).matches(""))
    }

    @Test("matches raw text case-insensitively")
    func matchesRaw() {
        #expect(entry(raw: "Hello World", cleaned: nil).matches("hello"))
        #expect(!entry(raw: "Hello World", cleaned: nil).matches("xyz"))
    }

    @Test("matches cleaned text")
    func matchesCleaned() {
        let e = entry(raw: "raw", cleaned: "polished sentence")
        #expect(e.matches("polished"))
    }
}
