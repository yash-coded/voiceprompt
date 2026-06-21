# 03 — Floating Waveform Pill

Status: done
Type: AFK
Blocked by: 01

## What to build
An always-on-top, non-activating floating panel (NSPanel-style) that appears while the hotkey is held and recording is active. It renders a live waveform driven by microphone input levels so the user gets immediate visual feedback that they are being heard. When the hotkey is released, the pill switches to a processing state (e.g. animated indicator) while transcription/cleanup runs, then disappears when the text is pasted, the dictation is cancelled (early release or <1s clip), or an error occurs.

Critically, the panel must never steal keyboard focus or activate the app — the target app must remain frontmost the whole time so the paste lands in the right place.

## Acceptance criteria
- [x] Pill appears when recording starts and shows a waveform that visibly responds to speaking vs silence. (Driven by `recording` state → `beginRecording`; bars fed by per-chunk RMS levels. Live visual pending HITL.)
- [x] On hotkey release the pill switches to a processing state until paste completes. (`processing` state → `beginProcessing`.)
- [x] Pill disappears after paste, on cancel, and on error — it never lingers. (Every terminal path drives state to `.idle` → `hide()`; verified by control-flow + controller tests.)
- [x] The frontmost app keeps focus throughout; dictated text still pastes into it while the pill is visible. (`FloatingPanel` is non-activating, `canBecomeKey/Main == false`, ignores mouse events; verified by panel tests. Live paste pending HITL.)
- [x] Pill floats above other windows, including full-screen-adjacent contexts where feasible. (`.statusBar` level + `.fullScreenAuxiliary`/`.canJoinAllSpaces`; verified by panel tests.)

## Out of scope
- Any user-facing settings for pill position/appearance.
- Showing transcript text or cleanup status detail inside the pill.
- Menubar icon changes — slice 01's states remain as-is.

## Comments
2026-06-20 — Implemented as four seams: `AudioRecorder.level(of:)` (pure RMS) +
`onLevel` callback feed loudness; `WaveformPillModel` (@Observable) holds
visibility/phase/levels; `FloatingPanel` (non-activating NSPanel) provides the
focus-safe always-on-top surface; `WaveformPillController` maps `HotkeyState` →
show/processing/hide and gates levels on visibility. `WaveformPillView` renders
frosted capsule with scrolling bars (recording) / pulsing dots (processing).
DictationController drives the pill off the existing `onStateChange` plus
`recorder.onLevel`. 24 new unit tests (level math, model lifecycle, panel
config, controller state mapping); full suite 59/59 green; app launch smoke OK.
Live on-screen appearance + paste-while-visible need human verification (HITL),
same as slice 01's mic/paste.
