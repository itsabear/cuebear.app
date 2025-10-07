# 🚀 CueBear Bridge Notarization - Quick Start for Omri

## Your Apple ID: `omribehr@gmail.com`

---

## ✅ Step 1: Get Developer ID Certificates (5 minutes)

### Go to Apple Developer Portal
1. Visit: https://developer.apple.com/account
2. Sign in with Apple ID: **omribehr@gmail.com**
3. Click "Certificates, Identifiers & Profiles"
4. Click "Certificates" in sidebar

### Create Two Certificates

#### Certificate 1: Developer ID Application
1. Click the **+** button
2. Select **"Developer ID Application"**
3. Click **Continue**
4. Follow instructions to create Certificate Signing Request (CSR):
   - Open **Keychain Access** app
   - Menu: **Keychain Access → Certificate Assistant → Request a Certificate**
   - Email: Use your email for **omribehr**
   - Common Name: "Omri Behr" (or your name)
   - Request: **Saved to disk**
   - Click **Continue** and save CSR file
5. Upload CSR file
6. Download certificate (.cer file)
7. **Double-click** downloaded .cer file to install in Keychain

#### Certificate 2: Developer ID Installer
1. Click **+** button again
2. Select **"Developer ID Installer"**
3. Click **Continue**
4. Use the **same CSR file** from before
5. Download certificate
6. **Double-click** to install in Keychain

### Verify Certificates Installed
```bash
security find-identity -v -p codesigning
```

Should show:
```
1) ABC123... "Developer ID Application: Omri Behr (TEAMID)"
2) DEF456... "Developer ID Installer: Omri Behr (TEAMID)"
```

**Note your Team ID** - you'll need it in Step 2!

---

## ✅ Step 2: Create App-Specific Password (2 minutes)

### Get App-Specific Password
1. Visit: https://appleid.apple.com
2. Sign in with: **omribehr@gmail.com**
3. Go to **"Sign-In and Security"**
4. Click **"App-Specific Passwords"**
5. Click **+** to create new password
6. Label: **"CueBear Notarization"**
7. Click **Create**
8. **COPY THE PASSWORD** (format: `xxxx-xxxx-xxxx-xxxx`)
   - ⚠️ You can't see it again!

---

## ✅ Step 3: Store Notarization Credentials (1 minute)

### Run This Command

```bash
xcrun notarytool store-credentials "cuebear-notarize" \
  --apple-id "omribehr@gmail.com" \
  --team-id "2U78NYVLQN" \
  --password "qdxf-yaql-hidh-ruam"
```

**Replace:**
- `YOUR_TEAM_ID` - From Step 1 (like `ABCD123456` - found after creating certificates)
- `xxxx-xxxx-xxxx-xxxx` - App-specific password from Step 2

### Verify Stored
```bash
xcrun notarytool history --keychain-profile "cuebear-notarize"
```

If successful: Shows "No submissions found" or list of past submissions.

---

## ✅ Step 4: Build Signed & Notarized Installer (15-30 minutes)

### Run the Build Script

```bash
cd "/Users/omribehr/Library/CloudStorage/Dropbox/Unsorted items/Cue Bear/CueBearBridge/CueBearBridgeInstaller"
./build_signed_installer.sh
```

### What Happens

**Phase 1: Pre-flight Checks** (~10 seconds)
- ✅ Checks for Xcode
- ✅ Checks for certificates
- ✅ Checks for notarization credentials

**Phase 2: Build & Sign** (~5-10 minutes)
- ✅ Builds app from Xcode
- ✅ Bundles dylibs and iproxy
- ✅ Signs everything with Developer ID
- ✅ Creates installer package

**Phase 3: Notarize** (~10-20 minutes)
- ✅ Uploads to Apple (~2-5 mins)
- ✅ Apple security scan (~5-15 mins)
- ✅ Staples notarization ticket (~10 secs)

**Phase 4: Summary**
- ✅ Shows output files
- ✅ Generates reports
- ✅ Ready to ship!

### What You'll Get

```
dist/
├── CueBearBridge-Installer-notarized.pkg    ⭐ SHIP THIS!
├── build_report.txt
├── notarization_report.txt
└── notarization_log.txt
```

---

## ✅ Step 5: Test the Installer (5 minutes)

### Install Locally
```bash
sudo installer -pkg dist/CueBearBridge-Installer-notarized.pkg -target /
```

### Launch App
```bash
open /Applications/CueBearBridge.app
```

Should launch without any Gatekeeper warnings!

### Verify Notarization
```bash
# Check notarization ticket
xcrun stapler validate /Applications/CueBearBridge.app

# Check Gatekeeper
spctl -a -vv /Applications/CueBearBridge.app
```

Both should show ✅ success!

---

## ✅ Step 6: Distribute! 🎉

Your notarized package is ready to ship!

Upload `dist/CueBearBridge-Installer-notarized.pkg` to:
- Your website
- GitHub Releases
- Direct download link

Users will:
- Download .pkg
- Double-click to install
- **No Gatekeeper warnings!**
- Professional installation experience

---

## 🐛 Troubleshooting

### "No Developer ID certificate found"
→ Go back to Step 1, make sure you **double-clicked** the .cer files to install them

### "Keychain profile not found"
→ Go back to Step 3, run the `xcrun notarytool store-credentials` command

### "Invalid Apple ID or password"
→ Make sure you used your **app-specific password** (NOT your Apple ID password)
→ Generate new one at https://appleid.apple.com

### "Notarization failed"
→ Check `dist/notarization_log.txt` for details
→ Most common: unsigned component, re-run build script

### Still stuck?
→ Read the full guide: `NOTARIZATION_GUIDE.md`
→ Has detailed troubleshooting for every issue

---

## 📝 Your Checklist

- [ ] Step 1: Get Developer ID certificates from https://developer.apple.com/account
- [ ] Step 2: Create app-specific password at https://appleid.apple.com
- [ ] Step 3: Store credentials with `xcrun notarytool store-credentials`
- [ ] Step 4: Run `./build_signed_installer.sh`
- [ ] Step 5: Test installation
- [ ] Step 6: Distribute to users!

---

## ⏱️ Time Estimate

- **Steps 1-3:** ~10 minutes (one-time setup)
- **Step 4:** ~15-30 minutes (automated, mostly waiting for Apple)
- **Step 5:** ~5 minutes (testing)
- **Total:** ~30-45 minutes for first build
- **Future builds:** ~15-30 minutes (Steps 1-3 already done!)

---

## 🎯 Commands Summary

```bash
# 1. Verify certificates installed
security find-identity -v -p codesigning

# 2. Store notarization credentials (replace YOUR_TEAM_ID and password!)
xcrun notarytool store-credentials "cuebear-notarize" \
  --apple-id "omribehr@gmail.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "xxxx-xxxx-xxxx-xxxx"

# 3. Build signed and notarized installer
cd "/Users/omribehr/Library/CloudStorage/Dropbox/Unsorted items/Cue Bear/CueBearBridge/CueBearBridgeInstaller"
./build_signed_installer.sh

# 4. Test installation
sudo installer -pkg dist/CueBearBridge-Installer-notarized.pkg -target /
open /Applications/CueBearBridge.app

# 5. Verify notarization
xcrun stapler validate /Applications/CueBearBridge.app
spctl -a -vv /Applications/CueBearBridge.app
```

---

## 🚀 You're Ready!

Everything is set up and ready to go. Just follow the 6 steps above and you'll have a fully notarized, Apple-approved installer in about 30-45 minutes!

**Questions?** Check the full documentation:
- `NOTARIZATION_GUIDE.md` - Complete guide
- `README_INSTALLER.md` - Quick reference
- `NOTARIZATION_FLOW.md` - Visual flowcharts

**Good luck!** 🎉

---

**Prepared for:** Omri Behr (omribehr@gmail.com)
**Date:** 2025-10-04
**Project:** CueBear Bridge Installer
