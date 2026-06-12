# 09 — Onboarding Wizard

Status: ready
Type: AFK
Blocked by: 04

## What to build
A first-launch guided wizard that takes a fresh install to a working dictation setup: welcome screen → microphone permission request → Parakeet model download with a progress bar and retry on failure → accessibility permission walkthrough that detects when the grant happens and advances automatically → optional OpenAI API key entry (clearly skippable, explaining the raw-transcript fallback) → a "try it now" step with a live dictation test box where the user holds the hotkey and sees their words appear.

The wizard runs automatically on first launch only, is re-runnable from Settings, and the app must be fully usable immediately after finishing it — no restart required.

## Acceptance criteria
- [ ] On a profile with no prior state, the wizard appears on first launch and never again on subsequent launches.
- [ ] Mic and accessibility steps trigger the system prompts/panes, and the accessibility step detects the grant and advances.
- [ ] Model download shows real progress and a failed download can be retried without restarting the wizard.
- [ ] API key step can be skipped, and a key entered here lands in the Keychain and is used by the cleaner.
- [ ] The "try it now" step performs a real hotkey-driven dictation whose text appears in the test box.
- [ ] The wizard can be relaunched from Settings, and dictation works immediately after completing it with no app restart.

## Out of scope
- Permission-revocation recovery flows outside the wizard.
- Video tutorials, tips, or marketing content in the wizard.
- Migrating legacy Python config (handled in slice 06).

## Comments
