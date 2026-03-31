# Contributing to VoicePrompt

Thanks for your interest in contributing!

## Getting started

```bash
git clone https://github.com/yash-coded/voiceprompt
cd voiceprompt
uv sync --extra dev
uv run pytest   # make sure everything passes before you start
```

## Making changes

- **Bug fixes and small improvements** — open a PR directly.
- **New features** — open an issue first to discuss the approach. This avoids wasted effort on things that might not fit the project's direction.

## Code style

- Format with `ruff format` or keep consistent with the surrounding code.
- No docstrings or comments on code that is self-evident — only where the logic genuinely needs explanation.
- Don't add error handling for scenarios that can't happen. Trust internal guarantees.

## Tests

Every change should come with tests. Run the suite with:

```bash
uv run pytest --tb=short
```

Tests run on `macos-latest` in CI (required for Apple Silicon dependencies). The CI workflow is in `.github/workflows/ci.yml`.

A few conventions:
- Heavy macOS dependencies (`AppKit`, `rumps`, `sounddevice`) are mocked in tests — see `tests/conftest.py` and the existing test files for patterns.
- Use `monkeypatch` for constants like `HOLD_THRESHOLD` rather than sleeping in tests.

## Pull requests

- Keep PRs focused — one logical change per PR.
- Write a clear description of *why*, not just *what*.
- All CI checks must pass before merging.

## Reporting bugs

Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.md). Include your macOS version, chip, Python version, and `LOG_LEVEL=DEBUG` output if relevant.

## Security

If you find a security issue (e.g. credential exposure, privilege escalation), please **do not open a public issue**. Email the maintainer directly instead.
