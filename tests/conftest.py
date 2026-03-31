"""Shared pytest fixtures."""

from __future__ import annotations

import os
import sys

import pytest

# Ensure src/ is importable without an editable install during testing
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))


@pytest.fixture(autouse=True)
def set_openai_key(monkeypatch):
    """Provide a dummy API key so Cleaner() doesn't raise by default."""
    monkeypatch.setenv("OPENAI_API_KEY", "sk-test-dummy")
