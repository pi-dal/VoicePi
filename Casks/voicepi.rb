cask "voicepi" do
  version "1.1.0"
  sha256 "dc408597ada3771f578bfbc2514c89b0428e9df0b370e5b1d9f33fca37a5d4ad"

  url "https://github.com/pi-dal/VoicePi/releases/download/v1.1.0/VoicePi-macOS.zip"
  name "VoicePi"
  desc "macOS menu-bar voice input app built with SwiftPM"
  homepage "https://github.com/pi-dal/VoicePi"

  depends_on macos: ">= :sonoma"

  app "VoicePi.app"
end
