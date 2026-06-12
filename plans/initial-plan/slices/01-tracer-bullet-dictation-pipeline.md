# 01 — Tracer Bullet: Dictation Pipeline

Status: ready
Type: HITL
Blocked by: None — can start immediately

## What to build
A minimal SwiftUI menubar app named Murmur (macOS 15+, Apple Silicon only) as an SPM/Xcode project living in a `Murmur/` directory at the repo root (path exception allowed — the project does not exist yet). It implements the narrowest possible end-to-end dictation path: hold right Option to record, release to transcribe, and the raw transcript is pasted into whatever app is frontmost. No cleanup, no settings, no windows — this slice proves the whole stack.

The hotkey is a hardcoded right-Option hold-to-talk monitored via NSEvent flags-changed global monitoring (no Input Monitoring permission). Port the behavior of the Python hotkey module's state machine: IDLE → WAITING (key down, 0.5s hold-threshold timer) → RECORDING (timer fires while still held) → PROCESSING (key released). Releasing before the threshold cancels silently back to IDLE; recordings shorter than 1 second are discarded. Audio is captured at 16kHz mono via AVAudioEngine from the default input device. Transcription runs locally with Parakeet TDT v3 via FluidAudio; the model is downloaded on first run (blocking the first dictation is acceptable for now).

Insertion ports the Python pipeline's clipboard strategy: save the current clipboard, set the transcript, synthesize Cmd-V via CGEvent (requires Accessibility permission), then restore the prior clipboard contents. The menubar icon visually distinguishes idle, recording, and processing states, and offers a Quit action.

## Acceptance criteria
- [ ] Holding right Option for 0.5s starts recording; releasing before 0.5s does nothing visible and returns to idle.
- [ ] Releasing after recording transcribes the audio locally with Parakeet and pastes the raw transcript into the frontmost app via simulated Cmd-V.
- [ ] Recordings under 1 second are discarded with no paste.
- [ ] The user's prior clipboard contents are restored after the paste.
- [ ] Menubar icon reflects idle / recording / processing states and has a working Quit item.
- [ ] The Parakeet model downloads automatically on first run if missing, and subsequent runs reuse it.
- [ ] Human verifies: after granting mic and Accessibility permissions, a real spoken sentence lands as text in another app (e.g. TextEdit).

## Out of scope
- LLM cleanup, app/mode detection, vocabulary (slice 02).
- Floating waveform pill or any window UI (slices 03–04).
- Configurable hotkey, device selection, settings persistence (slice 04).
- Onboarding/permission walkthrough UX — manual permission grants are fine here (slice 09).

## Comments
