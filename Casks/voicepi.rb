cask "voicepi" do
  version "1.6.0"
  sha256 "290c35401309814caae95652de373dbe51bb122f0020c11071a799819c7ddc10"

  url "https://github.com/pi-dal/VoicePi/releases/download/v1.6.0/VoicePi-1.6.0.zip"
  name "VoicePi"
  desc "macOS menu-bar voice input app built with SwiftPM"
  homepage "https://github.com/pi-dal/VoicePi"

  depends_on macos: ">= :sonoma"

  app "VoicePi.app"
end
