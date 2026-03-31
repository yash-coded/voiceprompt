"""Audio recording via sounddevice."""

from __future__ import annotations

import logging
import os
import tempfile
import threading
import wave
from typing import Optional

import numpy as np
import sounddevice as sd

LOG = logging.getLogger(__name__)

SAMPLERATE = 16000
CHANNELS = 1
DTYPE = "int16"


class RecordThread(threading.Thread):
    """Records audio from the default mic in a background thread.

    Usage::

        t = RecordThread()
        t.start()
        # ... user speaks ...
        t.stop()
        wav_path = t.result()   # None if duration < 1 s
    """

    def __init__(self) -> None:
        super().__init__(daemon=True)
        self._stop_event = threading.Event()
        self._frames: list[np.ndarray] = []
        self._exception: Optional[Exception] = None
        self._wav_path: Optional[str] = None

    # ------------------------------------------------------------------
    def run(self) -> None:
        try:
            with sd.InputStream(
                samplerate=SAMPLERATE,
                channels=CHANNELS,
                dtype=DTYPE,
                callback=self._callback,
            ):
                self._stop_event.wait()
        except Exception as exc:  # noqa: BLE001
            LOG.exception("sounddevice stream error")
            self._exception = exc

    def _callback(
        self,
        indata: np.ndarray,
        frames: int,
        time: object,
        status: sd.CallbackFlags,
    ) -> None:
        if status:
            LOG.warning("sounddevice status: %s", status)
        self._frames.append(indata.copy())

    # ------------------------------------------------------------------
    def stop(self) -> None:
        """Signal the stream to stop."""
        self._stop_event.set()

    def result(self) -> Optional[str]:
        """Block until the thread finishes, then return a WAV file path.

        Returns None if the recording was shorter than 1 second (accidental
        tap) or if no audio was captured.  The caller is responsible for
        deleting the returned file.

        Raises the underlying sounddevice exception if recording failed.
        """
        self.join()

        if self._exception is not None:
            raise self._exception

        if not self._frames:
            LOG.debug("No audio frames captured")
            return None

        audio = np.concatenate(self._frames, axis=0)
        duration = len(audio) / SAMPLERATE

        LOG.debug("Recorded %.2f s of audio", duration)

        if duration < 1.0:
            LOG.debug("Clip too short (%.2f s) – discarding", duration)
            return None

        # Write to a named temp file the caller owns
        fd, path = tempfile.mkstemp(suffix=".wav", prefix="voiceprompt_")
        try:
            with wave.open(path, "wb") as wf:
                wf.setnchannels(CHANNELS)
                wf.setsampwidth(2)  # int16 → 2 bytes
                wf.setframerate(SAMPLERATE)
                wf.writeframes(audio.tobytes())
        finally:
            os.close(fd)

        LOG.debug("WAV written to %s", path)
        return path
