# 07 — Cleanup Mode Editor

Status: ready
Type: AFK
Blocked by: 04

## What to build
The Cleanup Modes sidebar section: a UI exposing the per-app bundle-id → mode mapping that drives mode selection. It shows the built-in mappings (terminals/editors → Technical, work chat/email → Professional, casual messengers → Casual), lets the user override any app's mode, and lets them add custom entries for apps not in the built-in list (ideally pickable from installed/running apps rather than typing bundle ids by hand). Overrides take precedence over built-ins and the name-substring fallback.

Each of the four modes' prompt-instruction text is also editable, with a reset-to-default action per mode that restores the built-in instructions. Edits take effect on the next dictation without restart.

## Acceptance criteria
- [ ] Built-in app→mode mappings are visible in the UI.
- [ ] Overriding an app's mode changes which prompt is used on the next dictation into that app.
- [ ] A custom app entry can be added and removed, and behaves like a built-in mapping.
- [ ] Per-mode prompt text can be edited, persists, and is used by the cleaner.
- [ ] Reset-to-default restores a mode's original prompt text.

## Out of scope
- Creating new modes beyond the four built-ins.
- Per-app (rather than per-mode) prompt text.
- Editing the vocabulary blocks (slice 06 / built-in).

## Comments
