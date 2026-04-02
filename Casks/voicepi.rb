cask "voicepi" do
  version "1.1.1"
  sha256 "ba253e2fe13799fca10e9b2469a99c37ec48f392e8a5182a98b51bc93e64c957"

  url "https://github.com/pi-dal/VoicePi/releases/download/v1.1.1/VoicePi-macOS.zip"
  name "VoicePi"
  desc "macOS menu-bar voice input app built with SwiftPM"
  homepage "https://github.com/pi-dal/VoicePi"

  depends_on macos: ">= :sonoma"

  app "VoicePi.app"
end
