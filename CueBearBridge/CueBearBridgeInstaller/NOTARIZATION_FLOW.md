# CueBear Bridge Notarization Process Flow

## Visual Guide to the Complete Build and Notarization Process

---

## 📊 High-Level Overview

```
┌─────────────────┐
│  Prerequisites  │  One-time setup
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Build & Sign   │  5-10 minutes
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Notarize      │  10-15 minutes
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Distribute    │  Ready to ship!
└─────────────────┘
```

---

## 🔧 Phase 1: Prerequisites (One-Time Setup)

```
┌───────────────────────────────────────────────────────────────┐
│                    APPLE DEVELOPER ACCOUNT                     │
│                                                                │
│  Sign up at: https://developer.apple.com/programs/           │
│  Cost: $99/year                                               │
└───────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌───────────────────────────────────────────────────────────────┐
│                  DEVELOPER ID CERTIFICATES                     │
│                                                                │
│  Certificate 1: Developer ID Application                      │
│  └─ Purpose: Sign app, dylibs, helpers                       │
│                                                                │
│  Certificate 2: Developer ID Installer                        │
│  └─ Purpose: Sign .pkg package                                │
│                                                                │
│  Download from: https://developer.apple.com/account           │
│  Install: Double-click .cer files → Keychain                  │
└───────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌───────────────────────────────────────────────────────────────┐
│                  APP-SPECIFIC PASSWORD                         │
│                                                                │
│  Create at: https://appleid.apple.com                         │
│  Format: xxxx-xxxx-xxxx-xxxx                                  │
│  Note: NOT your Apple ID password!                            │
└───────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌───────────────────────────────────────────────────────────────┐
│              STORE NOTARIZATION CREDENTIALS                    │
│                                                                │
│  xcrun notarytool store-credentials "cuebear-notarize" \      │
│    --apple-id "your@email.com" \                              │
│    --team-id "TEAMID" \                                       │
│    --password "xxxx-xxxx-xxxx-xxxx"                           │
│                                                                │
│  Stored in: macOS Keychain                                    │
│  Reusable: Yes (one-time setup)                               │
└───────────────────────────────────────────────────────────────┘
```

---

## 🏗️ Phase 2: Build & Sign (Automated)

```
┌────────────────────────────────────────────────────────────────┐
│                  RUN BUILD SCRIPT                               │
│                                                                 │
│  ./build_signed_installer.sh                                   │
│  or                                                             │
│  ./scripts/build_pkg.sh                                        │
└────────────────────┬───────────────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────────┐
│  STEP 1: Build App with Xcode                                  │
│  ───────────────────────────────────                           │
│  • Compiles CueBearBridge.swift sources                        │
│  • Links frameworks                                             │
│  • Creates .app bundle                                          │
│  • Configuration: Release                                       │
│  • Time: ~2-3 minutes                                           │
│                                                                 │
│  Output: CueBearBridge.app                                     │
└────────────────────┬───────────────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────────┐
│  STEP 2: Bundle Dependencies                                   │
│  ───────────────────────────                                   │
│  Copy to .app/Contents/Frameworks/:                            │
│    ✓ libxml2.2.dylib                                           │
│    ✓ libusbmuxd.4.dylib                                        │
│    ✓ libicudata.77.dylib                                       │
│    ✓ libicuuc.77.dylib                                         │
│    ✓ libimobiledevice-glue.1.dylib                             │
│    ✓ libplist.3.dylib                                          │
│                                                                 │
│  Copy to .app/Contents/Resources/Helpers/:                     │
│    ✓ iproxy (iOS USB proxy binary)                            │
│                                                                 │
│  Time: <1 minute                                                │
└────────────────────┬───────────────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────────┐
│  STEP 3: Fix Dylib Install Names                               │
│  ────────────────────────────────                              │
│  Using install_name_tool:                                      │
│                                                                 │
│  /usr/local/lib/libxml2.2.dylib                                │
│           ↓                                                     │
│  @rpath/libxml2.2.dylib                                        │
│                                                                 │
│  Why? Makes dylibs relocatable in app bundle                   │
│  Time: <1 minute                                                │
└────────────────────┬───────────────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────────┐
│  STEP 4: Sign All Dylibs                                       │
│  ───────────────────────                                       │
│  For each dylib:                                                │
│    codesign --sign "Developer ID Application" \                │
│      --timestamp --options runtime dylib                       │
│                                                                 │
│  Signed:                                                        │
│    ✓ libxml2.2.dylib                                           │
│    ✓ libusbmuxd.4.dylib                                        │
│    ✓ libicudata.77.dylib                                       │
│    ✓ libicuuc.77.dylib                                         │
│    ✓ libimobiledevice-glue.1.dylib                             │
│    ✓ libplist.3.dylib                                          │
│                                                                 │
│  Time: <1 minute                                                │
└────────────────────┬───────────────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────────┐
│  STEP 5: Sign Helper Binaries                                  │
│  ─────────────────────────────                                 │
│  codesign --sign "Developer ID Application" \                  │
│    --timestamp --options runtime iproxy                        │
│                                                                 │
│  Signed:                                                        │
│    ✓ iproxy                                                    │
│                                                                 │
│  Time: <1 minute                                                │
└────────────────────┬───────────────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────────┐
│  STEP 6: Sign Main App Bundle                                  │
│  ─────────────────────────────                                 │
│  codesign --deep --sign "Developer ID Application" \           │
│    --timestamp --options runtime \                             │
│    --entitlements Entitlements.plist \                         │
│    CueBearBridge.app                                           │
│                                                                 │
│  Entitlements applied:                                          │
│    • com.apple.security.cs.allow-dyld-environment-variables    │
│    • com.apple.security.cs.disable-library-validation          │
│    • com.apple.security.network.client                         │
│    • com.apple.security.network.server                         │
│    • com.apple.security.device.usb                             │
│    • com.apple.security.device.audio-input                     │
│                                                                 │
│  Time: <1 minute                                                │
└────────────────────┬───────────────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────────┐
│  STEP 7: Verify All Signatures                                 │
│  ──────────────────────────────                                │
│  codesign --verify --deep --strict CueBearBridge.app           │
│                                                                 │
│  Checks:                                                        │
│    ✓ App signature valid                                       │
│    ✓ All dylibs signed                                         │
│    ✓ All helpers signed                                        │
│    ✓ No unsigned code                                          │
│    ✓ Hardened runtime enabled                                  │
│    ✓ Entitlements present                                      │
│                                                                 │
│  Time: <1 minute                                                │
└────────────────────┬───────────────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────────┐
│  STEP 8: Create Package                                        │
│  ──────────────────────                                        │
│  pkgbuild --root package_root \                                │
│    --identifier com.cuebear.bridge \                           │
│    --version 1.0.0 \                                           │
│    --install-location /Applications \                          │
│    --sign "Developer ID Installer" \                           │
│    CueBearBridge-Installer.pkg                                 │
│                                                                 │
│  Creates:                                                       │
│    • Standard macOS .pkg installer                             │
│    • Installs to /Applications                                 │
│    • Signed with Developer ID Installer                        │
│                                                                 │
│  Time: <1 minute                                                │
│                                                                 │
│  Output: dist/CueBearBridge-Installer.pkg                      │
└────────────────────┬───────────────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────────┐
│  BUILD PHASE COMPLETE                                          │
│  ────────────────────────                                      │
│  ✅ App built                                                  │
│  ✅ Dependencies bundled                                       │
│  ✅ Everything signed                                          │
│  ✅ Package created                                            │
│                                                                 │
│  Total time: 5-10 minutes                                      │
└────────────────────────────────────────────────────────────────┘
```

---

## ☁️ Phase 3: Notarize with Apple (Automated)

```
┌────────────────────────────────────────────────────────────────┐
│                  RUN NOTARIZATION SCRIPT                        │
│                                                                 │
│  ./scripts/notarize_pkg.sh dist/CueBearBridge-Installer.pkg   │
└────────────────────┬───────────────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────────┐
│  STEP 1: Upload Package to Apple                               │
│  ────────────────────────────────                              │
│  xcrun notarytool submit pkg \                                 │
│    --keychain-profile "cuebear-notarize" \                     │
│    --wait                                                       │
│                                                                 │
│  What happens:                                                  │
│    • Package uploaded to Apple servers                         │
│    • Submission ID assigned                                    │
│    • Upload progress shown                                     │
│                                                                 │
│  Package size: ~10-20 MB                                       │
│  Upload time: ~2-5 minutes (depends on connection)             │
└────────────────────┬───────────────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────────┐
│  STEP 2: Apple Security Scan                                   │
│  ───────────────────────────                                   │
│  Status: In Progress                                            │
│  Message: "Waiting for processing..."                          │
│                                                                 │
│  Apple's automated systems:                                     │
│    • Scan for malware                                          │
│    • Check code signatures                                     │
│    • Verify entitlements                                       │
│    • Check hardened runtime                                    │
│    • Analyze dylibs and helpers                                │
│    • Verify certificate chains                                 │
│                                                                 │
│  This is the longest step!                                     │
│  Scan time: ~5-15 minutes (typically ~10 minutes)              │
│                                                                 │
│  Your script waits automatically...                            │
└────────────────────┬───────────────────────────────────────────┘
                     │
                     ▼
         ┌───────────┴───────────┐
         │                       │
         ▼                       ▼
┌─────────────────┐    ┌─────────────────────┐
│   ACCEPTED ✅   │    │   INVALID ❌        │
└────────┬────────┘    └──────────┬──────────┘
         │                        │
         │                        ▼
         │             ┌───────────────────────┐
         │             │  Get Error Log:       │
         │             │  xcrun notarytool log │
         │             │                       │
         │             │  Common issues:       │
         │             │  • Unsigned dylib     │
         │             │  • Bad entitlements   │
         │             │  • Missing hardening  │
         │             └───────────────────────┘
         │                        │
         │                        ▼
         │             [Fix issues and rebuild]
         │
         ▼
┌────────────────────────────────────────────────────────────────┐
│  STEP 3: Staple Notarization Ticket                            │
│  ───────────────────────────────────────────                   │
│  xcrun stapler staple CueBearBridge-Installer.pkg              │
│                                                                 │
│  What happens:                                                  │
│    • Downloads notarization ticket from Apple                  │
│    • Embeds ticket into package                                │
│    • Package can now be verified offline                       │
│                                                                 │
│  Why stapling?                                                  │
│    • Users don't need internet to verify                       │
│    • Faster installation                                       │
│    • Works on isolated networks                                │
│                                                                 │
│  Time: <10 seconds                                              │
└────────────────────┬───────────────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────────┐
│  STEP 4: Verify Notarization                                   │
│  ───────────────────────────                                   │
│  xcrun stapler validate pkg                                    │
│  spctl -a -vv -t install pkg                                   │
│                                                                 │
│  Checks:                                                        │
│    ✓ Ticket present                                            │
│    ✓ Ticket valid                                              │
│    ✓ Gatekeeper accepts                                        │
│    ✓ Ready for distribution                                    │
│                                                                 │
│  Time: <5 seconds                                               │
└────────────────────┬───────────────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────────┐
│  NOTARIZATION COMPLETE                                         │
│  ─────────────────────────                                     │
│  ✅ Package uploaded                                           │
│  ✅ Security scan passed                                       │
│  ✅ Notarization approved                                      │
│  ✅ Ticket stapled                                             │
│  ✅ Gatekeeper verified                                        │
│                                                                 │
│  Output: dist/CueBearBridge-Installer-notarized.pkg            │
│                                                                 │
│  Total time: 10-20 minutes                                     │
└────────────────────────────────────────────────────────────────┘
```

---

## 🚢 Phase 4: Distribution

```
┌────────────────────────────────────────────────────────────────┐
│            YOUR NOTARIZED PACKAGE IS READY!                     │
│                                                                 │
│  File: dist/CueBearBridge-Installer-notarized.pkg              │
│  Size: ~10-20 MB                                                │
│  Status: ✅ Signed, notarized, and ready to ship               │
└────────────────────┬───────────────────────────────────────────┘
                     │
         ┌───────────┼───────────┬─────────────┐
         │           │           │             │
         ▼           ▼           ▼             ▼
┌───────────┐ ┌────────────┐ ┌──────────┐ ┌──────────┐
│  Website  │ │   GitHub   │ │   DMG    │ │  Email   │
│  Upload   │ │  Releases  │ │  Wrapper │ │  Direct  │
└───────────┘ └────────────┘ └──────────┘ └──────────┘
```

---

## 👤 User Installation Experience

```
┌────────────────────────────────────────────────────────────────┐
│  USER DOWNLOADS PACKAGE                                         │
│  ──────────────────────────                                    │
│  • Downloads .pkg file from your site                          │
│  • File appears in Downloads folder                            │
└────────────────────┬───────────────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────────┐
│  USER DOUBLE-CLICKS PACKAGE                                     │
│  ──────────────────────────────────                            │
│  macOS checks:                                                  │
│    1. Code signature ✓                                         │
│    2. Developer ID present ✓                                   │
│    3. Notarization ticket ✓                                    │
│    4. Gatekeeper verification ✓                                │
│                                                                 │
│  Result: Installation proceeds without warnings!               │
└────────────────────┬───────────────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────────┐
│  STANDARD INSTALLER UI                                          │
│  ─────────────────────────                                     │
│  ┌──────────────────────────────────────┐                     │
│  │  Install CueBear Bridge               │                     │
│  │                                       │                     │
│  │  [Introduction]                       │                     │
│  │  [License]                            │                     │
│  │  [Installation Type]                  │                     │
│  │  [Install]                            │                     │
│  │                                       │                     │
│  │  [Cancel]              [Continue]     │                     │
│  └──────────────────────────────────────┘                     │
│                                                                 │
│  No scary warnings!                                             │
│  Clean, professional experience                                │
└────────────────────┬───────────────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────────┐
│  INSTALLATION COMPLETE                                          │
│  ─────────────────────────                                     │
│  • App installed to /Applications/CueBearBridge.app            │
│  • All dylibs in Frameworks folder                             │
│  • iproxy helper in Resources                                  │
│  • LaunchServices notified                                     │
│                                                                 │
│  User can now:                                                  │
│    • Launch from Applications folder                           │
│    • Launch from Spotlight                                     │
│    • Launch from Dock                                          │
│                                                                 │
│  NO additional warnings or confirmations needed!               │
└────────────────────┬───────────────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────────┐
│  APP LAUNCHES                                                   │
│  ────────────────                                              │
│  • No Gatekeeper warning                                       │
│  • Menu bar icon appears                                       │
│  • Ready to connect to iPad                                    │
│  • Clean, professional experience                              │
│                                                                 │
│  ✅ Perfect user experience!                                   │
└────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Complete Timeline

```
┌─────────────────────────────────────────────────────────────────┐
│  Prerequisites Setup (One-Time)                                 │
│  ────────────────────────────────                               │
│  • Create Apple Developer account: 5 minutes                   │
│  • Download certificates: 2 minutes                            │
│  • Create app-specific password: 1 minute                      │
│  • Store credentials: 1 minute                                 │
│  ────────────────────────────────                               │
│  Total: ~10 minutes (only once!)                               │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  Build & Sign (Every Release)                                   │
│  ─────────────────────────────                                  │
│  • Build app: 2-3 minutes                                       │
│  • Bundle dependencies: <1 minute                               │
│  • Fix dylib paths: <1 minute                                   │
│  • Sign components: <1 minute                                   │
│  • Sign app: <1 minute                                          │
│  • Create package: <1 minute                                    │
│  ─────────────────────────────                                  │
│  Total: ~5-10 minutes                                           │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  Notarize with Apple (Every Release)                            │
│  ────────────────────────────────────                           │
│  • Upload: 2-5 minutes                                          │
│  • Apple scan: 5-15 minutes                                     │
│  • Staple ticket: <1 minute                                     │
│  ────────────────────────────────────                           │
│  Total: ~10-20 minutes                                          │
└─────────────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════
  TOTAL TIME PER RELEASE: 15-30 minutes
═══════════════════════════════════════════════════════════════════
```

---

## ✅ What Makes This Work

```
┌────────────────────────────────────────────────────────────────┐
│  CODE SIGNING                                                   │
│  ────────────────────────                                      │
│  • Uses Developer ID certificates                              │
│  • Proves you are verified developer                           │
│  • Required for notarization                                   │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│  HARDENED RUNTIME                                               │
│  ────────────────────────                                      │
│  • Additional security protections                             │
│  • Memory safety                                                │
│  • Library validation                                          │
│  • Required for notarization                                   │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│  ENTITLEMENTS                                                   │
│  ────────────────────────                                      │
│  • Declares capabilities                                       │
│  • USB device access                                            │
│  • Network access                                               │
│  • Audio/MIDI access                                            │
│  • Dylib loading                                                │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│  NOTARIZATION                                                   │
│  ────────────────────────                                      │
│  • Apple security scan                                         │
│  • Malware detection                                            │
│  • Code quality check                                          │
│  • Issues notarization ticket                                  │
│  • Ticket is cryptographically signed                          │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│  GATEKEEPER                                                     │
│  ────────────────────────                                      │
│  • macOS security system                                       │
│  • Checks code signature                                       │
│  • Verifies notarization ticket                                │
│  • Allows installation if all checks pass                      │
└────────────────────────────────────────────────────────────────┘
```

---

**This visual guide shows the complete journey from raw source code to a distribution-ready, Apple-notarized installer package!**

**Questions?** See NOTARIZATION_GUIDE.md for detailed explanations of each step.

---

**Document Version:** 1.0
**Created:** 2025-10-04
**Author:** CueBear Development Team
