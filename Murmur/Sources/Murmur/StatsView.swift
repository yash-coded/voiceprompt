import Charts
import SwiftUI

/// The Stats sidebar pane: headline numbers plus a words-per-day chart, all
/// derived from history. When history is off or empty it explains why there is
/// nothing to show rather than rendering zeros.
struct StatsView: View {
    @Bindable var store: HistoryStore
    let historyEnabled: Bool

    private var stats: DictationStats { DictationStats.compute(store.entries) }

    var body: some View {
        if !historyEnabled {
            ContentUnavailableView(
                "History is off", systemImage: "chart.bar",
                description: Text("Turn on history in Settings to track words dictated, time saved, and your streak."))
        } else if store.entries.isEmpty {
            ContentUnavailableView(
                "No stats yet", systemImage: "chart.bar",
                description: Text("Dictate something and your stats will appear here."))
        } else {
            content(stats)
        }
    }

    private func content(_ stats: DictationStats) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    StatCard(title: "Words dictated", value: stats.totalWords.formatted())
                    StatCard(title: "Time saved", value: timeSaved(stats.timeSaved))
                    StatCard(title: "Day streak", value: "\(stats.streak)", systemImage: "flame.fill")
                }
                Text("Time saved assumes typing at \(Int(DictationStats.typingWPM)) wpm vs speaking at \(Int(DictationStats.speakingWPM)) wpm.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Words per day").font(.headline)
                Chart(stats.perDay.suffix(30)) { day in
                    BarMark(
                        x: .value("Day", day.day, unit: .day),
                        y: .value("Words", day.words))
                }
                .frame(height: 220)
            }
            .padding()
        }
    }

    private func timeSaved(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}

/// A single headline metric tile.
private struct StatCard: View {
    let title: String
    let value: String
    var systemImage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 4) {
                if let systemImage { Image(systemName: systemImage).foregroundStyle(.orange) }
                Text(value).font(.system(.title, design: .rounded)).fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}
