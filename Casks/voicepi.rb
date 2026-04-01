cask "voicepi" do
  version "1.0.0"
  sha256 "e320034cf102dc89d8a3e68b3bd9a3eaa3f493441ea12f5ca8dc8f038c3f1526"

  url "https://github.com/pi-dal/VoicePi/releases/download/v1.0.0/VoicePi-macOS.zip"
  name "VoicePi"
  desc "macOS menu-bar voice input app built with SwiftPM"
  homepage "https://github.com/pi-dal/VoicePi"

  depends_on macos: ">= :sonoma"

  app "VoicePi.app"
end
