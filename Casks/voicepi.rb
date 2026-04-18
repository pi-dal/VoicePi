cask "voicepi" do
  version "1.9.2"
  sha256 "07c91537082a27d5bb262997e1fc61b8c866e5ab8f3f9de72bc9a3f4698acfbb"

  url "https://github.com/pi-dal/VoicePi/releases/download/v1.9.2/VoicePi-1.9.2.zip"
  name "VoicePi"
  desc "macOS menu-bar voice input app built with SwiftPM"
  homepage "https://github.com/pi-dal/VoicePi"

  depends_on macos: ">= :sonoma"

  app "VoicePi.app"
end
