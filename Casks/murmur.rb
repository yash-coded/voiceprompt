# Homebrew cask for Murmur.
#
# Murmur is ad-hoc-signed (no Apple Developer ID), so install with the
# --no-quarantine flag to skip Gatekeeper:
#
#   brew install --cask --no-quarantine yash-coded/tap/murmur
#
# Per release: bump `version` and replace `sha256` with the value printed by
# scripts/build-dmg.sh (or `shasum -a 256` of the published .dmg).
cask "murmur" do
  version "0.1.0"
  sha256 "14e446bb066386351ba797b499b2fed7cd4b5c50df021d4dc429799a6c4ceab2"

  url "https://github.com/yash-coded/voiceprompt/releases/download/v#{version}/Murmur-#{version}.dmg"
  name "Murmur"
  desc "Hold-to-talk dictation with local transcription and AI cleanup"
  homepage "https://github.com/yash-coded/voiceprompt"

  depends_on macos: ">= :sequoia"
  depends_on arch: :arm64

  app "Murmur.app"

  zap trash: [
    "~/Library/Application Support/Murmur",
    "~/Library/Preferences/io.github.yash-coded.murmur.plist",
  ]
end
