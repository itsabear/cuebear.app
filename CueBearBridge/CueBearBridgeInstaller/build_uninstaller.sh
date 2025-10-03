#!/bin/bash

# Cue Bear Bridge Uninstaller Package Builder
# Creates a proper .pkg uninstaller

set -e

echo "🗑️  Cue Bear Bridge Uninstaller Package Builder"
echo "=============================================="

# Configuration
INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="$INSTALLER_DIR/dist"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Create directories
mkdir -p "$DIST_DIR"

# Create temporary directory structure
TEMP_DIR=$(mktemp -d)
print_status "Using temp directory: $TEMP_DIR"

# Create package structure
PACKAGE_ROOT="$TEMP_DIR/package_root"
mkdir -p "$PACKAGE_ROOT/Applications"
mkdir -p "$PACKAGE_ROOT/usr/local/bin"

# Create uninstaller app bundle
print_status "Creating uninstaller app bundle..."
UNINSTALLER_APP="$PACKAGE_ROOT/Applications/CueBearBridge Uninstaller.app"
mkdir -p "$UNINSTALLER_APP/Contents/MacOS"
mkdir -p "$UNINSTALLER_APP/Contents/Resources"

# Create Info.plist for uninstaller app
cat > "$UNINSTALLER_APP/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>uninstall</string>
    <key>CFBundleIdentifier</key>
    <string>com.cuebear.bridge.uninstaller</string>
    <key>CFBundleName</key>
    <string>CueBearBridge Uninstaller</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Create uninstaller executable
cat > "$UNINSTALLER_APP/Contents/MacOS/uninstall" << 'EOF'
#!/bin/bash

# Cue Bear Bridge Uninstaller App
# This is a wrapper that runs the actual uninstaller script

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"

# Run the actual uninstaller
exec "$APP_DIR/usr/local/bin/cuebearbridge-uninstall"
EOF

chmod +x "$UNINSTALLER_APP/Contents/MacOS/uninstall"

# Copy the uninstaller script to usr/local/bin
print_status "Copying uninstaller script..."
cp "uninstaller/uninstall.sh" "$PACKAGE_ROOT/usr/local/bin/cuebearbridge-uninstall"
chmod +x "$PACKAGE_ROOT/usr/local/bin/cuebearbridge-uninstall"

# Create postinstall script
print_status "Creating postinstall script..."
mkdir -p "$PACKAGE_ROOT/scripts"
cat > "$PACKAGE_ROOT/scripts/postinstall" << 'EOF'
#!/bin/bash

# Post-install script for Cue Bear Bridge Uninstaller
echo "🗑️  Cue Bear Bridge Uninstaller Installation"
echo "==========================================="

# Set proper permissions
echo "🔐 Setting permissions..."
chmod -R 755 "/Applications/CueBearBridge Uninstaller.app"
chmod 755 "/usr/local/bin/cuebearbridge-uninstall"

# Register with Launch Services
echo "🔗 Registering with Launch Services..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/CueBearBridge Uninstaller.app"

# Create desktop shortcut (optional)
echo "🖥️ Creating desktop shortcut..."
ln -sf "/Applications/CueBearBridge Uninstaller.app" "$HOME/Desktop/CueBearBridge Uninstaller" 2>/dev/null || true

echo "✅ Cue Bear Bridge Uninstaller installation complete!"
echo ""
echo "🎉 Uninstaller Summary:"
echo "   • Uninstaller app: /Applications/CueBearBridge Uninstaller.app"
echo "   • Uninstaller script: /usr/local/bin/cuebearbridge-uninstall"
echo "   • Desktop shortcut: Created for easy access"
echo ""
echo "🚀 You can now use the uninstaller to safely remove Cue Bear Bridge!"
EOF

chmod +x "$PACKAGE_ROOT/scripts/postinstall"

# Create preinstall script
cat > "$PACKAGE_ROOT/scripts/preinstall" << 'EOF'
#!/bin/bash

# Pre-install script for Cue Bear Bridge Uninstaller
echo "🔍 Cue Bear Bridge Uninstaller Pre-Installation Check"
echo "====================================================="

# Check if Cue Bear Bridge is installed
if [ ! -d "/Applications/CueBearBridge.app" ]; then
    echo "⚠️  Cue Bear Bridge is not installed"
    echo "   This uninstaller is only useful if Cue Bear Bridge is installed"
    echo "   You can still install it, but it won't have anything to uninstall"
fi

# Check if uninstaller is already installed
if [ -d "/Applications/CueBearBridge Uninstaller.app" ]; then
    echo "⚠️  Cue Bear Bridge Uninstaller is already installed"
    echo "   This will upgrade the existing uninstaller"
fi

echo "✅ Pre-installation check complete"
echo "🚀 Ready to install Cue Bear Bridge Uninstaller"
EOF

chmod +x "$PACKAGE_ROOT/scripts/preinstall"

# Create distribution file for user-level installation
print_status "Creating distribution file..."
cat > "$TEMP_DIR/distribution.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="1">
    <title>Cue Bear Bridge Uninstaller</title>
    <organization>com.cuebear</organization>
    <domains enable_localSystem="false" enable_anywhere="true"/>
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
            <line choice="com.cuebear.bridge.uninstaller"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="com.cuebear.bridge.uninstaller" visible="false">
        <pkg-ref id="com.cuebear.bridge.uninstaller"/>
    </choice>
    <pkg-ref id="com.cuebear.bridge.uninstaller" version="1.0" onConclusion="none">#CueBearBridge-Uninstaller.pkg</pkg-ref>
</installer-gui-script>
EOF

# Build the package
print_status "Building uninstaller package..."
pkgbuild \
    --root "$PACKAGE_ROOT" \
    --identifier "com.cuebear.bridge.uninstaller" \
    --version "1.0" \
    --install-location "/" \
    --scripts "$PACKAGE_ROOT/scripts" \
    "$TEMP_DIR/CueBearBridge-Uninstaller.pkg"

# Build the distribution package
print_status "Building distribution package..."
productbuild \
    --distribution "$TEMP_DIR/distribution.xml" \
    --package-path "$TEMP_DIR" \
    "$DIST_DIR/CueBearBridge-Uninstaller.pkg"

# Clean up
rm -rf "$TEMP_DIR"

print_success "Uninstaller package created: $DIST_DIR/CueBearBridge-Uninstaller.pkg"
echo ""
echo "🎉 Safe uninstaller ready!"
echo "   Users can double-click to install the uninstaller"
echo "   Then use the uninstaller app to safely remove Cue Bear Bridge"
echo "   Only removes Cue Bear Bridge files, preserves system integrity"
echo ""
echo "📦 Package size: $(ls -lh "$DIST_DIR/CueBearBridge-Uninstaller.pkg" | awk '{print $5}')"

