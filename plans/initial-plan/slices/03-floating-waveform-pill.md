# 03 — Floating Waveform Pill

Status: ready
Type: AFK
Blocked by: 01

## What to build
An always-on-top, non-activating floating panel (NSPanel-style) that appears while the hotkey is held and recording is active. It renders a live waveform driven by microphone input levels so the user gets immediate visual feedback that they are being heard. When the hotkey is released, the pill switches to a processing state (e.g. animated indicator) while transcription/cleanup runs, then disappears when the text is pasted, the dictation is cancelled (early release or <1s clip), or an error occurs.

Critically, the panel must never steal keyboard focus or activate the app — the target app must remain frontmost the whole time so the paste lands in the right place.

## Acceptance criteria
- [ ] Pill appears when recording starts and shows a waveform that visibly responds to speaking vs silence.
- [ ] On hotkey release the pill switches to a processing state until paste completes.
- [ ] Pill disappears after paste, on cancel, and on error — it never lingers.
- [ ] The frontmost app keeps focus throughout; dictated text still pastes into it while the pill is visible.
- [ ] Pill floats above other windows, including full-screen-adjacent contexts where feasible.

## Out of scope
- Any user-facing settings for pill position/appearance.
- Showing transcript text or cleanup status detail inside the pill.
- Menubar icon changes — slice 01's states remain as-is.

## Comments
