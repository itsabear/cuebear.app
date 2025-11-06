# Cue Bear Bridge - Onboarding Feature Preview

This is a preview build of Cue Bear Bridge with the new onboarding feature.

## What's New

### Onboarding Window
- Welcome screen that appears on first launch
- Step 1: Download Cue Bear app from App Store (with QR code placeholder)
- Step 2: Connect via USB or WiFi (with icons)
- "Don't show again" checkbox
- "Getting Started" menu item to reopen the onboarding

## How to Test

1. **Launch the preview app:**
   ```bash
   open "CueBearBridge-Onboarding-Preview.app"
   ```

2. **First launch:**
   - The onboarding window will automatically appear
   - Review the welcome message and instructions
   - Try checking/unchecking "Don't show again"
   - Click "Get Started" to close

3. **Reopen onboarding:**
   - Click the menu bar icon (bear paw)
   - Click "Getting Started"
   - The onboarding window should reappear

4. **Reset to test first-launch again:**
   ```bash
   defaults delete com.cuebear.bridge.clean hasShownOnboarding
   ```

## Files Modified

- `OnboardingWindow.swift` - New file with onboarding UI
- `CueBearBridgeApp.swift` - Added onboarding manager and "Getting Started" menu item

## Features to Note

- Window is 500x600pt
- Clean, modern design with SF Symbols icons
- QR code is currently a placeholder (can be replaced with real App Store QR code)
- "Don't show again" preference persists across launches
- Window is modal-ish (brings app to front)

## Next Steps

After approval:
1. Add real QR code for App Store link
2. Integrate into v1.2.1 release
3. Test on both Intel and Apple Silicon Macs
