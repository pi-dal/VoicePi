cask "voicepi" do
  version "1.5.1"
  sha256 "3b79f3e9a272bbf195316df47faf997cfaaf30ab6100cd8b92b6038b0b510bfd"

  url "https://github.com/pi-dal/VoicePi/releases/download/v1.5.1/VoicePi-1.5.1.zip"
  name "VoicePi"
  desc "macOS menu-bar voice input app built with SwiftPM"
  homepage "https://github.com/pi-dal/VoicePi"

  depends_on macos: ">= :sonoma"

  app "VoicePi.app"
end
