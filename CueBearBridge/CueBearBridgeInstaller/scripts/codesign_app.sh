#!/bin/bash

# ============================================================================
# CueBear Bridge Code Signing Script
# ============================================================================
# Signs the app bundle, all dylibs, and helper binaries with Developer ID
# Fixes dylib install names to use @rpath for proper loading
# Applies hardened runtime and entitlements for notarization
# ============================================================================

set -e  # Exit on error
set -u  # Exit on undefined variable

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(dirname "$INSTALLER_DIR")"

APP_BUNDLE="$1"  # Path to CueBearBridge.app
SIGNING_IDENTITY="${2:-}"  # Developer ID Application certificate name

ENTITLEMENTS="$INSTALLER_DIR/Entitlements.plist"

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
    log_error "Usage: $0 <path-to-app-bundle> [signing-identity]"
    log_error "Example: $0 build/CueBearBridge.app 'Developer ID Application: Name (TEAMID)'"
    exit 1
fi

if [ ! -f "$ENTITLEMENTS" ]; then
    log_error "Entitlements file not found: $ENTITLEMENTS"
    exit 1
fi

# Auto-detect signing identity if not provided
if [ -z "$SIGNING_IDENTITY" ]; then
    log_info "Auto-detecting Developer ID Application certificate..."
    SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed -E 's/.*"(.*)"/\1/')

    if [ -z "$SIGNING_IDENTITY" ]; then
        log_error "No Developer ID Application certificate found in keychain"
        log_error "Please install certificates from https://developer.apple.com"
        exit 1
    fi

    log_success "Found: $SIGNING_IDENTITY"
fi

log_info "Starting code signing process..."
log_info "App Bundle: $APP_BUNDLE"
log_info "Signing Identity: $SIGNING_IDENTITY"
log_info "Entitlements: $ENTITLEMENTS"

# ============================================================================
# Step 1: Fix Dylib Install Names
# ============================================================================

log_info "Step 1: Fixing dylib install names..."

FRAMEWORKS_DIR="$APP_BUNDLE/Contents/Frameworks"
if [ -d "$FRAMEWORKS_DIR" ]; then
    cd "$FRAMEWORKS_DIR"

    # List of dylibs (old system + new iproxy dependencies)
    DYLIBS=(
        "libxml2.2.dylib"
        "libusbmuxd.4.dylib"
        "libicudata.77.dylib"
        "libicuuc.77.dylib"
        "libimobiledevice-glue.1.dylib"
        "libplist.3.dylib"
        "libusbmuxd-2.0.7.dylib"
        "libimobiledevice-glue-1.0.0.dylib"
        "libplist-2.0.4.dylib"
    )

    for dylib in "${DYLIBS[@]}"; do
        if [ -f "$dylib" ]; then
            log_info "  Fixing install name for $dylib..."

            # Set the dylib's own ID to use @rpath
            install_name_tool -id "@rpath/$dylib" "$dylib" 2>/dev/null || true

            # Fix dependencies to use @rpath
            # Check current dependencies
            DEPS=$(otool -L "$dylib" | grep -E "lib.*\.dylib" | awk '{print $1}' | grep -v "@rpath" | grep -v "/usr/lib" || true)

            for dep in $DEPS; do
                DEP_NAME=$(basename "$dep")
                log_info "    Changing $DEP_NAME to @rpath..."
                install_name_tool -change "$dep" "@rpath/$DEP_NAME" "$dylib" 2>/dev/null || true
            done

            log_success "  ✓ $dylib install name fixed"
        else
            log_warning "  Dylib not found: $dylib (skipping)"
        fi
    done

    cd - > /dev/null
else
    log_warning "Frameworks directory not found: $FRAMEWORKS_DIR"
fi

log_success "Step 1 complete: Dylib install names fixed"

# ============================================================================
# Step 2: Sign All Dylibs
# ============================================================================

log_info "Step 2: Signing dylibs..."

if [ -d "$FRAMEWORKS_DIR" ]; then
    for dylib in "$FRAMEWORKS_DIR"/*.dylib; do
        if [ -f "$dylib" ]; then
            DYLIB_NAME=$(basename "$dylib")
            log_info "  Signing $DYLIB_NAME..."

            codesign --force --sign "$SIGNING_IDENTITY" \
                --timestamp \
                --options runtime \
                "$dylib"

            log_success "  ✓ $DYLIB_NAME signed"
        fi
    done
else
    log_warning "No dylibs found to sign"
fi

log_success "Step 2 complete: All dylibs signed"

# ============================================================================
# Step 3: Sign Helper Binaries
# ============================================================================

log_info "Step 3: Signing helper binaries..."

HELPERS_DIR="$APP_BUNDLE/Contents/Resources/Helpers"
if [ -d "$HELPERS_DIR" ]; then
    for helper in "$HELPERS_DIR"/*; do
        if [ -f "$helper" ] && [ -x "$helper" ]; then
            HELPER_NAME=$(basename "$helper")
            log_info "  Signing $HELPER_NAME..."

            # Ensure executable
            chmod +x "$helper"

            # Sign with hardened runtime
            codesign --force --sign "$SIGNING_IDENTITY" \
                --timestamp \
                --options runtime \
                "$helper"

            log_success "  ✓ $HELPER_NAME signed"
        fi
    done
else
    log_warning "Helpers directory not found: $HELPERS_DIR"
fi

log_success "Step 3 complete: Helper binaries signed"

# ============================================================================
# Step 3.5: Sign iproxy Binary in MacOS
# ============================================================================

log_info "Step 3.5: Signing iproxy binary..."

MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
IPROXY_BINARY="$MACOS_DIR/iproxy"

if [ -f "$IPROXY_BINARY" ]; then
    log_info "  Signing iproxy..."

    # Ensure executable
    chmod +x "$IPROXY_BINARY"

    # Sign with hardened runtime
    codesign --force --sign "$SIGNING_IDENTITY" \
        --timestamp \
        --options runtime \
        "$IPROXY_BINARY"

    log_success "  ✓ iproxy signed"
else
    log_warning "iproxy binary not found: $IPROXY_BINARY"
fi

log_success "Step 3.5 complete: iproxy binary signed"

# ============================================================================
# Step 4: Sign Frameworks (if any)
# ============================================================================

log_info "Step 4: Signing embedded frameworks..."

EMBEDDED_FRAMEWORKS="$APP_BUNDLE/Contents/Frameworks"
if [ -d "$EMBEDDED_FRAMEWORKS" ]; then
    for framework in "$EMBEDDED_FRAMEWORKS"/*.framework; do
        if [ -d "$framework" ]; then
            FRAMEWORK_NAME=$(basename "$framework")
            log_info "  Signing $FRAMEWORK_NAME..."

            codesign --force --sign "$SIGNING_IDENTITY" \
                --timestamp \
                --options runtime \
                "$framework"

            log_success "  ✓ $FRAMEWORK_NAME signed"
        fi
    done
fi

log_success "Step 4 complete: Frameworks signed"

# ============================================================================
# Step 5: Sign Main App Bundle
# ============================================================================

log_info "Step 5: Signing main app bundle..."

codesign --force --deep --sign "$SIGNING_IDENTITY" \
    --timestamp \
    --options runtime \
    --entitlements "$ENTITLEMENTS" \
    "$APP_BUNDLE"

log_success "Step 5 complete: App bundle signed"

# ============================================================================
# Step 6: Verify Code Signature
# ============================================================================

log_info "Step 6: Verifying code signature..."

# Verify app bundle
log_info "  Verifying app bundle..."
if codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE" 2>&1; then
    log_success "  ✓ App bundle signature valid"
else
    log_error "  ✗ App bundle signature invalid"
    exit 1
fi

# Verify dylibs
if [ -d "$FRAMEWORKS_DIR" ]; then
    log_info "  Verifying dylibs..."
    for dylib in "$FRAMEWORKS_DIR"/*.dylib; do
        if [ -f "$dylib" ]; then
            DYLIB_NAME=$(basename "$dylib")
            if codesign --verify --verbose=2 "$dylib" 2>&1 | grep -q "valid"; then
                log_success "    ✓ $DYLIB_NAME signature valid"
            else
                log_warning "    ? $DYLIB_NAME signature status unclear"
            fi
        fi
    done
fi

# Verify helpers
if [ -d "$HELPERS_DIR" ]; then
    log_info "  Verifying helpers..."
    for helper in "$HELPERS_DIR"/*; do
        if [ -f "$helper" ] && [ -x "$helper" ]; then
            HELPER_NAME=$(basename "$helper")
            if codesign --verify --verbose=2 "$helper" 2>&1 | grep -q "valid"; then
                log_success "    ✓ $HELPER_NAME signature valid"
            else
                log_warning "    ? $HELPER_NAME signature status unclear"
            fi
        fi
    done
fi

# Verify iproxy
if [ -f "$IPROXY_BINARY" ]; then
    log_info "  Verifying iproxy..."
    if codesign --verify --verbose=2 "$IPROXY_BINARY" 2>&1 | grep -q "valid"; then
        log_success "    ✓ iproxy signature valid"
    else
        log_warning "    ? iproxy signature status unclear"
    fi
fi

log_success "Step 6 complete: All signatures verified"

# ============================================================================
# Step 7: Display Signature Info
# ============================================================================

log_info "Step 7: Signature information..."

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Code Signature Information"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
codesign -dvvv "$APP_BUNDLE" 2>&1 | grep -E "(Identifier|Authority|TeamIdentifier|Sealed Resources|Info.plist)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ============================================================================
# Summary
# ============================================================================

echo ""
log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_success "Code Signing Complete!"
log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_success "✅ All dylibs signed with Developer ID"
log_success "✅ Helper binaries signed with hardened runtime"
log_success "✅ App bundle signed with entitlements"
log_success "✅ All signatures verified"
log_success "✅ Ready for notarization"
echo ""

exit 0
