"""Global hotkey listener using NSEvent (no Input Monitoring permission needed).

NSEvent.addGlobalMonitorForEventsMatchingMask with NSEventMaskFlagsChanged
monitors modifier-key state changes only.  Because modifier events don't
reveal typed characters, macOS does not gate them behind the Input Monitoring
TCC permission — the same mechanism Claude Desktop uses for its double-⌥ trigger.

The handler fires on the main AppKit run-loop thread, so all state-machine
transitions happen on the main thread (except the hold-threshold timer, which
fires on a daemon thread — see _on_hold_confirmed).

Hold-threshold behaviour
------------------------
Pressing Right Option starts a WAITING state and a 1-second timer.
Recording only begins if the key is still held when the timer fires.
Releasing the key before 1 second cancels the timer and returns to IDLE
silently — accidental or brief presses are ignored completely.
"""

from __future__ import annotations

import logging
import threading
import time
from enum import Enum, auto
from typing import Any, Callable, Optional

LOG = logging.getLogger(__name__)

# macOS virtual key codes (IOKit/hidsystem/IOLLEvent.h)
_kVK_RightOption = 61   # Right Option / Alt
_kVK_Option      = 58   # Left  Option / Alt

# NSEvent mask for modifier-flag changes (shift, ctrl, opt, cmd, fn)
_NSEventMaskFlagsChanged: int = 1 << 12   # = 4096

# NSEventModifierFlagOption = bit 19
_NSEventModifierFlagOption: int = 1 << 19  # = 524288

# Minimum hold duration before recording starts.
# Prevents accidental triggers from brief Right Option presses.
HOLD_THRESHOLD: float = 0.5  # seconds


class State(Enum):
    IDLE       = auto()
    WAITING    = auto()   # key held, hold timer counting down
    RECORDING  = auto()
    PROCESSING = auto()
    ERROR      = auto()


class HotkeyListener:
    """Right-Option hold-to-record, driven by NSEvent FlagsChanged.

    State machine
    -------------
    IDLE ──(press)──► WAITING ──(1 s timer fires)──► RECORDING ──(release)──► PROCESSING
                          │
                    (release early)
                          │
                          ▼
                        IDLE

    Callbacks
    ---------
    on_start_recording  : WAITING → RECORDING (after hold threshold)
    on_stop_recording   : called with duration (float) on key release
    on_state_change     : called with new State on every transition
    """

    def __init__(
        self,
        on_start_recording: Callable[[], None],
        on_stop_recording: Callable[[float], None],
        on_state_change: Callable[[State], None],
    ) -> None:
        self._on_start  = on_start_recording
        self._on_stop   = on_stop_recording
        self._on_change = on_state_change

        self._state            = State.IDLE
        self._state_lock       = threading.Lock()
        self._press_time: Optional[float] = None
        self._processing_guard = threading.Event()
        self._hold_timer: Optional[threading.Timer] = None

        self._monitor: Optional[Any] = None

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    @property
    def state(self) -> State:
        with self._state_lock:
            return self._state

    def set_processing(self) -> None:
        self._transition(State.PROCESSING)
        self._processing_guard.set()

    def set_idle(self) -> None:
        self._processing_guard.clear()
        self._transition(State.IDLE)

    def set_error(self) -> None:
        self._processing_guard.clear()
        self._transition(State.ERROR)

    def start(self) -> None:
        """Register the NSEvent global monitor.

        Must be called from the main thread (before or during the AppKit
        run loop).  The handler will be dispatched on the main thread.
        """
        try:
            from AppKit import NSEvent  # type: ignore[import]
            self._monitor = NSEvent.addGlobalMonitorForEventsMatchingMask_handler_(
                _NSEventMaskFlagsChanged,
                self._handle_flags_changed,
            )
            if self._monitor is None:
                LOG.warning(
                    "NSEvent monitor returned None — hotkey will not work. "
                    "Grant Input Monitoring to this app in System Settings."
                )
            else:
                LOG.debug("NSEvent hotkey monitor started (Right Option ⌥)")
        except Exception as exc:  # noqa: BLE001
            LOG.error("Failed to start hotkey monitor: %s", exc)

    def stop(self) -> None:
        self._cancel_hold_timer()
        if self._monitor is not None:
            try:
                from AppKit import NSEvent  # type: ignore[import]
                NSEvent.removeMonitor_(self._monitor)
            except Exception:  # noqa: BLE001
                pass
            self._monitor = None
            LOG.debug("NSEvent hotkey monitor stopped")

    # Restricted-mode / test helpers: drive state machine directly ------

    def trigger_press(self) -> None:
        """Manually fire as if Right Option was held long enough (menu / test use).

        Bypasses the hold threshold — this is an explicit, deliberate action.
        """
        with self._state_lock:
            if self._state != State.IDLE:
                return
        self._press_time = time.monotonic()
        self._transition(State.RECORDING)
        self._on_start()

    def trigger_release(self, duration: float) -> None:
        """Manually fire as if Right Option was released after *duration* s."""
        self._press_time = time.monotonic() - duration
        self._on_release()

    # ------------------------------------------------------------------
    # NSEvent handler (main thread)
    # ------------------------------------------------------------------

    def _handle_flags_changed(self, event: Any) -> None:
        # Only care about the Right Option key
        if event.keyCode() != _kVK_RightOption:
            return

        option_active = bool(event.modifierFlags() & _NSEventModifierFlagOption)
        if option_active:
            self._on_press()
        else:
            self._on_release()

    # ------------------------------------------------------------------
    # Internal press / release logic
    # ------------------------------------------------------------------

    def _on_press(self) -> None:
        with self._state_lock:
            current = self._state

        if current == State.IDLE:
            self._press_time = time.monotonic()
            self._transition(State.WAITING)
            # Recording starts only if the key is still held after HOLD_THRESHOLD
            self._hold_timer = threading.Timer(HOLD_THRESHOLD, self._on_hold_confirmed)
            self._hold_timer.daemon = True
            self._hold_timer.start()
            LOG.debug("Hold timer started (%.1f s threshold)", HOLD_THRESHOLD)
        elif current == State.PROCESSING:
            LOG.debug("Right Option pressed during PROCESSING – no-op")

    def _on_hold_confirmed(self) -> None:
        """Timer callback — fires after HOLD_THRESHOLD seconds of uninterrupted hold."""
        with self._state_lock:
            current = self._state

        if current == State.WAITING:
            LOG.debug("Hold threshold reached — starting recording")
            self._transition(State.RECORDING)
            self._on_start()

    def _on_release(self) -> None:
        with self._state_lock:
            current = self._state

        if current == State.WAITING:
            # Released before threshold — cancel timer, return to IDLE silently
            self._cancel_hold_timer()
            LOG.debug("Released before hold threshold — ignoring press")
            self._transition(State.IDLE)
            return

        if current != State.RECORDING:
            return

        duration = time.monotonic() - (self._press_time or time.monotonic())
        self._on_stop(duration)

    def _cancel_hold_timer(self) -> None:
        if self._hold_timer is not None:
            self._hold_timer.cancel()
            self._hold_timer = None

    # ------------------------------------------------------------------
    # State machine
    # ------------------------------------------------------------------

    def _transition(self, new_state: State) -> None:
        with self._state_lock:
            old = self._state
            self._state = new_state
        LOG.debug("State %s → %s", old.name, new_state.name)
        self._on_change(new_state)
