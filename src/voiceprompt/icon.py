"""Icon helper for VoicePrompt.

VoicePrompt uses emoji titles for state indication (🎙 🔴 ⏳ ⚠️).
If you want a custom brand icon in the menubar, drop a PNG at:

    ~/.config/voiceprompt/icon.png

Recommended: 44×44 px, black glyph on transparent background (template image).
The emoji state label will still appear next to it.

Good sources for free PNG icons:
  • https://icons8.com  (search "microphone", download PNG)
  • https://www.flaticon.com  (search "microphone", free PNG)
  • https://macosicons.com  (macOS-style icons)
"""

from __future__ import annotations

from pathlib import Path

ICON_PATH = Path.home() / ".config" / "voiceprompt" / "icon.png"


def get_icon_path() -> str:
    """Return path to a user-provided icon, or empty string to use emoji only."""
    if ICON_PATH.exists():
        return str(ICON_PATH)
    return ""
