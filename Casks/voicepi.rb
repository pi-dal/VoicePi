cask "voicepi" do
  version "1.10.1"
  sha256 "eb4a7b18a965c0e5e1517b731645bcc9cb8a529ae73cced7259121df68feb3c7"

  url "https://github.com/pi-dal/VoicePi/releases/download/v1.10.1/VoicePi-1.10.1.zip"
  name "VoicePi"
  desc "macOS menu-bar voice input app built with SwiftPM"
  homepage "https://github.com/pi-dal/VoicePi"

  depends_on macos: ">= :sonoma"

  app "VoicePi.app"
end
