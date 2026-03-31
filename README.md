# VoicePrompt

macOS menubar app that lets you hold a hotkey, speak, and get clean text pasted wherever your cursor is.

- **Local transcription** via [mlx-whisper](https://github.com/ml-explore/mlx-examples) (runs on Apple Silicon, no cloud)
- **AI cleanup** via OpenAI gpt-4o-mini (removes filler words, fixes grammar)
- **Zero friction**: hold Right Option → speak → release → text appears

## Requirements

- macOS on Apple Silicon
- Python 3.10+
- [uv](https://github.com/astral-sh/uv)
- `OPENAI_API_KEY` environment variable

## Installation

```bash
git clone https://github.com/yourname/voiceprompt
cd voiceprompt
uv sync
```

## Usage

```bash
export OPENAI_API_KEY=sk-...
uv run voiceprompt
```

Hold **Right Option (⌥)** to record, release to transcribe and paste.

### Menubar icons

| Icon | State |
|------|-------|
| ⚫ | Idle, ready |
| 🔴 | Recording |
| ⏳ | Transcribing / cleaning |
| ⚠️ | Error (auto-clears after 3 s) |

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENAI_API_KEY` | *(required)* | OpenAI API key |
| `LOG_LEVEL` | `WARNING` | Python logging level (`DEBUG`, `INFO`, …) |

## Development

```bash
uv sync --extra dev
uv run pytest
```

## Architecture

```
pynput thread          main thread (rumps)        worker thread
──────────────         ───────────────────        ─────────────
key press →            Timer (100 ms) polls        pulls from work_queue
  start RecordThread   result_queue →              transcribe (mlx-whisper)
key release →            pyperclip.copy            clean (gpt-4o-mini)
  stop thread            CGEvent Cmd+V  ←          push to result_queue
  push to work_queue
```

## License

MIT
