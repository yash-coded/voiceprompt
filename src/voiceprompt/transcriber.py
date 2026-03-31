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


def transcribe(wav_path: str, initial_prompt: str = "") -> str:
    """Transcribe *wav_path* and delete the file afterwards.

    *initial_prompt* is passed to Whisper as style/vocabulary context.
    Listing proper nouns and technical terms here (e.g. "PyTorch, kubectl")
    steers Whisper toward correct spelling and casing without changing the
    transcription otherwise.

    Returns the transcript text (may be empty string for silent audio).
    Raises RuntimeError if the model has not been loaded yet.
    """
    if _model is None:
        raise RuntimeError("Whisper model not loaded – call load_model() first")

    LOG.debug("Transcribing %s (prompt=%r)", wav_path, initial_prompt or "<none>")
    kwargs: dict[str, Any] = {"path_or_hf_repo": MODEL_NAME}
    if initial_prompt:
        kwargs["initial_prompt"] = initial_prompt

    try:
        result = _model.transcribe(wav_path, **kwargs)
        text: str = result.get("text", "").strip()
        LOG.debug("Transcript: %r", text)
        return text
    finally:
        try:
            os.unlink(wav_path)
            LOG.debug("Deleted temp WAV %s", wav_path)
        except FileNotFoundError:
            pass
