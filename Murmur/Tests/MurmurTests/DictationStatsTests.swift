import Foundation
import Testing
@testable import Murmur

@Suite("DictationStats")
struct DictationStatsTests {

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    private func entry(_ raw: String, _ date: Date) -> HistoryEntry {
        HistoryEntry(id: 0, timestamp: date, raw: raw, cleaned: nil,
                     targetApp: "A", mode: .general)
    }

    // MARK: word count

    @Test("word count ignores extra whitespace and newlines")
    func wordCount() {
        #expect(DictationStats.wordCount("") == 0)
        #expect(DictationStats.wordCount("   ") == 0)
        #expect(DictationStats.wordCount("hello") == 1)
        #expect(DictationStats.wordCount("  hello   world \n line ") == 3)
    }

    // MARK: totals

    @Test("total words sums words across all entries")
    func totalWords() {
        let s = DictationStats.compute([
            entry("one two three", day(2026, 6, 21)),
            entry("four five", day(2026, 6, 20)),
        ], now: day(2026, 6, 21), calendar: cal)
        #expect(s.totalWords == 5)
    }

    @Test("empty history yields zeroed stats")
    func empty() {
        let s = DictationStats.compute([], now: day(2026, 6, 21), calendar: cal)
        #expect(s.totalWords == 0)
        #expect(s.timeSaved == 0)
        #expect(s.streak == 0)
        #expect(s.perDay.isEmpty)
    }

    // MARK: time saved

    @Test("time saved uses the 40 vs 150 wpm baselines and is never negative")
    func timeSaved() {
        // 200 words: typing 200/40 = 5 min, speaking 200/150 = 1.333 min,
        // saved ≈ 3.667 min ≈ 220 s.
        let entries = (0..<10).map { entry(String(repeating: "w ", count: 20), day(2026, 6, 21, hour: $0)) }
        let s = DictationStats.compute(entries, now: day(2026, 6, 21), calendar: cal)
        #expect(s.totalWords == 200)
        #expect(abs(s.timeSaved - 220) < 0.5)
    }

    // MARK: streak

    @Test("streak counts consecutive days including today")
    func streakIncludingToday() {
        let s = DictationStats.compute([
            entry("a", day(2026, 6, 21)),
            entry("a", day(2026, 6, 20)),
            entry("a", day(2026, 6, 19)),
        ], now: day(2026, 6, 21), calendar: cal)
        #expect(s.streak == 3)
    }

    @Test("a gap breaks the streak")
    func streakGap() {
        let s = DictationStats.compute([
            entry("a", day(2026, 6, 21)),
            entry("a", day(2026, 6, 20)),
            entry("a", day(2026, 6, 18)), // missing the 19th
        ], now: day(2026, 6, 21), calendar: cal)
        #expect(s.streak == 2)
    }

    @Test("streak continues from yesterday when today has no dictation yet")
    func streakGraceYesterday() {
        let s = DictationStats.compute([
            entry("a", day(2026, 6, 20)),
            entry("a", day(2026, 6, 19)),
        ], now: day(2026, 6, 21), calendar: cal)
        #expect(s.streak == 2)
    }

    @Test("streak is zero when the last dictation is older than yesterday")
    func streakStale() {
        let s = DictationStats.compute([
            entry("a", day(2026, 6, 18)),
            entry("a", day(2026, 6, 17)),
        ], now: day(2026, 6, 21), calendar: cal)
        #expect(s.streak == 0)
    }

    @Test("multiple dictations on one day count as a single streak day")
    func streakSameDay() {
        let s = DictationStats.compute([
            entry("a", day(2026, 6, 21, hour: 9)),
            entry("a", day(2026, 6, 21, hour: 17)),
        ], now: day(2026, 6, 21), calendar: cal)
        #expect(s.streak == 1)
    }

    // MARK: per-day chart data

    @Test("per-day groups words by calendar day, oldest first")
    func perDay() {
        let s = DictationStats.compute([
            entry("one two", day(2026, 6, 21, hour: 9)),
            entry("three", day(2026, 6, 21, hour: 17)),
            entry("a b c d", day(2026, 6, 19)),
        ], now: day(2026, 6, 21), calendar: cal)
        #expect(s.perDay.map(\.day) == [day(2026, 6, 19, hour: 0), day(2026, 6, 21, hour: 0)])
        #expect(s.perDay.map(\.words) == [4, 3])
    }
}
