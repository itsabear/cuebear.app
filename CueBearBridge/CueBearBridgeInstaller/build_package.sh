#!/bin/bash

# Cue Bear Bridge Complete Package Builder
# Creates installer, uninstaller, and distribution package

set -e

echo "🏗️  Cue Bear Bridge Complete Package Builder"
echo "============================================="

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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
        print_error "Xcode command line tools not found"
        print_status "Please install Xcode or Xcode command line tools"
        exit 1
    fi
    
    # Check if pkgbuild is available
    if ! command -v pkgbuild &> /dev/null; then
        print_error "pkgbuild not found"
        print_status "This is part of Xcode command line tools"
        exit 1
    fi
    
    # Check if productbuild is available
    if ! command -v productbuild &> /dev/null; then
        print_error "productbuild not found"
        print_status "This is part of Xcode command line tools"
        exit 1
    fi
    
    print_success "All prerequisites found"
}

# Build the Bridge app
build_bridge_app() {
    print_status "Building Cue Bear Bridge application..."
    
    if [ ! -d "$BRIDGE_SOURCE" ]; then
        print_error "Bridge source directory not found: $BRIDGE_SOURCE"
        exit 1
    fi
    
    cd "$BRIDGE_SOURCE"
    
    # Clean previous build
    print_status "Cleaning previous build..."
    xcodebuild clean -project CueBearBridgeClean.xcodeproj -scheme CueBearBridgeClean 2>/dev/null || true
    
    # Build the app
    print_status "Building application..."
    xcodebuild build -project CueBearBridgeClean.xcodeproj -scheme CueBearBridgeClean -configuration Release -derivedDataPath "$BUILD_DIR/DerivedData"
    
    # Copy built app to build directory
    if [ -d "$BUILD_DIR/DerivedData/Build/Products/Release/CueBearBridgeClean.app" ]; then
        print_status "Copying built application..."
        cp -R "$BUILD_DIR/DerivedData/Build/Products/Release/CueBearBridgeClean.app" "$BUILD_DIR/CueBearBridge.app"
        print_success "Application built successfully"
    else
        print_error "Application build failed"
        print_status "Check Xcode build output for errors"
        exit 1
    fi
}

# Create installer package
create_installer() {
    print_status "Creating installer package..."
    
    # Make scripts executable
    chmod +x "$INSTALLER_DIR/scripts/build_installer.sh"
    chmod +x "$INSTALLER_DIR/scripts/install_manifest.sh"
    
    # Run installer script
    cd "$INSTALLER_DIR/scripts"
    ./build_installer.sh
    
    # Move installer to dist directory
    mkdir -p "$DIST_DIR"
    if [ -f "CueBearBridge-Installer.pkg" ]; then
        mv "CueBearBridge-Installer.pkg" "$DIST_DIR/"
        print_success "Installer package created"
    else
        print_error "Installer package creation failed"
        exit 1
    fi
}

# Create uninstaller package
create_uninstaller() {
    print_status "Creating uninstaller package..."
    
    # Make uninstaller executable
    chmod +x "$INSTALLER_DIR/uninstaller/uninstall.sh"
    
    # Create uninstaller package
    cd "$INSTALLER_DIR"
    
    # Create package structure for uninstaller
    UNINSTALLER_ROOT="$BUILD_DIR/uninstaller_root"
    mkdir -p "$UNINSTALLER_ROOT/Applications"
    mkdir -p "$UNINSTALLER_ROOT/usr/local/bin"
    
    # Copy uninstaller script
    cp "uninstaller/uninstall.sh" "$UNINSTALLER_ROOT/usr/local/bin/cuebearbridge-uninstall"
    chmod +x "$UNINSTALLER_ROOT/usr/local/bin/cuebearbridge-uninstall"
    
    # Create uninstaller app bundle
    cat > "$UNINSTALLER_ROOT/Applications/CueBearBridge Uninstaller.app/Contents/Info.plist" << 'EOF'
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
</dict>
</plist>
EOF
    
    mkdir -p "$UNINSTALLER_ROOT/Applications/CueBearBridge Uninstaller.app/Contents/MacOS"
    cat > "$UNINSTALLER_ROOT/Applications/CueBearBridge Uninstaller.app/Contents/MacOS/uninstall" << 'EOF'
#!/bin/bash
# Cue Bear Bridge Uninstaller App
# This is a wrapper that runs the actual uninstaller script

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"

# Run the actual uninstaller
exec "$APP_DIR/usr/local/bin/cuebearbridge-uninstall"
EOF
    
    chmod +x "$UNINSTALLER_ROOT/Applications/CueBearBridge Uninstaller.app/Contents/MacOS/uninstall"
    
    # Build uninstaller package
    pkgbuild \
        --root "$UNINSTALLER_ROOT" \
        --identifier "com.cuebear.bridge.uninstaller" \
        --version "1.0" \
        --install-location "/" \
        "CueBearBridge-Uninstaller.pkg"
    
    # Move to dist directory
    mv "CueBearBridge-Uninstaller.pkg" "$DIST_DIR/"
    print_success "Uninstaller package created"
}

# Create distribution DMG
create_dmg() {
    print_status "Creating distribution DMG..."
    
    cd "$DIST_DIR"
    
    # Create DMG contents
    DMG_CONTENTS="$BUILD_DIR/dmg_contents"
    mkdir -p "$DMG_CONTENTS"
    
    # Copy installer and uninstaller
    cp "CueBearBridge-Installer.pkg" "$DMG_CONTENTS/"
    cp "CueBearBridge-Uninstaller.pkg" "$DMG_CONTENTS/"
    
    # Create README
    cat > "$DMG_CONTENTS/README.txt" << 'EOF'
Cue Bear Bridge Installation Package
====================================

This package contains:

1. CueBearBridge-Installer.pkg
   - Main installer for Cue Bear Bridge
   - Double-click to install
   - Includes all required components

2. CueBearBridge-Uninstaller.pkg
   - Safe uninstaller for Cue Bear Bridge
   - Only removes Cue Bear Bridge files
   - Preserves system libraries and other apps

Installation Instructions:
1. Double-click CueBearBridge-Installer.pkg
2. Follow the installation wizard
3. Launch Cue Bear Bridge from Applications

Uninstallation Instructions:
1. Double-click CueBearBridge-Uninstaller.pkg
2. Follow the uninstallation wizard
3. All Cue Bear Bridge files will be safely removed

System Requirements:
- macOS 13.0 or later
- CoreMIDI framework
- Network framework

For support, visit: https://cuebear.app/support
EOF
    
    # Create DMG
    hdiutil create -srcfolder "$DMG_CONTENTS" -volname "Cue Bear Bridge" -fs HFS+ -fsargs "-c a=16384,c=64" -format UDZO "CueBearBridge-1.0.dmg"
    
    print_success "Distribution DMG created: CueBearBridge-1.0.dmg"
}

# Create build summary
create_summary() {
    print_status "Creating build summary..."
    
    cat > "$DIST_DIR/BUILD_SUMMARY.txt" << EOF
Cue Bear Bridge Package Build Summary
=====================================

Build Date: $(date)
Build Version: 1.0
Build Machine: $(hostname)
Build User: $(whoami)

Generated Packages:
- CueBearBridge-Installer.pkg (Main installer)
- CueBearBridge-Uninstaller.pkg (Safe uninstaller)
- CueBearBridge-1.0.dmg (Distribution package)

Package Sizes:
$(ls -lh *.pkg *.dmg 2>/dev/null | awk '{print "  " $5 " " $9}')

Installation Features:
✅ Professional installer with safety checks
✅ Safe uninstaller that preserves system files
✅ Installation manifest for tracking
✅ User-friendly installation wizard
✅ Desktop shortcut creation
✅ Launch Services registration
✅ Proper permissions and ownership

Safety Features:
✅ Only removes Cue Bear Bridge files
✅ Preserves system libraries and frameworks
✅ Preserves other applications and user data
✅ Installation manifest tracking
✅ Pre-installation system checks
✅ Running application detection

Distribution Ready:
✅ Code signing compatible
✅ Universal binary support
✅ macOS version compatibility
✅ Professional user experience

Next Steps:
1. Test installer on clean macOS system
2. Test uninstaller thoroughly
3. Code sign packages for distribution
4. Upload to distribution platform

Build completed successfully!
EOF
    
    print_success "Build summary created"
}

# Main execution
main() {
    print_status "Starting Cue Bear Bridge package build..."
    
    # Create build directories
    mkdir -p "$BUILD_DIR" "$DIST_DIR"
    
    # Run build steps
    check_prerequisites
    build_bridge_app
    create_installer
    create_uninstaller
    create_dmg
    create_summary
    
    # Final summary
    echo ""
    echo "🎉 Build Complete!"
    echo "=================="
    print_success "All packages created successfully"
    print_status "Distribution directory: $DIST_DIR"
    print_status "Ready for testing and distribution"
    
    echo ""
    print_status "Generated files:"
    ls -la "$DIST_DIR"
    
    echo ""
    print_status "Next steps:"
    echo "  1. Test installer on clean macOS system"
    echo "  2. Test uninstaller thoroughly"
    echo "  3. Code sign packages for distribution"
    echo "  4. Upload to distribution platform"
}

# Run main function
main "$@"
