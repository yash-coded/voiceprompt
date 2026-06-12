# Murmur — macOS GUI App Design

Decisions locked via design interview, 2026-06-11. This converts the proven
VoicePrompt Python pipeline into a distributable native macOS app.

## Identity
- **Name:** Murmur (renamed from VoicePrompt)
- **Repo:** this repo; Swift project replaces the Python source once at parity.
  Python code stays until then as the reference spec.
- **Target:** macOS 15 Sequoia+, Apple Silicon only.

## Stack
- **Framework:** Native Swift / SwiftUI (MenuBarExtra + windows). No Electron/Tauri.
- **Transcription:** Parakeet TDT v3 via FluidAudio (CoreML, ~600MB model,
  downloaded on first launch). Replaces mlx-whisper.
- **Cleanup:** OpenAI gpt-5-mini, BYO API key stored in Keychain.
  Port the existing prompt strategy: cached system prompt with built-in +
  personal vocabulary, clipboard context, per-app cleanup modes
  (Technical / Professional / Casual / General).
  **Graceful fallback:** no key / offline / 2s timeout → paste raw transcript.
  Settings toggle to disable cleanup. Keep an abstraction seam for a possible
  future local-LLM cleaner.
- **Storage:** SQLite (history), UserDefaults/JSON (settings), Keychain (API key).

## App shape
- **Menubar icon** — status states (idle/recording/processing/error), quick
  actions: mic picker, pause, open main window, quit.
- **Floating waveform pill** — always-on-top NSPanel with live waveform while
  the hotkey is held, processing state after release.
- **Main window** with sidebar sections:
  1. **History** — raw + cleaned text, timestamp, target app; search, copy,
     delete. On by default, 30-day retention (configurable: off/7d/30d/forever).
     Local only.
  2. **Dictionary** — manage personal vocabulary; per-term replacements
     ("jason" → "JSON"). Feeds the cleanup prompt.
  3. **Stats** — words dictated, time saved vs typing, streaks.
  4. **Cleanup modes** — view/edit per-app mode mapping and per-mode prompt
     customization.
  5. **Settings** — audio input source selector, hotkey picker, hold-threshold
     slider, API key, history retention, cleanup on/off.

## Input pipeline (port from Python spec)
- **Hotkey:** configurable modifier-hold (default right-⌥, options for other
  modifiers/Fn), 0.5s hold threshold (slider), via NSEvent flags monitoring —
  no Input Monitoring permission. State machine: IDLE → WAITING → RECORDING →
  PROCESSING; early release cancels; <1s clips discarded.
- **Audio:** AVAudioEngine capture, 16kHz mono; user-selectable input device.
- **Insertion:** save clipboard → set cleaned text → CGEvent ⌘V → restore
  clipboard. Requires Accessibility permission (requested in onboarding).

## Onboarding (guided wizard)
1. Welcome
2. Microphone permission
3. Parakeet model download with progress bar
4. Accessibility permission (for paste)
5. Optional OpenAI API key
6. "Try it now" dictation test box

## Distribution
- Ad-hoc-signed .dmg on GitHub Releases — **no Apple Developer account, no
  notarization, no auto-update**. README documents the one-time Gatekeeper
  bypass (System Settings → Privacy & Security → Open Anyway).
- Homebrew cask with `--no-quarantine` as the smooth install path.

## Explicitly out of scope (v1)
- Mac App Store, Sparkle auto-updates, code signing identity
- Intel Macs, macOS < 15
- Local LLM cleanup (seam only)
- Press-to-toggle / hands-free mode (hold-to-talk only)
