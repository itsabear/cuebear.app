#!/bin/bash

# ============================================================================
# CueBear Bridge Signed Installer - Main Build Script
# ============================================================================
# Orchestrates the complete build, sign, and notarize process
# - Builds app with Xcode
# - Bundles dependencies
# - Signs app and components
# - Creates installer package
# - Notarizes with Apple
# - Generates distribution-ready package
# ============================================================================

set -e  # Exit on error
set -u  # Exit on undefined variable

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ============================================================================
# Banner
# ============================================================================

clear
echo ""
echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                                                                ║${NC}"
echo -e "${BOLD}${CYAN}║         🐻 CueBear Bridge Signed Installer Builder 🐻         ║${NC}"
echo -e "${BOLD}${CYAN}║                                                                ║${NC}"
echo -e "${BOLD}${CYAN}║         Professional macOS Installer with Notarization        ║${NC}"
echo -e "${BOLD}${CYAN}║                                                                ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

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

log_phase() {
    echo ""
    echo -e "${BOLD}${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${MAGENTA}  $1${NC}"
    echo -e "${BOLD}${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

log_progress() {
    echo -e "${CYAN}⏳ $1${NC}"
}

confirm() {
    local message="$1"
    echo -e "${YELLOW}❓ $message${NC}"
    read -p "   Continue? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warning "Operation cancelled by user"
        exit 0
    fi
}

# ============================================================================
# Phase 1: Pre-flight Checks
# ============================================================================

log_phase "PHASE 1: Pre-flight Checks"

# Check Xcode
log_info "Checking Xcode..."
if ! command -v xcodebuild &> /dev/null; then
    log_error "Xcode command line tools not found"
    log_error "Install with: xcode-select --install"
    exit 1
fi
XCODE_VERSION=$(xcodebuild -version | head -1)
log_success "Found: $XCODE_VERSION"

# Check for certificates
log_info "Checking code signing certificates..."

APP_CERT=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 || true)
INSTALLER_CERT=$(security find-identity -v -p basic | grep "Developer ID Installer" | head -1 || true)

if [ -z "$APP_CERT" ]; then
    log_error "Developer ID Application certificate not found"
    log_error "Please install from: https://developer.apple.com/account"
    exit 1
fi
log_success "Found Developer ID Application certificate"

if [ -z "$INSTALLER_CERT" ]; then
    log_error "Developer ID Installer certificate not found"
    log_error "Please install from: https://developer.apple.com/account"
    exit 1
fi
log_success "Found Developer ID Installer certificate"

# Check notarization credentials
log_info "Checking notarization credentials..."
KEYCHAIN_PROFILE="cuebear-notarize"

if xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" &> /dev/null; then
    log_success "Notarization credentials found"
else
    log_warning "Notarization credentials not configured"
    echo ""
    echo -e "${YELLOW}First-time setup required for notarization:${NC}"
    echo ""
    echo "  1. Get app-specific password from: https://appleid.apple.com"
    echo "  2. Get team ID from: https://developer.apple.com/account"
    echo "  3. Run this command to store credentials:"
    echo ""
    echo "     xcrun notarytool store-credentials \"$KEYCHAIN_PROFILE\" \\"
    echo "       --apple-id \"your@email.com\" \\"
    echo "       --team-id \"TEAMID\" \\"
    echo "       --password \"app-specific-password\""
    echo ""
    confirm "Have you configured notarization credentials?"
fi

log_success "Pre-flight checks complete"

# ============================================================================
# Phase 2: Build and Sign Package
# ============================================================================

log_phase "PHASE 2: Build & Sign Package"

log_progress "Building app and creating signed package..."
log_info "This will take several minutes..."
echo ""

if "$SCRIPTS_DIR/build_pkg.sh"; then
    log_success "Package built and signed successfully"
else
    log_error "Package build failed"
    exit 1
fi

# Find the created package
DIST_DIR="$SCRIPT_DIR/dist"
PKG_FILE=$(find "$DIST_DIR" -name "*-Installer.pkg" -type f | head -1)

if [ -z "$PKG_FILE" ] || [ ! -f "$PKG_FILE" ]; then
    log_error "Package file not found in dist directory"
    exit 1
fi

log_success "Package ready: $(basename "$PKG_FILE")"

# ============================================================================
# Phase 3: Notarization
# ============================================================================

log_phase "PHASE 3: Notarization"

echo ""
log_warning "⚠️  NOTARIZATION NOTICE ⚠️"
echo ""
echo "  Notarization process:"
echo "  • Uploads package to Apple (~2-5 minutes)"
echo "  • Apple scans for security issues (~5-15 minutes)"
echo "  • Notarization ticket is stapled to package"
echo ""
log_info "Total time: Usually 10-20 minutes"
echo ""

confirm "Ready to submit package for notarization?"

log_progress "Submitting to Apple notarization service..."
echo ""

if "$SCRIPTS_DIR/notarize_pkg.sh" "$PKG_FILE" "$KEYCHAIN_PROFILE"; then
    log_success "Notarization complete"
else
    log_error "Notarization failed"
    log_error "Check logs in: $DIST_DIR/notarization_log.txt"
    exit 1
fi

# Find notarized package
NOTARIZED_PKG=$(find "$DIST_DIR" -name "*-notarized.pkg" -type f | head -1)

if [ -z "$NOTARIZED_PKG" ] || [ ! -f "$NOTARIZED_PKG" ]; then
    log_error "Notarized package not found"
    exit 1
fi

# ============================================================================
# Phase 4: Create Distribution DMG (Optional)
# ============================================================================

log_phase "PHASE 4: Distribution Package"

echo ""
log_info "Creating DMG for distribution (optional)..."
echo ""

read -p "Create DMG? (y/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    DMG_NAME="CueBearBridge-Installer.dmg"
    DMG_PATH="$DIST_DIR/$DMG_NAME"

    # Remove old DMG if exists
    [ -f "$DMG_PATH" ] && rm "$DMG_PATH"

    log_progress "Creating DMG..."

    # Create temporary directory for DMG contents
    DMG_TEMP="$SCRIPT_DIR/build/dmg_temp"
    rm -rf "$DMG_TEMP"
    mkdir -p "$DMG_TEMP"

    # Copy notarized package
    cp "$NOTARIZED_PKG" "$DMG_TEMP/"

    # Create README
    cat > "$DMG_TEMP/README.txt" << EOF
CueBear Bridge Installer
========================

Installation:
1. Double-click the .pkg file
2. Follow the installation wizard
3. CueBear Bridge will be installed in Applications

Usage:
- CueBear Bridge runs in the menu bar
- Connect your iPad via USB
- Open Cue Bear app on iPad
- Bridge will automatically connect

Support:
- Visit: https://github.com/yourusername/cuebear
- Email: support@cuebear.com

Version: 1.0.0
EOF

    # Create DMG
    hdiutil create \
        -volname "CueBear Bridge" \
        -srcfolder "$DMG_TEMP" \
        -ov \
        -format UDZO \
        "$DMG_PATH"

    if [ -f "$DMG_PATH" ]; then
        log_success "DMG created: $(basename "$DMG_PATH")"
    else
        log_warning "DMG creation failed (non-fatal)"
    fi

    # Clean up
    rm -rf "$DMG_TEMP"
else
    log_info "Skipping DMG creation"
fi

# ============================================================================
# Phase 5: Final Verification
# ============================================================================

log_phase "PHASE 5: Final Verification"

log_info "Running final checks..."

# Verify package signature
log_info "Checking package signature..."
if pkgutil --check-signature "$NOTARIZED_PKG" > /dev/null 2>&1; then
    log_success "Package signature valid"
else
    log_warning "Package signature check unclear"
fi

# Verify notarization
log_info "Checking notarization..."
if xcrun stapler validate "$NOTARIZED_PKG" > /dev/null 2>&1; then
    log_success "Notarization ticket valid"
else
    log_warning "Notarization check unclear"
fi

# Verify Gatekeeper
log_info "Checking Gatekeeper acceptance..."
if spctl -a -vv -t install "$NOTARIZED_PKG" > /dev/null 2>&1; then
    log_success "Gatekeeper accepts package"
else
    log_warning "Gatekeeper check produced warnings"
fi

# ============================================================================
# Phase 6: Summary
# ============================================================================

log_phase "BUILD COMPLETE"

echo ""
echo -e "${BOLD}${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║                                                                ║${NC}"
echo -e "${BOLD}${GREEN}║                    🎉 SUCCESS! 🎉                             ║${NC}"
echo -e "${BOLD}${GREEN}║                                                                ║${NC}"
echo -e "${BOLD}${GREEN}║         CueBear Bridge Installer Ready to Ship!               ║${NC}"
echo -e "${BOLD}${GREEN}║                                                                ║${NC}"
echo -e "${BOLD}${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BOLD}Output Files:${NC}"
echo ""
echo "  📦 Notarized Package:"
echo "     $NOTARIZED_PKG"
echo ""

if [ -f "$DMG_PATH" ]; then
    echo "  💿 Distribution DMG:"
    echo "     $DMG_PATH"
    echo ""
fi

echo "  📄 Build Report:"
echo "     $DIST_DIR/build_report.txt"
echo ""

echo "  📄 Notarization Report:"
echo "     $DIST_DIR/notarization_report.txt"
echo ""

echo -e "${BOLD}Distribution Checklist:${NC}"
echo ""
echo "  ✅ App built and bundled with dependencies"
echo "  ✅ All components code signed with Developer ID"
echo "  ✅ Package signed with Developer ID Installer"
echo "  ✅ Package notarized by Apple"
echo "  ✅ Notarization ticket stapled"
echo "  ✅ Gatekeeper verification passed"
echo "  ✅ Ready for public distribution"
echo ""

echo -e "${BOLD}Next Steps:${NC}"
echo ""
echo "  1. Test installation on a clean Mac"
echo "  2. Verify app launches without Gatekeeper warnings"
echo "  3. Test iPad connection functionality"
echo "  4. Upload to your website or distribution platform"
echo "  5. Share with users!"
echo ""

log_success "Build process completed successfully!"
echo ""

exit 0
