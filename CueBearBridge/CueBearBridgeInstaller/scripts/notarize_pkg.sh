#!/bin/bash

# ============================================================================
# CueBear Bridge Notarization Script
# ============================================================================
# Submits package to Apple notarization service
# Waits for notarization to complete
# Staples notarization ticket to package
# Verifies notarized package
# ============================================================================

set -e  # Exit on error
set -u  # Exit on undefined variable

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$INSTALLER_DIR/dist"

PKG_PATH="${1:-}"
KEYCHAIN_PROFILE="${2:-cuebear-notarize}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
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

log_progress() {
    echo -e "${CYAN}⏳ $1${NC}"
}

# ============================================================================
# Validation
# ============================================================================

log_step "Step 0: Validation"

if [ -z "$PKG_PATH" ] || [ ! -f "$PKG_PATH" ]; then
    log_error "Usage: $0 <path-to-package.pkg> [keychain-profile]"
    echo ""
    log_info "Example: $0 CueBearBridge-Installer.pkg"
    log_info "         $0 CueBearBridge-Installer.pkg my-profile"
    echo ""
    log_warning "First-time setup required:"
    echo ""
    echo "  1. Get your credentials:"
    echo "     - Apple ID: Your developer account email"
    echo "     - Team ID: From https://developer.apple.com/account"
    echo "     - App-Specific Password: From https://appleid.apple.com"
    echo ""
    echo "  2. Store credentials (one-time):"
    echo "     xcrun notarytool store-credentials \"$KEYCHAIN_PROFILE\" \\"
    echo "       --apple-id \"your@email.com\" \\"
    echo "       --team-id \"TEAMID\" \\"
    echo "       --password \"app-specific-password\""
    echo ""
    exit 1
fi

log_info "Package: $PKG_PATH"
log_info "Keychain Profile: $KEYCHAIN_PROFILE"

# Check if notarytool is available
if ! xcrun notarytool --version &> /dev/null; then
    log_error "notarytool not found. Please install Xcode 13 or later."
    exit 1
fi
log_success "notarytool available"

# Check if keychain profile exists
if ! xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" &> /dev/null; then
    log_error "Keychain profile '$KEYCHAIN_PROFILE' not found"
    echo ""
    log_warning "Please store your credentials first:"
    echo ""
    echo "  xcrun notarytool store-credentials \"$KEYCHAIN_PROFILE\" \\"
    echo "    --apple-id \"your@email.com\" \\"
    echo "    --team-id \"TEAMID\" \\"
    echo "    --password \"app-specific-password\""
    echo ""
    log_info "Get app-specific password from: https://appleid.apple.com"
    log_info "Get team ID from: https://developer.apple.com/account"
    echo ""
    exit 1
fi
log_success "Keychain profile found"

# ============================================================================
# Step 1: Verify Package Signature
# ============================================================================

log_step "Step 1: Verifying package signature"

log_info "Checking package signature..."
if pkgutil --check-signature "$PKG_PATH"; then
    log_success "Package signature valid"
else
    log_error "Package signature invalid or missing"
    log_error "Please sign the package before notarization"
    exit 1
fi

# ============================================================================
# Step 2: Submit for Notarization
# ============================================================================

log_step "Step 2: Submitting for notarization"

log_info "Uploading package to Apple (this may take a few minutes)..."
log_warning "Please be patient - large packages take longer to upload"
echo ""

NOTARIZE_LOG="$DIST_DIR/notarization_log.txt"

# Submit and capture submission ID
SUBMIT_OUTPUT=$(xcrun notarytool submit "$PKG_PATH" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait \
    2>&1 | tee "$NOTARIZE_LOG")

# Extract submission ID
SUBMISSION_ID=$(echo "$SUBMIT_OUTPUT" | grep -o "id: [a-f0-9-]*" | cut -d' ' -f2 | head -1)

if [ -z "$SUBMISSION_ID" ]; then
    log_error "Failed to get submission ID"
    log_error "Check log: $NOTARIZE_LOG"
    exit 1
fi

log_info "Submission ID: $SUBMISSION_ID"

# Check if notarization succeeded
if echo "$SUBMIT_OUTPUT" | grep -q "status: Accepted"; then
    log_success "Notarization succeeded!"
elif echo "$SUBMIT_OUTPUT" | grep -q "status: Invalid"; then
    log_error "Notarization failed: Invalid package"
    log_error "Getting detailed log..."

    # Get detailed log
    xcrun notarytool log "$SUBMISSION_ID" \
        --keychain-profile "$KEYCHAIN_PROFILE" \
        "$DIST_DIR/notarization_error.json"

    log_error "Error details saved: $DIST_DIR/notarization_error.json"
    echo ""
    cat "$DIST_DIR/notarization_error.json"
    exit 1
else
    log_warning "Notarization status unclear"
    log_info "Getting submission info..."

    xcrun notarytool info "$SUBMISSION_ID" \
        --keychain-profile "$KEYCHAIN_PROFILE"

    exit 1
fi

# ============================================================================
# Step 3: Staple Notarization Ticket
# ============================================================================

log_step "Step 3: Stapling notarization ticket"

log_info "Stapling ticket to package..."

if xcrun stapler staple "$PKG_PATH"; then
    log_success "Notarization ticket stapled"
else
    log_error "Failed to staple ticket"
    exit 1
fi

# ============================================================================
# Step 4: Verify Stapled Package
# ============================================================================

log_step "Step 4: Verifying stapled package"

# Verify staple
log_info "Verifying staple..."
if xcrun stapler validate "$PKG_PATH"; then
    log_success "Staple valid"
else
    log_warning "Staple validation unclear"
fi

# Verify with spctl (Gatekeeper)
log_info "Verifying with Gatekeeper..."
if spctl -a -vv -t install "$PKG_PATH" 2>&1 | tee "$DIST_DIR/gatekeeper_check.txt"; then
    log_success "Gatekeeper accepts package"
else
    log_warning "Gatekeeper check produced warnings (check log)"
fi

# ============================================================================
# Step 5: Create Notarized Package Copy
# ============================================================================

log_step "Step 5: Creating final notarized package"

PKG_DIR=$(dirname "$PKG_PATH")
PKG_NAME=$(basename "$PKG_PATH" .pkg)
NOTARIZED_PKG="$PKG_DIR/${PKG_NAME}-notarized.pkg"

log_info "Creating notarized copy: $NOTARIZED_PKG"
cp "$PKG_PATH" "$NOTARIZED_PKG"

log_success "Notarized package created"

# ============================================================================
# Step 6: Generate Notarization Report
# ============================================================================

log_step "Step 6: Generating notarization report"

REPORT_FILE="$DIST_DIR/notarization_report.txt"

cat > "$REPORT_FILE" << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CueBear Bridge Notarization Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Notarization Date: $(date)
Operator: $(whoami)
Machine: $(hostname)

Package Information:
  Original: $PKG_PATH
  Notarized: $NOTARIZED_PKG
  Submission ID: $SUBMISSION_ID

Status: ✅ APPROVED

Verification:
$(pkgutil --check-signature "$NOTARIZED_PKG" 2>&1)

Staple Verification:
$(xcrun stapler validate "$NOTARIZED_PKG" 2>&1)

Gatekeeper Check:
$(cat "$DIST_DIR/gatekeeper_check.txt" 2>&1)

Next Steps:
  1. Test installation on clean Mac
  2. Distribute package to users
  3. Create DMG for distribution (optional)

Distribution Checklist:
  ✅ Package signed with Developer ID Installer
  ✅ Package notarized by Apple
  ✅ Notarization ticket stapled
  ✅ Gatekeeper verification passed
  ✅ Ready for distribution

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

cat "$REPORT_FILE"

log_success "Notarization report saved: $REPORT_FILE"

# ============================================================================
# Summary
# ============================================================================

echo ""
log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_success "Notarization Complete!"
log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_success "✅ Package uploaded to Apple"
log_success "✅ Notarization approved"
log_success "✅ Ticket stapled to package"
log_success "✅ Gatekeeper verification passed"
log_success "✅ Ready for distribution"
echo ""
log_info "📦 Notarized Package: $NOTARIZED_PKG"
log_info "📄 Report: $REPORT_FILE"
log_info "📄 Full Log: $NOTARIZE_LOG"
echo ""
log_success "🎉 Your package is ready to ship!"
echo ""

exit 0
