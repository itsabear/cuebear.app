# CueBear Bridge Installer Development Agents Guide

## Overview
This document provides comprehensive instructions for AI agents to create a fully functional, signed, and notarized installer for CueBear Bridge macOS application.

## Project Structure
```
CueBearBridge/
├── CueBearBridgeApp.swift          # Main app
├── MacConnectionManager.swift       # Connection logic
├── MIDIManager.swift               # MIDI handling
├── IProxyManager.swift             # iproxy management
├── Resources/
│   ├── Frameworks/                 # Required dylibs (7 files)
│   │   ├── libxml2.2.dylib
│   │   ├── libusbmuxd.4.dylib
│   │   ├── libicudata.77.dylib
│   │   ├── libicuuc.77.dylib
│   │   ├── libimobiledevice-glue.1.dylib
│   │   └── libplist.3.dylib
│   └── Helpers/
│       └── iproxy                  # iOS proxy binary
└── CueBearBridgeInstaller/
    ├── build_signed_installer.sh   # Main build script (TO CREATE)
    ├── scripts/
    │   ├── codesign_app.sh        # Signs app and deps (TO CREATE)
    │   ├── build_pkg.sh           # Creates .pkg (TO CREATE)
    │   └── notarize_pkg.sh        # Notarizes package (TO CREATE)
    └── dist/                      # Output directory
```

## Required Dependencies to Bundle

### 1. Dynamic Libraries (7 files in Resources/Frameworks/)
These must be:
- Copied to app bundle at `CueBearBridge.app/Contents/Frameworks/`
- Code signed with `--deep` flag
- Set with correct install names using `install_name_tool`
- Have `@rpath` or `@executable_path` relative paths

**Libraries:**
1. `libxml2.2.dylib` - XML parsing
2. `libusbmuxd.4.dylib` - USB multiplexing for iOS devices
3. `libicudata.77.dylib` - International Components for Unicode (data)
4. `libicuuc.77.dylib` - International Components for Unicode (common)
5. `libimobiledevice-glue.1.dylib` - iOS device communication glue
6. `libplist.3.dylib` - Property list handling

### 2. Helper Binary (Resources/Helpers/)
- `iproxy` - iOS proxy binary for USB-over-TCP forwarding
- Must be bundled at `CueBearBridge.app/Contents/Resources/Helpers/iproxy`
- Must be code signed separately
- Must have executable permissions (755)

## Agent Tasks

### AGENT 1: Code Signing Expert
**File to create:** `scripts/codesign_app.sh`

**Responsibilities:**
1. Sign all dylibs in `CueBearBridge.app/Contents/Frameworks/` with Developer ID Application
2. Sign `iproxy` helper binary with Developer ID Application
3. Fix dylib install names using `install_name_tool` to use `@rpath` or `@executable_path/../Frameworks/`
4. Set proper entitlements for app (hardened runtime, library validation)
5. Deep sign the entire app bundle with `--deep --force`
6. Verify code signature with `codesign -vvv --deep --strict`

**Required inputs:**
- Developer ID Application certificate name
- Path to built app bundle
- Entitlements.plist file

**Key commands:**
```bash
# Fix dylib install names
install_name_tool -id "@rpath/libxml2.2.dylib" libxml2.2.dylib
install_name_tool -change "/old/path/libxml2.2.dylib" "@rpath/libxml2.2.dylib" dependent.dylib

# Sign dylibs
codesign --force --sign "Developer ID Application: Name" --timestamp libxml2.2.dylib

# Sign helper
codesign --force --sign "Developer ID Application: Name" --timestamp iproxy

# Sign app with entitlements
codesign --force --deep --sign "Developer ID Application: Name" --timestamp \
  --options runtime --entitlements Entitlements.plist CueBearBridge.app
```

**Entitlements needed:**
- `com.apple.security.cs.allow-dyld-environment-variables` (for @rpath)
- `com.apple.security.cs.disable-library-validation` (for bundled dylibs)
- `com.apple.security.network.client` (for network connections)
- `com.apple.security.network.server` (for USB proxy)
- `com.apple.security.device.usb` (for iOS device access)

### AGENT 2: Package Builder
**File to create:** `scripts/build_pkg.sh`

**Responsibilities:**
1. Build CueBearBridge Xcode project in Release configuration
2. Copy all required dylibs to app bundle Frameworks directory
3. Copy iproxy to app bundle Resources/Helpers directory
4. Invoke AGENT 1's codesign script
5. Create installer package with `pkgbuild`
6. Sign package with Developer ID Installer certificate
7. Verify package signature

**Key steps:**
```bash
# 1. Build app
xcodebuild -project CueBearBridge.xcodeproj -scheme CueBearBridge \
  -configuration Release -derivedDataPath build/DerivedData

# 2. Copy dylibs
mkdir -p "CueBearBridge.app/Contents/Frameworks"
cp Resources/Frameworks/*.dylib "CueBearBridge.app/Contents/Frameworks/"

# 3. Copy helper
mkdir -p "CueBearBridge.app/Contents/Resources/Helpers"
cp Resources/Helpers/iproxy "CueBearBridge.app/Contents/Resources/Helpers/"
chmod 755 "CueBearBridge.app/Contents/Resources/Helpers/iproxy"

# 4. Code sign
./scripts/codesign_app.sh

# 5. Build package
pkgbuild --root package_root --identifier com.cuebear.bridge \
  --version 1.0 --install-location /Applications \
  --sign "Developer ID Installer: Name" CueBearBridge.pkg
```

### AGENT 3: Notarization Manager
**File to create:** `scripts/notarize_pkg.sh`

**Responsibilities:**
1. Upload package to Apple notarization service using `notarytool`
2. Wait for notarization to complete (polling)
3. Staple notarization ticket to package
4. Verify stapled package
5. Provide clear status output and error handling

**Key commands:**
```bash
# Submit for notarization
xcrun notarytool submit CueBearBridge.pkg \
  --apple-id "your@email.com" \
  --password "app-specific-password" \
  --team-id "TEAMID" \
  --wait

# Staple ticket
xcrun stapler staple CueBearBridge.pkg

# Verify
xcrun stapler validate CueBearBridge.pkg
spctl -a -vv -t install CueBearBridge.pkg
```

**Prerequisites:**
- Apple ID with notarization access
- App-specific password (NOT Apple ID password)
- Team ID from Apple Developer account

### AGENT 4: Orchestrator
**File to create:** `build_signed_installer.sh`

**Responsibilities:**
1. Pre-flight checks (Xcode installed, certificates available, credentials configured)
2. Create necessary directories
3. Invoke AGENT 2 (build and sign app)
4. Invoke AGENT 3 (notarize package)
5. Create DMG for distribution (optional)
6. Generate build report
7. Error handling and rollback

**Workflow:**
```
1. Check environment
2. Build app → AGENT 2
3. Sign app → AGENT 1 (called by AGENT 2)
4. Create pkg → AGENT 2
5. Notarize pkg → AGENT 3
6. Create DMG (optional)
7. Report success
```

## Code Signing Requirements

### Certificates Needed
1. **Developer ID Application** - For signing app, dylibs, and helper binary
2. **Developer ID Installer** - For signing .pkg package

### How to Get Certificates
```bash
# List available certificates
security find-identity -v -p codesigning

# You should see:
# 1) ABC123... "Developer ID Application: Your Name (TEAMID)"
# 2) DEF456... "Developer ID Installer: Your Name (TEAMID)"
```

### If Certificates Missing
1. Log in to https://developer.apple.com
2. Go to Certificates, Identifiers & Profiles
3. Create "Developer ID Application" certificate
4. Create "Developer ID Installer" certificate
5. Download and install in Keychain

## Notarization Requirements

### Prerequisites
1. **Apple ID**: Developer account email
2. **App-Specific Password**:
   - Go to https://appleid.apple.com
   - Sign in
   - Security → App-Specific Passwords
   - Generate new password (save it!)
3. **Team ID**:
   - Go to https://developer.apple.com/account
   - Membership details → Team ID

### Store Credentials (Recommended)
```bash
# Store credentials in keychain (secure)
xcrun notarytool store-credentials "cuebear-notarize" \
  --apple-id "your@email.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"

# Then use in scripts:
xcrun notarytool submit pkg --keychain-profile "cuebear-notarize" --wait
```

## Entitlements.plist
**File to create:** `Entitlements.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Hardened Runtime -->
    <key>com.apple.security.cs.allow-dyld-environment-variables</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>

    <!-- Network Access -->
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>

    <!-- USB Device Access -->
    <key>com.apple.security.device.usb</key>
    <true/>

    <!-- Optional: Audio/MIDI -->
    <key>com.apple.security.device.audio-input</key>
    <true/>
</dict>
</plist>
```

## Testing Procedure

### 1. Test Code Signing
```bash
# Verify app signature
codesign -vvv --deep --strict CueBearBridge.app

# Check entitlements
codesign -d --entitlements - CueBearBridge.app

# Verify all dylibs signed
codesign -vvv CueBearBridge.app/Contents/Frameworks/*.dylib
```

### 2. Test Package
```bash
# Check package signature
pkgutil --check-signature CueBearBridge.pkg

# Test installation (on clean VM)
sudo installer -pkg CueBearBridge.pkg -target /
```

### 3. Test Notarization
```bash
# Check notarization status
xcrun stapler validate CueBearBridge.pkg

# Verify Gatekeeper accepts it
spctl -a -vv -t install CueBearBridge.pkg
```

### 4. Test on User Machine
1. Download pkg to different Mac
2. Double-click to install (should NOT show Gatekeeper warning)
3. Launch app from Applications
4. Verify app connects to iOS device
5. Verify all features work

## Common Issues & Solutions

### Issue: "code signature invalid"
**Solution:** Re-sign with `--deep --force` and verify all dylibs have valid signatures

### Issue: "library not loaded"
**Solution:** Fix dylib install names with `install_name_tool` to use `@rpath`

### Issue: "notarization failed - invalid signature"
**Solution:** Ensure hardened runtime enabled: `--options runtime`

### Issue: "Gatekeeper blocks app"
**Solution:** Staple notarization ticket: `xcrun stapler staple`

### Issue: "iproxy not found"
**Solution:** Verify helper binary bundled at correct path and has executable permissions

## Success Criteria

✅ **App builds without errors**
✅ **All dylibs and helper binary code signed**
✅ **App code signature valid with deep verification**
✅ **Package created and signed with Developer ID Installer**
✅ **Notarization succeeds (approved by Apple)**
✅ **Notarization ticket stapled to package**
✅ **Gatekeeper accepts package (spctl -a passes)**
✅ **App installs and launches without warnings**
✅ **App connects to iOS device successfully**
✅ **All MIDI functionality works**

## Output Files

After successful build:
```
CueBearBridgeInstaller/dist/
├── CueBearBridge.app              # Signed app bundle (for testing)
├── CueBearBridge.pkg              # Signed and notarized package
├── CueBearBridge-notarized.pkg    # Final package (stapled)
├── build_report.txt               # Build summary
└── notarization_log.txt           # Notarization details
```

## How to Use This Guide

### For AI Agents:
1. Read this entire document first
2. Create the 4 script files (codesign_app.sh, build_pkg.sh, notarize_pkg.sh, build_signed_installer.sh)
3. Create Entitlements.plist
4. Test each script individually
5. Run full build with orchestrator script
6. Verify all success criteria met

### For Developers:
1. Ensure Apple Developer certificates installed
2. Configure notarization credentials
3. Run `./build_signed_installer.sh`
4. Follow prompts for credentials if needed
5. Wait for notarization (5-15 minutes)
6. Distribute resulting .pkg file

---

**Version:** 1.0
**Last Updated:** 2025-10-04
**Author:** CueBear Development Team
