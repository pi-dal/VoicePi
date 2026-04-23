cask "voicepi" do
  version "1.10.2"
  sha256 "81c20652144648f3eb06c07e0378a3358c7a41dea41c18551d48076e0033b634"

  url "https://github.com/pi-dal/VoicePi/releases/download/v1.10.2/VoicePi-1.10.2.zip"
  name "VoicePi"
  desc "macOS menu-bar voice input app built with SwiftPM"
  homepage "https://github.com/pi-dal/VoicePi"

  depends_on macos: ">= :sonoma"

  app "VoicePi.app"
end
