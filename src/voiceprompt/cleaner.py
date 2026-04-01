"""OpenAI gpt-5-mini transcript cleaner."""

from __future__ import annotations

import logging
import os
from typing import Optional

from openai import OpenAI  # type: ignore[import]

from voiceprompt.context import CleanMode
from voiceprompt.vocabulary import VOCABULARY_BY_CATEGORY, WHISPER_VOCABULARY

LOG = logging.getLogger(__name__)

TIMEOUT = 2.0  # seconds
MODEL = "gpt-5-mini"

# ---------------------------------------------------------------------------
# Default vocabulary block — built once at import time from VOCABULARY_BY_CATEGORY.
# Injected into the LLM prompt for TECHNICAL, PROFESSIONAL, and GENERAL modes.
# Not injected for CASUAL (iMessage/WhatsApp/Discord — no need for kubectl there).
# ---------------------------------------------------------------------------

_DEFAULT_VOCAB_BLOCK: str = (
    "Software engineering vocabulary — preserve exact spelling and casing "
    "for all of the following terms:\n"
    + "\n".join(
        f"  {category}: {', '.join(terms)}"
        for category, terms in VOCABULARY_BY_CATEGORY.items()
    )
    + "\n\n"
)

_MODES_WITH_DEFAULT_VOCAB = {CleanMode.TECHNICAL, CleanMode.PROFESSIONAL, CleanMode.GENERAL}

# ---------------------------------------------------------------------------
# Prompt building blocks
# ---------------------------------------------------------------------------

# Injected when clipboard context is present (any mode).
_CONTEXT_BLOCK = (
    "Context the user is working with (use this to align terminology, "
    "do NOT include it in the output):\n---\n{clipboard_ctx}\n---\n\n"
)

# Injected when the user has a personal vocabulary list.
_USER_VOCAB_LINE = "Also preserve these personal terms exactly as written: {vocab_list}.\n\n"

# Prompt bodies are now the system message instructions only — the transcript
# is passed separately in the user message to maximise OpenAI prompt-cache hits.
_PROMPT_BODIES: dict[CleanMode, str] = {
    CleanMode.TECHNICAL: (
        "Clean the voice transcript the user provides. It will be used as a "
        "technical prompt or command.\n\n"
        "Rules:\n"
        "- Remove filler words (uh, um, like, you know, so) and verbal tics\n"
        "- If the speaker corrects themselves mid-sentence, include only the "
        "corrected version\n"
        "- Preserve ALL technical details exactly: variable names, CLI flags, "
        "model names, code identifiers, numbers, file paths, and exact wording\n"
        "- Fix punctuation and capitalisation only — do NOT rephrase, simplify, "
        "or reword anything\n"
        "- This is a cleanup task, not a rewriting task\n\n"
        "Return only the cleaned text, nothing else."
    ),
    CleanMode.PROFESSIONAL: (
        "Clean the voice transcript the user provides. It will be sent as a "
        "work message (Slack, Teams, or email).\n\n"
        "Rules:\n"
        "- Remove filler words (uh, um, like, you know, so) and verbal tics\n"
        "- If the speaker corrects themselves mid-sentence, include only the "
        "corrected version\n"
        "- Fix grammar and punctuation\n"
        "- Keep the tone professional yet friendly and natural — do not make it "
        "overly formal or stiff\n"
        "- Preserve the original meaning completely — do NOT add new ideas or "
        "expand on what was said\n"
        "- This is a cleanup task, not a rewriting task\n\n"
        "Return only the cleaned text, nothing else."
    ),
    CleanMode.CASUAL: (
        "Lightly clean the voice transcript the user provides. It will be sent "
        "as a casual message (iMessage, WhatsApp, or Discord).\n\n"
        "Rules:\n"
        "- Remove only mechanical filler words (uh, um, hmm) — preserve natural "
        "speech patterns like 'you know', 'I mean', 'right?'\n"
        "- If the speaker corrects themselves mid-sentence, include only the "
        "corrected version\n"
        "- Fix obvious typos but preserve the speaker's style, contractions, and "
        "informal phrasing\n"
        "- Do NOT restructure sentences or make them sound formal\n"
        "- Replace any spoken emoji descriptions (e.g. 'laughing face') with the "
        "actual emoji\n\n"
        "Return only the cleaned text, nothing else."
    ),
    CleanMode.GENERAL: (
        "Clean the voice transcript the user provides.\n\n"
        "Rules:\n"
        "- Remove filler words (uh, um, like, you know)\n"
        "- If the speaker corrects themselves mid-sentence, include only the "
        "corrected version\n"
        "- Fix grammar and punctuation, preserve technical terms exactly as spoken\n\n"
        "Return only the cleaned text, nothing else."
    ),
}

# LLM preambles to strip from responses (case-insensitive prefix check).
_PREAMBLE_PREFIXES = (
    "sure,", "here is", "here's", "certainly,", "of course,",
    "cleaned text:", "corrected text:", "transcript:",
)


def _strip_preamble(text: str) -> str:
    """Remove common LLM preamble lines from the start of *text*."""
    lines = text.splitlines()
    if lines and lines[0].lower().rstrip().startswith(_PREAMBLE_PREFIXES):
        lines = lines[1:]
        while lines and not lines[0].strip():
            lines = lines[1:]
    return "\n".join(lines).strip()


def build_whisper_prompt(user_vocabulary: list[str]) -> str:
    """Return an initial_prompt string for Whisper.

    Combines the built-in WHISPER_VOCABULARY with the user's personal terms.
    Whisper follows the *style* of the prompt rather than instructions, so
    listing terms naturally steers it toward correct spelling and casing.
    The combined list is capped so the prompt stays under Whisper's 224-token limit.
    """
    # Merge: built-in defaults first, then user additions (deduped, preserve order)
    seen: set[str] = set()
    merged: list[str] = []
    for term in WHISPER_VOCABULARY + user_vocabulary:
        if term not in seen:
            seen.add(term)
            merged.append(term)
    # Hard cap: ~90 terms × ~2 tokens each ≈ 180 tokens + prefix safely under 224
    merged = merged[:90]
    return "Key terms: " + ", ".join(merged) + "."


class Cleaner:
    """Wraps OpenAI to clean raw Whisper transcripts."""

    def __init__(self, api_key: str = "", vocabulary: list[str] | None = None) -> None:
        """*api_key* takes precedence; falls back to OPENAI_API_KEY env var."""
        key = api_key or os.environ.get("OPENAI_API_KEY", "")
        if not key:
            raise EnvironmentError(
                "OPENAI_API_KEY is not set. Run 'voiceprompt-setup' to configure."
            )

        self._client = OpenAI(api_key=key, timeout=TIMEOUT)
        self._vocabulary: list[str] = vocabulary or []

    def _build_system_prompt(self, mode: CleanMode) -> str:
        """Build the static system message for *mode*.

        This is the same for every request of the same mode (assuming the user's
        personal vocabulary doesn't change mid-session), so OpenAI's automatic
        prompt caching will kick in after the first request and cache the entire
        system message at 50% cost.
        """
        parts: list[str] = []

        if mode in _MODES_WITH_DEFAULT_VOCAB:
            parts.append(_DEFAULT_VOCAB_BLOCK)

        if self._vocabulary:
            parts.append(_USER_VOCAB_LINE.format(vocab_list=", ".join(self._vocabulary)))

        parts.append(_PROMPT_BODIES[mode])
        return "".join(parts)

    def clean(
        self,
        transcript: str,
        mode: CleanMode = CleanMode.GENERAL,
        clipboard_ctx: str = "",
    ) -> str:
        """Return cleaned transcript, or *transcript* on any failure.

        Args:
            transcript:    Raw Whisper output.
            mode:          Cleanup style derived from the frontmost app.
            clipboard_ctx: Optional clipboard text captured at key-press time,
                           used to align terminology (e.g. replying to a message).

        Prompt caching strategy
        -----------------------
        The static parts (vocabulary block, user vocab, mode instructions) go in
        the ``system`` message.  The variable parts (clipboard context, transcript)
        go in the ``user`` message.  OpenAI automatically caches ``system`` message
        prefixes ≥1024 tokens at 50% off, so the ~2200-token vocabulary block is
        cached after the first request for each mode.
        """
        if not transcript.strip():
            return transcript

        system_prompt = self._build_system_prompt(mode)

        # User message: variable content only
        user_parts: list[str] = []
        if clipboard_ctx:
            user_parts.append(_CONTEXT_BLOCK.format(clipboard_ctx=clipboard_ctx[:500]))
        user_parts.append("Transcript: " + transcript)
        user_prompt = "".join(user_parts)

        try:
            response = self._client.chat.completions.create(
                model=MODEL,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user",   "content": user_prompt},
                ],
                max_tokens=1024,
                temperature=0,
            )
            cleaned: Optional[str] = response.choices[0].message.content
            if not cleaned or not cleaned.strip():
                LOG.warning("OpenAI returned empty response – using raw transcript")
                return transcript
            cleaned = _strip_preamble(cleaned)
            if not cleaned:
                return transcript
            LOG.debug("Cleaned transcript (%s): %r", mode.name, cleaned)
            return cleaned
        except Exception as exc:  # noqa: BLE001
            LOG.warning("OpenAI cleanup failed (%s: %s) – using raw transcript", type(exc).__name__, exc)
            return transcript
