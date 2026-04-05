cask "voicepi" do
  version "1.3.0"
  sha256 "9192976f1f6a3ef4e32be387bfe85c0a7365c59c01ffb965dbac36aba9741812"

  url "https://github.com/pi-dal/VoicePi/releases/download/v1.3.0/VoicePi-1.3.0.zip"
  name "VoicePi"
  desc "macOS menu-bar voice input app built with SwiftPM"
  homepage "https://github.com/pi-dal/VoicePi"

  depends_on macos: ">= :sonoma"

  app "VoicePi.app"
end
