# 02 — OpenAI Cleanup with Graceful Fallback

Status: ready
Type: AFK
Blocked by: 01

## What to build
Port the Python cleaner module's behavior into the Swift pipeline: after transcription, the raw transcript is sent to OpenAI gpt-5-mini for cleanup before pasting. The system prompt is structured for prompt-cache hits (stable system message, transcript in the user message) and includes the built-in ~400-term software-engineering vocabulary block. At key-press time (while the target app still has focus) the frontmost app is detected and mapped to one of four cleanup modes — Technical / Professional / Casual / General — via a bundle-id map with name-substring fallback, each mode carrying its own prompt instructions (Casual omits the built-in vocabulary). Up to 500 characters of clipboard text is injected as context when present. The API call has a 2-second timeout.

The API key is read from the macOS Keychain; until slice 04 ships a settings UI, provide a temporary debug mechanism to set it (e.g. a hidden menubar item or command-line flag). Fallback must be graceful in every failure case — no key, offline, timeout, or API error — by pasting the raw transcript instead, never blocking or erroring at the user. The cleaner sits behind a protocol abstraction so a local-LLM cleaner could be slotted in later. Strip common LLM preamble lines (e.g. "Here is…", "Cleaned text:") from responses, matching the Python behavior.

## Acceptance criteria
- [ ] With a valid key, a dictation pastes cleaned text (fillers removed, self-corrections collapsed) instead of the raw transcript.
- [ ] Frontmost-app detection picks the correct mode (e.g. a terminal → Technical, Slack → Professional, Messages → Casual, unknown app → General) and the mode's prompt instructions are used.
- [ ] Clipboard text up to 500 chars is included as context in the request; longer clipboard content is truncated.
- [ ] With no key, no network, or a response slower than 2s, the raw transcript is pasted with no user-facing error.
- [ ] API key is stored in and read from the Keychain via the temporary debug mechanism.
- [ ] The cleaner is invoked through a protocol so an alternative implementation can be substituted without touching the pipeline.

## Out of scope
- Settings UI for the API key or cleanup toggle (slice 04).
- Personal vocabulary / dictionary terms (slice 06) — built-in vocabulary only.
- Editable mode mappings or prompt text (slice 07).
- Any local-LLM cleaner implementation — the protocol seam only.

## Comments
