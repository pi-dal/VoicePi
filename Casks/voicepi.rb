cask "voicepi" do
  version "1.1.2"
  sha256 "0aec8d8e147a1b75c5562ec54a6c01d2c5a731005dbd39cfef1eba37710d9d14"

  url "https://github.com/pi-dal/VoicePi/releases/download/v1.1.2/VoicePi-macOS.zip"
  name "VoicePi"
  desc "macOS menu-bar voice input app built with SwiftPM"
  homepage "https://github.com/pi-dal/VoicePi"

  depends_on macos: ">= :sonoma"

  app "VoicePi.app"
end
