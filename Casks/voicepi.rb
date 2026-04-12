cask "voicepi" do
  version "1.8.0"
  sha256 "35f9478d7ab21042eb37bf9ebe59aadba5f8fec03b02c48f53813ce4748d1f64"

  url "https://github.com/pi-dal/VoicePi/releases/download/v1.8.0/VoicePi-1.8.0.zip"
  name "VoicePi"
  desc "macOS menu-bar voice input app built with SwiftPM"
  homepage "https://github.com/pi-dal/VoicePi"

  depends_on macos: ">= :sonoma"

  app "VoicePi.app"
end
