# Build System Agent

## Role
Expert in fixing and modifying the CueBear Bridge installer build scripts to work with user's specific certificate setup.

## Current Situation
- User has Developer ID Application certificate (works ✅)
- User has Developer ID Installer certificate (exists but not detected by scripts ❌)
- Certificate exists in Keychain Access with private key
- `security find-identity` doesn't show the Installer certificate
- Build script fails at pre-flight check

## Build Scripts Location
```
CueBearBridge/CueBearBridgeInstaller/
├── build_signed_installer.sh       # Main orchestrator
└── scripts/
    ├── build_pkg.sh               # Calls codesign_app.sh, creates package
    ├── codesign_app.sh            # Signs app components
    └── notarize_pkg.sh            # Notarizes with Apple
```

## Problem in build_pkg.sh
Lines that auto-detect certificates:
```bash
if [ -z "$SIGNING_IDENTITY_INSTALLER" ]; then
    log_info "Auto-detecting Developer ID Installer certificate..."
    SIGNING_IDENTITY_INSTALLER=$(security find-identity -v -p codesigning | grep "Developer ID Installer" | head -1 | sed -E 's/.*"(.*)"/\1/')

    if [ -z "$SIGNING_IDENTITY_INSTALLER" ]; then
        log_error "No Developer ID Installer certificate found"
        exit 1
    fi
}
```

## Alternative Detection Methods

### Method 1: Use `security find-certificate` Instead
```bash
SIGNING_IDENTITY_INSTALLER=$(security find-certificate -c "Developer ID Installer" -p | openssl x509 -noout -subject | sed 's/.*CN=\(.*\)/\1/')
```

### Method 2: Search Keychain Directly
```bash
SIGNING_IDENTITY_INSTALLER=$(security find-certificate -a -c "Developer ID Installer" | grep "labl" | head -1 | sed 's/.*"labl"<blob>="\(.*\)"/\1/')
```

### Method 3: Try pkgbuild's Auto-Detection
```bash
# Don't specify --sign flag, let pkgbuild auto-detect
pkgbuild --root ... --identifier ... output.pkg
# Then sign separately
productsign --sign "Developer ID Installer" input.pkg output.pkg
```

### Method 4: Manual Override
Allow user to manually specify certificate name:
```bash
SIGNING_IDENTITY_INSTALLER="Developer ID Installer: Omri Behr (2U78NYVLQN)"
```

## Workaround: Skip Auto-Detection

Add manual override option to build_pkg.sh:
```bash
# After line that checks for certificate, add:
if [ -z "$SIGNING_IDENTITY_INSTALLER" ]; then
    log_warning "Auto-detection failed. Trying manual certificate name..."
    SIGNING_IDENTITY_INSTALLER="Developer ID Installer: Omri Behr (2U78NYVLQN)"

    # Test if this works with pkgbuild
    if pkgbuild --check-signature-identity "$SIGNING_IDENTITY_INSTALLER" &>/dev/null; then
        log_success "Found certificate: $SIGNING_IDENTITY_INSTALLER"
    else
        log_error "Certificate not usable for signing"
        exit 1
    fi
fi
```

## Files to Modify

### scripts/build_pkg.sh
Lines ~40-50: Certificate auto-detection logic

**Current code:**
```bash
if [ -z "$SIGNING_IDENTITY_INSTALLER" ]; then
    log_info "Auto-detecting Developer ID Installer certificate..."
    SIGNING_IDENTITY_INSTALLER=$(security find-identity -v -p codesigning | grep "Developer ID Installer" | head -1 | sed -E 's/.*"(.*)"/\1/')

    if [ -z "$SIGNING_IDENTITY_INSTALLER" ]; then
        log_error "No Developer ID Installer certificate found"
        exit 1
    fi
    log_success "Found: $SIGNING_IDENTITY_INSTALLER"
fi
```

**Improved code:**
```bash
if [ -z "$SIGNING_IDENTITY_INSTALLER" ]; then
    log_info "Auto-detecting Developer ID Installer certificate..."

    # Try method 1: security find-identity
    SIGNING_IDENTITY_INSTALLER=$(security find-identity -v -p codesigning | grep "Developer ID Installer" | head -1 | sed -E 's/.*"(.*)"/\1/')

    # Try method 2: security find-certificate
    if [ -z "$SIGNING_IDENTITY_INSTALLER" ]; then
        log_info "Trying alternate detection method..."
        SIGNING_IDENTITY_INSTALLER=$(security find-certificate -a -c "Developer ID Installer" ~/Library/Keychains/login.keychain-db | grep "labl" | head -1 | sed 's/.*"labl"<blob>="\(.*\)"/\1/')
    fi

    # Try method 3: Check with pkgbuild directly
    if [ -z "$SIGNING_IDENTITY_INSTALLER" ]; then
        log_info "Attempting to detect via pkgbuild..."
        # List all available signing identities for pkg
        SIGNING_IDENTITY_INSTALLER=$(pkgbuild --list-signature-identities 2>/dev/null | grep "Developer ID Installer" | head -1 | sed 's/.*) \(.*\)/\1/')
    fi

    if [ -z "$SIGNING_IDENTITY_INSTALLER" ]; then
        log_error "No Developer ID Installer certificate found"
        log_error "Try running: security find-certificate -a -c 'Developer ID Installer'"
        exit 1
    fi
    log_success "Found: $SIGNING_IDENTITY_INSTALLER"
fi
```

## Test Commands for Agent

```bash
# Test if pkgbuild can find the certificate
pkgbuild --list-signature-identities

# Test with explicit certificate name
pkgbuild --check-signature-identity "Developer ID Installer: Omri Behr (2U78NYVLQN)"

# Try finding via different method
security find-certificate -a -c "Developer ID Installer" | grep "labl"
```

## Next Steps
1. Run diagnostic commands to find working detection method
2. Update build_pkg.sh with improved certificate detection
3. Test updated script
4. If detection still fails, add manual override option

## Success Criteria
`./scripts/build_pkg.sh` proceeds past certificate detection and starts building the package.
