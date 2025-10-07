#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$INSTALLER_DIR/build"
DIST_DIR="$INSTALLER_DIR/dist"
RESOURCES_DIR="$INSTALLER_DIR/resources/dmg"

APP_NAME="CueBearBridge"
DMG_NAME="CueBear-Bridge-Installer"
VOLUME_NAME="CueBear Bridge"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Creating DMG installer for CueBear Bridge...${NC}"

# Create temp directory for DMG contents
DMG_TEMP="/tmp/${APP_NAME}_dmg_$$"
mkdir -p "$DMG_TEMP"

echo "Copying app bundle..."
cp -R "$BUILD_DIR/${APP_NAME}.app" "$DMG_TEMP/"

echo "Creating Applications symlink..."
ln -s /Applications "$DMG_TEMP/Applications"

echo "Creating temporary DMG..."
hdiutil create -volname "${VOLUME_NAME}" \
    -srcfolder "$DMG_TEMP" \
    -ov -format UDRW \
    -fs HFS+ \
    "$DMG_TEMP/temp.dmg"

echo "Mounting temporary DMG..."
MOUNT_DIR=$(hdiutil attach "$DMG_TEMP/temp.dmg" | grep Volumes | awk '{print $3}')

echo "Setting DMG window properties..."
# Set window properties using AppleScript
osascript <<EOD
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 700, 450}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set position of item "${APP_NAME}.app" of container window to {150, 180}
        set position of item "Applications" of container window to {450, 180}
        update without registering applications
        delay 2
    end tell
end tell
EOD

# Sync and unmount
sync
echo "Unmounting temporary DMG..."
hdiutil detach "$MOUNT_DIR"

echo "Compressing final DMG..."
hdiutil convert "$DMG_TEMP/temp.dmg" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DIST_DIR/${DMG_NAME}.dmg"

echo "Cleaning up..."
rm -rf "$DMG_TEMP"

echo -e "${GREEN}✅ DMG created: $DIST_DIR/${DMG_NAME}.dmg${NC}"
echo -e "${GREEN}✅ Users can drag ${APP_NAME}.app to Applications folder to install${NC}"
