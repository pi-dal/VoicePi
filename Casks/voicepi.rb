cask "voicepi" do
  version "1.10.0"
  sha256 "8ef0fd895f52149a267c0250d15b5415a15d12fb88d7aea79abed14bbdc721bb"

  url "https://github.com/pi-dal/VoicePi/releases/download/v1.10.0/VoicePi-1.10.0.zip"
  name "VoicePi"
  desc "macOS menu-bar voice input app built with SwiftPM"
  homepage "https://github.com/pi-dal/VoicePi"

  depends_on macos: ">= :sonoma"

  app "VoicePi.app"
end
