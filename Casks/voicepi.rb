cask "voicepi" do
  version "1.4.0"
  sha256 "ab4daa2fd8b1b26db291f1591364a0219ed422e16b4c8c402175200fd51f55c3"

  url "https://github.com/pi-dal/VoicePi/releases/download/v1.4.0/VoicePi-1.4.0.zip"
  name "VoicePi"
  desc "macOS menu-bar voice input app built with SwiftPM"
  homepage "https://github.com/pi-dal/VoicePi"

  depends_on macos: ">= :sonoma"

  app "VoicePi.app"
end
