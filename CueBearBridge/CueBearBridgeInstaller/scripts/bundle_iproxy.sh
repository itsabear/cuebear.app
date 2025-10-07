#!/bin/bash

# ============================================================================
# Bundle iproxy and Dependencies Script
# ============================================================================
# Copies iproxy and all required dylibs into the app bundle
# Fixes all library paths to use @executable_path/../Frameworks/
# Following TouchOSC's approach: no @rpath, only @executable_path
# ============================================================================

set -e  # Exit on error
set -u  # Exit on undefined variable

# ============================================================================
# Configuration
# ============================================================================

APP_BUNDLE="$1"  # Path to CueBearBridge.app

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# ============================================================================
# Validation
# ============================================================================

if [ -z "$APP_BUNDLE" ] || [ ! -d "$APP_BUNDLE" ]; then
    log_error "Usage: $0 <path-to-app-bundle>"
    log_error "Example: $0 build/CueBearBridge.app"
    exit 1
fi

log_info "Starting iproxy bundling process..."
log_info "App Bundle: $APP_BUNDLE"

# Check if iproxy exists
if ! command -v iproxy &> /dev/null; then
    log_error "iproxy not found in PATH"
    log_error "Please install: brew install libusbmuxd"
    exit 1
fi

IPROXY_PATH=$(which iproxy)
log_info "Found iproxy: $IPROXY_PATH"

# ============================================================================
# Step 1: Create Directories
# ============================================================================

log_info "Step 1: Creating bundle directories..."

FRAMEWORKS_DIR="$APP_BUNDLE/Contents/Frameworks"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"

mkdir -p "$FRAMEWORKS_DIR"
mkdir -p "$MACOS_DIR"

log_success "Directories created"

# ============================================================================
# Step 2: Copy iproxy Binary
# ============================================================================

log_info "Step 2: Copying iproxy binary..."

# Remove existing iproxy if present (may be from Xcode build phase)
if [ -f "$MACOS_DIR/iproxy" ]; then
    log_info "  Removing existing iproxy..."
    rm -f "$MACOS_DIR/iproxy"
fi

cp "$IPROXY_PATH" "$MACOS_DIR/iproxy"
chmod +x "$MACOS_DIR/iproxy"

log_success "iproxy binary copied to: $MACOS_DIR/iproxy"

# ============================================================================
# Step 3: Copy Required Dylibs
# ============================================================================

log_info "Step 3: Copying required dylibs..."

# Copy dylibs one by one (using direct paths from otool output)
copy_dylib() {
    local source_path="$1"
    local dylib_name="$2"

    if [ -f "$source_path" ]; then
        log_info "  Copying $dylib_name..."
        cp "$source_path" "$FRAMEWORKS_DIR/$dylib_name"
        chmod 644 "$FRAMEWORKS_DIR/$dylib_name"
        log_success "  ✓ $dylib_name copied"
    else
        log_error "  ✗ Dylib not found: $source_path"
        exit 1
    fi
}

copy_dylib "/opt/homebrew/Cellar/libusbmuxd/2.1.1/lib/libusbmuxd-2.0.7.dylib" "libusbmuxd-2.0.7.dylib"
copy_dylib "/opt/homebrew/opt/libimobiledevice-glue/lib/libimobiledevice-glue-1.0.0.dylib" "libimobiledevice-glue-1.0.0.dylib"
copy_dylib "/opt/homebrew/opt/libplist/lib/libplist-2.0.4.dylib" "libplist-2.0.4.dylib"

log_success "All dylibs copied"

# ============================================================================
# Step 4: Fix iproxy Library Paths
# ============================================================================

log_info "Step 4: Fixing iproxy library paths..."

IPROXY_BINARY="$MACOS_DIR/iproxy"

log_info "  Current iproxy dependencies:"
otool -L "$IPROXY_BINARY" | tail -n +2

# Fix each dependency in iproxy
install_name_tool -change \
    "/opt/homebrew/Cellar/libusbmuxd/2.1.1/lib/libusbmuxd-2.0.7.dylib" \
    "@executable_path/../Frameworks/libusbmuxd-2.0.7.dylib" \
    "$IPROXY_BINARY"
log_info "  ✓ Fixed libusbmuxd-2.0.7.dylib reference"

install_name_tool -change \
    "/opt/homebrew/opt/libimobiledevice-glue/lib/libimobiledevice-glue-1.0.0.dylib" \
    "@executable_path/../Frameworks/libimobiledevice-glue-1.0.0.dylib" \
    "$IPROXY_BINARY"
log_info "  ✓ Fixed libimobiledevice-glue-1.0.0.dylib reference"

install_name_tool -change \
    "/opt/homebrew/opt/libplist/lib/libplist-2.0.4.dylib" \
    "@executable_path/../Frameworks/libplist-2.0.4.dylib" \
    "$IPROXY_BINARY"
log_info "  ✓ Fixed libplist-2.0.4.dylib reference"

log_info "  Updated iproxy dependencies:"
otool -L "$IPROXY_BINARY" | tail -n +2

log_success "iproxy library paths fixed"

# ============================================================================
# Step 5: Fix Dylib Install Names and Inter-Dependencies
# ============================================================================

log_info "Step 5: Fixing dylib install names and inter-dependencies..."

# Fix libusbmuxd-2.0.7.dylib
DYLIB="$FRAMEWORKS_DIR/libusbmuxd-2.0.7.dylib"
log_info "  Processing libusbmuxd-2.0.7.dylib..."

# Set its own install name
install_name_tool -id "@executable_path/../Frameworks/libusbmuxd-2.0.7.dylib" "$DYLIB"
log_info "    ✓ Set install name"

# Fix its dependencies
install_name_tool -change \
    "/opt/homebrew/opt/libusbmuxd/lib/libusbmuxd-2.0.7.dylib" \
    "@executable_path/../Frameworks/libusbmuxd-2.0.7.dylib" \
    "$DYLIB"

install_name_tool -change \
    "/opt/homebrew/opt/libimobiledevice-glue/lib/libimobiledevice-glue-1.0.0.dylib" \
    "@executable_path/../Frameworks/libimobiledevice-glue-1.0.0.dylib" \
    "$DYLIB"

install_name_tool -change \
    "/opt/homebrew/opt/libplist/lib/libplist-2.0.4.dylib" \
    "@executable_path/../Frameworks/libplist-2.0.4.dylib" \
    "$DYLIB"
log_info "    ✓ Fixed dependencies"

# Fix libimobiledevice-glue-1.0.0.dylib
DYLIB="$FRAMEWORKS_DIR/libimobiledevice-glue-1.0.0.dylib"
log_info "  Processing libimobiledevice-glue-1.0.0.dylib..."

# Set its own install name
install_name_tool -id "@executable_path/../Frameworks/libimobiledevice-glue-1.0.0.dylib" "$DYLIB"
log_info "    ✓ Set install name"

# Fix its dependencies
install_name_tool -change \
    "/opt/homebrew/opt/libimobiledevice-glue/lib/libimobiledevice-glue-1.0.0.dylib" \
    "@executable_path/../Frameworks/libimobiledevice-glue-1.0.0.dylib" \
    "$DYLIB"

install_name_tool -change \
    "/opt/homebrew/opt/libplist/lib/libplist-2.0.4.dylib" \
    "@executable_path/../Frameworks/libplist-2.0.4.dylib" \
    "$DYLIB"
log_info "    ✓ Fixed dependencies"

# Fix libplist-2.0.4.dylib
DYLIB="$FRAMEWORKS_DIR/libplist-2.0.4.dylib"
log_info "  Processing libplist-2.0.4.dylib..."

# Set its own install name
install_name_tool -id "@executable_path/../Frameworks/libplist-2.0.4.dylib" "$DYLIB"
log_info "    ✓ Set install name"

# Fix its own dependency (it references itself)
install_name_tool -change \
    "/opt/homebrew/opt/libplist/lib/libplist-2.0.4.dylib" \
    "@executable_path/../Frameworks/libplist-2.0.4.dylib" \
    "$DYLIB"
log_info "    ✓ Fixed self-reference"

log_success "All dylib paths fixed"

# ============================================================================
# Step 6: Verify All Paths
# ============================================================================

log_info "Step 6: Verifying all paths..."

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "iproxy Dependencies:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
otool -L "$IPROXY_BINARY"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "libusbmuxd-2.0.7.dylib Dependencies:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
otool -L "$FRAMEWORKS_DIR/libusbmuxd-2.0.7.dylib"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "libimobiledevice-glue-1.0.0.dylib Dependencies:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
otool -L "$FRAMEWORKS_DIR/libimobiledevice-glue-1.0.0.dylib"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "libplist-2.0.4.dylib Dependencies:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
otool -L "$FRAMEWORKS_DIR/libplist-2.0.4.dylib"
echo ""

# Check for any remaining Homebrew references
log_info "Checking for remaining Homebrew references..."
HOMEBREW_REFS=$(otool -L "$IPROXY_BINARY" "$FRAMEWORKS_DIR"/*.dylib | grep -c "/opt/homebrew" || true)

if [ "$HOMEBREW_REFS" -gt 0 ]; then
    log_error "Found $HOMEBREW_REFS remaining Homebrew references!"
    otool -L "$IPROXY_BINARY" "$FRAMEWORKS_DIR"/*.dylib | grep "/opt/homebrew"
    exit 1
fi

log_success "No Homebrew references found - all paths use @executable_path"

# ============================================================================
# Summary
# ============================================================================

echo ""
log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_success "iproxy Bundling Complete!"
log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_success "✅ iproxy binary copied to Contents/MacOS/"
log_success "✅ 3 dylibs copied to Contents/Frameworks/"
log_success "✅ All library paths fixed to use @executable_path"
log_success "✅ No Homebrew dependencies remaining"
log_success "✅ Ready for code signing"
echo ""

log_info "Files bundled:"
log_info "  Binary: $MACOS_DIR/iproxy"
log_info "  Dylibs:"
log_info "    - $FRAMEWORKS_DIR/libusbmuxd-2.0.7.dylib"
log_info "    - $FRAMEWORKS_DIR/libimobiledevice-glue-1.0.0.dylib"
log_info "    - $FRAMEWORKS_DIR/libplist-2.0.4.dylib"
echo ""

exit 0
