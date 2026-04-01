#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

mkdir -p "$TMP_DIR/Sources/VoicePi" "$TMP_DIR/bin" "$TMP_DIR/dist/Test.app/Contents/MacOS"

cp "$ROOT_DIR/Makefile" "$TMP_DIR/Makefile"

cat > "$TMP_DIR/Sources/VoicePi/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>VoicePi</string>
</dict>
</plist>
EOF

mkdir -p "$TMP_DIR/Sources/VoicePi/AppIcon.appiconset"
cat > "$TMP_DIR/Sources/VoicePi/AppIcon.appiconset/Contents.json" <<'EOF'
{
  "images" : [
    {
      "filename" : "icon_16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_64.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_1024.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF
printf 'png-data' > "$TMP_DIR/Sources/VoicePi/AppIcon.appiconset/icon_16.png"
printf 'png-data' > "$TMP_DIR/Sources/VoicePi/AppIcon.appiconset/icon_32.png"
printf 'png-data' > "$TMP_DIR/Sources/VoicePi/AppIcon.appiconset/icon_64.png"
printf 'png-data' > "$TMP_DIR/Sources/VoicePi/AppIcon.appiconset/icon_128.png"
printf 'png-data' > "$TMP_DIR/Sources/VoicePi/AppIcon.appiconset/icon_256.png"
printf 'png-data' > "$TMP_DIR/Sources/VoicePi/AppIcon.appiconset/icon_512.png"
printf 'png-data' > "$TMP_DIR/Sources/VoicePi/AppIcon.appiconset/icon_1024.png"
printf '#!/bin/sh\nexit 0\n' > "$TMP_DIR/Sources/VoicePi/VoicePi.entitlements"
chmod +x "$TMP_DIR/Sources/VoicePi/VoicePi.entitlements"
printf '#!/bin/sh\nexit 0\n' > "$TMP_DIR/dummy-exec"
chmod +x "$TMP_DIR/dummy-exec"

cat > "$TMP_DIR/bin/iconutil" <<'EOF'
#!/bin/sh
set -eu

output=""
input=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --convert)
      shift 2
      ;;
    --output)
      output="$2"
      shift 2
      ;;
    *)
      input="$1"
      shift
      ;;
  esac
done

[ -n "$output" ]
[ -n "$input" ]
[ -f "$input/icon_16x16.png" ]
[ -f "$input/icon_16x16@2x.png" ]
[ -f "$input/icon_512x512.png" ]
[ -f "$input/icon_512x512@2x.png" ]
printf 'icns-data' > "$output"
EOF
chmod +x "$TMP_DIR/bin/iconutil"

cat > "$TMP_DIR/bin/codesign" <<'EOF'
#!/bin/sh
set -eu
exit 0
EOF
chmod +x "$TMP_DIR/bin/codesign"

(
  cd "$TMP_DIR"
  PATH="$TMP_DIR/bin:$PATH" \
  make bundle APP_DIR="$TMP_DIR/dist/Test.app" EXEC="$TMP_DIR/dummy-exec" SIGN_IDENTITY="-"
)

[ -f "$TMP_DIR/dist/Test.app/Contents/Resources/AppIcon.icns" ]
