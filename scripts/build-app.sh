#!/bin/sh
# Builds build/Krasnotch.app as a universal (Apple silicon + Intel) release build.
#
#   VERSION=1.2.0 scripts/build-app.sh                  # ad-hoc signed, for local use
#   DEVELOPER_ID="Developer ID Application: …" …        # hardened runtime + Developer ID, for releases
set -eu
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Krasnotch"
APP="build/Krasnotch.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Krasnotch"

# App icon (exported from the Figma logo file).
ICON_SRC="Resources/AppIcon-1024.png"
if [ -f "$ICON_SRC" ]; then
  ICONSET="$(mktemp -d)/AppIcon.iconset"; mkdir -p "$ICONSET"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$ICON_SRC" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) "$ICON_SRC" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>dev.krasnotch.app</string>
  <key>CFBundleName</key><string>Krasnotch</string>
  <key>CFBundleDisplayName</key><string>Krasnotch</string>
  <key>CFBundleExecutable</key><string>Krasnotch</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSUIElement</key><true/>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>NSAppleEventsUsageDescription</key><string>Krasnotch selects the Terminal or iTerm2 tab running your agent when you click the notch.</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

if [ -n "${DEVELOPER_ID:-}" ]; then
  codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID" "$APP"
else
  codesign --force --sign - "$APP"
fi
echo "Built $APP ($VERSION)"
