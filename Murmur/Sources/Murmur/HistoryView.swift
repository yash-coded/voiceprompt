import SwiftUI

/// The History sidebar pane: a searchable, reverse-chronological list of
/// dictations with per-row copy/delete and a clear-all action.
struct HistoryView: View {
    @Bindable var store: HistoryStore
    @State private var query = ""

    private var visible: [HistoryEntry] {
        store.entries.filter { $0.matches(query) }
    }

    var body: some View {
        Group {
            if store.entries.isEmpty {
                ContentUnavailableView("No dictations yet", systemImage: "clock.arrow.circlepath",
                                       description: Text("Your dictation history will appear here."))
            } else if visible.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List(visible) { entry in
                    HistoryRow(entry: entry, onDelete: { store.delete(entry.id) })
                }
            }
        }
        .searchable(text: $query, prompt: "Search transcripts")
        .toolbar {
            Button("Clear All", role: .destructive) { store.clearAll() }
                .disabled(store.entries.isEmpty)
        }
    }
}

/// One dictation: metadata header, the transcript text, and copy/delete actions.
private struct HistoryRow: View {
    let entry: HistoryEntry
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.timestamp, format: .dateTime.month().day().hour().minute())
                Text("·"); Text(entry.targetApp)
                Text("·"); Text(entry.mode.rawValue.capitalized)
                Spacer()
                Button { copy(entry.raw) } label: { Text("Copy raw") }
                if let cleaned = entry.cleaned {
                    Button { copy(cleaned) } label: { Text("Copy cleaned") }
                }
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .buttonStyle(.borderless)

            Text(entry.cleaned ?? entry.raw)
            if let cleaned = entry.cleaned, cleaned != entry.raw {
                Text(entry.raw).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
