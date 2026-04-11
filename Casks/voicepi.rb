cask "voicepi" do
  version "1.7.1"
  sha256 "2adc8f0c08c6355849cd6977c24af72ad14e91997b3568e9ba426fbac3e9f9cc"

  url "https://github.com/pi-dal/VoicePi/releases/download/v1.7.1/VoicePi-1.7.1.zip"
  name "VoicePi"
  desc "macOS menu-bar voice input app built with SwiftPM"
  homepage "https://github.com/pi-dal/VoicePi"

  depends_on macos: ">= :sonoma"

  app "VoicePi.app"
end
