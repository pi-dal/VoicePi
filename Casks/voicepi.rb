cask "voicepi" do
  version "1.12.0"
  sha256 "bfe91214d6060461023edc655b556f34a635f70979ac306e751cd34134f55960"

  url "https://github.com/pi-dal/VoicePi/releases/download/v1.12.0/VoicePi-1.12.0.zip"
  name "VoicePi"
  desc "macOS menu-bar voice input app built with SwiftPM"
  homepage "https://github.com/pi-dal/VoicePi"

  depends_on macos: ">= :sonoma"

  app "VoicePi.app"
end
