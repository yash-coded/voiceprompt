"""VoicePrompt – macOS menubar app entry point."""

from __future__ import annotations

import atexit
import logging
import os
import queue
import subprocess
import sys
import threading
import time
from typing import Optional

import pyperclip  # type: ignore[import]
import rumps  # type: ignore[import]

from voiceprompt import recorder as rec_module
from voiceprompt import transcriber
from voiceprompt.cleaner import Cleaner, build_whisper_prompt
from voiceprompt.config import Config
from voiceprompt.context import CleanMode, get_frontmost_mode
from voiceprompt.hotkey import HotkeyListener, State

LOG = logging.getLogger(__name__)

ICON_IDLE       = "🎙"
ICON_RECORDING  = "🔴"
ICON_PROCESSING = "⏳"
ICON_ERROR      = "⚠️"

ERROR_RESET_DELAY = 3.0  # seconds before auto-reset from ERROR → IDLE

# Clipboard context: maximum characters to pass to the LLM.
_CLIPBOARD_CTX_MAX = 500


def _read_clipboard_ctx() -> str:
    """Return current clipboard text (up to _CLIPBOARD_CTX_MAX chars), or ''."""
    try:
        text = pyperclip.paste()
        if not isinstance(text, str) or not text.strip():
            return ""
        return text.strip()[:_CLIPBOARD_CTX_MAX]
    except Exception:  # noqa: BLE001
        return ""


class VoicePromptApp(rumps.App):
    """rumps menubar application.

    Both personal and company Macs use the same Right-Option hold trigger
    via NSEvent.  The only difference is paste behaviour:
      - Personal (full)    : auto Cmd+V via osascript
      - Company (restricted): copies to clipboard only; user presses ⌘V
    """

    def __init__(self, cfg: Config) -> None:
        super().__init__(
            "VoicePrompt",
            title=ICON_IDLE,
            quit_button="Quit VoicePrompt",
        )

        self._cfg = cfg
        self._restricted_mode: bool = cfg.restricted_mode
        self._cleaner = Cleaner(cfg.openai_api_key, vocabulary=cfg.vocabulary)
        self._whisper_prompt: str = build_whisper_prompt(cfg.vocabulary)

        self._record_thread: Optional[rec_module.RecordThread] = None
        self._current_mode: CleanMode = CleanMode.GENERAL
        self._clipboard_ctx: str = ""

        # Work queue carries (wav_path, mode, clipboard_ctx)
        self._work_queue: queue.Queue[tuple[str, CleanMode, str]] = queue.Queue(maxsize=1)
        self._result_queue: queue.Queue[str] = queue.Queue()

        self._temp_files: list[str] = []
        atexit.register(self._cleanup_temp_files)

        self._hotkey = HotkeyListener(
            on_start_recording=self._start_recording,
            on_stop_recording=self._handle_release,
            on_state_change=self._on_state_change,
        )

        if self._restricted_mode:
            self.menu = [
                rumps.MenuItem("Hold Right ⌥ to record  •  ⌘V to paste", callback=None),
            ]

        self._poll_timer = rumps.Timer(self._poll_result, 0.1)
        self._worker = threading.Thread(target=self._pipeline_worker, daemon=True)

    # ------------------------------------------------------------------
    # App lifecycle
    # ------------------------------------------------------------------

    def run(self) -> None:  # type: ignore[override]
        self._poll_timer.start()
        self._hotkey.start()          # NSEvent monitor — works on personal + company Mac
        self._worker.start()
        LOG.info("VoicePrompt started (restricted=%s)", self._restricted_mode)
        super().run()

    # ------------------------------------------------------------------
    # Recording callbacks (called on main thread from NSEvent handler)
    # ------------------------------------------------------------------

    def _start_recording(self) -> None:
        # Capture both context signals before the microphone opens —
        # the target app still has focus at this exact moment.
        self._current_mode = get_frontmost_mode()
        self._clipboard_ctx = _read_clipboard_ctx()
        LOG.debug("Starting recording (mode=%s, clipboard=%d chars)",
                  self._current_mode.name, len(self._clipboard_ctx))
        self._record_thread = rec_module.RecordThread()
        self._record_thread.start()

    def _handle_release(self, duration: float) -> None:
        if duration < 1.0:
            LOG.debug("Short clip (%.2f s) – discarding", duration)
            if self._record_thread:
                self._record_thread.stop()
                self._record_thread = None
            self._hotkey.set_idle()
            return

        rt = self._record_thread
        self._record_thread = None
        self._hotkey.set_processing()

        threading.Thread(
            target=self._collect_and_enqueue,
            args=(rt, self._current_mode, self._clipboard_ctx),
            daemon=True,
        ).start()

    def _collect_and_enqueue(
        self,
        rt: Optional[rec_module.RecordThread],
        mode: CleanMode,
        clipboard_ctx: str,
    ) -> None:
        try:
            if rt:
                rt.stop()
            wav_path = rt.result() if rt else None
            if wav_path is None:
                self._hotkey.set_idle()
                return
            self._temp_files.append(wav_path)
            try:
                self._work_queue.put_nowait((wav_path, mode, clipboard_ctx))
            except queue.Full:
                LOG.warning("Work queue full – dropping clip")
                self._hotkey.set_idle()
        except Exception as exc:  # noqa: BLE001
            LOG.exception("Error collecting recording: %s", exc)
            self._hotkey.set_error()

    # ------------------------------------------------------------------
    # Pipeline worker (background thread)
    # ------------------------------------------------------------------

    def _pipeline_worker(self) -> None:
        while True:
            wav_path, mode, clipboard_ctx = self._work_queue.get()
            try:
                raw = transcriber.transcribe(wav_path, initial_prompt=self._whisper_prompt)
                try:
                    self._temp_files.remove(wav_path)
                except ValueError:
                    pass
                cleaned = self._cleaner.clean(raw, mode=mode, clipboard_ctx=clipboard_ctx)
                if cleaned:
                    self._result_queue.put(cleaned)
                else:
                    LOG.warning("Empty cleaned text – nothing to paste")
                self._hotkey.set_idle()
            except Exception as exc:  # noqa: BLE001
                LOG.exception("Pipeline error: %s", exc)
                self._hotkey.set_error()
            finally:
                self._work_queue.task_done()

    # ------------------------------------------------------------------
    # Main-thread timer
    # ------------------------------------------------------------------

    def _poll_result(self, _sender: rumps.Timer) -> None:
        try:
            text = self._result_queue.get_nowait()
        except queue.Empty:
            return
        LOG.info("Pasting %d chars", len(text))
        self._paste(text)

    # ------------------------------------------------------------------
    # Paste
    # ------------------------------------------------------------------

    def _paste(self, text: str) -> None:
        """Copy to clipboard; auto Cmd+V in full mode, clipboard-only in restricted."""
        pyperclip.copy(text)

        if self._restricted_mode:
            # Company Mac: no Accessibility — user presses ⌘V manually
            return

        time.sleep(0.05)
        try:
            subprocess.run(
                [
                    "osascript", "-e",
                    'tell application "System Events" to keystroke "v" using command down',
                ],
                timeout=2,
                check=False,
            )
            LOG.debug("Cmd+V fired via osascript")
        except Exception as exc:  # noqa: BLE001
            LOG.warning("osascript paste failed: %s", exc)

    # ------------------------------------------------------------------
    # State → icon / title
    # ------------------------------------------------------------------

    def _on_state_change(self, state: State) -> None:
        labels = {
            State.IDLE:       ICON_IDLE,
            State.WAITING:    ICON_IDLE,      # no visual change — brief hold, no noise
            State.RECORDING:  ICON_RECORDING,
            State.PROCESSING: ICON_PROCESSING,
            State.ERROR:      ICON_ERROR,
        }
        self.title = labels.get(state, ICON_IDLE)

        if state == State.ERROR:
            threading.Timer(ERROR_RESET_DELAY, self._auto_reset_error).start()

    def _auto_reset_error(self) -> None:
        if self._hotkey.state == State.ERROR:
            self._hotkey.set_idle()

    # ------------------------------------------------------------------
    # Cleanup
    # ------------------------------------------------------------------

    def _cleanup_temp_files(self) -> None:
        for path in self._temp_files:
            try:
                os.unlink(path)
            except FileNotFoundError:
                pass


# ------------------------------------------------------------------
# Entry point
# ------------------------------------------------------------------

def main() -> None:
    log_level = os.environ.get("LOG_LEVEL", "WARNING").upper()
    logging.basicConfig(level=getattr(logging, log_level, logging.WARNING))

    try:
        cfg = Config.load()
    except FileNotFoundError as exc:
        rumps.notification(
            title="VoicePrompt",
            subtitle="Setup required",
            message="Run 'voiceprompt-setup' in your terminal to get started.",
        )
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)

    # Mic permission warm-up
    try:
        import sounddevice as sd  # type: ignore[import]
        with sd.InputStream(samplerate=16000, channels=1, dtype="int16"):
            pass
    except Exception:
        pass

    threading.Thread(target=transcriber.load_model, daemon=True).start()

    app = VoicePromptApp(cfg)
    app.run()


if __name__ == "__main__":
    main()
