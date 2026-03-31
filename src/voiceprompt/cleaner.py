"""OpenAI gpt-4o-mini transcript cleaner."""

from __future__ import annotations

import logging
import os
from typing import Optional

from openai import OpenAI  # type: ignore[import]

LOG = logging.getLogger(__name__)

TIMEOUT = 2.0  # seconds
MODEL = "gpt-4o-mini"
SYSTEM_PROMPT = (
    "Clean this voice transcript. Remove filler words (uh, um, like, you know), "
    "fix grammar, preserve technical terms exactly as spoken (model names, CLI "
    "flags, code identifiers). Return only the cleaned text, nothing else: {transcript}"
)


class Cleaner:
    """Wraps OpenAI to clean raw Whisper transcripts."""

    def __init__(self, api_key: str = "") -> None:
        """*api_key* takes precedence; falls back to OPENAI_API_KEY env var."""
        key = api_key or os.environ.get("OPENAI_API_KEY", "")
        if not key:
            raise EnvironmentError(
                "OPENAI_API_KEY is not set. Run 'voiceprompt-setup' to configure."
            )

        self._client = OpenAI(api_key=key, timeout=TIMEOUT)

    def clean(self, transcript: str) -> str:
        """Return cleaned transcript, or *transcript* on any failure."""
        if not transcript.strip():
            return transcript

        try:
            response = self._client.chat.completions.create(
                model=MODEL,
                messages=[
                    {
                        "role": "user",
                        "content": SYSTEM_PROMPT.format(transcript=transcript),
                    }
                ],
                max_tokens=1024,
            )
            cleaned: Optional[str] = response.choices[0].message.content
            if not cleaned or not cleaned.strip():
                LOG.warning("OpenAI returned empty response – using raw transcript")
                return transcript
            LOG.debug("Cleaned transcript: %r", cleaned)
            return cleaned.strip()
        except Exception as exc:  # noqa: BLE001
            LOG.warning("OpenAI cleanup failed (%s: %s) – using raw transcript", type(exc).__name__, exc)
            return transcript
