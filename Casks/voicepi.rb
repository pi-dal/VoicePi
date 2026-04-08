cask "voicepi" do
  version "1.5.0"
  sha256 "1fe1890b90d00c643fa9d1b1f935b6cb4036b56fdfdebc916f0bf50000009ff8"

  url "https://github.com/pi-dal/VoicePi/releases/download/v1.5.0/VoicePi-1.5.0.zip"
  name "VoicePi"
  desc "macOS menu-bar voice input app built with SwiftPM"
  homepage "https://github.com/pi-dal/VoicePi"

  depends_on macos: ">= :sonoma"

  app "VoicePi.app"
end
