cask "voicepi" do
  version "1.3.1"
  sha256 "6a5fe8ecae7a9039b6d44f04edb6a16ab3adc4b666fe12c557893d49b3c47744"

  url "https://github.com/pi-dal/VoicePi/releases/download/v1.3.1/VoicePi-1.3.1.zip"
  name "VoicePi"
  desc "macOS menu-bar voice input app built with SwiftPM"
  homepage "https://github.com/pi-dal/VoicePi"

  depends_on macos: ">= :sonoma"

  app "VoicePi.app"
end
