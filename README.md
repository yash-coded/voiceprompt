# Murmur

**Tired of typing long prompts? Hold a key, speak, release — clean text appears instantly.**

Murmur is a native macOS menubar app that turns your voice into polished text and
pastes it into whatever you're focused on. Transcription runs fully locally on
Apple Silicon ([FluidAudio Parakeet TDT v3](https://github.com/FluidInference/FluidAudio));
the transcript is then optionally cleaned with OpenAI — removing filler words,
fixing grammar, and adapting tone to the app you're in.

[![CI](https://github.com/yash-coded/voiceprompt/actions/workflows/ci.yml/badge.svg)](https://github.com/yash-coded/voiceprompt/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform: macOS Apple Silicon](https://img.shields.io/badge/platform-macOS%20Sequoia%20%C2%B7%20Apple%20Silicon-lightgrey.svg)](https://support.apple.com/en-us/HT211814)

---

## How it works

1. Hold **Right Option (⌥)**
2. Speak naturally — filler words, false starts, anything
3. Release — your words are transcribed, cleaned, and pasted

No wake word. No window switching. Works in any app.

---

## Install

Murmur requires **macOS 15 (Sequoia) or later on Apple Silicon (M1+)**.

Because Murmur is ad-hoc-signed (no paid Apple Developer ID), macOS Gatekeeper
needs a one-time bypass. Pick whichever path you prefer.

### Homebrew

```bash
brew install --cask yash-coded/tap/murmur
```

Murmur is ad-hoc-signed, so the installed app is quarantined like any download.
Clear it once with the **Open Anyway** step below, or skip quarantine up front:

```bash
HOMEBREW_CASK_OPTS="--no-quarantine" brew install --cask yash-coded/tap/murmur
```

(Recent Homebrew removed the bare `--no-quarantine` install flag; the
`HOMEBREW_CASK_OPTS` form above is the current equivalent.)

### Direct download

1. Download the latest `Murmur-<version>.dmg` from
   [Releases](https://github.com/yash-coded/voiceprompt/releases).
2. Open the `.dmg` and drag **Murmur** to **Applications**.
3. Launch it. macOS will warn that it's from an unidentified developer.
4. Open **System Settings → Privacy & Security**, scroll to the message about
   Murmur being blocked, and click **Open Anyway**. Confirm once more.

You only need to do this on first launch.

---

## First run

A short setup wizard walks you through everything:

1. **Microphone access** — required; transcription is local, no audio leaves your Mac.
2. **Speech model download** — a one-time ~600 MB download, cached for future runs.
3. **Accessibility access** — lets Murmur paste text into the focused app via ⌘V.
4. **OpenAI API key** *(optional)* — enables AI cleanup. Skip it and Murmur pastes
   the raw transcript. Stored in your macOS Keychain, never on disk.
5. **Try it** — hold Right Option and dictate a test sentence.

After setup, Murmur lives in the menubar. The icon shows the current state:

| Icon | State |
|------|-------|
| 🎙 `mic` | Idle, ready |
| 🔴 `mic.fill` | Recording |
| ⏳ `hourglass` | Transcribing / cleaning |

Re-run the wizard anytime from **Settings → Run setup again…**.

---

## Features

### Context-aware cleanup
Murmur detects the focused app and applies the right cleanup style automatically —
**Technical** (preserves code, flags, file paths), **Professional**, **Casual**, or
**General**. Per-app modes and the prompts behind each are editable in **Settings**.

### Local transcription
Audio is transcribed on-device with FluidAudio's Parakeet TDT v3 model. Nothing
is uploaded. Only the resulting text is sent to OpenAI when cleanup is enabled.

### Personal dictionary
Add project names, internal tools, or acronyms. Plain terms guide the cleanup
model's spelling; replacement pairs rewrite the transcript before cleanup so they
survive even when cleanup is off or offline.

### History & stats
Optional local SQLite history (off / 7 days / 30 days / forever) with search and
one-click copy, plus a dashboard of words dictated and time saved.

---

## Build from source

```bash
swift build --package-path Murmur            # build
swift test  --package-path Murmur            # run the test suite
scripts/build-dmg.sh                         # produce dist/Murmur-<version>.dmg
scripts/verify-dmg.sh                         # QA-check the produced .dmg
```

### Cutting a release
Bump `VERSION`, then push a matching tag:

```bash
git tag v$(cat VERSION) && git push origin v$(cat VERSION)
```

The [release workflow](.github/workflows/release.yml) builds the ad-hoc-signed
`.dmg` on a macOS runner and attaches it to a new GitHub Release. Then update
`Casks/murmur.rb` with the new `version` and `sha256` (printed by
`scripts/build-dmg.sh`).

---

## Legacy Python CLI

The original Python implementation lives under `src/voiceprompt/` and remains as a
reference spec until Murmur reaches full parity. See its history in the git log.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).
