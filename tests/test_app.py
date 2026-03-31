"""Tests for app.py"""

from __future__ import annotations

import threading
from unittest.mock import MagicMock, patch

import pytest


# ---------------------------------------------------------------------------
# Helpers / fixtures
# ---------------------------------------------------------------------------

def _make_cfg(restricted_mode: bool = False) -> "Config":
    from voiceprompt.config import Config
    return Config(openai_api_key="sk-test", restricted_mode=restricted_mode)


def _make_app(restricted_mode: bool = False):
    """Create VoicePromptApp with heavy deps mocked."""
    cfg = _make_cfg(restricted_mode=restricted_mode)

    with patch("rumps.App.__init__", return_value=None), \
         patch("rumps.Timer", return_value=MagicMock()), \
         patch("voiceprompt.app.Cleaner"):
        from voiceprompt.app import VoicePromptApp
        app = VoicePromptApp.__new__(VoicePromptApp)
        # Provide _menu so rumps.App.menu setter doesn't crash
        app._menu = MagicMock()
        app.icon = None
        app.title = ""
        app.template = False
        VoicePromptApp.__init__(app, cfg)
    return app


# ---------------------------------------------------------------------------
# test_app_exits_without_api_key
# ---------------------------------------------------------------------------

def test_app_exits_without_api_key(monkeypatch):
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)

    with patch("voiceprompt.app.Config.load",
               side_effect=FileNotFoundError("no config")), \
         patch("voiceprompt.app.rumps.notification"), \
         pytest.raises(SystemExit) as exc_info:
        from voiceprompt.app import main
        main()

    assert exc_info.value.code == 1


# ---------------------------------------------------------------------------
# test_app_timer_copies_result_to_clipboard
# ---------------------------------------------------------------------------

def test_app_timer_copies_result_to_clipboard():
    app = _make_app()
    app._result_queue.put("hello world")

    with patch.object(app, "_paste") as mock_paste:
        app._poll_result(MagicMock())

    mock_paste.assert_called_once_with("hello world")


# ---------------------------------------------------------------------------
# test_app_timer_fires_cmd_v
# ---------------------------------------------------------------------------

def test_app_timer_fires_cmd_v():
    """_paste copies text to clipboard and fires Cmd+V via osascript in full mode."""
    app = _make_app(restricted_mode=False)

    with patch("subprocess.run") as mock_run, \
         patch("voiceprompt.app.pyperclip") as mock_clip, \
         patch("voiceprompt.app.time.sleep"):
        app._paste("test text")

    mock_clip.copy.assert_called_once_with("test text")
    mock_run.assert_called_once()
    cmd = mock_run.call_args[0][0]
    assert "osascript" in cmd


# ---------------------------------------------------------------------------
# test_restricted_mode_paste_no_osascript
# ---------------------------------------------------------------------------

def test_restricted_mode_paste_no_osascript():
    """In restricted mode _paste only copies to clipboard — no osascript."""
    app = _make_app(restricted_mode=True)

    with patch("subprocess.run") as mock_run, \
         patch("voiceprompt.app.pyperclip") as mock_clip:
        app._paste("clipped text")

    mock_clip.copy.assert_called_once_with("clipped text")
    mock_run.assert_not_called()


# ---------------------------------------------------------------------------
# test_restricted_mode_trigger_still_works
# ---------------------------------------------------------------------------

def test_restricted_mode_trigger_still_works():
    """In restricted mode the Right Option hotkey still starts recording."""
    from voiceprompt.hotkey import State

    app = _make_app(restricted_mode=True)

    mock_start = MagicMock()
    app._hotkey._on_start = mock_start  # replace stored callback ref

    app._hotkey.trigger_press()

    assert app._hotkey.state == State.RECORDING
    mock_start.assert_called_once()


# ---------------------------------------------------------------------------
# test_app_error_icon_resets_after_3s
# ---------------------------------------------------------------------------

def test_app_error_icon_resets_after_3s():
    from voiceprompt.hotkey import State
    from voiceprompt.app import ERROR_RESET_DELAY

    app = _make_app()
    app._hotkey._transition(State.ERROR)
    app._hotkey._processing_guard.set()

    reset_called = threading.Event()
    original_set_idle = app._hotkey.set_idle

    def _mock_set_idle():
        reset_called.set()
        original_set_idle()

    app._hotkey.set_idle = _mock_set_idle
    app._on_state_change(State.ERROR)

    assert reset_called.wait(timeout=ERROR_RESET_DELAY + 1.0), \
        "Error state was not auto-reset within the expected time"
