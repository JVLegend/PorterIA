#!/usr/bin/env bash
# Submits build/PorterIA-<version>.dmg to Apple notary service and staples the ticket.
#
# Prerequisite: run once to store credentials in the Keychain:
#   xcrun notarytool store-credentials "porteria-notary" \
#       --apple-id "iaparamedicos@gmail.com" \
#       --team-id "XYMF8L77YL"
# (paste your app-specific password from appleid.apple.com when prompted)
#
# Override the profile name by exporting NOTARY_PROFILE before running.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/PorterIA.app"
PROFILE="${NOTARY_PROFILE:-porteria-notary}"

if [[ ! -d "$APP" ]]; then
    echo "ERROR: $APP not found. Run ./scripts/build-app.sh release first." >&2
    exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="$ROOT/build/PorterIA-$VERSION.dmg"

if [[ ! -f "$DMG" ]]; then
    echo "ERROR: $DMG not found. Run ./scripts/dmg.sh first." >&2
    exit 1
fi

if ! xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
    echo "ERROR: notarytool profile '$PROFILE' not configured." >&2
    echo "       Run once:" >&2
    echo "         xcrun notarytool store-credentials '$PROFILE' \\" >&2
    echo "             --apple-id 'iaparamedicos@gmail.com' \\" >&2
    echo "             --team-id 'XYMF8L77YL'" >&2
    exit 1
fi

echo "==> submitting $DMG to Apple notary (this can take minutes)"
xcrun notarytool submit "$DMG" \
    --keychain-profile "$PROFILE" \
    --wait

echo "==> stapling ticket to $DMG"
xcrun stapler staple "$DMG"

echo "==> validating stapled ticket"
xcrun stapler validate "$DMG"
spctl --assess --type install --verbose=4 "$DMG"

echo "==> done: $DMG is signed, notarized, and stapled."
echo "    sha256: $(shasum -a 256 "$DMG" | awk '{print $1}')"
