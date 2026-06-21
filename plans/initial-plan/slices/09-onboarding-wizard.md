# 09 — Onboarding Wizard

Status: done
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

2026-06-21 — Implemented. Pure core (`OnboardingStep` ordered steps; `OnboardingModel`
step navigation + model-download state machine with retry + accessibility auto-advance
+ API-key commit to Keychain) is fully unit-tested with an injected `ModelDownloader`
(`.live` wraps FluidAudio's cached, idempotent `downloadAndLoad`+`modelsExist`).
`OnboardingView` renders one screen per step with a shared Back/Continue footer; the
model step blocks Continue until the download is ready and shows a Retry button on
failure; the accessibility step opens the Privacy pane and a 0.5s poll auto-advances on
`AXIsProcessTrusted`; the API-key field is clearly optional; the "try it now" step has a
focused editable test box that the live dictation pipeline pastes into. `OnboardingWindowController`
hosts it in an NSWindow, shown from `AppDelegate` on first launch only (gated on new
`Settings.onboardingCompleted`, which also persists when the window is dismissed by any
means) and re-runnable via a "Run setup again…" button in Settings. The dictation
pipeline runs from launch independent of the wizard, so the app is usable immediately
after finishing with no restart. The key lands in `KeychainStore.openAIKey`, the same
entry `OpenAICleaner` reads. 14 new tests, full suite 132/132, app launch smoke OK.
Live mic/accessibility prompts, real model download progress, and hotkey dictation in
the test box are pending HITL.
