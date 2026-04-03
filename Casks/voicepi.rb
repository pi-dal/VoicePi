cask "voicepi" do
  version "1.2.0"
  sha256 "250278dbeed23102a6fbd322b540c4232d27b1cfd824eedb09b3b2ffb3236788"

  url "https://github.com/pi-dal/VoicePi/releases/download/v1.2.0/VoicePi-macOS.zip"
  name "VoicePi"
  desc "macOS menu-bar voice input app built with SwiftPM"
  homepage "https://github.com/pi-dal/VoicePi"

  depends_on macos: ">= :sonoma"

  app "VoicePi.app"
end
