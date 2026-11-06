#!/bin/sh
# Packages build/Krasnotch.app into dist/: a drag-to-Applications DMG, a zip, and SHA-256 checksums.
# Notarizes and staples when NOTARY_PROFILE (a `xcrun notarytool store-credentials` profile) is set.
set -eu
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.1.0}"
export VERSION
scripts/build-app.sh

DIST="dist"
NAME="Krasnotch-$VERSION"
rm -rf "$DIST" && mkdir -p "$DIST"

# DMG: the app plus an Applications shortcut.
STAGE="$(mktemp -d)"
cp -R build/Krasnotch.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname "Krasnotch" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DIST/$NAME.dmg" >/dev/null
rm -rf "$STAGE"
if [ -n "${DEVELOPER_ID:-}" ]; then
  codesign --force --timestamp --sign "$DEVELOPER_ID" "$DIST/$NAME.dmg"
fi

if [ -n "${NOTARY_PROFILE:-}" ]; then
  xcrun notarytool submit "$DIST/$NAME.dmg" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DIST/$NAME.dmg"
  xcrun stapler staple build/Krasnotch.app
fi

ditto -c -k --keepParent build/Krasnotch.app "$DIST/$NAME.zip"
# Unversioned copy so https://github.com/<owner>/krasnotch/releases/latest/download/Krasnotch.dmg always works.
cp "$DIST/$NAME.dmg" "$DIST/Krasnotch.dmg"
(cd "$DIST" && shasum -a 256 "$NAME.dmg" "$NAME.zip" Krasnotch.dmg > SHA256SUMS.txt)
echo "Packaged:"; ls -lh "$DIST"
