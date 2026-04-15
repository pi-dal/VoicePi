cask "voicepi" do
  version "1.9.1"
  sha256 "b1b0ce5b3b574d6d651fae76eb15e0c54477137fe1b1d39ea4f6a3244ce3bc9b"

  url "https://github.com/pi-dal/VoicePi/releases/download/v1.9.1/VoicePi-1.9.1.zip"
  name "VoicePi"
  desc "macOS menu-bar voice input app built with SwiftPM"
  homepage "https://github.com/pi-dal/VoicePi"

  depends_on macos: ">= :sonoma"

  app "VoicePi.app"
end
