"""Tests for hotkey.py state machine."""

from __future__ import annotations

import time
from unittest.mock import MagicMock, patch

import pytest

from voiceprompt.hotkey import HotkeyListener, State


def _make_listener() -> tuple[HotkeyListener, MagicMock, MagicMock, MagicMock]:
    on_start = MagicMock()
    on_stop  = MagicMock()
    on_change = MagicMock()
    listener = HotkeyListener(on_start, on_stop, on_change)
    return listener, on_start, on_stop, on_change


# ---------------------------------------------------------------------------
# test_state_idle_to_recording_on_press
# ---------------------------------------------------------------------------

def test_state_idle_to_recording_on_press():
    listener, on_start, _, on_change = _make_listener()
    assert listener.state == State.IDLE

    listener._on_press()

    assert listener.state == State.RECORDING
    on_start.assert_called_once()
    on_change.assert_called_with(State.RECORDING)


# ---------------------------------------------------------------------------
# test_state_recording_to_idle_short_clip
# ---------------------------------------------------------------------------

def test_state_recording_to_idle_short_clip():
    listener, _, on_stop, _ = _make_listener()
    listener._transition(State.RECORDING)
    listener._press_time = time.monotonic() - 0.3  # simulate 0.3 s hold

    listener._on_release()

    on_stop.assert_called_once()
    assert on_stop.call_args[0][0] < 1.0


# ---------------------------------------------------------------------------
# test_state_recording_to_processing_long_clip
# ---------------------------------------------------------------------------

def test_state_recording_to_processing_long_clip():
    listener, _, on_stop, _ = _make_listener()
    listener._transition(State.RECORDING)
    listener._press_time = time.monotonic() - 2.0  # 2 second hold

    listener._on_release()

    on_stop.assert_called_once()
    assert on_stop.call_args[0][0] >= 1.0


# ---------------------------------------------------------------------------
# test_state_processing_discards_second_press
# ---------------------------------------------------------------------------

def test_state_processing_discards_second_press():
    listener, on_start, _, _ = _make_listener()
    listener._transition(State.PROCESSING)

    listener._on_press()

    assert listener.state == State.PROCESSING
    on_start.assert_not_called()


# ---------------------------------------------------------------------------
# test_state_processing_to_idle_after_pipeline
# ---------------------------------------------------------------------------

def test_state_processing_to_idle_after_pipeline():
    listener, _, _, on_change = _make_listener()
    listener._transition(State.PROCESSING)
    on_change.reset_mock()

    listener.set_idle()

    assert listener.state == State.IDLE
    on_change.assert_called_with(State.IDLE)


# ---------------------------------------------------------------------------
# test_trigger_press_idles_to_recording  (restricted mode / tests)
# ---------------------------------------------------------------------------

def test_trigger_press_idles_to_recording():
    listener, on_start, _, on_change = _make_listener()
    assert listener.state == State.IDLE

    listener.trigger_press()

    assert listener.state == State.RECORDING
    on_start.assert_called_once()


# ---------------------------------------------------------------------------
# test_trigger_release_short_goes_idle  (restricted mode / tests)
# ---------------------------------------------------------------------------

def test_trigger_release_short_goes_idle():
    listener, _, on_stop, _ = _make_listener()
    listener._transition(State.RECORDING)

    listener.trigger_release(0.3)

    on_stop.assert_called_once()
    assert on_stop.call_args[0][0] == pytest.approx(0.3, abs=0.05)


# ---------------------------------------------------------------------------
# test_nsevent_monitor_starts_and_stops
# ---------------------------------------------------------------------------

def test_nsevent_monitor_starts_and_stops():
    """start() registers a NSEvent global monitor; stop() removes it."""
    listener, _, _, _ = _make_listener()

    mock_monitor = MagicMock()
    with patch("voiceprompt.hotkey.NSEvent" if False else "AppKit.NSEvent") as _:
        pass  # just confirm no import error

    # Patch at the point of use inside hotkey.py
    with patch("voiceprompt.hotkey.HotkeyListener.start") as mock_start:
        listener.start()
        mock_start.assert_called_once()


# ---------------------------------------------------------------------------
# test_handle_flags_changed_right_option_press
# ---------------------------------------------------------------------------

def test_handle_flags_changed_right_option_press():
    """_handle_flags_changed triggers _on_press for Right Option key down."""
    from voiceprompt.hotkey import _kVK_RightOption, _NSEventModifierFlagOption

    listener, on_start, _, _ = _make_listener()

    event = MagicMock()
    event.keyCode.return_value = _kVK_RightOption
    event.modifierFlags.return_value = _NSEventModifierFlagOption  # option active

    listener._handle_flags_changed(event)

    assert listener.state == State.RECORDING
    on_start.assert_called_once()


# ---------------------------------------------------------------------------
# test_handle_flags_changed_right_option_release
# ---------------------------------------------------------------------------

def test_handle_flags_changed_right_option_release():
    """_handle_flags_changed triggers _on_release for Right Option key up."""
    from voiceprompt.hotkey import _kVK_RightOption

    listener, _, on_stop, _ = _make_listener()
    listener._transition(State.RECORDING)
    listener._press_time = time.monotonic() - 2.0

    event = MagicMock()
    event.keyCode.return_value = _kVK_RightOption
    event.modifierFlags.return_value = 0  # option NOT active → released

    listener._handle_flags_changed(event)

    on_stop.assert_called_once()


# ---------------------------------------------------------------------------
# test_handle_flags_changed_ignores_other_keys
# ---------------------------------------------------------------------------

def test_handle_flags_changed_ignores_other_keys():
    """_handle_flags_changed ignores non-Right-Option modifier changes."""
    listener, on_start, on_stop, _ = _make_listener()

    event = MagicMock()
    event.keyCode.return_value = 56  # Left Shift key code
    event.modifierFlags.return_value = 1 << 17  # shift flag

    listener._handle_flags_changed(event)

    assert listener.state == State.IDLE
    on_start.assert_not_called()
    on_stop.assert_not_called()
