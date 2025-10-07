# CueBear Bridge Notarization Guide

## 📚 Complete Guide to Notarizing CueBear Bridge for macOS

This guide walks you through the entire process of code signing and notarizing CueBear Bridge so it can be distributed without Gatekeeper warnings.

---

## 🎯 What is Notarization?

**Notarization** is Apple's automated security scanning service for macOS apps. When you notarize an app:

1. Apple scans it for malicious code
2. Apple verifies proper code signing
3. Apple issues a "notarization ticket" if approved
4. Users can install without Gatekeeper warnings

**Without notarization:** Users see scary warnings like "Apple cannot check this app for malicious software"

**With notarization:** Users get a clean, professional installation experience

---

## 📋 Prerequisites

### 1. Apple Developer Account
- **Required:** Paid Apple Developer Program membership ($99/year)
- **Sign up at:** https://developer.apple.com/programs/

### 2. Xcode and Command Line Tools
- **Install:** Download from Mac App Store or https://developer.apple.com/xcode/
- **Verify:**
  ```bash
  xcodebuild -version
  # Should output: Xcode 15.x or later
  ```

### 3. Developer ID Certificates
You need TWO certificates:
1. **Developer ID Application** - For signing the app
2. **Developer ID Installer** - For signing the .pkg package

---

## 🔐 Step 1: Get Developer ID Certificates

### Create Certificates in Apple Developer Portal

1. **Log in to Apple Developer:**
   - Go to https://developer.apple.com/account
   - Sign in with your Apple ID

2. **Navigate to Certificates:**
   - Click "Certificates, Identifiers & Profiles"
   - Click "Certificates" in the left sidebar
   - Click the "+" button to create a new certificate

3. **Create Developer ID Application Certificate:**
   - Select "Developer ID Application"
   - Click "Continue"
   - Follow instructions to create a Certificate Signing Request (CSR)
   - Upload CSR and download certificate
   - Double-click to install in Keychain

4. **Create Developer ID Installer Certificate:**
   - Repeat steps above but select "Developer ID Installer"
   - Download and install in Keychain

### Verify Certificates Installed

```bash
security find-identity -v -p codesigning
```

You should see:
```
1) ABC123... "Developer ID Application: Your Name (TEAMID)"
2) DEF456... "Developer ID Installer: Your Name (TEAMID)"
```

**Note your Team ID** (the code in parentheses) - you'll need it later!

---

## 🔑 Step 2: Create App-Specific Password for Notarization

Apple requires an **app-specific password** (NOT your Apple ID password) for notarization.

### Create App-Specific Password

1. **Go to Apple ID portal:**
   - Visit https://appleid.apple.com
   - Sign in with your Apple ID

2. **Navigate to Security:**
   - Click "Sign-In and Security"
   - Click "App-Specific Passwords"

3. **Generate password:**
   - Click "+" to create new password
   - Enter label: "CueBear Notarization"
   - Click "Create"
   - **IMPORTANT:** Copy the password immediately (format: `xxxx-xxxx-xxxx-xxxx`)
   - You cannot see it again!

### Store Credentials in Keychain (Recommended)

This saves you from entering credentials every time:

```bash
xcrun notarytool store-credentials "cuebear-notarize" \
  --apple-id "your@email.com" \
  --team-id "TEAMID" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

**Replace:**
- `your@email.com` - Your Apple ID email
- `TEAMID` - Your Team ID from Step 1 (like `ABCD123456`)
- `xxxx-xxxx-xxxx-xxxx` - App-specific password from above

**Verify stored:**
```bash
xcrun notarytool history --keychain-profile "cuebear-notarize"
```

If successful, you'll see a list of past submissions (or "No submissions found" if first time).

---

## 🏗️ Step 3: Build and Sign the Installer

Now you're ready to build! Our scripts will:
1. Build CueBear Bridge app
2. Bundle all dylibs and helpers
3. Sign everything with your certificates
4. Create a signed .pkg installer

### Run the Build Script

```bash
cd CueBearBridge/CueBearBridgeInstaller
./scripts/build_pkg.sh
```

**What happens:**
- ✅ Builds app in Release configuration
- ✅ Copies 6 required dylibs to app bundle
- ✅ Copies iproxy helper binary
- ✅ Fixes dylib install names (@rpath)
- ✅ Signs all dylibs with Developer ID
- ✅ Signs helper binary with hardened runtime
- ✅ Signs app with entitlements
- ✅ Creates signed .pkg package
- ✅ Verifies all signatures

**Build time:** ~2-5 minutes

**Output:**
- Package: `dist/CueBearBridge-Installer.pkg`
- Report: `dist/build_report.txt`

### Verify Package Built

```bash
ls -lh dist/CueBearBridge-Installer.pkg
```

You should see a file ~10-20 MB in size.

---

## ☁️ Step 4: Notarize with Apple

Now submit the signed package to Apple for notarization.

### Run the Notarization Script

```bash
./scripts/notarize_pkg.sh dist/CueBearBridge-Installer.pkg
```

**What happens:**
1. **Upload** (~2-5 minutes)
   - Package uploaded to Apple servers
   - Progress shown in terminal

2. **Scanning** (~5-15 minutes)
   - Apple scans for security issues
   - Script waits for completion
   - You'll see "Waiting for processing..."

3. **Stapling** (~10 seconds)
   - If approved, ticket is downloaded
   - Ticket is stapled to package
   - Creates `CueBearBridge-Installer-notarized.pkg`

**Total time:** Usually 10-20 minutes

**Output:**
- Notarized package: `dist/CueBearBridge-Installer-notarized.pkg`
- Report: `dist/notarization_report.txt`
- Full log: `dist/notarization_log.txt`

### If Notarization Succeeds

You'll see:
```
✅ Notarization succeeded!
✅ Notarization ticket stapled
✅ Ready for distribution
```

**Your package is ready to ship!** 🎉

### If Notarization Fails

Common issues:

**Issue:** "status: Invalid"
- **Cause:** Code signature issue
- **Fix:** Re-run `build_pkg.sh` and check all dylibs are signed
- **Check:** `codesign -vvv --deep dist/CueBearBridge.app`

**Issue:** "Invalid entitlements"
- **Cause:** Entitlements.plist has invalid keys
- **Fix:** Review `Entitlements.plist` against Apple docs
- **Docs:** https://developer.apple.com/documentation/security/hardened_runtime

**Issue:** "iproxy not signed"
- **Cause:** Helper binary missing signature
- **Fix:** Ensure `codesign_app.sh` signs helpers
- **Check:** `codesign -vvv dist/CueBearBridge.app/Contents/Resources/Helpers/iproxy`

**Get detailed error log:**
```bash
cat dist/notarization_error.json
```

---

## 🧪 Step 5: Test the Notarized Package

**IMPORTANT:** Test on a different Mac (or fresh user account) to verify Gatekeeper accepts it!

### Test Installation

1. **Copy package to test Mac:**
   ```bash
   # On test Mac
   scp user@buildmac:path/to/CueBearBridge-Installer-notarized.pkg ~/Downloads/
   ```

2. **Install package:**
   ```bash
   # Double-click or:
   open ~/Downloads/CueBearBridge-Installer-notarized.pkg
   ```

3. **Verify no Gatekeeper warnings:**
   - You should see standard installer UI
   - NO warnings about "unidentified developer"
   - NO "Open anyway" needed in System Settings

4. **Test app launches:**
   ```bash
   # App should be in Applications
   ls /Applications/CueBearBridge.app

   # Launch (should open without warnings)
   open /Applications/CueBearBridge.app
   ```

5. **Test functionality:**
   - Connect iPad via USB
   - Verify Bridge detects iPad
   - Test MIDI communication
   - Check menu bar icon works

### Verify Notarization Status

```bash
# Check stapled ticket
xcrun stapler validate /Applications/CueBearBridge.app

# Check Gatekeeper
spctl -a -vv /Applications/CueBearBridge.app
```

Should output:
```
✅ The validate action worked!
✅ accepted
```

---

## 🚀 Step 6: Distribute to Users

Your notarized package is ready for distribution!

### Distribution Options

#### Option 1: Direct Download (Recommended)
Upload to your website:
```
https://yoursite.com/downloads/CueBearBridge-Installer-notarized.pkg
```

Users download and install - no Gatekeeper warnings!

#### Option 2: DMG Wrapper
Create a DMG for professional presentation:

```bash
# Create DMG temp folder
mkdir dmg_temp
cp dist/CueBearBridge-Installer-notarized.pkg dmg_temp/
cp README.txt dmg_temp/

# Create DMG
hdiutil create -volname "CueBear Bridge" \
  -srcfolder dmg_temp \
  -ov -format UDZO \
  dist/CueBearBridge-1.0.dmg

# Clean up
rm -rf dmg_temp
```

**Note:** DMG itself doesn't need notarization (the .pkg inside is notarized).

#### Option 3: GitHub Releases
Upload to GitHub Releases:
1. Create release tag (e.g., `v1.0.0`)
2. Upload `CueBearBridge-Installer-notarized.pkg`
3. Users download from Releases page

---

## 🔄 Step 7: All-in-One Build Script

For convenience, use the orchestrator script that does everything:

```bash
./build_signed_installer.sh
```

This script:
1. ✅ Checks for certificates
2. ✅ Checks for notarization credentials
3. ✅ Builds and signs package
4. ✅ Submits for notarization
5. ✅ Waits for approval
6. ✅ Staples ticket
7. ✅ (Optional) Creates DMG
8. ✅ Generates reports

**Total time:** ~15-30 minutes (mostly waiting for Apple)

**Interactive:** Prompts for confirmation at key steps

---

## 📊 Build Outputs Summary

After successful build and notarization:

```
CueBearBridgeInstaller/
├── build/
│   ├── CueBearBridge.app          # Signed app bundle
│   └── DerivedData/                # Xcode build artifacts
└── dist/
    ├── CueBearBridge-Installer.pkg           # Signed (pre-notarization)
    ├── CueBearBridge-Installer-notarized.pkg # READY TO SHIP ⭐
    ├── CueBearBridge-1.0.dmg                 # DMG wrapper (optional)
    ├── build_report.txt                      # Build details
    ├── notarization_report.txt               # Notarization details
    └── notarization_log.txt                  # Full Apple response
```

**Distribute this file:** `CueBearBridge-Installer-notarized.pkg`

---

## 🛠️ Troubleshooting

### "No Developer ID certificate found"

**Problem:** Build script can't find certificates

**Solution:**
1. Check certificates installed:
   ```bash
   security find-identity -v -p codesigning
   ```
2. If empty, download and install from https://developer.apple.com/account
3. Double-click downloaded `.cer` files to install in Keychain

### "Keychain profile not found"

**Problem:** Notarization credentials not stored

**Solution:**
```bash
xcrun notarytool store-credentials "cuebear-notarize" \
  --apple-id "your@email.com" \
  --team-id "TEAMID" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

### "Code signature invalid"

**Problem:** App or dylibs not properly signed

**Solution:**
1. Clean build directory:
   ```bash
   rm -rf build dist
   ```
2. Re-run build script:
   ```bash
   ./scripts/build_pkg.sh
   ```
3. Verify all components signed:
   ```bash
   codesign -vvv --deep build/CueBearBridge.app
   ```

### "Notarization failed: Invalid binary"

**Problem:** iproxy helper not signed or has wrong architecture

**Solution:**
1. Check iproxy architecture:
   ```bash
   file Resources/Helpers/iproxy
   # Should show: arm64 and x86_64 (universal)
   ```
2. Re-build iproxy as universal binary if needed
3. Ensure signed:
   ```bash
   codesign -s "Developer ID Application" Resources/Helpers/iproxy
   ```

### "Library not loaded: libxml2.2.dylib"

**Problem:** Dylib install names not fixed

**Solution:**
1. Check install names:
   ```bash
   otool -L build/CueBearBridge.app/Contents/MacOS/CueBearBridge
   ```
2. Should see `@rpath/libxml2.2.dylib`, not absolute paths
3. Re-run codesign script:
   ```bash
   ./scripts/codesign_app.sh build/CueBearBridge.app
   ```

### "App crashes on launch"

**Problem:** Hardened runtime restrictions

**Solution:**
1. Check entitlements:
   ```bash
   codesign -d --entitlements - build/CueBearBridge.app
   ```
2. Verify includes:
   - `com.apple.security.cs.allow-dyld-environment-variables` (for @rpath)
   - `com.apple.security.cs.disable-library-validation` (for bundled libs)
3. Re-sign with correct entitlements

---

## 📚 Helpful Commands Reference

### Code Signing

```bash
# List certificates
security find-identity -v -p codesigning

# Sign app
codesign --sign "Developer ID Application: Name" \
  --timestamp --options runtime \
  --entitlements Entitlements.plist \
  MyApp.app

# Verify signature
codesign -vvv --deep --strict MyApp.app

# Check entitlements
codesign -d --entitlements - MyApp.app
```

### Notarization

```bash
# Store credentials
xcrun notarytool store-credentials "profile-name" \
  --apple-id "email@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"

# Submit package
xcrun notarytool submit MyApp.pkg \
  --keychain-profile "profile-name" \
  --wait

# Check submission status
xcrun notarytool info SUBMISSION-ID \
  --keychain-profile "profile-name"

# Get error log
xcrun notarytool log SUBMISSION-ID \
  --keychain-profile "profile-name" \
  error.json

# Staple ticket
xcrun stapler staple MyApp.pkg

# Verify staple
xcrun stapler validate MyApp.pkg
```

### Gatekeeper

```bash
# Check if app accepted
spctl -a -vv /Applications/MyApp.app

# Check if installer accepted
spctl -a -vv -t install MyInstaller.pkg

# Temporarily disable Gatekeeper (testing only!)
sudo spctl --master-disable
```

### Packages

```bash
# Build package
pkgbuild --root package_root \
  --identifier com.example.app \
  --version 1.0 \
  --install-location /Applications \
  --sign "Developer ID Installer: Name" \
  output.pkg

# Check package signature
pkgutil --check-signature MyApp.pkg

# List package contents
pkgutil --payload-files MyApp.pkg

# Expand package (for inspection)
pkgutil --expand MyApp.pkg expanded/
```

---

## 🔗 Useful Links

- **Apple Developer Portal:** https://developer.apple.com/account
- **App-Specific Passwords:** https://appleid.apple.com
- **Notarization Guide:** https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution
- **Hardened Runtime:** https://developer.apple.com/documentation/security/hardened_runtime
- **Code Signing Guide:** https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/
- **Entitlements Reference:** https://developer.apple.com/documentation/bundleresources/entitlements

---

## ✅ Quick Start Checklist

- [ ] Paid Apple Developer account
- [ ] Xcode and command line tools installed
- [ ] Developer ID Application certificate installed
- [ ] Developer ID Installer certificate installed
- [ ] App-specific password created
- [ ] Notarization credentials stored in keychain
- [ ] All dylibs present in `Resources/Frameworks/`
- [ ] iproxy binary present in `Resources/Helpers/`
- [ ] Run `./build_signed_installer.sh`
- [ ] Wait for notarization (~15 minutes)
- [ ] Test on different Mac
- [ ] Distribute notarized package!

---

## 🎉 You're Ready to Ship!

Once notarized, your CueBear Bridge installer will:
- ✅ Install cleanly on any Mac (macOS 10.15+)
- ✅ No Gatekeeper warnings
- ✅ Professional user experience
- ✅ Apple security verified
- ✅ Ready for public distribution

**Questions?** Check the troubleshooting section or Apple's documentation.

**Happy shipping!** 🚀

---

**Document Version:** 1.0
**Last Updated:** 2025-10-04
**Author:** CueBear Development Team
