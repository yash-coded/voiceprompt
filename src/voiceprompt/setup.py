"""Interactive one-time setup wizard for VoicePrompt.

Run once with:  uv run voiceprompt-setup
Re-run any time to update your key or switch modes.
"""

from __future__ import annotations

import getpass
import os
import subprocess
import sys
from pathlib import Path

# ANSI colours (degrade gracefully on terminals that don't support them)
RESET = "\033[0m"
BOLD = "\033[1m"
DIM = "\033[2m"
GREEN = "\033[32m"
CYAN = "\033[36m"
YELLOW = "\033[33m"
RED = "\033[31m"


def _c(color: str, text: str) -> str:
    return f"{color}{text}{RESET}"


def _banner() -> None:
    print()
    print(_c(BOLD, "  ╔══════════════════════════════════════╗"))
    print(_c(BOLD, "  ║") + "  🎤  " + _c(BOLD + CYAN, "VoicePrompt") + "  Setup Wizard          " + _c(BOLD, "║"))
    print(_c(BOLD, "  ║") + _c(DIM, "  Speak → transcribe → paste anywhere  ") + _c(BOLD, "║"))
    print(_c(BOLD, "  ╚══════════════════════════════════════╝"))
    print()


def _step(n: int, total: int, title: str) -> None:
    print(_c(BOLD, f"  [{n}/{total}] {title}"))
    print()


def _ok(msg: str) -> None:
    print(f"  {_c(GREEN, '✓')} {msg}")


def _warn(msg: str) -> None:
    print(f"  {_c(YELLOW, '⚠')}  {msg}")


def _err(msg: str) -> None:
    print(f"  {_c(RED, '✗')} {msg}")


def _ask(prompt: str, default: str = "", secret: bool = False) -> str:
    full_prompt = f"  {_c(CYAN, '→')} {prompt}"
    if default:
        full_prompt += _c(DIM, f" [{default}]")
    full_prompt += ": "
    try:
        if secret:
            val = getpass.getpass(full_prompt)
        else:
            val = input(full_prompt).strip()
    except (EOFError, KeyboardInterrupt):
        print()
        sys.exit(0)
    return val or default


def _ask_yes_no(prompt: str, default: bool = False) -> bool:
    hint = "Y/n" if default else "y/N"
    raw = _ask(f"{prompt} [{hint}]")
    if not raw:
        return default
    return raw.lower().startswith("y")


# ── Step 1: API key ────────────────────────────────────────────────────────


def _collect_api_key(existing: str) -> str:
    print(_c(DIM, "  Your key is stored locally at ~/.config/voiceprompt/config.json"))
    print(_c(DIM, "  It is never sent anywhere except OpenAI's API."))
    print()

    if existing:
        masked = existing[:8] + "..." + existing[-4:]
        print(f"  Current key: {_c(DIM, masked)}")
        if not _ask_yes_no("  Replace it?", default=False):
            return existing
        print()

    while True:
        key = _ask("OpenAI API key", secret=True)
        if not key:
            _err("API key cannot be empty.")
            continue
        if not key.startswith("sk-"):
            _warn("Key doesn't look right (expected 'sk-…'). Continue anyway?")
            if not _ask_yes_no("", default=False):
                continue
        print()
        print("  Validating key … ", end="", flush=True)
        if _validate_key(key):
            print(_c(GREEN, "valid ✓"))
        else:
            print(_c(YELLOW, "could not validate (offline or wrong key?)"))
            if not _ask_yes_no("  Use it anyway?", default=False):
                print()
                continue
        print()
        return key


def _validate_key(key: str) -> bool:
    try:
        from openai import OpenAI  # type: ignore[import]
        client = OpenAI(api_key=key, timeout=5)
        client.models.list()
        return True
    except Exception:  # noqa: BLE001
        return False


# ── Step 2: Mac type ───────────────────────────────────────────────────────


def _collect_mac_type() -> bool:
    """Return True if restricted mode (company Mac)."""
    print(_c(DIM, "  Both Mac types use the same trigger: hold Right Option ⌥ to record."))
    print(_c(DIM, "  The only difference is how text gets pasted after transcription:"))
    print(_c(DIM, "  • Personal Mac  → auto Cmd+V into whatever is focused"))
    print(_c(DIM, "  • Company Mac   → copied to clipboard; press ⌘V yourself"))
    print()

    is_company = _ask_yes_no("  Is this a company-managed Mac (no admin rights)?", default=False)
    print()
    return is_company


# ── Step 3: Personal vocabulary ───────────────────────────────────────────


def _collect_vocabulary(existing: list[str]) -> list[str]:
    """Return the user's personal vocabulary list."""
    print(_c(DIM, "  Add technical terms, product names, or jargon that Whisper"))
    print(_c(DIM, "  should transcribe accurately (e.g. PyTorch, kubectl, gpt-4o)."))
    print(_c(DIM, "  These are also used to guide the AI cleanup step."))
    print()

    if existing:
        print(f"  Current terms: {_c(CYAN, ', '.join(existing))}")
        print()
        action = _ask("  [a]dd more, [r]eplace all, [c]lear, or Enter to keep", default="keep")
        action = action.lower().strip()
        if action in ("c", "clear"):
            _ok("Vocabulary cleared")
            return []
        if action not in ("a", "add", "r", "replace"):
            return existing  # keep as-is
        if action in ("r", "replace"):
            existing = []

    raw = _ask("  Terms (comma-separated, or Enter to skip)", default="")
    if not raw:
        return existing

    new_terms = [t.strip() for t in raw.split(",") if t.strip()]
    merged = existing + [t for t in new_terms if t not in existing]
    if merged:
        _ok(f"Vocabulary: {', '.join(merged)}")
    return merged


# ── Step 4: Install service ────────────────────────────────────────────────


def _install_service(api_key: str, restricted_mode: bool) -> bool:
    """Write plist and load via launchctl. Returns True on success."""
    import shutil
    import plistlib

    uv = shutil.which("uv")
    if not uv:
        _err("'uv' not found on PATH — cannot install as a background service.")
        return False

    project = str(Path(__file__).parent.parent.parent.resolve())
    label = "com.voiceprompt"
    plist_path = Path.home() / "Library" / "LaunchAgents" / f"{label}.plist"

    plist: dict = {
        "Label": label,
        "ProgramArguments": [uv, "run", "--project", project, "voiceprompt"],
        "EnvironmentVariables": {
            "VOICEPROMPT_CONFIG": str(Path.home() / ".config" / "voiceprompt" / "config.json"),
            "PATH": os.environ.get("PATH", "/usr/local/bin:/usr/bin:/bin"),
        },
        "RunAtLoad": True,
        "KeepAlive": True,
        "StandardOutPath": "/tmp/voiceprompt.log",
        "StandardErrorPath": "/tmp/voiceprompt.error.log",
    }

    plist_path.parent.mkdir(parents=True, exist_ok=True)
    with open(plist_path, "wb") as f:
        plistlib.dump(plist, f)

    # Unload old version first (ignore errors)
    subprocess.run(["launchctl", "unload", str(plist_path)],
                   capture_output=True)
    result = subprocess.run(["launchctl", "load", str(plist_path)],
                            capture_output=True, text=True)
    if result.returncode != 0:
        _err(f"launchctl: {result.stderr.strip()}")
        return False
    return True


# ── Main ───────────────────────────────────────────────────────────────────


def main() -> None:
    from voiceprompt.config import Config

    _banner()

    # Load existing config if present
    existing_key = ""
    existing_restricted = False
    existing_vocabulary: list[str] = []
    if Config.exists():
        try:
            cfg = Config.load()
            existing_key = cfg.openai_api_key
            existing_restricted = cfg.restricted_mode
            existing_vocabulary = cfg.vocabulary
        except Exception:
            pass

    total_steps = 4

    # ── Step 1 ──────────────────────────────────────────────────────
    _step(1, total_steps, "OpenAI API Key")
    api_key = _collect_api_key(existing_key)

    # ── Step 2 ──────────────────────────────────────────────────────
    _step(2, total_steps, "Mac Type")
    restricted_mode = _collect_mac_type()

    # ── Step 3 ──────────────────────────────────────────────────────
    _step(3, total_steps, "Personal Vocabulary (optional)")
    vocabulary = _collect_vocabulary(existing_vocabulary)
    print()

    # ── Step 4 ──────────────────────────────────────────────────────
    _step(4, total_steps, "Installing background service")

    cfg = Config(openai_api_key=api_key, restricted_mode=restricted_mode, vocabulary=vocabulary)
    cfg.save()
    _ok(f"Config saved to ~/.config/voiceprompt/config.json")

    if _install_service(api_key, restricted_mode):
        _ok("LaunchAgent installed — VoicePrompt starts at every login")
        _ok("Service is running now")
    else:
        _warn("Service install failed. You can still run manually: uv run voiceprompt")

    # ── Summary ─────────────────────────────────────────────────────
    print()
    print(_c(BOLD, "  ══ All done! ══════════════════════════════"))
    print()
    print("  Trigger: Hold " + _c(BOLD, "Right Option (⌥)") + " → speak → release")
    if restricted_mode:
        print("  Mode:    " + _c(YELLOW, "Company Mac") + " — text copied to clipboard")
        print("  Paste:   Press " + _c(BOLD, "⌘V") + " wherever you want the text")
    else:
        print("  Mode:    " + _c(GREEN, "Personal Mac") + " — text auto-pasted")
        print("  Paste:   Auto Cmd+V into whatever is focused")
    print()
    print(_c(DIM, "  Logs:     tail -f /tmp/voiceprompt.log"))
    print(_c(DIM, "  Uninstall: voiceprompt-uninstall"))
    print()
