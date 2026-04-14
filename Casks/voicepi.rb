cask "voicepi" do
  version "1.9.0"
  sha256 "04f1875fba1eb22e30065ca66d8a17ca632f3961c9cdb891c18275e363dc024d"

  url "https://github.com/pi-dal/VoicePi/releases/download/v1.9.0/VoicePi-1.9.0.zip"
  name "VoicePi"
  desc "macOS menu-bar voice input app built with SwiftPM"
  homepage "https://github.com/pi-dal/VoicePi"

  depends_on macos: ">= :sonoma"

  app "VoicePi.app"
end
