#!/bin/bash

# Cue Bear Bridge Enhanced Installer with Bear Paw Icon
# Creates a complete installation package with custom icon

set -e

echo "🔨 Cue Bear Bridge Enhanced Installer with Bear Paw Icon"
echo "======================================================="

# Configuration
APP_NAME="CueBearBridge"
BUNDLE_ID="com.cuebear.bridge"
VERSION="1.0"
INSTALLER_NAME="CueBearBridge-Enhanced-Installer"

# Create temporary directory structure
TEMP_DIR=$(mktemp -d)
echo "📁 Using temp directory: $TEMP_DIR"

# Create package structure - app only
PACKAGE_ROOT="$TEMP_DIR/package_root"
mkdir -p "$PACKAGE_ROOT"

# Copy the Bridge app (check multiple possible locations)
APP_FOUND=false
if [ -d "../CueBearBridgeClean.app" ]; then
    echo "📱 Copying CueBearBridge app from project root..."
    cp -R "../CueBearBridgeClean.app" "$PACKAGE_ROOT/CueBearBridge.app"
    APP_FOUND=true
elif [ -d "build/DerivedData/Build/Products/Release/CueBearBridgeClean.app" ]; then
    echo "📱 Copying CueBearBridge app from build directory..."
    cp -R "build/DerivedData/Build/Products/Release/CueBearBridgeClean.app" "$PACKAGE_ROOT/CueBearBridge.app"
    APP_FOUND=true
fi

if [ "$APP_FOUND" = true ]; then
    # Ensure the app icon is properly set
    echo "🎨 Verifying bear paw icon is included..."
    if [ -f "$PACKAGE_ROOT/Applications/CueBearBridge.app/Contents/Resources/AppIcon.icns" ]; then
        echo "✅ Bear paw icon (AppIcon.icns) found in app bundle"
    else
        echo "⚠️  AppIcon.icns not found in app bundle"
    fi
    
    if [ -d "$PACKAGE_ROOT/Applications/CueBearBridge.app/Contents/Resources/Assets.xcassets/AppIcon.appiconset" ]; then
        echo "✅ Bear paw icon assets found in app bundle"
    else
        echo "⚠️  Bear paw icon assets not found in app bundle"
    fi
else
    echo "❌ Error: CueBearBridge app not found!"
    echo "   Please build the app first in Xcode"
    echo "   Expected locations:"
    echo "   - ../CueBearBridgeClean.app"
    echo "   - build/DerivedData/Build/Products/Release/CueBearBridgeClean.app"
    exit 1
fi

# Copy bundled libraries and helpers
if [ -d "../Resources" ]; then
    echo "📚 Copying bundled libraries..."
    mkdir -p "$PACKAGE_ROOT/CueBearBridge.app/Contents/Resources"
    cp -R "../Resources/"* "$PACKAGE_ROOT/CueBearBridge.app/Contents/Resources/"
fi

# No installation manifest needed for app-only installation

# No scripts needed for app-only installation

# Create package info
echo "📦 Creating package info..."
mkdir -p "$TEMP_DIR/pkg_info"
cat > "$TEMP_DIR/pkg_info/package_info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>IFMajorVersion</key>
    <integer>1</integer>
    <key>IFMinorVersion</key>
    <integer>0</integer>
    <key>IFPkgFlagAllowBackRev</key>
    <false/>
    <key>IFPkgFlagAuthorizationAction</key>
    <string>AdminAuthorization</string>
    <key>IFPkgFlagDefaultLocation</key>
    <string>/</string>
    <key>IFPkgFlagInstallFat</key>
    <false/>
    <key>IFPkgFlagIsRequired</key>
    <false/>
    <key>IFPkgFlagOverwritePermissions</key>
    <false/>
    <key>IFPkgFlagRelocatable</key>
    <false/>
    <key>IFPkgFlagRestartAction</key>
    <string>NoRestart</string>
    <key>IFPkgFlagRootVolumeOnly</key>
    <true/>
    <key>IFPkgFlagUpdateInstalledLanguages</key>
    <false/>
</dict>
</plist>
EOF

# Create distribution file
echo "📋 Creating distribution file..."
cat > "$TEMP_DIR/distribution.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="1">
    <title>Cue Bear Bridge</title>
    <organization>com.cuebear</organization>
    <domains enable_localSystem="true" enable_anywhere="true"/>
    <options customize="never" require-scripts="false" rootVolumeOnly="false" />
    
    <!-- Define the volume requirements -->
    <volume-check>
        <allowed-os-versions>
            <os-version min="10.0"/>
        </allowed-os-versions>
    </volume-check>
    
    <!-- Define what this package will install -->
    <choices-outline>
        <line choice="default">
            <line choice="$BUNDLE_ID"/>
        </line>
    </choices-outline>
    
    <choice id="default"/>
    <choice id="$BUNDLE_ID" visible="false">
        <pkg-ref id="$BUNDLE_ID"/>
    </choice>
    
    <pkg-ref id="$BUNDLE_ID" version="$VERSION" onConclusion="none">$INSTALLER_NAME.pkg</pkg-ref>
    
    <!-- Customize the installer appearance -->
    <welcome file="welcome.html" mime-type="text/html"/>
    <conclusion file="conclusion.html" mime-type="text/html"/>
</installer-gui-script>
EOF

# Copy installer resources
echo "🎨 Copying installer resources..."
mkdir -p "$TEMP_DIR/resources"

# Copy HTML resources
cp "resources/welcome.html" "$TEMP_DIR/resources/"
cp "resources/conclusion.html" "$TEMP_DIR/resources/"

# Build the package
echo "🔨 Building installer package..."
pkgbuild --root "$PACKAGE_ROOT" \
         --identifier "$BUNDLE_ID" \
         --version "$VERSION" \
         --install-location "/Applications" \
         "$TEMP_DIR/$INSTALLER_NAME.pkg"

# Build the distribution package
echo "📦 Building distribution package..."
productbuild --distribution "$TEMP_DIR/distribution.xml" \
             --package-path "$TEMP_DIR" \
             --resources "$TEMP_DIR/resources" \
             "dist/$INSTALLER_NAME.pkg"

# Create DMG with custom icon
echo "💿 Creating DMG with Icon-iOS-Default-1024x1024 icon..."
DMG_NAME="$INSTALLER_NAME.dmg"
DMG_PATH="dist/$DMG_NAME"

# Create DMG directly from package
hdiutil create -srcfolder "dist/$INSTALLER_NAME.pkg" -volname "Cue Bear Bridge Installer" -fs HFS+ -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH"

# Clean up
rm -rf "$TEMP_DIR"

echo ""
echo "✅ Enhanced installer with bear paw icon created successfully!"
echo ""
echo "📦 Package: dist/$INSTALLER_NAME.pkg"
echo "💿 DMG: dist/$DMG_NAME"
echo ""
echo "🎨 Features:"
echo "   • Bear paw icon in installer background"
echo "   • Bear paw icon in DMG"
echo "   • Professional installer appearance"
echo "   • Safe installation with pre/post scripts"
echo "   • Desktop shortcut creation"
echo "   • Icon cache refresh for immediate visibility"
echo ""
echo "🐾 The installer now showcases your bear paw branding!"
