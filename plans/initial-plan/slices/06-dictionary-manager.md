# 06 — Dictionary Manager

Status: done
Type: AFK
Blocked by: 04

## What to build
The Dictionary sidebar section: a GUI for the user's personal vocabulary. Users can add and remove terms, and optionally attach a replacement pair to a term (e.g. "jason" → "JSON") so common mistranscriptions are corrected. Plain terms are injected into the cleanup system prompt's personal-vocabulary line so the LLM preserves their exact spelling and casing. Replacement pairs are applied deterministically to the transcript even when cleanup is skipped or falls back to raw mode, so they work offline.

On first use, migrate any existing personal terms from the legacy Python config at ~/.config/voiceprompt/config.json if that file exists, without modifying or deleting the original file.

## Acceptance criteria
- [ ] Terms can be added and removed in the UI and persist across restarts.
- [ ] A term with a replacement pair rewrites matching transcript text even when cleanup is off or has fallen back to raw paste.
- [ ] Plain terms appear in the cleanup prompt's personal-vocabulary section on the next dictation.
- [ ] Existing terms in the legacy Python config are imported once, appear in the UI, and the legacy file is left untouched.
- [ ] Duplicate terms are prevented or merged sensibly.

## Out of scope
- Editing the built-in ~400-term vocabulary.
- Per-mode or per-app vocabularies.
- Import/export of dictionaries beyond the one-time legacy migration.

## Comments
2026-06-20: Implemented. `DictionaryStore` (JSON-backed, observable) + pure
`PersonalDictionary` helpers + `DictionaryTerm` value type. Plain terms inject
into the cleanup system prompt (ported Python's user-vocab line); replacement
pairs rewrite the transcript whole-word/case-insensitive in the controller
*before* cleanup, so they survive the cleaned, raw, and fallback paths. Legacy
`~/.config/voiceprompt/config.json` `vocabulary` migrates once on first launch
(read-only; never modified) — "once" is enforced by the saved dictionary.json
existing. Duplicates merge case-insensitively, updating the replacement source.
DictionaryView wired into the sidebar. 14 new tests; full suite 98/98; app
launch smoke OK. Live UI interaction pending HITL.
