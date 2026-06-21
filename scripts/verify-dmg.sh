#!/usr/bin/env bash
#
# Verifies the artifact produced by build-dmg.sh: mounts the .dmg, asserts the
# bundle structure, ad-hoc signature, and Info.plist contents are correct.
# Acts as the automated QA gate for the packaging slice.
#
# Usage: scripts/verify-dmg.sh [version]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-$(tr -d '[:space:]' < "$REPO_ROOT/VERSION")}"
DMG="$REPO_ROOT/dist/Murmur-$VERSION.dmg"
BUNDLE_ID="io.github.yash-coded.murmur"

fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

[ -f "$DMG" ] || fail "missing $DMG"
ok "dmg exists"

MOUNT="$(mktemp -d)"
hdiutil attach "$DMG" -mountpoint "$MOUNT" -nobrowse -quiet
trap 'hdiutil detach "$MOUNT" -quiet -force >/dev/null 2>&1 || true; rmdir "$MOUNT" 2>/dev/null || true' EXIT

APP="$MOUNT/Murmur.app"
PLIST="$APP/Contents/Info.plist"

[ -d "$APP" ] || fail "Murmur.app not in dmg"
ok "Murmur.app present"
[ -x "$APP/Contents/MacOS/Murmur" ] || fail "executable missing"
ok "executable present"
[ -L "$MOUNT/Applications" ] || fail "/Applications drag-target symlink missing"
ok "Applications symlink present"

codesign --verify --deep --strict "$APP" || fail "ad-hoc signature invalid"
ok "ad-hoc signature valid"

plutil -lint "$PLIST" >/dev/null || fail "Info.plist malformed"
ok "Info.plist well-formed"

check_key() {
	local got; got="$(plutil -extract "$1" raw -o - "$PLIST" 2>/dev/null)" || fail "Info.plist missing $1"
	[ "$got" = "$2" ] || fail "$1 = '$got', expected '$2'"
	ok "$1 = $2"
}
check_key CFBundleIdentifier "$BUNDLE_ID"
check_key CFBundleShortVersionString "$VERSION"
check_key LSUIElement "true"

plutil -extract NSMicrophoneUsageDescription raw -o - "$PLIST" >/dev/null \
	|| fail "NSMicrophoneUsageDescription missing"
ok "NSMicrophoneUsageDescription present"

echo "PASS — $DMG is a valid ad-hoc-signed release artifact"
