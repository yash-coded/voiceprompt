"""Tests for cleaner.py"""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from voiceprompt.cleaner import Cleaner, build_whisper_prompt, _strip_preamble
from voiceprompt.context import CleanMode
from voiceprompt.vocabulary import DEFAULT_VOCABULARY, WHISPER_VOCABULARY


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_cleaner(vocabulary: list[str] | None = None) -> Cleaner:
    """Instantiate Cleaner with a mocked OpenAI client."""
    with patch("voiceprompt.cleaner.OpenAI") as mock_cls:
        mock_cls.return_value = MagicMock()
        c = Cleaner(api_key="sk-test", vocabulary=vocabulary)
    return c


def _set_response(cleaner: Cleaner, text: str) -> None:
    msg = MagicMock()
    msg.content = text
    choice = MagicMock()
    choice.message = msg
    cleaner._client.chat.completions.create.return_value.choices = [choice]


def _last_system(cleaner: Cleaner) -> str:
    """Return the system-message content from the most recent API call."""
    messages = cleaner._client.chat.completions.create.call_args[1]["messages"]
    return next(m["content"] for m in messages if m["role"] == "system")


def _last_user(cleaner: Cleaner) -> str:
    """Return the user-message content from the most recent API call."""
    messages = cleaner._client.chat.completions.create.call_args[1]["messages"]
    return next(m["content"] for m in messages if m["role"] == "user")


# ---------------------------------------------------------------------------
# test_cleaner_removes_filler_words (GENERAL mode, default)
# ---------------------------------------------------------------------------

def test_cleaner_removes_filler_words():
    c = _make_cleaner()
    _set_response(c, "Run pytest dash dash verbose.")
    result = c.clean("Um, run, like, pytest -- verbose, you know.")
    assert result == "Run pytest dash dash verbose."


# ---------------------------------------------------------------------------
# test_cleaner_technical_mode
# ---------------------------------------------------------------------------

def test_cleaner_technical_mode():
    c = _make_cleaner()
    _set_response(c, "uv run pytest --tb=short -x")
    result = c.clean(
        "um, uv run, like, pytest -- tb equals short, uh, dash x",
        mode=CleanMode.TECHNICAL,
    )
    assert result == "uv run pytest --tb=short -x"
    system = _last_system(c)
    assert "technical" in system.lower()
    assert "rewriting task" in system.lower()


# ---------------------------------------------------------------------------
# test_cleaner_professional_mode
# ---------------------------------------------------------------------------

def test_cleaner_professional_mode():
    c = _make_cleaner()
    _set_response(c, "Can we sync tomorrow afternoon to review the design?")
    result = c.clean(
        "um like can we, uh, sync tomorrow afternoon to, you know, review the design",
        mode=CleanMode.PROFESSIONAL,
    )
    assert result == "Can we sync tomorrow afternoon to review the design?"
    system = _last_system(c)
    assert "work message" in system.lower()


# ---------------------------------------------------------------------------
# test_cleaner_casual_mode
# ---------------------------------------------------------------------------

def test_cleaner_casual_mode():
    c = _make_cleaner()
    _set_response(c, "haha yeah totally, you know what I mean?")
    result = c.clean(
        "um haha yeah totally, you know what I mean?",
        mode=CleanMode.CASUAL,
    )
    assert result == "haha yeah totally, you know what I mean?"
    system = _last_system(c)
    assert "casual" in system.lower()
    assert "formal" in system.lower()  # specifically says do NOT make formal


# ---------------------------------------------------------------------------
# test_cleaner_temperature_is_zero
# ---------------------------------------------------------------------------

def test_cleaner_temperature_is_zero():
    c = _make_cleaner()
    _set_response(c, "hello world")
    c.clean("hello world")
    call_kwargs = c._client.chat.completions.create.call_args[1]
    assert call_kwargs.get("temperature") == 0


# ---------------------------------------------------------------------------
# test_cleaner_vocabulary_injected_in_prompt
# ---------------------------------------------------------------------------

def test_cleaner_vocabulary_injected_in_prompt():
    c = _make_cleaner(vocabulary=["PyTorch", "kubectl", "gpt-4o"])
    _set_response(c, "Install PyTorch with pip.")
    c.clean("install pie torch with pip")
    system = _last_system(c)
    assert "PyTorch" in system
    assert "kubectl" in system
    assert "gpt-4o" in system


# ---------------------------------------------------------------------------
# test_cleaner_clipboard_context_in_user_message
# ---------------------------------------------------------------------------

def test_cleaner_clipboard_context_in_user_message():
    """Clipboard context is in the user message (not system) to preserve caching."""
    c = _make_cleaner()
    _set_response(c, "Sounds good, I'll take a look.")
    c.clean("sounds good ill take a look", clipboard_ctx="Can you review this PR?")
    user = _last_user(c)
    system = _last_system(c)
    assert "Can you review this PR?" in user
    assert "Can you review this PR?" not in system


# ---------------------------------------------------------------------------
# test_cleaner_transcript_in_user_message
# ---------------------------------------------------------------------------

def test_cleaner_transcript_in_user_message():
    """Transcript is always in the user message so the system prompt can be cached."""
    c = _make_cleaner()
    _set_response(c, "Run tests.")
    c.clean("run tests")
    user = _last_user(c)
    assert "run tests" in user


# ---------------------------------------------------------------------------
# test_cleaner_clipboard_context_truncated_to_500_chars
# ---------------------------------------------------------------------------

def test_cleaner_clipboard_context_truncated_to_500_chars():
    c = _make_cleaner()
    _set_response(c, "ok")
    long_ctx = "x" * 1000
    c.clean("ok", clipboard_ctx=long_ctx)
    user = _last_user(c)
    assert "x" * 500 in user
    assert "x" * 501 not in user


# ---------------------------------------------------------------------------
# test_cleaner_preamble_stripped
# ---------------------------------------------------------------------------

def test_cleaner_preamble_stripped():
    c = _make_cleaner()
    _set_response(c, "Here's the cleaned text:\n\nRun pytest now.")
    result = c.clean("um run pytest now")
    assert result == "Run pytest now."


def test_strip_preamble_no_false_positives():
    assert _strip_preamble("Sure thing, let's go.") == "Sure thing, let's go."


# ---------------------------------------------------------------------------
# test_build_whisper_prompt
# ---------------------------------------------------------------------------

def test_build_whisper_prompt_always_includes_defaults():
    """build_whisper_prompt always includes WHISPER_VOCABULARY even with no user terms."""
    prompt = build_whisper_prompt([])
    assert prompt != ""
    # Spot-check a few well-known Whisper-tricky terms
    assert "PostgreSQL" in prompt
    assert "kubectl" in prompt
    assert "TypeScript" in prompt


def test_build_whisper_prompt_merges_user_terms():
    """User vocabulary is appended after built-in defaults."""
    prompt = build_whisper_prompt(["myCustomLib", "MyBrandTerm"])
    assert "myCustomLib" in prompt
    assert "MyBrandTerm" in prompt
    # Built-in terms still present
    assert "TypeScript" in prompt


def test_build_whisper_prompt_deduplicates():
    """Terms already in WHISPER_VOCABULARY are not repeated when user adds them."""
    prompt = build_whisper_prompt(["PostgreSQL"])
    assert prompt.count("PostgreSQL") == 1


def test_build_whisper_prompt_capped_at_90_terms():
    """Prompt never exceeds 90 terms to stay within Whisper's 224-token limit."""
    many_terms = [f"Term{i}" for i in range(200)]
    prompt = build_whisper_prompt(many_terms)
    # Count comma-separated entries (rough proxy for term count)
    term_count = len(prompt.replace("Key terms: ", "").rstrip(".").split(", "))
    assert term_count <= 90


# ---------------------------------------------------------------------------
# test_default_vocabulary_injected_in_non_casual_modes
# ---------------------------------------------------------------------------

def test_default_vocab_injected_for_technical_mode():
    c = _make_cleaner()
    _set_response(c, "Run pytest.")
    c.clean("run pytest", mode=CleanMode.TECHNICAL)
    system = _last_system(c)
    assert "PostgreSQL" in system
    assert "TypeScript" in system
    assert "Kubernetes" in system


def test_default_vocab_not_injected_for_casual_mode():
    c = _make_cleaner()
    _set_response(c, "yeah sounds good")
    c.clean("yeah sounds good", mode=CleanMode.CASUAL)
    system = _last_system(c)
    assert "PostgreSQL" not in system
    assert "Kubernetes" not in system


def test_default_vocabulary_has_expected_categories():
    """Sanity-check that vocabulary.py covers expected technology areas."""
    flat = set(DEFAULT_VOCABULARY)
    # JS/TS
    assert "TypeScript" in flat
    assert "Next.js" in flat
    assert "useEffect" in flat
    # Databases
    assert "PostgreSQL" in flat
    assert "Redis" in flat
    assert "Pinecone" in flat
    # Cloud/DevOps
    assert "Kubernetes" in flat
    assert "Terraform" in flat
    assert "GitHub Actions" in flat
    # AI/ML
    assert "LangChain" in flat
    assert "RAG" in flat
    assert "Claude" in flat
    # Whisper vocab spot-check
    assert "kubectl" in WHISPER_VOCABULARY
    assert "PostgreSQL" in WHISPER_VOCABULARY


# ---------------------------------------------------------------------------
# Failure / fallback cases
# ---------------------------------------------------------------------------

def test_cleaner_timeout_returns_raw():
    c = _make_cleaner()
    c._client.chat.completions.create.side_effect = TimeoutError("timed out")
    raw = "uh hello world"
    assert c.clean(raw) == raw


def test_cleaner_network_error_returns_raw():
    c = _make_cleaner()
    c._client.chat.completions.create.side_effect = ConnectionError("no network")
    raw = "some transcript"
    assert c.clean(raw) == raw


def test_cleaner_rate_limit_returns_raw():
    c = _make_cleaner()
    c._client.chat.completions.create.side_effect = Exception("429 rate limit exceeded")
    raw = "another transcript"
    assert c.clean(raw) == raw


def test_cleaner_empty_response_returns_raw():
    c = _make_cleaner()
    _set_response(c, "")
    raw = "non empty input"
    assert c.clean(raw) == raw


def test_cleaner_missing_api_key(monkeypatch):
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)
    with pytest.raises(EnvironmentError, match="OPENAI_API_KEY"):
        Cleaner(api_key="")
