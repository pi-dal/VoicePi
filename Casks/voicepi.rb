cask "voicepi" do
  version "1.7.0"
  sha256 "34eac75b9143a66db66c19e119be8ad3fcfc67f733703ebd514468afb78bb3c3"

  url "https://github.com/pi-dal/VoicePi/releases/download/v1.7.0/VoicePi-1.7.0.zip"
  name "VoicePi"
  desc "macOS menu-bar voice input app built with SwiftPM"
  homepage "https://github.com/pi-dal/VoicePi"

  depends_on macos: ">= :sonoma"

  app "VoicePi.app"
end
