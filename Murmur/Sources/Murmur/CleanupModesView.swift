import AppKit
import SwiftUI

/// The Cleanup Modes pane: map apps to a cleanup mode and edit each mode's
/// instructions. Overrides beat the built-in mappings; prompt edits take effect
/// on the next dictation. Both persist via `CleanupModeStore`.
struct CleanupModesView: View {
    @Bindable var store: CleanupModeStore

    var body: some View {
        Form {
            Section("App Modes") {
                ForEach(store.builtIns) { app in
                    appRow(app, revertTo: app.mode, onRemove: nil)
                }
                ForEach(store.customApps) { app in
                    appRow(app, revertTo: nil) { store.clearOverride(bundleID: app.bundleID) }
                }
                addAppMenu
            }

            Section("Mode Prompts") {
                ForEach(CleanMode.allCases, id: \.self) { mode in
                    promptEditor(mode)
                }
            }
        }
        .formStyle(.grouped)
    }

    /// One app row: name, a mode picker, and an optional remove button.
    /// `revertTo` is the built-in default — picking it drops the override;
    /// custom apps (nil) are only removed via their button.
    private func appRow(_ app: AppModeMapping, revertTo: CleanMode?,
                        onRemove: (() -> Void)?) -> some View {
        HStack {
            Text(app.appName)
            if store.isOverridden(app.bundleID) {
                Text("override").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Picker("", selection: modeBinding(app, revertTo: revertTo)) {
                ForEach(CleanMode.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .labelsHidden()
            .fixedSize()
            if let onRemove {
                Button(role: .destructive, action: onRemove) { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
            }
        }
    }

    private func modeBinding(_ app: AppModeMapping, revertTo: CleanMode?) -> Binding<CleanMode> {
        Binding(
            get: { store.mode(forBundleID: app.bundleID, appName: app.appName) },
            set: { new in
                if let revertTo, new == revertTo {
                    store.clearOverride(bundleID: app.bundleID)
                } else {
                    store.setMode(new, forBundleID: app.bundleID, appName: app.appName)
                }
            })
    }

    /// Pick a running app to add a custom mapping for — no bundle-id typing.
    private var addAppMenu: some View {
        Menu("Add App…") {
            let apps = addableApps
            if apps.isEmpty {
                Text("No other apps running")
            } else {
                ForEach(apps) { app in
                    Button(app.appName) {
                        store.setMode(.general, forBundleID: app.bundleID, appName: app.appName)
                    }
                }
            }
        }
        .fixedSize()
    }

    /// Running, user-facing apps that aren't already mapped.
    private var addableApps: [AppModeMapping] {
        let existing = Set(store.builtIns.map(\.bundleID) + store.overrides.map(\.bundleID))
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> AppModeMapping? in
                guard let bid = app.bundleIdentifier, !existing.contains(bid) else { return nil }
                return AppModeMapping(bundleID: bid, appName: app.localizedName ?? bid, mode: .general)
            }
            .sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
    }

    private func promptEditor(_ mode: CleanMode) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(mode.label).font(.headline)
                Spacer()
                Button("Reset to Default") { store.resetPrompt(for: mode) }
                    .disabled(!store.hasPromptOverride(mode))
            }
            TextEditor(text: Binding(
                get: { store.body(for: mode) },
                set: { store.setPrompt($0, for: mode) }))
                .font(.body.monospaced())
                .frame(minHeight: 120)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(.quaternary))
        }
        .padding(.vertical, 4)
    }
}
