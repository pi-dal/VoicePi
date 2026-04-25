cask "voicepi" do
  version "1.11.0"
  sha256 "76f5f8c8265dcf71fac579403f8cb059934d590f3cf908eac006a5bfcec304f5"

  url "https://github.com/pi-dal/VoicePi/releases/download/v1.11.0/VoicePi-1.11.0.zip"
  name "VoicePi"
  desc "macOS menu-bar voice input app built with SwiftPM"
  homepage "https://github.com/pi-dal/VoicePi"

  depends_on macos: ">= :sonoma"

  app "VoicePi.app"
end
