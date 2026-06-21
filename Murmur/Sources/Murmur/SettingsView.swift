import SwiftUI

/// The functional Settings pane. Every control binds straight to the shared
/// `Settings` (write-through to UserDefaults) or the Keychain, so changes
/// persist and take effect on the next dictation without a restart.
struct SettingsView: View {
    @Bindable var settings: Settings

    /// Live input devices, refreshed when the pane appears.
    @State private var devices: [AudioDevice] = []
    /// Mirrors the Keychain-stored API key while editing.
    @State private var apiKey: String = KeychainStore.openAIKey.read() ?? ""

    var body: some View {
        Form {
            Section("Audio") {
                Picker("Input device", selection: $settings.inputDeviceUID) {
                    Text("System Default").tag(String?.none)
                    ForEach(devices) { device in
                        Text(device.name).tag(String?.some(device.uid))
                    }
                }
            }

            Section("Hotkey") {
                Picker("Hold to dictate", selection: $settings.hotkeyModifier) {
                    ForEach(HotkeyModifier.allCases, id: \.self) { modifier in
                        Text(modifier.label).tag(modifier)
                    }
                }
                LabeledContent("Hold threshold") {
                    VStack(alignment: .leading) {
                        Slider(value: $settings.holdThreshold, in: 0.2...1.0, step: 0.05)
                        Text(String(format: "%.2fs", settings.holdThreshold))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section("Cleanup") {
                Toggle("Clean up transcripts with OpenAI", isOn: $settings.cleanupEnabled)
                SecureField("OpenAI API key", text: $apiKey)
                    .onChange(of: apiKey) { _, key in saveAPIKey(key) }
            }

            Section("History") {
                Picker("Keep history", selection: $settings.historyRetention) {
                    ForEach(HistoryRetention.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
            }

            Section("Setup") {
                Button("Run setup again…") { AppDelegate.onboarding.show() }
            }
        }
        .formStyle(.grouped)
        .onAppear { devices = AudioDevices.inputDevices() }
    }

    private func saveAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainStore.openAIKey.delete()
        } else {
            KeychainStore.openAIKey.write(trimmed)
        }
    }
}
