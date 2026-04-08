cask "voicepi" do
  version "1.5.0"
  sha256 "26b7cb7612cc516339d2f871bfcfbb2c22828c851b25b3ead2452898e7fda77c"

  url "https://github.com/pi-dal/VoicePi/releases/download/v1.5.0/VoicePi-1.5.0.zip"
  name "VoicePi"
  desc "macOS menu-bar voice input app built with SwiftPM"
  homepage "https://github.com/pi-dal/VoicePi"

  depends_on macos: ">= :sonoma"

  app "VoicePi.app"
end
