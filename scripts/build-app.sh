#!/usr/bin/env bash
# Builds PorterIA.app from the SwiftPM executable.
# Usage: ./scripts/build-app.sh [debug|release]
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="PorterIA"
APP_BUNDLE="$ROOT/build/$APP_NAME.app"

cd "$ROOT"

echo "==> swift build --configuration $CONFIG"
swift build --configuration "$CONFIG"

BIN_PATH="$(swift build --configuration "$CONFIG" --show-bin-path)"
EXECUTABLE="$BIN_PATH/$APP_NAME"

if [[ ! -x "$EXECUTABLE" ]]; then
    echo "ERROR: built binary not found at $EXECUTABLE" >&2
    exit 1
fi

echo "==> assembling $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

echo "==> done: $APP_BUNDLE"
