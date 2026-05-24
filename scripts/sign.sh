#!/usr/bin/env bash
# Signs build/PorterIA.app with the Developer ID Application certificate,
# enabling the hardened runtime (required for notarization).
#
# Requires: a "Developer ID Application: ..." identity in the login keychain.
# Override the identity by exporting CODESIGN_IDENTITY before running.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/PorterIA.app"
ENTITLEMENTS="$ROOT/Resources/PorterIA.entitlements"
IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application: Joao Dias (XYMF8L77YL)}"

if [[ ! -d "$APP" ]]; then
    echo "ERROR: $APP not found. Run ./scripts/build-app.sh release first." >&2
    exit 1
fi

if ! security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
    echo "ERROR: codesign identity not found in keychain:" >&2
    echo "       \"$IDENTITY\"" >&2
    echo "       Run: security find-identity -v -p codesigning" >&2
    exit 1
fi

echo "==> codesign --deep --options runtime --entitlements ... $APP"
codesign \
    --force \
    --deep \
    --options runtime \
    --entitlements "$ENTITLEMENTS" \
    --sign "$IDENTITY" \
    --timestamp \
    "$APP"

echo "==> verifying"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> spctl assessment (informational — will say 'rejected' until notarized)"
spctl --assess --type execute --verbose=4 "$APP" || true

echo "==> done"
