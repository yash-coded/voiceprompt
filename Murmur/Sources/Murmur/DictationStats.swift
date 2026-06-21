import Foundation

/// Words dictated on one calendar day — a single bar in the stats chart.
struct DayWords: Identifiable, Equatable, Sendable {
    let day: Date   // start of day
    let words: Int
    var id: Date { day }
}

/// Aggregate dictation statistics computed purely from history entries, so the
/// Stats view stays a thin renderer and the arithmetic is unit-tested. Words are
/// counted from the raw transcript — what the user actually spoke.
struct DictationStats: Equatable, Sendable {
    let totalWords: Int
    /// Estimated time saved versus typing, in seconds (never negative).
    let timeSaved: TimeInterval
    /// Consecutive days with at least one dictation, ending today (or yesterday
    /// when nothing has been dictated yet today).
    let streak: Int
    /// Words per day, oldest first — drives the chart.
    let perDay: [DayWords]

    /// Baselines behind `timeSaved`, surfaced in the UI so the estimate is honest.
    static let typingWPM = 40.0
    static let speakingWPM = 150.0

    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    static func compute(_ entries: [HistoryEntry], now: Date = Date(),
                        calendar: Calendar = .current) -> DictationStats {
        var byDay: [Date: Int] = [:]
        for entry in entries {
            byDay[calendar.startOfDay(for: entry.timestamp), default: 0] += wordCount(entry.raw)
        }
        let total = byDay.values.reduce(0, +)
        let minutesSaved = Double(total) * (1 / typingWPM - 1 / speakingWPM)
        let perDay = byDay.map { DayWords(day: $0.key, words: $0.value) }
            .sorted { $0.day < $1.day }
        return DictationStats(
            totalWords: total,
            timeSaved: max(0, minutesSaved * 60),
            streak: streak(activeDays: Set(byDay.keys), now: now, calendar: calendar),
            perDay: perDay)
    }

    private static func streak(activeDays: Set<Date>, now: Date,
                               calendar: Calendar) -> Int {
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
        var cursor = activeDays.contains(today) ? today : yesterday
        guard let start = cursor, activeDays.contains(start) else { return 0 }
        var count = 0
        cursor = start
        while let day = cursor, activeDays.contains(day) {
            count += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: day)
        }
        return count
    }
}
