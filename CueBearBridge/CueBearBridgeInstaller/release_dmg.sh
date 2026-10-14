#!/bin/bash
# ============================================================================
# CueBear Bridge - build a signed, notarized DMG (drag to Applications)
# Usage: ./release_dmg.sh
# Needs: "Developer ID Application" certificate in the keychain, and notarization
#        credentials saved once with:
#        xcrun notarytool store-credentials "cuebear-notarize" --apple-id <id> --team-id 2U78NYVLQN
# ============================================================================
set -euo pipefail

INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$INSTALLER_DIR")"
BUILD_DIR="$INSTALLER_DIR/build"
DIST_DIR="$INSTALLER_DIR/dist"
PROFILE="${KEYCHAIN_PROFILE:-cuebear-notarize}"
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PROJECT_DIR/Info.plist")"
IDENTITY="$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed -E 's/.*"(.*)"/\1/')"
FINAL_DMG="$DIST_DIR/CueBear-Bridge-v${VERSION}.dmg"

say() { echo ""; echo "==> $1"; }

[ -n "$IDENTITY" ] || { echo "No Developer ID Application certificate found."; exit 1; }
xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1 || {
    echo "Notarization login \"$PROFILE\" isn't saved yet (or the password was revoked)."; exit 1; }

say "1/5 Building and signing CueBear Bridge $VERSION"
DMG_ONLY=1 "$INSTALLER_DIR/scripts/build_pkg.sh" "$IDENTITY"

say "2/5 Making the DMG"
"$INSTALLER_DIR/scripts/create_dmg.sh"
mv -f "$DIST_DIR/CueBear-Bridge-Installer.dmg" "$FINAL_DMG"

say "3/5 Signing the DMG"
codesign --force --sign "$IDENTITY" --timestamp "$FINAL_DMG"

say "4/5 Sending to Apple for notarization (usually 1-10 minutes)"
xcrun notarytool submit "$FINAL_DMG" --keychain-profile "$PROFILE" --wait

say "5/5 Stapling and checking"
xcrun stapler staple "$FINAL_DMG"
spctl --assess --type open --context context:primary-signature -v "$FINAL_DMG"

echo ""
echo "DONE: $FINAL_DMG"
open -R "$FINAL_DMG"
