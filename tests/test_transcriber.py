"""Tests for transcriber.py"""

from __future__ import annotations

import os
import tempfile
from unittest.mock import MagicMock, patch

import pytest

import voiceprompt.transcriber as transcriber_mod


def _make_wav() -> str:
    """Create a dummy WAV temp file and return its path."""
    fd, path = tempfile.mkstemp(suffix=".wav")
    os.close(fd)
    return path


# ---------------------------------------------------------------------------
# test_transcriber_happy_path
# ---------------------------------------------------------------------------

def test_transcriber_happy_path():
    """transcribe() returns the text from mlx_whisper."""
    wav = _make_wav()

    mock_mlx = MagicMock()
    mock_mlx.transcribe.return_value = {"text": "  hello world  "}

    transcriber_mod._model = mock_mlx
    result = transcriber_mod.transcribe(wav)

    assert result == "hello world"
    mock_mlx.transcribe.assert_called_once()


# ---------------------------------------------------------------------------
# test_transcriber_deletes_temp_file
# ---------------------------------------------------------------------------

def test_transcriber_deletes_temp_file():
    """transcribe() must delete the WAV file after transcription."""
    wav = _make_wav()
    assert os.path.exists(wav)

    mock_mlx = MagicMock()
    mock_mlx.transcribe.return_value = {"text": "test"}

    transcriber_mod._model = mock_mlx
    transcriber_mod.transcribe(wav)

    assert not os.path.exists(wav)


# ---------------------------------------------------------------------------
# test_transcriber_model_load_failure
# ---------------------------------------------------------------------------

def test_transcriber_model_load_failure():
    """load_model() must propagate import/network errors."""
    with patch.dict("sys.modules", {"mlx_whisper": None}):
        # Force re-import to trigger the failure path
        with pytest.raises((ImportError, TypeError)):
            transcriber_mod._model = None
            transcriber_mod.load_model()


# ---------------------------------------------------------------------------
# test_transcriber_passes_initial_prompt
# ---------------------------------------------------------------------------

def test_transcriber_passes_initial_prompt():
    """transcribe() passes initial_prompt to mlx_whisper when provided."""
    wav = _make_wav()

    mock_mlx = MagicMock()
    mock_mlx.transcribe.return_value = {"text": "PyTorch training loop"}

    transcriber_mod._model = mock_mlx
    transcriber_mod.transcribe(wav, initial_prompt="Key terms: PyTorch, CUDA.")

    call_kwargs = mock_mlx.transcribe.call_args[1]
    assert call_kwargs.get("initial_prompt") == "Key terms: PyTorch, CUDA."


def test_transcriber_omits_initial_prompt_when_empty():
    """transcribe() does not pass initial_prompt when it is empty."""
    wav = _make_wav()

    mock_mlx = MagicMock()
    mock_mlx.transcribe.return_value = {"text": "hello"}

    transcriber_mod._model = mock_mlx
    transcriber_mod.transcribe(wav, initial_prompt="")

    call_kwargs = mock_mlx.transcribe.call_args[1]
    assert "initial_prompt" not in call_kwargs


# ---------------------------------------------------------------------------
# test_transcriber_empty_audio
# ---------------------------------------------------------------------------

def test_transcriber_empty_audio():
    """Silence (empty text response) should return empty string without crash."""
    wav = _make_wav()

    mock_mlx = MagicMock()
    mock_mlx.transcribe.return_value = {"text": "   "}

    transcriber_mod._model = mock_mlx
    result = transcriber_mod.transcribe(wav)

    assert result == ""
