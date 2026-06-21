# Homebrew cask for Murmur.
#
# Murmur is ad-hoc-signed (no Apple Developer ID). Current Homebrew no longer
# honours --no-quarantine, so the app is always quarantined on install. After
# installing, approve it once via System Settings -> Privacy & Security ->
# "Open Anyway", or clear the flag directly:
#
#   xattr -dr com.apple.quarantine /Applications/Murmur.app
#
# Per release: bump `version` and replace `sha256` with the value printed by
# scripts/build-dmg.sh (or `shasum -a 256` of the published .dmg).
cask "murmur" do
  version "0.1.2"
  sha256 "385600e0fdf80bad60b04dfbf524f7837f25ebfba6ec216b092f8a06383b28f1"

  url "https://github.com/yash-coded/voiceprompt/releases/download/v#{version}/Murmur-#{version}.dmg"
  name "Murmur"
  desc "Hold-to-talk dictation with local transcription and AI cleanup"
  homepage "https://github.com/yash-coded/voiceprompt"

  depends_on macos: :sequoia
  depends_on arch: :arm64

  app "Murmur.app"

  zap trash: [
    "~/Library/Application Support/Murmur",
    "~/Library/Preferences/io.github.yash-coded.murmur.plist",
  ]
end
