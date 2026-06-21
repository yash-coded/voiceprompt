#!/usr/bin/env bash
#
# Builds an ad-hoc-signed Murmur.app and packages it into a versioned .dmg.
# No Apple Developer account or notarization required.
#
# Usage: scripts/build-dmg.sh [version]
#   version defaults to the contents of the VERSION file.
#
# Output: dist/Murmur-<version>.dmg (plus its SHA-256, printed at the end).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-$(tr -d '[:space:]' < "$REPO_ROOT/VERSION")}"
BUNDLE_ID="io.github.yash-coded.murmur"

DIST="$REPO_ROOT/dist"
APP="$DIST/Murmur.app"
STAGE="$DIST/dmg-stage"
DMG="$DIST/Murmur-$VERSION.dmg"

echo "==> Building Murmur $VERSION (release)"
swift build -c release --package-path "$REPO_ROOT/Murmur"
BINARY="$REPO_ROOT/Murmur/.build/release/Murmur"

echo "==> Assembling $APP"
rm -rf "$APP" "$STAGE" "$DMG"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/Murmur"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>Murmur</string>
	<key>CFBundleDisplayName</key>
	<string>Murmur</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleExecutable</key>
	<string>Murmur</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>CFBundleVersion</key>
	<string>$VERSION</string>
	<key>LSMinimumSystemVersion</key>
	<string>15.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSMicrophoneUsageDescription</key>
	<string>Murmur transcribes your speech locally to turn it into text.</string>
	<key>NSHumanReadableCopyright</key>
	<string>MIT License</string>
</dict>
</plist>
PLIST

echo "==> Ad-hoc signing"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

echo "==> Packaging $DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Murmur" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo "==> Done: $DMG"
shasum -a 256 "$DMG"
