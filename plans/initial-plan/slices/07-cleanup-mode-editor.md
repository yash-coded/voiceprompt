# 07 — Cleanup Mode Editor

Status: done
Type: AFK
Blocked by: 04

## What to build
The Cleanup Modes sidebar section: a UI exposing the per-app bundle-id → mode mapping that drives mode selection. It shows the built-in mappings (terminals/editors → Technical, work chat/email → Professional, casual messengers → Casual), lets the user override any app's mode, and lets them add custom entries for apps not in the built-in list (ideally pickable from installed/running apps rather than typing bundle ids by hand). Overrides take precedence over built-ins and the name-substring fallback.

Each of the four modes' prompt-instruction text is also editable, with a reset-to-default action per mode that restores the built-in instructions. Edits take effect on the next dictation without restart.

## Acceptance criteria
- [x] Built-in app→mode mappings are visible in the UI.
- [x] Overriding an app's mode changes which prompt is used on the next dictation into that app.
- [x] A custom app entry can be added and removed, and behaves like a built-in mapping.
- [x] Per-mode prompt text can be edited, persists, and is used by the cleaner.
- [x] Reset-to-default restores a mode's original prompt text.

## Out of scope
- Creating new modes beyond the four built-ins.
- Per-app (rather than per-mode) prompt text.
- Editing the vocabulary blocks (slice 06 / built-in).

## Comments
2026-06-21 — Implemented. `CleanupModeStore` (JSON-backed, observable) holds app
overrides + custom apps and per-mode prompt edits; `CleanModeDetector` refactored
to a `builtIns: [AppModeMapping]` list (with display names) plus an `overrides`
param that wins over the bundle map and name fallback. `CleanupPrompts.systemPrompt`
gained a `promptBody` override + `defaultBody(for:)`; the `TranscriptCleaner` seam
threads it through and `DictationController` captures the effective body at
key-press time so edits apply next dictation without restart. `CleanupModesView`
wires the pane (mode pickers per app, "Add App…" from running apps, per-mode
TextEditor with reset). 10 new tests, full suite 108/108, app launch smoke OK.
Live UI/picker/paste-while-overridden pending HITL.
