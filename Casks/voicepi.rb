cask "voicepi" do
  version "0.0.0"
  sha256 :no_check

  url "https://github.com/pi-dal/VoicePi/releases/download/v#{version}/VoicePi-macOS.zip"
  name "VoicePi"
  desc "macOS menu-bar voice input app built with SwiftPM"
  homepage "https://github.com/pi-dal/VoicePi"

  depends_on macos: ">= :sonoma"

  app "VoicePi.app"
end
