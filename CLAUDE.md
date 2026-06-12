# VoicePrompt → Murmur

This repo is mid-conversion from a Python CLI dictation tool (`src/voiceprompt/`,
the proven reference spec — do not delete until parity) to **Murmur**, a native
Swift/SwiftUI macOS GUI app.

## Multi-session plan execution

Work is planned and executed across independent agent sessions. Before doing
ANY implementation work:

1. Read `plans/PROCESS.md` — the rules for planning, executing, and reviewing.
2. Read the active plan: `plans/initial-plan/DESIGN.md` and `progress.txt`.
3. Pick the lowest-numbered slice in `plans/initial-plan/slices/` that is
   `Status: ready` with all blockers `done`. Execute exactly one slice, verify
   its acceptance criteria, then update its Status and append to progress.txt
   in the same commit.

`progress.txt` is append-only — never edit existing lines.
