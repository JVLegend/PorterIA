#!/usr/bin/env bash
# Packages build/PorterIA.app into build/PorterIA-<version>.dmg.
# Includes a /Applications symlink for drag-to-install UX.
# Signs the .dmg with the same Developer ID Application identity.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/PorterIA.app"
IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application: Joao Dias (XYMF8L77YL)}"

if [[ ! -d "$APP" ]]; then
    echo "ERROR: $APP not found. Run ./scripts/build-app.sh release first." >&2
    exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="$ROOT/build/PorterIA-$VERSION.dmg"
STAGING="$ROOT/build/dmg-staging"

echo "==> staging $STAGING"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/PorterIA.app"
ln -s /Applications "$STAGING/Applications"

echo "==> hdiutil create $DMG"
hdiutil create \
    -volname "PorterIA $VERSION" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG" >/dev/null

rm -rf "$STAGING"

echo "==> codesign $DMG"
codesign \
    --force \
    --sign "$IDENTITY" \
    --timestamp \
    "$DMG"

echo "==> done: $DMG"
echo "    sha256: $(shasum -a 256 "$DMG" | awk '{print $1}')"
