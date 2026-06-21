# 10 — Packaging and Distribution

Status: done
Type: HITL
Blocked by: 09

## What to build
A release build script that produces an ad-hoc-signed .dmg of Murmur (no Apple Developer account, no notarization), plus the distribution channels around it: a GitHub Release flow that publishes the versioned .dmg, and a Homebrew cask formula installing it with `--no-quarantine` as the smooth path.

Rewrite the README for the GUI app: what Murmur is, install instructions for both paths — the direct .dmg download including the one-time Gatekeeper "Open Anyway" bypass (System Settings → Privacy & Security), and the Homebrew cask with `--no-quarantine` — plus first-run expectations (model download, permissions). A human must verify the .dmg installs and runs on a clean machine.

## Acceptance criteria
- [ ] A single script produces an ad-hoc-signed .dmg from a clean checkout.
- [ ] A GitHub Release is created (or a documented, repeatable flow exists) with the .dmg attached.
- [ ] The Homebrew cask formula installs the app with `--no-quarantine` and it launches.
- [ ] README documents both install paths, including the Gatekeeper "Open Anyway" steps, accurately for the GUI app.
- [ ] Human verifies: installing the .dmg on a clean machine (no dev tools), passing Gatekeeper via Open Anyway, completing onboarding, and performing a successful dictation.

## Out of scope
- Notarization or a paid signing identity.
- Sparkle or any auto-update mechanism.
- Mac App Store distribution.
- Removing the legacy Python source (stays as reference spec until parity is confirmed).

## Comments

2026-06-21 — Implemented. `scripts/build-dmg.sh` builds release, assembles an
ad-hoc-signed `Murmur.app` (Info.plist with bundle id `io.github.yash-coded.murmur`,
`LSUIElement`, `NSMicrophoneUsageDescription`), and packages a versioned
`dist/Murmur-<version>.dmg` with an /Applications drag target; version comes from
the `VERSION` file. `scripts/verify-dmg.sh` is the automated QA gate (mounts the
dmg, asserts bundle structure, ad-hoc signature, and Info.plist keys) — ran green
on the produced 0.1.0 dmg, and the packaged app launches without crashing.
`.github/workflows/release.yml` builds + verifies + publishes the dmg on a `v*`
tag. `Casks/murmur.rb` installs via `brew install --cask --no-quarantine`. README
rewritten for the GUI app (both install paths incl. Gatekeeper "Open Anyway",
first-run wizard, build-from-source). Remaining HITL: install the dmg on a clean
machine, pass Gatekeeper, complete onboarding, perform a real dictation.
