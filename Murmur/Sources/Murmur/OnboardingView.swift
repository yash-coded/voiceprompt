import AVFoundation
import SwiftUI

/// The first-launch wizard: one screen per `OnboardingStep`, a shared footer
/// with Back/Continue, and a progress poll that auto-advances the accessibility
/// step the instant the grant lands. `onFinish` closes the hosting window.
struct OnboardingView: View {
    @State var model: OnboardingModel
    var onFinish: () -> Void = {}

    /// Drives accessibility-grant detection while that step is on screen.
    private let pollTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(28)
            Divider()
            footer
        }
        .frame(width: 520, height: 460)
        .onChange(of: model.step) { _, step in
            if step == .model { Task { await model.downloadModel() } }
        }
        .onReceive(pollTimer) { _ in model.pollAccessibility() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: model.step.systemImage)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 28)
            Text(model.step.title).font(.title2.weight(.semibold))
            Spacer()
            Text("\(model.step.rawValue + 1) of \(OnboardingStep.allCases.count)")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch model.step {
        case .welcome: WelcomeStep()
        case .microphone: MicrophoneStep()
        case .model: ModelStep(phase: model.modelPhase, retry: { Task { await model.downloadModel() } })
        case .accessibility: AccessibilityStep()
        case .apiKey: APIKeyStep(apiKey: $model.apiKey)
        case .tryIt: TryItStep(controller: AppDelegate.controller)
        }
    }

    private var footer: some View {
        HStack {
            if !model.isFirst {
                Button("Back") { model.back() }
            }
            Spacer()
            Button(model.isLast ? "Finish" : "Continue") {
                if model.isLast {
                    model.finish()
                    onFinish()
                } else {
                    model.advance()
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(continueDisabled)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
    }

    /// Block Continue only on the model step until the download succeeds —
    /// every other step (including the optional key) is freely skippable.
    private var continueDisabled: Bool {
        model.step == .model && model.modelPhase != .ready
    }
}

// MARK: - Steps

private struct WelcomeStep: View {
    var body: some View {
        StepBody(
            text: "Murmur turns your voice into text anywhere you can type. Hold your hotkey, speak, and release — your words are transcribed on-device and pasted into the app you're using.",
            footnote: "This quick setup grants the permissions Murmur needs and downloads the speech model.")
    }
}

private struct MicrophoneStep: View {
    @State private var status = AVCaptureDevice.authorizationStatus(for: .audio)

    var body: some View {
        StepBody(text: "Murmur needs your microphone to hear what you dictate. Audio is transcribed on-device and never leaves your Mac.") {
            switch status {
            case .authorized:
                Label("Microphone access granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .denied, .restricted:
                Label("Enable Microphone for Murmur in System Settings → Privacy & Security.",
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            default:
                Button("Grant Microphone Access") {
                    AVCaptureDevice.requestAccess(for: .audio) { granted in
                        Task { @MainActor in status = granted ? .authorized : .denied }
                    }
                }
                .controlSize(.large)
            }
        }
    }
}

private struct ModelStep: View {
    let phase: OnboardingModel.ModelPhase
    let retry: () -> Void

    var body: some View {
        StepBody(text: "Murmur downloads a ~600 MB speech model once. It runs entirely on your Mac afterwards — no internet needed to dictate.") {
            switch phase {
            case .idle:
                ProgressView().controlSize(.small)
            case .downloading(let fraction):
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: fraction)
                    Text("Downloading… \(Int(fraction * 100))%")
                        .font(.caption).foregroundStyle(.secondary)
                }
            case .ready:
                Label("Model ready", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed(let message):
                VStack(alignment: .leading, spacing: 8) {
                    Label("Download failed: \(message)", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Button("Retry", action: retry)
                }
            }
        }
    }
}

private struct AccessibilityStep: View {
    var body: some View {
        StepBody(text: "To paste your dictation into other apps, Murmur needs Accessibility access. Click below, then enable Murmur in the list — this screen advances automatically once you do.") {
            Button("Open Accessibility Settings") {
                let url = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                if let link = URL(string: url) { NSWorkspace.shared.open(link) }
            }
            .controlSize(.large)
        }
    }
}

private struct APIKeyStep: View {
    @Binding var apiKey: String

    var body: some View {
        StepBody(text: "Optionally add an OpenAI API key to clean up your transcripts — fixing punctuation, casing, and filler words. Without a key, Murmur pastes the raw transcript, so this step is entirely optional.") {
            VStack(alignment: .leading, spacing: 6) {
                SecureField("OpenAI API key (optional)", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                Text("Leave blank to skip — you can add one later in Settings.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct TryItStep: View {
    let controller: DictationController
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        StepBody(text: "You're all set! Hold your hotkey, say something, and release — your words will appear below.") {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $text)
                    .focused($focused)
                    .frame(height: 90)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                    .onAppear { focused = true }
                Text(statusText)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var statusText: String {
        switch controller.state {
        case .idle, .waiting: "Waiting — hold your hotkey and speak."
        case .recording: "Listening…"
        case .processing: "Transcribing…"
        }
    }
}

// MARK: - Shared layout

/// A step's explanatory paragraph over an optional interactive area.
private struct StepBody<Content: View>: View {
    let text: String
    var footnote: String?
    @ViewBuilder var content: Content

    init(text: String, footnote: String? = nil, @ViewBuilder content: () -> Content = { EmptyView() }) {
        self.text = text
        self.footnote = footnote
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(text).font(.body)
            content
            if let footnote {
                Text(footnote).font(.callout).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
