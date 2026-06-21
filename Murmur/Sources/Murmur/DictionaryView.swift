import SwiftUI

/// The Dictionary sidebar pane: manage personal vocabulary. Plain terms steer
/// the cleanup prompt; a term with a "heard as" source fixes a common
/// mistranscription deterministically (e.g. "jason" → "JSON").
struct DictionaryView: View {
    @Bindable var store: DictionaryStore
    @State private var newTerm = ""
    @State private var newSpokenAs = ""

    var body: some View {
        VStack(spacing: 0) {
            addBar
            Divider()
            if store.terms.isEmpty {
                ContentUnavailableView(
                    "No personal terms", systemImage: "character.book.closed",
                    description: Text("Add words Murmur should spell your way, or fix a common mistranscription."))
            } else {
                List(store.terms) { term in
                    DictionaryRow(term: term, onDelete: { store.remove(term.id) })
                }
            }
        }
    }

    private var addBar: some View {
        HStack {
            TextField("Term (e.g. JSON)", text: $newTerm)
            Image(systemName: "arrow.left")
            TextField("Heard as (optional)", text: $newSpokenAs)
            Button("Add", action: add)
                .disabled(newTerm.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .textFieldStyle(.roundedBorder)
        .onSubmit(add)
        .padding(8)
    }

    private func add() {
        store.add(term: newTerm, spokenAs: newSpokenAs)
        newTerm = ""
        newSpokenAs = ""
    }
}

/// One dictionary entry: the term, an optional "heard as" source, and delete.
private struct DictionaryRow: View {
    let term: DictionaryTerm
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Text(term.term).fontWeight(.medium)
            if term.isReplacement {
                Text("← \(term.spokenAs)").foregroundStyle(.secondary)
            }
            Spacer()
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }
}
