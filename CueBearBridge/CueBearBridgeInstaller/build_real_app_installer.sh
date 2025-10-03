#!/bin/bash

# Cue Bear Bridge Real App Installer Builder
# Creates installer package with the actual Bridge app built from Xcode

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

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if Xcode is installed
    if ! command -v xcodebuild &> /dev/null; then
        print_error "xcodebuild not found"
        print_status "Please install Xcode from the App Store"
        print_status "Command line tools are not sufficient for building apps"
        exit 1
    fi
    
    # Check if we can access Xcode
    if ! xcodebuild -version &> /dev/null; then
        print_error "Xcode is not properly configured"
        print_status "Please open Xcode and accept the license agreement"
        exit 1
    fi
    
    print_success "Xcode found: $(xcodebuild -version | head -1)"
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
    echo "$BUILT_APP"
}

# Create directories
mkdir -p "$BUILD_DIR" "$DIST_DIR"

# Check prerequisites
check_prerequisites

# Build the real app
BUILT_APP=$(build_real_bridge_app)

# Create temporary directory structure
TEMP_DIR=$(mktemp -d)
print_status "Using temp directory: $TEMP_DIR"

# Create package structure
PACKAGE_ROOT="$TEMP_DIR/package_root"
mkdir -p "$PACKAGE_ROOT/Applications"
mkdir -p "$PACKAGE_ROOT/Library/Application Support/CueBearBridge"

# Copy the real Bridge app
print_status "Copying real Bridge app..."
cp -R "$BUILT_APP" "$PACKAGE_ROOT/Applications/CueBearBridge.app"

# Update the app name in Info.plist
print_status "Updating app information..."
/usr/libexec/PlistBuddy -c "Set :CFBundleName CueBearBridge" "$PACKAGE_ROOT/Applications/CueBearBridge.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.cuebear.bridge" "$PACKAGE_ROOT/Applications/CueBearBridge.app/Contents/Info.plist"

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
cat > "$PACKAGE_ROOT/scripts/postinstall" << 'EOF'
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
mkdir -p "$HOME/Library/Logs/CueBearBridge"
mkdir -p "$HOME/Library/Caches/com.cuebear.bridge"

# Set user permissions
chmod 755 "$HOME/Library/Logs/CueBearBridge"
chmod 755 "$HOME/Library/Caches/com.cuebear.bridge"

# Register with Launch Services
echo "🔗 Registering with Launch Services..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/CueBearBridge.app"

# Create desktop shortcut (optional)
echo "🖥️ Creating desktop shortcut..."
ln -sf "/Applications/CueBearBridge.app" "$HOME/Desktop/CueBearBridge" 2>/dev/null || true

echo "✅ Cue Bear Bridge installation complete!"
echo ""
echo "🎉 Installation Summary:"
echo "   • Real Bridge app: /Applications/CueBearBridge.app"
echo "   • Support files: /Library/Application Support/CueBearBridge/"
echo "   • User data: ~/Library/Logs/CueBearBridge/"
echo "   • Safe uninstaller: Available in Applications folder"
echo ""
echo "🚀 You can now launch the real Cue Bear Bridge from Applications!"
echo "🎵 Connect your iPad and start making music!"
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
echo "🚀 Ready to install the real Cue Bear Bridge"
EOF

chmod +x "$PACKAGE_ROOT/scripts/preinstall"

# Build the package
print_status "Building real app installer package..."
pkgbuild \
    --root "$PACKAGE_ROOT" \
    --identifier "com.cuebear.bridge" \
    --version "1.0" \
    --install-location "/" \
    --scripts "$PACKAGE_ROOT/scripts" \
    "$DIST_DIR/CueBearBridge-RealApp-Installer.pkg"

# Clean up
rm -rf "$TEMP_DIR"

print_success "Real app installer created: $DIST_DIR/CueBearBridge-RealApp-Installer.pkg"
echo ""
echo "🎉 Real Bridge app installer ready!"
echo "   This installer contains the actual Cue Bear Bridge application"
echo "   Built from Xcode with all real functionality"
echo "   Users can double-click to install the complete Bridge app"
echo ""
echo "📦 Package size: $(ls -lh "$DIST_DIR/CueBearBridge-RealApp-Installer.pkg" | awk '{print $5}')"
echo ""
echo "🎵 Ready for real MIDI control between iPad and Mac!"

