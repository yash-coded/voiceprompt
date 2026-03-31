"""Persistent config stored at ~/.config/voiceprompt/config.json."""

from __future__ import annotations

import json
import os
from pathlib import Path

CONFIG_DIR = Path.home() / ".config" / "voiceprompt"
CONFIG_FILE = CONFIG_DIR / "config.json"


class Config:
    def __init__(
        self,
        openai_api_key: str,
        restricted_mode: bool,
        vocabulary: list[str] | None = None,
    ) -> None:
        self.openai_api_key = openai_api_key
        self.restricted_mode = restricted_mode
        self.vocabulary: list[str] = vocabulary or []

    # ------------------------------------------------------------------
    def save(self) -> None:
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        with open(CONFIG_FILE, "w") as f:
            json.dump(
                {
                    "openai_api_key": self.openai_api_key,
                    "restricted_mode": self.restricted_mode,
                    "vocabulary": self.vocabulary,
                },
                f,
                indent=2,
            )

    # ------------------------------------------------------------------
    @classmethod
    def load(cls) -> "Config":
        """Load from config file, fall back to env vars.

        Raises FileNotFoundError if neither source provides an API key.
        """
        data: dict = {}
        if CONFIG_FILE.exists():
            with open(CONFIG_FILE) as f:
                data = json.load(f)

        api_key = data.get("openai_api_key") or os.environ.get("OPENAI_API_KEY", "")
        restricted_mode = data.get("restricted_mode", False)
        vocabulary = data.get("vocabulary", [])

        if not api_key:
            raise FileNotFoundError(
                "No config found. Run 'voiceprompt-setup' to get started."
            )

        return cls(openai_api_key=api_key, restricted_mode=restricted_mode, vocabulary=vocabulary)

    @classmethod
    def exists(cls) -> bool:
        return CONFIG_FILE.exists()
