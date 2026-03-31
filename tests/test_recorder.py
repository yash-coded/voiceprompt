"""Tests for recorder.py"""

from __future__ import annotations

import os
import time
import wave
from unittest.mock import MagicMock, patch

import numpy as np
import pytest

from voiceprompt.recorder import RecordThread, SAMPLERATE, CHANNELS


def _make_frames(duration_s: float) -> list[np.ndarray]:
    """Generate fake audio frames for *duration_s* seconds."""
    n_samples = int(SAMPLERATE * duration_s)
    return [np.zeros((n_samples, CHANNELS), dtype="int16")]


# ---------------------------------------------------------------------------
# test_recorder_opens_correct_samplerate
# ---------------------------------------------------------------------------

def test_recorder_opens_correct_samplerate():
    """RecordThread must open an InputStream with samplerate=16000, channels=1."""
    with patch("voiceprompt.recorder.sd.InputStream") as mock_stream:
        # Make the context manager work
        mock_stream.return_value.__enter__ = lambda s: s
        mock_stream.return_value.__exit__ = MagicMock(return_value=False)

        t = RecordThread()
        # stop immediately so run() exits
        t._stop_event.set()
        t.run()

        mock_stream.assert_called_once()
        kwargs = mock_stream.call_args.kwargs
        assert kwargs["samplerate"] == 16000
        assert kwargs["channels"] == 1


# ---------------------------------------------------------------------------
# test_recorder_short_clip_returns_none
# ---------------------------------------------------------------------------

def test_recorder_short_clip_returns_none():
    """Recording shorter than 1 s must return None (accidental tap)."""
    t = RecordThread()
    t._frames = _make_frames(0.5)  # inject 0.5 s of fake audio
    # simulate join completing immediately
    with patch.object(t, "join"):
        result = t.result()
    assert result is None


# ---------------------------------------------------------------------------
# test_recorder_writes_valid_wav
# ---------------------------------------------------------------------------

def test_recorder_writes_valid_wav(tmp_path):
    """Recording >= 1 s must produce a WAV file with the correct format."""
    t = RecordThread()
    t._frames = _make_frames(2.0)  # 2 seconds

    with patch.object(t, "join"):
        wav_path = t.result()

    try:
        assert wav_path is not None
        assert os.path.exists(wav_path)

        with wave.open(wav_path, "rb") as wf:
            assert wf.getnchannels() == CHANNELS
            assert wf.getsampwidth() == 2  # int16
            assert wf.getframerate() == SAMPLERATE
    finally:
        if wav_path and os.path.exists(wav_path):
            os.unlink(wav_path)


# ---------------------------------------------------------------------------
# test_recorder_mic_error
# ---------------------------------------------------------------------------

def test_recorder_mic_error():
    """An OSError from sounddevice must propagate through result()."""
    with patch("voiceprompt.recorder.sd.InputStream", side_effect=OSError("no mic")):
        t = RecordThread()
        t.run()  # stores exception

    with patch.object(t, "join"):
        with pytest.raises(OSError, match="no mic"):
            t.result()
