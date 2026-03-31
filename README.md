# VoicePrompt

**Tired of typing long prompts? Hold a key, speak, release — clean text appears instantly.**

VoicePrompt is a macOS menubar app that turns your voice into polished text and pastes it directly into whatever you're focused on. It runs fully local transcription on Apple Silicon using Whisper, then cleans the transcript with GPT-4o-mini — removing filler words, fixing grammar, and adapting the tone to the app you're using.

[![CI](https://github.com/yash-coded/voiceprompt/actions/workflows/ci.yml/badge.svg)](https://github.com/yash-coded/voiceprompt/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Python 3.10+](https://img.shields.io/badge/python-3.10%2B-blue.svg)](https://www.python.org/)
[![Platform: macOS Apple Silicon](https://img.shields.io/badge/platform-macOS%20Apple%20Silicon-lightgrey.svg)](https://support.apple.com/en-us/HT211814)

---

## How it works

1. Hold **Right Option (⌥)** for 0.5 seconds
2. Speak naturally — filler words, false starts, anything
3. Release — your words are transcribed, cleaned, and pasted

No wake word. No window switching. Works in any app.

---

## Features

### Context-aware cleanup
VoicePrompt detects which app is focused and applies the right cleanup style automatically:

| App | Mode | Behaviour |
|-----|------|-----------|
| Claude, VS Code, iTerm2, Warp, Cursor | **Technical** | Preserves every technical detail exactly — variable names, CLI flags, model names, file paths. Removes filler only. |
| Slack, Teams, Outlook, Mail | **Professional** | Removes fillers, fixes grammar, keeps tone friendly and natural. |
| iMessage, WhatsApp, Discord, Telegram | **Casual** | Minimal touch — strips only `um/uh`, preserves your speaking style and converts spoken emoji descriptions to real emoji. |
| Everything else | **General** | Balanced cleanup. |

### Local transcription, no audio leaves your machine
Transcription runs on-device using [mlx-whisper](https://github.com/ml-explore/mlx-examples) — your audio is never sent to any server. Only the text transcript is sent to OpenAI for cleanup.

### Built-in software engineering vocabulary
Over 400 technical terms are pre-loaded — `TypeScript`, `kubectl`, `PostgreSQL`, `useEffect`, `Next.js`, `gRPC`, `Terraform`, `LangChain`, and more. Whisper uses these to spell them correctly. The cleanup model uses them to preserve exact casing and hyphenation.

### Personal vocabulary
Add your own terms during setup: project names, internal tools, unusual acronyms. Stored locally in `~/.config/voiceprompt/config.json`.

### Clipboard context
Whatever is in your clipboard when you start speaking is silently passed to the cleanup model as context. If you copy a function signature before dictating a comment about it, the model aligns terminology automatically.

---

## Requirements

- macOS on Apple Silicon (M1 or later)
- Python 3.10+
- [uv](https://github.com/astral-sh/uv) — fast Python package manager
- OpenAI API key (for cleanup — transcription is local)

---

## Installation

```bash
git clone https://github.com/yash-coded/voiceprompt
cd voiceprompt
uv sync
uv run voiceprompt-setup
```

The setup wizard walks you through:
1. OpenAI API key
2. Paste behaviour (auto-paste vs clipboard-only, depending on admin rights)
3. Personal vocabulary
4. Installing as a background service (starts at login)

---

## Usage

If you installed via the setup wizard, VoicePrompt runs automatically at login. The menubar icon shows the current state:

| Icon | State |
|------|-------|
| 🎙 | Idle, ready to record |
| 🔴 | Recording |
| ⏳ | Transcribing and cleaning |
| ⚠️ | Error (auto-clears after 3 s) |

**Trigger:** hold **Right Option (⌥)** for 0.5 seconds, speak, release.

To run manually without the service:
```bash
uv run voiceprompt
```

To re-run setup (update API key, paste mode, or vocabulary):
```bash
uv run voiceprompt-setup
```

To uninstall the background service:
```bash
uv run voiceprompt-uninstall
```

---

## Configuration

All config is stored at `~/.config/voiceprompt/config.json` and never committed to git.

| Environment variable | Default | Description |
|----------------------|---------|-------------|
| `OPENAI_API_KEY` | *(from config)* | OpenAI API key — set during setup |
| `LOG_LEVEL` | `WARNING` | Python logging level (`DEBUG`, `INFO`, `WARNING`) |

---

## Architecture

```
NSEvent (main thread)          worker thread              main thread (rumps)
─────────────────────          ─────────────              ──────────────────
Right Option held 0.5s →       pulls (wav, mode, ctx)     Timer (100 ms) polls
  detect frontmost app →         transcribe (mlx-whisper)  result_queue →
  read clipboard ctx   →         clean (gpt-4o-mini)         pyperclip.copy
  start RecordThread   →         push to result_queue        osascript Cmd+V
Right Option released →
  stop RecordThread
  push to work_queue
```

**Key design decisions:**
- NSEvent `FlagsChanged` monitor requires no Input Monitoring permission (same mechanism as Claude Desktop's double-⌥ trigger)
- 0.5-second hold threshold prevents accidental triggers
- Context detection (`NSWorkspace.frontmostApplication`) happens at key-press time while the target app still has focus
- Vocabulary block is in the OpenAI `system` message — cached automatically after the first request for ~40% cost reduction

---

## Development

```bash
uv sync --extra dev
uv run pytest
uv run pytest --tb=short -v   # verbose
LOG_LEVEL=DEBUG uv run voiceprompt  # run with debug logging
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## License

MIT — see [LICENSE](LICENSE).
