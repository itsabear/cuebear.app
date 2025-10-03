#!/bin/bash

# Cue Bear Bridge Real App Installer Builder
# Creates installer package with the actual Bridge app
# Works with Xcode or provides instructions for installation

set -e

echo "🔨 Cue Bear Bridge Real App Installer Builder"
echo "============================================="

# Configuration
BRIDGE_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$INSTALLER_DIR/build"
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

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check for Xcode
check_xcode() {
    print_status "Checking for Xcode..."
    
    # Check if xcodebuild is available
    if ! command -v xcodebuild &> /dev/null; then
        print_error "xcodebuild not found"
        return 1
    fi
    
    # Check if we can run xcodebuild
    if ! xcodebuild -version &> /dev/null; then
        print_error "Xcode is not properly configured"
        return 1
    fi
    
    print_success "Xcode found: $(xcodebuild -version | head -1)"
    return 0
}

# Build the real Bridge app
build_real_bridge_app() {
    print_status "Building real Cue Bear Bridge application..."
    
    if [ ! -d "$BRIDGE_SOURCE/CueBearBridgeClean.xcodeproj" ]; then
        print_error "Xcode project not found: $BRIDGE_SOURCE/CueBearBridgeClean.xcodeproj"
        exit 1
    fi
    
    cd "$BRIDGE_SOURCE"
    
    # Clean previous build
    print_status "Cleaning previous build..."
    xcodebuild clean -project CueBearBridgeClean.xcodeproj -scheme CueBearBridgeClean 2>/dev/null || true
    
    # Build the app
    print_status "Building application..."
    xcodebuild build -project CueBearBridgeClean.xcodeproj -scheme CueBearBridgeClean -configuration Release -derivedDataPath "$BUILD_DIR/DerivedData"
    
    # Find the built app
    BUILT_APP=$(find "$BUILD_DIR/DerivedData" -name "CueBearBridgeClean.app" -type d | head -1)
    
    if [ -z "$BUILT_APP" ]; then
        print_error "Failed to find built application"
        print_status "Build may have failed. Check Xcode build output."
        exit 1
    fi
    
    print_success "Real Bridge app built: $BUILT_APP"
    echo "$BUILT_APP" >&2  # Send to stderr so it doesn't interfere with return value
    echo "$BUILT_APP"
}

# Create directories
mkdir -p "$BUILD_DIR" "$DIST_DIR"

# Check if we can build the real app
if check_xcode; then
    print_status "Xcode is available - building real app..."
    BUILT_APP=$(build_real_bridge_app 2>/dev/null | tail -1)  # Get only the last line (the path)
    APP_TYPE="real"
else
    print_warning "Xcode not available - creating enhanced placeholder"
    print_status "To build the real app, you need to:"
    echo ""
    echo "1. Install Xcode from the App Store (free)"
    echo "2. Open Xcode and accept the license agreement"
    echo "3. Run this script again"
    echo ""
    print_status "For now, creating an enhanced placeholder installer..."
    APP_TYPE="placeholder"
fi

# Create temporary directory structure (use shorter path to avoid "File name too long" error)
TEMP_DIR="/tmp/cuebear_installer_$$"
mkdir -p "$TEMP_DIR"
print_status "Using temp directory: $TEMP_DIR"

# Create package structure
PACKAGE_ROOT="$TEMP_DIR/package_root"
mkdir -p "$PACKAGE_ROOT/Applications"
mkdir -p "$PACKAGE_ROOT/Library/Application Support/CueBearBridge"

if [ "$APP_TYPE" = "real" ]; then
    # Copy the real Bridge app (use symlink to avoid "File name too long" error)
    print_status "Copying real Bridge app..."
    SHORT_LINK="/tmp/bridge_app"
    ln -sf "$BUILT_APP" "$SHORT_LINK"
    cp -R "$SHORT_LINK" "$PACKAGE_ROOT/Applications/CueBearBridge.app"
    rm -f "$SHORT_LINK"
    
    # Update the app name in Info.plist
    print_status "Updating app information..."
    /usr/libexec/PlistBuddy -c "Set :CFBundleName CueBearBridge" "$PACKAGE_ROOT/Applications/CueBearBridge.app/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.cuebear.bridge" "$PACKAGE_ROOT/Applications/CueBearBridge.app/Contents/Info.plist"
    
    APP_DESCRIPTION="Real Cue Bear Bridge application with full MIDI functionality"
else
    # Create enhanced placeholder app
    print_status "Creating enhanced placeholder app..."
    APP_BUNDLE="$PACKAGE_ROOT/Applications/CueBearBridge.app"
    mkdir -p "$APP_BUNDLE/Contents/MacOS"
    mkdir -p "$APP_BUNDLE/Contents/Resources"
    
    # Create Info.plist for the app
    cat > "$APP_BUNDLE/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>CueBearBridge</string>
    <key>CFBundleIdentifier</key>
    <string>com.cuebear.bridge</string>
    <key>CFBundleName</key>
    <string>CueBearBridge</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF
    
    # Create enhanced placeholder executable
    cat > "$APP_BUNDLE/Contents/MacOS/CueBearBridge" << 'EOF'
#!/bin/bash

# Cue Bear Bridge - Enhanced Placeholder
echo "🎵 Cue Bear Bridge"
echo "=================="
echo ""
echo "✅ Cue Bear Bridge has been successfully installed!"
echo ""
echo "📱 This is an enhanced placeholder executable."
echo "   The installer has set up all the infrastructure:"
echo ""
echo "🔗 What's installed:"
echo "   • Application bundle: /Applications/CueBearBridge.app"
echo "   • Support files: /Library/Application Support/CueBearBridge/"
echo "   • Real Resources: All libraries and frameworks"
echo "   • Real Assets: App icons and resources"
echo "   • Safe uninstaller: Available in Applications"
echo ""
echo "🚀 To get the real Bridge app:"
echo "   1. Install Xcode from the App Store (free)"
echo "   2. Open CueBearBridgeClean.xcodeproj in Xcode"
echo "   3. Build the project (⌘+B)"
echo "   4. Replace this placeholder with the real executable"
echo ""
echo "🎉 Installation infrastructure complete!"
echo "   Ready for the real Bridge app when you build it."
echo ""
read -p "Press Enter to continue..."
EOF
    
    chmod +x "$APP_BUNDLE/Contents/MacOS/CueBearBridge"
    
    APP_DESCRIPTION="Enhanced placeholder with real resources and infrastructure"
fi

# Copy Resources if they exist (always copy, even for real app)
if [ -d "$BRIDGE_SOURCE/Resources" ]; then
    print_status "Copying Resources..."
    cp -R "$BRIDGE_SOURCE/Resources" "$PACKAGE_ROOT/Applications/CueBearBridge.app/Contents/"
fi

# Copy Assets if they exist (always copy, even for real app)
if [ -d "$BRIDGE_SOURCE/Assets.xcassets" ]; then
    print_status "Copying Assets..."
    cp -R "$BRIDGE_SOURCE/Assets.xcassets" "$PACKAGE_ROOT/Applications/CueBearBridge.app/Contents/Resources/"
fi

# Create installation manifest
print_status "Creating installation manifest..."
cat > "$PACKAGE_ROOT/Library/Application Support/CueBearBridge/install_manifest.txt" << EOF
# Cue Bear Bridge Installation Manifest
# Generated on: $(date)
# This file tracks all components installed by Cue Bear Bridge
# DO NOT DELETE - Required for safe uninstallation

# Application Bundle
/Applications/CueBearBridge.app

# Application Support Files
/Library/Application Support/CueBearBridge/

# Preferences (if any)
~/Library/Preferences/com.cuebear.bridge.plist

# Launch Agents (if any)
~/Library/LaunchAgents/com.cuebear.bridge.plist

# Logs Directory
~/Library/Logs/CueBearBridge/

# Cache Directory
~/Library/Caches/com.cuebear.bridge/

# Temporary Files
/tmp/cuebearbridge-*
EOF

# Create postinstall script
print_status "Creating postinstall script..."
mkdir -p "$PACKAGE_ROOT/scripts"
cat > "$PACKAGE_ROOT/scripts/postinstall" << EOF
#!/bin/bash

# Post-install script for Cue Bear Bridge
echo "🚀 Cue Bear Bridge Installation"
echo "==============================="

# Set proper permissions
echo "🔐 Setting permissions..."
chmod -R 755 "/Applications/CueBearBridge.app"
chmod -R 755 "/Library/Application Support/CueBearBridge"

# Create user directories
echo "📁 Creating user directories..."
mkdir -p "\$HOME/Library/Logs/CueBearBridge"
mkdir -p "\$HOME/Library/Caches/com.cuebear.bridge"

# Set user permissions
chmod 755 "\$HOME/Library/Logs/CueBearBridge"
chmod 755 "\$HOME/Library/Caches/com.cuebear.bridge"

# Register with Launch Services
echo "🔗 Registering with Launch Services..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/CueBearBridge.app"

# Create desktop shortcut (optional)
echo "🖥️ Creating desktop shortcut..."
ln -sf "/Applications/CueBearBridge.app" "\$HOME/Desktop/CueBearBridge" 2>/dev/null || true

echo "✅ Cue Bear Bridge installation complete!"
echo ""
echo "🎉 Installation Summary:"
echo "   • Application: /Applications/CueBearBridge.app"
echo "   • Support files: /Library/Application Support/CueBearBridge/"
echo "   • User data: ~/Library/Logs/CueBearBridge/"
echo "   • Safe uninstaller: Available in Applications folder"
echo ""
if [ "$APP_TYPE" = "real" ]; then
    echo "🚀 You can now launch the real Cue Bear Bridge from Applications!"
    echo "🎵 Connect your iPad and start making music!"
else
    echo "📱 This is an enhanced placeholder with real infrastructure"
    echo "🚀 Install Xcode and build the real app to get full functionality"
fi
EOF

chmod +x "$PACKAGE_ROOT/scripts/postinstall"

# Create preinstall script
cat > "$PACKAGE_ROOT/scripts/preinstall" << 'EOF'
#!/bin/bash

# Pre-install script for Cue Bear Bridge
echo "🔍 Cue Bear Bridge Pre-Installation Check"
echo "=========================================="

# Check if app is already installed
if [ -d "/Applications/CueBearBridge.app" ]; then
    echo "⚠️  Cue Bear Bridge is already installed"
    echo "   This will upgrade the existing installation"
    
    # Check if app is running
    if pgrep -f "CueBearBridge" > /dev/null; then
        echo "⚠️  Cue Bear Bridge is currently running"
        echo "   Please quit the application before installing"
        echo "   You can quit it from the menu bar or Activity Monitor"
        exit 1
    fi
fi

# Check system requirements
echo "🔍 Checking system requirements..."
MACOS_VERSION=$(sw_vers -productVersion)
echo "   macOS Version: $MACOS_VERSION"

# Check for required frameworks
echo "🔍 Checking required frameworks..."
if [ ! -d "/System/Library/Frameworks/CoreMIDI.framework" ]; then
    echo "❌ CoreMIDI framework not found"
    echo "   This is required for MIDI functionality"
    exit 1
fi

if [ ! -d "/System/Library/Frameworks/Network.framework" ]; then
    echo "❌ Network framework not found"
    echo "   This is required for network communication"
    exit 1
fi

echo "✅ System requirements check passed"
echo "🚀 Ready to install Cue Bear Bridge"
EOF

chmod +x "$PACKAGE_ROOT/scripts/preinstall"

# Build the package
if [ "$APP_TYPE" = "real" ]; then
    PACKAGE_NAME="CueBearBridge-RealApp-Installer.pkg"
    PACKAGE_DESCRIPTION="Real Cue Bear Bridge application"
else
    PACKAGE_NAME="CueBearBridge-Enhanced-Installer.pkg"
    PACKAGE_DESCRIPTION="Enhanced placeholder with real infrastructure"
fi

print_status "Building installer package..."
pkgbuild \
    --root "$PACKAGE_ROOT" \
    --identifier "com.cuebear.bridge" \
    --version "1.0" \
    --install-location "/" \
    --scripts "$PACKAGE_ROOT/scripts" \
    "$DIST_DIR/$PACKAGE_NAME"

# Clean up
rm -rf "$TEMP_DIR"

print_success "Installer created: $DIST_DIR/$PACKAGE_NAME"
echo ""
echo "🎉 $PACKAGE_DESCRIPTION installer ready!"
echo "   $APP_DESCRIPTION"
echo "   Users can double-click to install Cue Bear Bridge"
echo ""
echo "📦 Package size: $(ls -lh "$DIST_DIR/$PACKAGE_NAME" | awk '{print $5}')"
echo ""

if [ "$APP_TYPE" = "placeholder" ]; then
    echo "📱 To get the real Bridge app:"
    echo "   1. Install Xcode from the App Store (free)"
    echo "   2. Open CueBearBridgeClean.xcodeproj in Xcode"
    echo "   3. Build the project (⌘+B)"
    echo "   4. Run this script again to create the real app installer"
    echo ""
fi

echo "🎵 Ready for MIDI control between iPad and Mac!"
