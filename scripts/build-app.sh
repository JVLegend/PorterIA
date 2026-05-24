#!/usr/bin/env bash
# Builds a UNIVERSAL (arm64 + x86_64) PorterIA.app from the SwiftPM executable.
# Usage: ./scripts/build-app.sh [debug|release]
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="PorterIA"
APP_BUNDLE="$ROOT/build/$APP_NAME.app"
TARGET_MIN="14.0"

cd "$ROOT"

echo "==> swift build arm64 ($CONFIG)"
swift build --configuration "$CONFIG" --triple "arm64-apple-macosx${TARGET_MIN}"

echo "==> swift build x86_64 ($CONFIG)"
swift build --configuration "$CONFIG" --triple "x86_64-apple-macosx${TARGET_MIN}"

ARM_BIN="$(swift build --configuration "$CONFIG" --triple "arm64-apple-macosx${TARGET_MIN}" --show-bin-path)/$APP_NAME"
X86_BIN="$(swift build --configuration "$CONFIG" --triple "x86_64-apple-macosx${TARGET_MIN}" --show-bin-path)/$APP_NAME"

for bin in "$ARM_BIN" "$X86_BIN"; do
    if [[ ! -x "$bin" ]]; then
        echo "ERROR: built binary not found at $bin" >&2
        exit 1
    fi
done

echo "==> assembling $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "==> lipo -create (universal binary)"
lipo -create "$ARM_BIN" "$X86_BIN" -output "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cp "$ROOT/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
    cp "$ROOT/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    echo "==> bundled AppIcon.icns"
else
    echo "==> WARN: Resources/AppIcon.icns not found; building without custom icon"
fi

echo "==> architectures in final binary:"
lipo -info "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "==> done: $APP_BUNDLE"
