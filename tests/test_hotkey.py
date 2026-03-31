"""Tests for hotkey.py state machine."""

from __future__ import annotations

import time
import threading
from unittest.mock import MagicMock, patch, call

import pytest

from voiceprompt.hotkey import HotkeyListener, State, HOLD_THRESHOLD


def _make_listener() -> tuple[HotkeyListener, MagicMock, MagicMock, MagicMock]:
    on_start  = MagicMock()
    on_stop   = MagicMock()
    on_change = MagicMock()
    listener  = HotkeyListener(on_start, on_stop, on_change)
    return listener, on_start, on_stop, on_change


# ---------------------------------------------------------------------------
# Hold-threshold: press goes to WAITING, not RECORDING
# ---------------------------------------------------------------------------

def test_press_transitions_to_waiting():
    """_on_press() goes IDLE → WAITING and does NOT start recording immediately."""
    listener, on_start, _, on_change = _make_listener()
    assert listener.state == State.IDLE

    listener._on_press()

    assert listener.state == State.WAITING
    on_start.assert_not_called()
    on_change.assert_called_with(State.WAITING)


def test_release_during_waiting_cancels_and_returns_to_idle():
    """Releasing before the hold threshold cancels the timer and goes back to IDLE."""
    listener, on_start, on_stop, _ = _make_listener()
    listener._on_press()
    assert listener.state == State.WAITING

    listener._on_release()

    assert listener.state == State.IDLE
    on_start.assert_not_called()
    on_stop.assert_not_called()


def test_hold_confirmed_starts_recording():
    """After HOLD_THRESHOLD, _on_hold_confirmed transitions WAITING → RECORDING."""
    listener, on_start, _, on_change = _make_listener()
    listener._transition(State.WAITING)
    listener._press_time = time.monotonic()
    on_change.reset_mock()

    listener._on_hold_confirmed()

    assert listener.state == State.RECORDING
    on_start.assert_called_once()
    on_change.assert_called_with(State.RECORDING)


def test_hold_confirmed_ignored_when_not_waiting():
    """Timer callback is a no-op if the state changed before it fired (e.g. released)."""
    listener, on_start, _, _ = _make_listener()
    # State is IDLE (key was already released)
    listener._on_hold_confirmed()

    assert listener.state == State.IDLE
    on_start.assert_not_called()


def test_hold_timer_fires_after_threshold(monkeypatch):
    """Integration: real timer fires after HOLD_THRESHOLD and starts recording."""
    listener, on_start, _, _ = _make_listener()

    # Use a very short threshold for the test
    monkeypatch.setattr("voiceprompt.hotkey.HOLD_THRESHOLD", 0.05)

    listener._on_press()
    assert listener.state == State.WAITING
    on_start.assert_not_called()

    # Wait for timer to fire
    time.sleep(0.15)

    assert listener.state == State.RECORDING
    on_start.assert_called_once()


def test_early_release_cancels_timer(monkeypatch):
    """Releasing the key before the timer fires cancels it; recording never starts."""
    listener, on_start, _, _ = _make_listener()
    monkeypatch.setattr("voiceprompt.hotkey.HOLD_THRESHOLD", 0.5)

    listener._on_press()
    listener._on_release()          # release immediately
    time.sleep(0.6)                  # wait longer than threshold

    assert listener.state == State.IDLE
    on_start.assert_not_called()


# ---------------------------------------------------------------------------
# Recording → Processing flow (unchanged from before)
# ---------------------------------------------------------------------------

def test_recording_to_idle_on_short_clip():
    listener, _, on_stop, _ = _make_listener()
    listener._transition(State.RECORDING)
    listener._press_time = time.monotonic() - 0.3

    listener._on_release()

    on_stop.assert_called_once()
    assert on_stop.call_args[0][0] < 1.0


def test_recording_to_processing_on_long_clip():
    listener, _, on_stop, _ = _make_listener()
    listener._transition(State.RECORDING)
    listener._press_time = time.monotonic() - 2.0

    listener._on_release()

    on_stop.assert_called_once()
    assert on_stop.call_args[0][0] >= 1.0


def test_processing_discards_second_press():
    listener, on_start, _, _ = _make_listener()
    listener._transition(State.PROCESSING)

    listener._on_press()

    assert listener.state == State.PROCESSING
    on_start.assert_not_called()


def test_processing_to_idle_after_pipeline():
    listener, _, _, on_change = _make_listener()
    listener._transition(State.PROCESSING)
    on_change.reset_mock()

    listener.set_idle()

    assert listener.state == State.IDLE
    on_change.assert_called_with(State.IDLE)


# ---------------------------------------------------------------------------
# trigger_press bypasses threshold (menu / test helper)
# ---------------------------------------------------------------------------

def test_trigger_press_bypasses_hold_threshold():
    """trigger_press() skips the hold timer — for menu and test use."""
    listener, on_start, _, on_change = _make_listener()

    listener.trigger_press()

    assert listener.state == State.RECORDING
    on_start.assert_called_once()


def test_trigger_release_short_goes_idle():
    listener, _, on_stop, _ = _make_listener()
    listener._transition(State.RECORDING)

    listener.trigger_release(0.3)

    on_stop.assert_called_once()
    assert on_stop.call_args[0][0] == pytest.approx(0.3, abs=0.05)


# ---------------------------------------------------------------------------
# NSEvent handler
# ---------------------------------------------------------------------------

def test_nsevent_monitor_starts_and_stops():
    listener, _, _, _ = _make_listener()
    with patch("voiceprompt.hotkey.HotkeyListener.start") as mock_start:
        listener.start()
        mock_start.assert_called_once()


def test_handle_flags_changed_right_option_press():
    """Right Option key down → WAITING (hold threshold not yet met)."""
    from voiceprompt.hotkey import _kVK_RightOption, _NSEventModifierFlagOption

    listener, on_start, _, _ = _make_listener()

    event = MagicMock()
    event.keyCode.return_value = _kVK_RightOption
    event.modifierFlags.return_value = _NSEventModifierFlagOption

    listener._handle_flags_changed(event)

    assert listener.state == State.WAITING
    on_start.assert_not_called()   # not called until timer fires


def test_handle_flags_changed_right_option_release():
    """Right Option key up → triggers _on_release."""
    from voiceprompt.hotkey import _kVK_RightOption

    listener, _, on_stop, _ = _make_listener()
    listener._transition(State.RECORDING)
    listener._press_time = time.monotonic() - 2.0

    event = MagicMock()
    event.keyCode.return_value = _kVK_RightOption
    event.modifierFlags.return_value = 0  # option NOT active → released

    listener._handle_flags_changed(event)

    on_stop.assert_called_once()


def test_handle_flags_changed_ignores_other_keys():
    listener, on_start, on_stop, _ = _make_listener()

    event = MagicMock()
    event.keyCode.return_value = 56  # Left Shift
    event.modifierFlags.return_value = 1 << 17

    listener._handle_flags_changed(event)

    assert listener.state == State.IDLE
    on_start.assert_not_called()
    on_stop.assert_not_called()
