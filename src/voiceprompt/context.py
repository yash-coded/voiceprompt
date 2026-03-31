"""Detect the frontmost application and map it to a CleanMode.

The mode is captured at key-press time (before recording starts) so the
target app still has focus and can be reliably identified.
"""

from __future__ import annotations

import logging
from enum import Enum, auto

LOG = logging.getLogger(__name__)


class CleanMode(Enum):
    TECHNICAL    = auto()   # Claude, terminals, code editors — preserve every detail
    PROFESSIONAL = auto()   # Teams, Slack, email — polished but friendly
    CASUAL       = auto()   # iMessage, WhatsApp, Discord — light touch, keep voice
    GENERAL      = auto()   # everything else — balanced cleanup


# Map bundle identifier → CleanMode
_BUNDLE_MAP: dict[str, CleanMode] = {
    # ── Claude ────────────────────────────────────────────────────────────
    "com.anthropic.claudefordesktop": CleanMode.TECHNICAL,

    # ── Terminals ─────────────────────────────────────────────────────────
    "com.apple.Terminal":             CleanMode.TECHNICAL,
    "com.googlecode.iterm2":          CleanMode.TECHNICAL,
    "dev.warp.desktop":               CleanMode.TECHNICAL,
    "com.github.wez.wezterm":         CleanMode.TECHNICAL,
    "net.kovidgoyal.kitty":           CleanMode.TECHNICAL,
    "com.mitchellh.ghostty":          CleanMode.TECHNICAL,

    # ── Code editors / IDEs ───────────────────────────────────────────────
    "com.microsoft.VSCode":           CleanMode.TECHNICAL,
    "com.microsoft.VSCodeInsiders":   CleanMode.TECHNICAL,
    "com.todesktop.230313mzl4w4u92":  CleanMode.TECHNICAL,  # Cursor
    "com.jetbrains.intellij":         CleanMode.TECHNICAL,
    "com.jetbrains.pycharm":          CleanMode.TECHNICAL,
    "com.jetbrains.webstorm":         CleanMode.TECHNICAL,
    "com.apple.dt.Xcode":             CleanMode.TECHNICAL,

    # ── Work chat / email ─────────────────────────────────────────────────
    "com.microsoft.teams2":           CleanMode.PROFESSIONAL,
    "com.microsoft.teams":            CleanMode.PROFESSIONAL,
    "com.tinyspeck.slackmacgap":      CleanMode.PROFESSIONAL,
    "com.apple.mail":                 CleanMode.PROFESSIONAL,
    "com.microsoft.Outlook":          CleanMode.PROFESSIONAL,

    # ── Casual messaging ──────────────────────────────────────────────────
    "com.apple.MobileSMS":            CleanMode.CASUAL,
    "com.apple.iChat":                CleanMode.CASUAL,
    "com.discord":                    CleanMode.CASUAL,
    "ru.keepcoder.Telegram":          CleanMode.CASUAL,
    "WhatsApp":                       CleanMode.CASUAL,
    "net.whatsapp.WhatsApp":          CleanMode.CASUAL,
}

# Substrings used as a fallback when the bundle ID isn't in the map above.
_TECHNICAL_NAMES    = ("terminal", "iterm", "warp", "wezterm", "kitty", "ghostty",
                       "code", "cursor", "claude", "xcode", "vim", "nvim", "emacs")
_PROFESSIONAL_NAMES = ("teams", "slack", "mail", "outlook")
_CASUAL_NAMES       = ("messages", "whatsapp", "telegram", "discord", "signal")


def get_frontmost_mode() -> CleanMode:
    """Return the CleanMode for the application that currently has focus."""
    try:
        from AppKit import NSWorkspace  # type: ignore[import]
        app = NSWorkspace.sharedWorkspace().frontmostApplication()
        bundle_id: str = app.bundleIdentifier() or ""
        app_name: str  = app.localizedName() or ""

        mode = _BUNDLE_MAP.get(bundle_id)
        if mode is not None:
            LOG.debug("App %r (%s) → %s", app_name, bundle_id, mode.name)
            return mode

        # Name-based fallback for apps not yet in the map
        name_lower = app_name.lower()
        if any(kw in name_lower for kw in _TECHNICAL_NAMES):
            LOG.debug("App %r matched TECHNICAL by name", app_name)
            return CleanMode.TECHNICAL
        if any(kw in name_lower for kw in _PROFESSIONAL_NAMES):
            LOG.debug("App %r matched PROFESSIONAL by name", app_name)
            return CleanMode.PROFESSIONAL
        if any(kw in name_lower for kw in _CASUAL_NAMES):
            LOG.debug("App %r matched CASUAL by name", app_name)
            return CleanMode.CASUAL

        LOG.debug("App %r (%s) → GENERAL (no match)", app_name, bundle_id)
        return CleanMode.GENERAL

    except Exception as exc:  # noqa: BLE001
        LOG.warning("Could not detect frontmost app: %s", exc)
        return CleanMode.GENERAL
