# Homebrew cask for Murmur.
#
# Murmur is ad-hoc-signed (no Apple Developer ID). Recent Homebrew removed the
# bare `--no-quarantine` install flag, so either do the one-time Gatekeeper
# "Open Anyway" after installing, or skip quarantine up front:
#
#   HOMEBREW_CASK_OPTS="--no-quarantine" brew install --cask yash-coded/tap/murmur
#
# Per release: bump `version` and replace `sha256` with the value printed by
# scripts/build-dmg.sh (or `shasum -a 256` of the published .dmg).
cask "murmur" do
  version "0.1.0"
  sha256 "cc26d81b4ad33ffd237eec702fb85df5bc5f2fa4a4d208e5af448d4fddea57c6"

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
