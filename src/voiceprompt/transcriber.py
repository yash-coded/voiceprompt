"""mlx-whisper transcription wrapper."""

from __future__ import annotations

import logging
import os
from typing import Any

LOG = logging.getLogger(__name__)

MODEL_NAME = "mlx-community/whisper-small-mlx"

# Module-level reference; populated by load_model()
_model: Any = None


def load_model() -> None:
    """Eagerly load the Whisper model.  Safe to call from a daemon thread."""
    global _model  # noqa: PLW0603
    import mlx_whisper  # type: ignore[import]

    LOG.info("Loading Whisper model %s …", MODEL_NAME)
    # Trigger a warm-up decode so the model weights are fully loaded
    _model = mlx_whisper
    LOG.info("Whisper model ready")


def transcribe(wav_path: str) -> str:
    """Transcribe *wav_path* and delete the file afterwards.

    Returns the transcript text (may be empty string for silent audio).
    Raises RuntimeError if the model has not been loaded yet.
    """
    if _model is None:
        raise RuntimeError("Whisper model not loaded – call load_model() first")

    LOG.debug("Transcribing %s", wav_path)
    try:
        result = _model.transcribe(wav_path, path_or_hf_repo=MODEL_NAME)
        text: str = result.get("text", "").strip()
        LOG.debug("Transcript: %r", text)
        return text
    finally:
        try:
            os.unlink(wav_path)
            LOG.debug("Deleted temp WAV %s", wav_path)
        except FileNotFoundError:
            pass
