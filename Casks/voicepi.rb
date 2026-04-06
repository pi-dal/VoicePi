cask "voicepi" do
  version "1.3.2"
  sha256 "707aee2f1d2dcd21385d23b94cb3871bae3ff530cbc36a5a20a1d02aee901ef8"

  url "https://github.com/pi-dal/VoicePi/releases/download/v1.3.2/VoicePi-1.3.2.zip"
  name "VoicePi"
  desc "macOS menu-bar voice input app built with SwiftPM"
  homepage "https://github.com/pi-dal/VoicePi"

  depends_on macos: ">= :sonoma"

  app "VoicePi.app"
end
