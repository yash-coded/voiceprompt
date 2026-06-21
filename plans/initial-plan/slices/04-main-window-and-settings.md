# 04 — Main Window and Settings

Status: done
Type: AFK
Blocked by: 02

## What to build
A main window, opened from the menubar menu, with a sidebar navigation shell containing History, Dictionary, Stats, Cleanup Modes, and Settings sections. Only Settings needs to be functional in this slice; the other sections may be placeholders that later slices fill in.

The Settings section is fully working: an audio input device picker (lists live devices, persists the choice, and falls back to the system default if the chosen device disconnects), a hotkey modifier picker plus hold-threshold slider, an OpenAI API key field stored in the Keychain (replacing slice 02's temporary debug mechanism), a cleanup on/off toggle, and a history retention picker (off / 7 days / 30 days / forever, defaulting to 30 days). All settings persist across launches and take effect immediately without restarting the app — e.g. changing the hotkey modifier or threshold rebinds the listener live, and toggling cleanup off makes the next dictation paste raw text.

## Acceptance criteria
- [ ] Main window opens from the menubar menu and shows the five sidebar sections.
- [ ] Selected input device is used for recording, persists across restarts, and recording falls back to the default device if it disconnects.
- [ ] Changing the hotkey modifier and hold threshold takes effect on the very next dictation without restart.
- [ ] API key entered in Settings is stored in the Keychain and used by the cleaner; the slice-02 debug mechanism is removed.
- [ ] Cleanup toggle off → raw transcript pasted; on → cleaned text pasted.
- [ ] History retention setting persists with the correct default (30 days), ready for slice 05 to enforce.

## Out of scope
- History, Dictionary, Stats, Cleanup Modes section content (slices 05–08).
- Onboarding wizard (slice 09).
- Login-item / launch-at-startup behavior.

## Comments
2026-06-20 — Implemented. `Settings` is an `@Observable` write-through store
over UserDefaults (single source of truth); API key stays in the Keychain. The
`DictationController` reads settings live on each event, so hotkey/threshold/
device/cleanup changes apply on the next dictation with no restart and no
listener rebind. Audio device selection resolves the chosen UID against the
live device list (`AudioDeviceResolver`), falling back to the system default
when it disconnects. Main window is a `NavigationSplitView` with 5 sections;
only Settings is functional (others are `ContentUnavailableView` placeholders
for slices 05–08). Removed slice-02's debug API-key NSAlert.
Testable kernels covered by 12 new unit tests (Settings defaults/persistence,
HotkeyModifier matching, HistoryRetention mapping, AudioDeviceResolver
fallback). SwiftUI views and live device switching are visual/HITL — full
suite 71/71, app launch smoke OK.
