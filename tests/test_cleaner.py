"""Tests for cleaner.py"""

from __future__ import annotations

import os
from unittest.mock import MagicMock, patch

import pytest

from voiceprompt.cleaner import Cleaner


def _make_cleaner() -> Cleaner:
    """Instantiate Cleaner with a mocked OpenAI client."""
    with patch("voiceprompt.cleaner.OpenAI") as mock_cls:
        mock_cls.return_value = MagicMock()
        c = Cleaner(api_key="sk-test")
    return c


def _set_response(cleaner: Cleaner, text: str) -> None:
    msg = MagicMock()
    msg.content = text
    choice = MagicMock()
    choice.message = msg
    cleaner._client.chat.completions.create.return_value.choices = [choice]


# ---------------------------------------------------------------------------
# test_cleaner_removes_filler_words
# ---------------------------------------------------------------------------

def test_cleaner_removes_filler_words():
    c = _make_cleaner()
    _set_response(c, "Run pytest dash dash verbose.")
    result = c.clean("Um, run, like, pytest -- verbose, you know.")
    assert result == "Run pytest dash dash verbose."


# ---------------------------------------------------------------------------
# test_cleaner_timeout_returns_raw
# ---------------------------------------------------------------------------

def test_cleaner_timeout_returns_raw():
    c = _make_cleaner()
    c._client.chat.completions.create.side_effect = TimeoutError("timed out")
    raw = "uh hello world"
    assert c.clean(raw) == raw


# ---------------------------------------------------------------------------
# test_cleaner_network_error_returns_raw
# ---------------------------------------------------------------------------

def test_cleaner_network_error_returns_raw():
    c = _make_cleaner()
    c._client.chat.completions.create.side_effect = ConnectionError("no network")
    raw = "some transcript"
    assert c.clean(raw) == raw


# ---------------------------------------------------------------------------
# test_cleaner_rate_limit_returns_raw
# ---------------------------------------------------------------------------

def test_cleaner_rate_limit_returns_raw():
    c = _make_cleaner()
    # Simulate a 429-like exception
    exc = Exception("429 rate limit exceeded")
    c._client.chat.completions.create.side_effect = exc
    raw = "another transcript"
    assert c.clean(raw) == raw


# ---------------------------------------------------------------------------
# test_cleaner_empty_response_returns_raw
# ---------------------------------------------------------------------------

def test_cleaner_empty_response_returns_raw():
    c = _make_cleaner()
    _set_response(c, "")
    raw = "non empty input"
    assert c.clean(raw) == raw


# ---------------------------------------------------------------------------
# test_cleaner_missing_api_key
# ---------------------------------------------------------------------------

def test_cleaner_missing_api_key(monkeypatch):
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)
    with pytest.raises(EnvironmentError, match="OPENAI_API_KEY"):
        Cleaner(api_key="")
