#!/bin/bash

# ============================================================================
# CueBear Bridge Package Builder
# ============================================================================
# Builds CueBearBridge app from Xcode
# Bundles all required dylibs and helper binaries
# Signs app with Developer ID
# Creates installer package (.pkg)
# ============================================================================

set -e  # Exit on error
set -u  # Exit on undefined variable

# Prevent AppleDouble files in package (must be set at script start)
export COPYFILE_DISABLE=1

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(dirname "$INSTALLER_DIR")"

BUILD_DIR="$INSTALLER_DIR/build"
DIST_DIR="$INSTALLER_DIR/dist"
DERIVED_DATA="$BUILD_DIR/DerivedData"

APP_NAME="CueBearBridge"
BUNDLE_ID="com.cuebear.bridge.clean"
VERSION="1.0.0"

XCODE_PROJECT="$PROJECT_DIR/CueBearBridge.xcodeproj"
XCODE_SCHEME="CueBearBridge"

SIGNING_IDENTITY_APP="${1:-}"      # Developer ID Application
SIGNING_IDENTITY_INSTALLER="${2:-}"  # Developer ID Installer

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# ============================================================================
# Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_step() {
    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}$1${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# ============================================================================
# Validation
# ============================================================================

log_step "Step 0: Validation"

# Check Xcode project
if [ ! -d "$XCODE_PROJECT" ]; then
    log_error "Xcode project not found: $XCODE_PROJECT"
    exit 1
fi
log_success "Found Xcode project"

# Check for xcodebuild
if ! command -v xcodebuild &> /dev/null; then
    log_error "xcodebuild not found. Please install Xcode command line tools."
    exit 1
fi
log_success "xcodebuild available"

# Auto-detect signing identities if not provided
if [ -z "$SIGNING_IDENTITY_APP" ]; then
    log_info "Auto-detecting Developer ID Application certificate..."
    SIGNING_IDENTITY_APP=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed -E 's/.*"(.*)"/\1/')

    if [ -z "$SIGNING_IDENTITY_APP" ]; then
        log_error "No Developer ID Application certificate found"
        exit 1
    fi
    log_success "Found: $SIGNING_IDENTITY_APP"
fi

if [ -z "$SIGNING_IDENTITY_INSTALLER" ]; then
    log_info "Auto-detecting Developer ID Installer certificate..."
    # Note: Use -p basic (not codesigning) for installer certificates
    # Installer certs use OID 1.2.840.113635.100.4.13 (Package Signing)
    # which is not included in the codesigning policy
    SIGNING_IDENTITY_INSTALLER=$(security find-identity -v -p basic | grep "Developer ID Installer" | head -1 | sed -E 's/.*"(.*)"/\1/')

    if [ -z "$SIGNING_IDENTITY_INSTALLER" ]; then
        log_error "No Developer ID Installer certificate found"
        exit 1
    fi
    log_success "Found: $SIGNING_IDENTITY_INSTALLER"
fi

log_info "Configuration:"
log_info "  Project: $XCODE_PROJECT"
log_info "  Scheme: $XCODE_SCHEME"
log_info "  Bundle ID: $BUNDLE_ID"
log_info "  Version: $VERSION"
log_info "  App Signing: $SIGNING_IDENTITY_APP"
log_info "  Installer Signing: $SIGNING_IDENTITY_INSTALLER"

# ============================================================================
# Step 1: Clean Build Directories
# ============================================================================

log_step "Step 1: Cleaning build directories"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$DIST_DIR"

log_success "Build directories cleaned"

# ============================================================================
# Step 2: Build App with Xcode
# ============================================================================

log_step "Step 2: Building app with Xcode"

log_info "Running xcodebuild (this may take a few minutes)..."

xcodebuild \
    -project "$XCODE_PROJECT" \
    -scheme "$XCODE_SCHEME" \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    clean build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

# Find built app
BUILT_APP=$(find "$DERIVED_DATA" -name "${APP_NAME}.app" -type d | head -1)

if [ -z "$BUILT_APP" ] || [ ! -d "$BUILT_APP" ]; then
    log_error "Built app not found in DerivedData"
    exit 1
fi

log_success "App built successfully: $BUILT_APP"

# Copy to build directory
APP_BUNDLE="$BUILD_DIR/${APP_NAME}.app"
cp -R "$BUILT_APP" "$APP_BUNDLE"

log_success "App copied to: $APP_BUNDLE"

# ============================================================================
# Step 3: Bundle Required Dylibs
# ============================================================================

log_step "Step 3: Bundling required dylibs"

FRAMEWORKS_DIR="$APP_BUNDLE/Contents/Frameworks"
mkdir -p "$FRAMEWORKS_DIR"

SOURCE_FRAMEWORKS="$PROJECT_DIR/Resources/Frameworks"

if [ ! -d "$SOURCE_FRAMEWORKS" ]; then
    log_error "Source frameworks directory not found: $SOURCE_FRAMEWORKS"
    exit 1
fi

log_info "Copying dylibs from: $SOURCE_FRAMEWORKS"

DYLIBS=(
    "libxml2.2.dylib"
    "libusbmuxd.4.dylib"
    "libicudata.77.dylib"
    "libicuuc.77.dylib"
    "libimobiledevice-glue.1.dylib"
    "libplist.3.dylib"
)

for dylib in "${DYLIBS[@]}"; do
    SOURCE="$SOURCE_FRAMEWORKS/$dylib"
    if [ -f "$SOURCE" ]; then
        log_info "  Copying $dylib..."
        cp "$SOURCE" "$FRAMEWORKS_DIR/"
        log_success "  ✓ $dylib copied"
    else
        log_warning "  Dylib not found: $dylib (skipping)"
    fi
done

log_success "Dylibs bundled"

# ============================================================================
# Step 4: Bundle Helper Binaries
# ============================================================================

log_step "Step 4: Bundling helper binaries"

HELPERS_DIR="$APP_BUNDLE/Contents/Resources/Helpers"
mkdir -p "$HELPERS_DIR"

SOURCE_HELPERS="$PROJECT_DIR/Resources/Helpers"

if [ ! -d "$SOURCE_HELPERS" ]; then
    log_error "Source helpers directory not found: $SOURCE_HELPERS"
    exit 1
fi

log_info "Copying helpers from: $SOURCE_HELPERS"

for helper in "$SOURCE_HELPERS"/*; do
    if [ -f "$helper" ]; then
        HELPER_NAME=$(basename "$helper")
        log_info "  Copying $HELPER_NAME..."
        cp "$helper" "$HELPERS_DIR/"
        chmod +x "$HELPERS_DIR/$HELPER_NAME"
        log_success "  ✓ $HELPER_NAME copied and made executable"
    fi
done

log_success "Helper binaries bundled"

# ============================================================================
# Step 5: Sign App Bundle
# ============================================================================

log_step "Step 5: Signing app bundle"

log_info "Running codesign script..."

"$SCRIPT_DIR/codesign_app.sh" "$APP_BUNDLE" "$SIGNING_IDENTITY_APP"

log_success "App bundle signed"

# ============================================================================
# Step 6: Create Package Root
# ============================================================================

log_step "Step 6: Creating package root"

# Create package root in /tmp to avoid Dropbox issues
TEMP_PACKAGE_ROOT="/tmp/cuebear_pkg_root_$$"
mkdir -p "$TEMP_PACKAGE_ROOT/Applications"

log_info "Creating package root in /tmp (avoiding Dropbox AppleDouble issues)..."
log_info "Temp location: $TEMP_PACKAGE_ROOT"

log_info "Creating intermediate clean copy in /tmp (avoiding Dropbox)..."
# CRITICAL: Copy to /tmp FIRST to escape Dropbox's extended attribute management
TEMP_APP="/tmp/cuebear_clean_app_$$"
cp -R "$APP_BUNDLE" "$TEMP_APP"

log_info "Stripping ALL extended attributes from temp copy..."
# Now strip from the /tmp copy (outside Dropbox)
xattr -cr "$TEMP_APP"

log_info "Copying clean app bundle to package root..."
# Copy the cleaned app to package root
cp -R "$TEMP_APP" "$TEMP_PACKAGE_ROOT/Applications/$(basename "$APP_BUNDLE")"

log_info "Cleaning up intermediate copy..."
rm -rf "$TEMP_APP"

# Double-check: Remove any remaining extended attributes
xattr -cr "$TEMP_PACKAGE_ROOT"

# Remove any AppleDouble files (should be none at this point)
find "$TEMP_PACKAGE_ROOT" -name '._*' -type f -delete 2>/dev/null || true
log_success "Clean, metadata-free copy completed"

# Verify no AppleDouble files remain
APPLEDOUBLE_COUNT=$(find "$TEMP_PACKAGE_ROOT" -name '._*' -type f | wc -l)
if [ "$APPLEDOUBLE_COUNT" -gt 0 ]; then
    log_error "Found $APPLEDOUBLE_COUNT AppleDouble files in package root!"
    exit 1
fi
log_success "Verified: No AppleDouble files in package root"

log_success "Package root created"

# Set PACKAGE_ROOT to temp location
PACKAGE_ROOT="$TEMP_PACKAGE_ROOT"

# ============================================================================
# Step 7: Build Package
# ============================================================================

log_step "Step 7: Building installer package"

# Build in /tmp to avoid Dropbox AppleDouble file issues
TEMP_BUILD_DIR="/tmp/cuebear_pkg_build_$$"
mkdir -p "$TEMP_BUILD_DIR"

COMPONENT_PKG="$TEMP_BUILD_DIR/${APP_NAME}-component.pkg"
FINAL_COMPONENT_PKG="$BUILD_DIR/${APP_NAME}-component.pkg"
PKG_PATH="$DIST_DIR/${APP_NAME}-Installer.pkg"

log_info "Creating component package in temp directory (avoiding Dropbox issues)..."
log_info "Temp location: $COMPONENT_PKG"
log_info "COPYFILE_DISABLE is set to prevent AppleDouble files"

pkgbuild \
    --root "$PACKAGE_ROOT" \
    --identifier "$BUNDLE_ID" \
    --version "$VERSION" \
    --install-location "/" \
    --filter '\.svn$' \
    --filter 'CVS$' \
    --filter '\.DS_Store$' \
    --filter '\.\_' \
    --filter '\.__' \
    --sign "$SIGNING_IDENTITY_INSTALLER" \
    "$COMPONENT_PKG"

if [ ! -f "$COMPONENT_PKG" ]; then
    log_error "Component package creation failed"
    rm -rf "$TEMP_BUILD_DIR"
    exit 1
fi

log_success "Component package created in temp directory"

# Copy component package to build directory for reference
cp "$COMPONENT_PKG" "$FINAL_COMPONENT_PKG"
log_info "Component package copied to: $FINAL_COMPONENT_PKG"

log_info "Creating distribution package: $PKG_PATH"

TEMP_DIST_PKG="$TEMP_BUILD_DIR/${APP_NAME}-Installer.pkg"

productbuild \
    --package "$COMPONENT_PKG" \
    --sign "$SIGNING_IDENTITY_INSTALLER" \
    "$TEMP_DIST_PKG"

if [ ! -f "$TEMP_DIST_PKG" ]; then
    log_error "Distribution package creation failed"
    rm -rf "$TEMP_BUILD_DIR"
    exit 1
fi

log_success "Distribution package created in temp directory"

# Copy final package to dist directory and remove Dropbox attributes
cp "$TEMP_DIST_PKG" "$PKG_PATH"
xattr -cr "$PKG_PATH"

# Clean up temp directories
rm -rf "$TEMP_BUILD_DIR"
rm -rf "$TEMP_PACKAGE_ROOT"

log_success "Distribution package copied to: $PKG_PATH"
log_success "Dropbox attributes removed from package"
log_success "Temporary build directories cleaned up"

# ============================================================================
# Step 8: Verify Package
# ============================================================================

log_step "Step 8: Verifying package"

log_info "Checking package signature..."
pkgutil --check-signature "$PKG_PATH"

log_info "Package info:"
pkgutil --payload-files "$PKG_PATH" | head -20

log_success "Package verified"

# ============================================================================
# Step 9: Generate Build Report
# ============================================================================

log_step "Step 9: Generating build report"

REPORT_FILE="$DIST_DIR/build_report.txt"

cat > "$REPORT_FILE" << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CueBear Bridge Installer Build Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Build Date: $(date)
Builder: $(whoami)
Machine: $(hostname)

Project Information:
  App Name: $APP_NAME
  Bundle ID: $BUNDLE_ID
  Version: $VERSION
  Xcode Project: $XCODE_PROJECT
  Scheme: $XCODE_SCHEME

Signing:
  App Certificate: $SIGNING_IDENTITY_APP
  Installer Certificate: $SIGNING_IDENTITY_INSTALLER

Output Files:
  Package: $PKG_PATH
  App Bundle: $APP_BUNDLE
  Build Directory: $BUILD_DIR

Bundled Components:
  ✅ App binary
  ✅ Dylibs (6 files):
$(for dylib in "${DYLIBS[@]}"; do echo "      - $dylib"; done)
  ✅ Helper binaries:
$(for helper in "$HELPERS_DIR"/*; do [ -f "$helper" ] && echo "      - $(basename "$helper")"; done)

Package Signature:
$(pkgutil --check-signature "$PKG_PATH" 2>&1)

Next Steps:
  1. Test installation: sudo installer -pkg "$PKG_PATH" -target /
  2. Notarize package: ./scripts/notarize_pkg.sh "$PKG_PATH"
  3. Distribute notarized package

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

cat "$REPORT_FILE"

log_success "Build report saved: $REPORT_FILE"

# ============================================================================
# Summary
# ============================================================================

echo ""
log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_success "Package Build Complete!"
log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_success "✅ App built and bundled with dependencies"
log_success "✅ All components code signed"
log_success "✅ Installer package created and signed"
log_success "✅ Package verified"
echo ""
log_info "📦 Package: $PKG_PATH"
log_info "📄 Report: $REPORT_FILE"
echo ""
log_warning "⚠️  Next step: Notarize the package with Apple"
log_info "Run: ./scripts/notarize_pkg.sh \"$PKG_PATH\""
echo ""

exit 0
