#!/usr/bin/env bash
# Interactive one-time setup for code signing + notarization.
# Run this once. It checks prerequisites, guides you through missing steps,
# and stores your notarytool credentials in the Keychain.
set -euo pipefail

APPLE_ID="iaparamedicos@gmail.com"
TEAM_ID="XYMF8L77YL"
PROFILE="porteria-notary"
EXPECTED_IDENTITY="Developer ID Application: Joao Dias (${TEAM_ID})"

echo "================================================================="
echo "  PorterIA — code signing & notarization setup"
echo "================================================================="
echo ""

# ----- Step 1: Developer ID Application certificate -----
echo "[1/3] Checking for Developer ID Application certificate..."
if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    FOUND="$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/')"
    echo "      ✓ Found: $FOUND"
    if [[ "$FOUND" != "$EXPECTED_IDENTITY" ]]; then
        echo "      ! Expected exactly:  $EXPECTED_IDENTITY"
        echo "        Will use the one found. Override with: export CODESIGN_IDENTITY=\"...\""
    fi
else
    echo "      ✗ Not found in keychain."
    echo ""
    echo "      You need to create one via Xcode (30 seconds, one-time):"
    echo "        1. Open Xcode"
    echo "        2. Xcode menu → Settings → Accounts"
    echo "        3. Select your Apple ID → click 'Manage Certificates...'"
    echo "        4. Click the '+' at the bottom-left → 'Developer ID Application'"
    echo "        5. Wait for it to be issued (a few seconds)"
    echo "        6. Re-run this script"
    echo ""
    exit 1
fi
echo ""

# ----- Step 2: App-specific password (cannot check, only remind) -----
echo "[2/3] App-specific password (Apple's web form — cannot be automated):"
echo "      If you haven't created one yet:"
echo "        1. Go to https://appleid.apple.com"
echo "        2. Sign-In and Security → App-Specific Passwords → '+'"
echo "        3. Name it something like 'PorterIA notarytool'"
echo "        4. Copy the password (format: xxxx-xxxx-xxxx-xxxx)"
echo "      Have it ready — you'll paste it in the next step."
echo ""
read -p "      Press Enter when ready (or Ctrl+C to abort)..."
echo ""

# ----- Step 3: Store credentials in Keychain -----
echo "[3/3] Storing credentials in the Keychain as profile '$PROFILE'..."
echo "      Apple ID: $APPLE_ID"
echo "      Team ID:  $TEAM_ID"
echo ""

if xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
    echo "      ! Profile '$PROFILE' already exists in the Keychain."
    read -p "        Overwrite? [y/N] " ans
    if [[ "${ans:-N}" != "y" && "${ans:-N}" != "Y" ]]; then
        echo "      Keeping existing profile. Setup complete."
        exit 0
    fi
fi

xcrun notarytool store-credentials "$PROFILE" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID"

echo ""
echo "      Verifying profile..."
if xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
    echo "      ✓ Profile '$PROFILE' stored and validated."
else
    echo "      ✗ Profile validation failed. Check the password and try again."
    exit 1
fi

echo ""
echo "================================================================="
echo "  ✓ Setup complete. You can now run:"
echo "      make release"
echo "================================================================="
