"""Uninstall VoicePrompt's LaunchAgent.

Install is handled by voiceprompt-setup (setup.py).
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

LABEL = "com.voiceprompt"
PLIST_PATH = Path.home() / "Library" / "LaunchAgents" / f"{LABEL}.plist"


def uninstall() -> None:
    if not PLIST_PATH.exists():
        print("VoicePrompt service is not installed.")
        return

    subprocess.run(["launchctl", "unload", str(PLIST_PATH)], capture_output=True)
    PLIST_PATH.unlink()

    # Optionally remove config
    config_path = Path.home() / ".config" / "voiceprompt" / "config.json"
    if config_path.exists():
        answer = input("Also remove config and API key? [y/N]: ").strip().lower()
        if answer == "y":
            config_path.unlink()
            print("Config removed.")

    print("VoicePrompt uninstalled.")
