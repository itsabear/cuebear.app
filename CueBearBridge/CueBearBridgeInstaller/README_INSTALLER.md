# CueBear Bridge Installer - Quick Reference

## 🚀 Quick Start

### One-Command Build (Recommended)
```bash
cd CueBearBridgeInstaller
./build_signed_installer.sh
```

This will:
1. Build app from Xcode
2. Bundle all dependencies
3. Sign with Developer ID
4. Create installer package
5. Notarize with Apple
6. Generate distribution-ready package

**Time:** ~15-30 minutes (mostly waiting for Apple)

---

## 📁 Files Created

### Scripts (What We Built)
- `build_signed_installer.sh` - **Main orchestrator** (run this!)
- `scripts/build_pkg.sh` - Build and create package
- `scripts/codesign_app.sh` - Sign app and dependencies
- `scripts/notarize_pkg.sh` - Notarize with Apple
- `Entitlements.plist` - Code signing entitlements
- `AGENTS.md` - Technical documentation for AI agents
- `NOTARIZATION_GUIDE.md` - **Complete notarization guide** (read this!)

### Outputs (After Build)
- `dist/CueBearBridge-Installer-notarized.pkg` - **SHIP THIS FILE** ⭐
- `dist/build_report.txt` - Build summary
- `dist/notarization_report.txt` - Notarization summary
- `build/CueBearBridge.app` - Signed app bundle (for testing)

---

## 📋 Prerequisites Checklist

Before running the build:

- [ ] Paid Apple Developer account ($99/year)
- [ ] Xcode installed (`xcodebuild -version`)
- [ ] Developer ID Application certificate
- [ ] Developer ID Installer certificate
- [ ] App-specific password created
- [ ] Notarization credentials stored

### First-Time Setup (One-Time)

#### 1. Install Certificates
1. Go to https://developer.apple.com/account
2. Certificates → Create "Developer ID Application"
3. Certificates → Create "Developer ID Installer"
4. Download and double-click to install

#### 2. Store Notarization Credentials
```bash
xcrun notarytool store-credentials "cuebear-notarize" \
  --apple-id "your@email.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

**Get:**
- App-specific password from: https://appleid.apple.com
- Team ID from: https://developer.apple.com/account

---

## 🛠️ Manual Build Steps

If you want to run steps individually:

### Step 1: Build and Sign Package
```bash
./scripts/build_pkg.sh
```

Output: `dist/CueBearBridge-Installer.pkg`

### Step 2: Notarize with Apple
```bash
./scripts/notarize_pkg.sh dist/CueBearBridge-Installer.pkg
```

Output: `dist/CueBearBridge-Installer-notarized.pkg`

---

## ✅ Verify Build Success

### Check Package Created
```bash
ls -lh dist/CueBearBridge-Installer-notarized.pkg
# Should show ~10-20 MB file
```

### Check Signature
```bash
pkgutil --check-signature dist/CueBearBridge-Installer-notarized.pkg
# Should show: Status: signed by a developer certificate
```

### Check Notarization
```bash
xcrun stapler validate dist/CueBearBridge-Installer-notarized.pkg
# Should show: The validate action worked!
```

---

## 🧪 Testing

### Test on Clean Mac (Recommended)
1. Copy .pkg to different Mac
2. Double-click to install
3. Should install without Gatekeeper warnings
4. Launch from Applications - no warnings
5. Test iPad connection and MIDI

### Quick Local Test
```bash
# Install locally
sudo installer -pkg dist/CueBearBridge-Installer-notarized.pkg -target /

# Launch
open /Applications/CueBearBridge.app

# Verify Gatekeeper accepts
spctl -a -vv /Applications/CueBearBridge.app
```

---

## 🚢 Distribution

Your notarized package is ready to distribute!

### Option 1: Direct Download
Upload `CueBearBridge-Installer-notarized.pkg` to your website.

### Option 2: GitHub Releases
1. Create release (e.g., v1.0.0)
2. Upload `CueBearBridge-Installer-notarized.pkg`
3. Users download and install

### Option 3: DMG Wrapper
Create professional DMG:
```bash
# See build_signed_installer.sh for DMG creation
# Or run the main script and choose "y" when prompted
```

---

## 🐛 Troubleshooting

### "No Developer ID certificate found"
→ Install certificates from https://developer.apple.com/account

### "Keychain profile not found"
→ Run `xcrun notarytool store-credentials` (see above)

### "Notarization failed"
→ Check `dist/notarization_log.txt` for details
→ Most common: unsigned dylib or helper binary

### "Library not loaded"
→ Re-run `./scripts/codesign_app.sh` to fix dylib paths

### Need Help?
→ Read **NOTARIZATION_GUIDE.md** (comprehensive troubleshooting)
→ Check **AGENTS.md** (technical details)

---

## 📚 Documentation

- **NOTARIZATION_GUIDE.md** - Complete step-by-step guide (READ THIS FIRST!)
- **AGENTS.md** - Technical documentation for AI agents
- **README.md** - General installer information
- This file - Quick reference

---

## 🎯 What Gets Bundled

The installer includes:

**App Bundle:**
- CueBearBridge.app (menu bar app)

**Dependencies (6 dylibs):**
- libxml2.2.dylib
- libusbmuxd.4.dylib
- libicudata.77.dylib
- libicuuc.77.dylib
- libimobiledevice-glue.1.dylib
- libplist.3.dylib

**Helper Binary:**
- iproxy (iOS USB proxy)

All components are:
- ✅ Code signed with Developer ID
- ✅ Hardened runtime enabled
- ✅ Notarized by Apple
- ✅ Ready for distribution

---

## 📝 Build Requirements

- **macOS:** 10.15 or later
- **Xcode:** 13.0 or later
- **Disk space:** ~1 GB for build artifacts
- **Internet:** Required for notarization
- **Time:** 15-30 minutes (first build)

---

## 🔄 Rebuilding for Updates

When you update the app:

1. Update version in `scripts/build_pkg.sh` (VERSION variable)
2. Run `./build_signed_installer.sh`
3. New package will be notarized automatically
4. Distribute new `-notarized.pkg` file

---

## ✨ Features

Our installer system provides:

✅ **Professional Installation**
- Standard macOS installer UI
- No Gatekeeper warnings
- Automatic dependency bundling
- Proper code signing

✅ **Apple Notarized**
- Uploaded to Apple
- Security scanned
- Notarization ticket stapled
- Trusted by macOS

✅ **Distribution Ready**
- Works on all Macs (macOS 10.15+)
- No "unidentified developer" warnings
- Clean installation experience
- Professional presentation

---

## 🎉 Success Criteria

After successful build, you should have:

- [x] Package file: `dist/CueBearBridge-Installer-notarized.pkg`
- [x] Package size: ~10-20 MB
- [x] Signature: Developer ID Installer
- [x] Notarization: Approved and stapled
- [x] Gatekeeper: Accepted (`spctl -a` passes)
- [x] Installation: Works without warnings
- [x] Launch: App opens without warnings
- [x] Functionality: iPad connection works

**If all checked: You're ready to ship!** 🚀

---

**Questions?** Check NOTARIZATION_GUIDE.md for detailed help.

**Version:** 1.0
**Created:** 2025-10-04
**Author:** CueBear Development Team
