# Cue Bear - App Store Shipping Checklist

## ✅ Completed Items

### Core Functionality
- [x] Faders (vertical/horizontal with adjustable direction)
- [x] Buttons (regular and small)
- [x] Toggle buttons
- [x] Grid layout with drag-to-reorder in edit mode
- [x] MIDI sending (CC and Note messages)
- [x] Setlist management
- [x] Library with search
- [x] Project save/load
- [x] WiFi and USB connectivity
- [x] CueBearBridge Mac companion app
- [x] Auto-assign MIDI numbers
- [x] Channel selection (1-16)
- [x] Velocity control
- [x] Global channel mode
- [x] MIDI conflict detection

### Recent Fixes (January 2025)
- [x] Velocity picker implementation
- [x] Simplified MIDI display text (bullet format)
- [x] Project name in menu bar
- [x] Wobble animation fixes
- [x] Resize handle (height-only resizing)
- [x] Edit mode sheet bug (shows "Save" CTA correctly)
- [x] Compiler type-checking optimization

### App Store Requirements
- [x] Privacy policy published (https://cuebear.app/privacy)
- [x] Website live (https://cuebear.app)
- [x] CueBearBridge downloadable from website
- [x] App metadata prepared (see APP_STORE_METADATA.md)
- [x] Bundle ID configured: Omri-Behr.Cue-Bear
- [x] 5 demo projects included

---

## 🔄 Ready for Final Testing

### Critical Testing (Must Pass Before Submission)

#### 1. Core MIDI Functionality
- [x] Test all 5 demo projects load correctly
- [x] Verify MIDI messages send on button tap
- [x] Verify MIDI messages send on fader drag
- [x] Test CC messages (0-127)
- [x] Test Note messages (On/Off)
- [x] Test all 16 MIDI channels
- [xx] Test velocity control (buttons)
- [x] Test toggle buttons (latching behavior)

#### 2. Connection Testing
- [x] USB connection establishes successfully
- [x] WiFi connection establishes successfully
- [x] Auto-reconnect works after connection drop
- [x] App continues running in background
- [x] Connection survives app switching
- [ ] CueBearBridge receives all MIDI messages

#### 3. UI/UX Testing
- [x] Edit mode wobble animation smooth
- [x] Drag-to-reorder controls works
- [x] Resize handle (height-only) works
- [x] **CRITICAL: Tap wobbling control → Edit sheet with "Save" CTA appears**
- [x] Add button/fader shows "Add" CTA correctly
- [x] Control editor auto-assign works
- [x] Library search works
- [x] Setlist reordering works

#### 4. Project Management
- [x] Save project works
- [x] Load project works
- [x] Create new project works
- [xx] Duplicate project works
- [x] Delete project works
- [x] Dirty state tracking works (unsaved changes warning)
- [x] AutoSave on background works

#### 5. Edge Cases
- [x] App handles no internet connection
- [x] App handles CueBearBridge not running
- [x] App handles invalid MIDI assignments
- [x] App handles 100+ cues in setlist
- [x] App handles many controls (30+)
- [x] App survives low memory warning
- [x] App handles rotation (portrait/landscape)

#### 6. Performance
- [x] No lag when dragging faders
- [x] Smooth scrolling in library
- [x] Smooth scrolling in setlist
- [x] No crashes during 5-minute stress test
- [x] Battery drain is reasonable

---

## 📸 Screenshots Needed

### iPad Pro 12.9-inch (2048 x 2732) - **REQUIRED**
- [x] Screenshot 1: Main interface with controls
- [x] Screenshot 2: Setlist view
- [x] Screenshot 3: Control editor
- [x] Screenshot 4: Library with search
- [x] Screenshot 5: Connections status
- [x] Screenshot 6: Demo project in action

**Tips:**
- Use demo projects for visually appealing content
- Show faders at different positions
- Capture in both portrait and landscape
- Consider adding text overlays explaining features

---

## 📋 App Store Connect Setup

### Information Needed
- [ ] App Store listing text (use APP_STORE_METADATA.md)
- [ ] Keywords
- [ ] Support email address
- [ ] Company name
- [ ] Phone number
- [ ] Address
- [ ] Price (or Free)
- [ ] App category: Music
- [ ] Age rating: 4+

### Media Assets
- [ ] App icon (1024x1024, already in project)
- [ ] Screenshots (see section above)
- [ ] Optional: App preview video (15-30 seconds)

---

## 🚀 Build & Archive

### Pre-Submission Checklist
- [ ] All tests passed (see Critical Testing above)
- [ ] Version number set (e.g., 1.0)
- [ ] Build number set (e.g., 1)
- [ ] Signing configured (automatic or manual)
- [ ] Release scheme selected
- [ ] Archive builds successfully
- [ ] No warnings in build log
- [ ] Archive validated in Xcode
- [ ] Archive uploaded to App Store Connect

---

## 📝 Submission Notes

### For App Review Team

**Important:** This app requires the free CueBearBridge companion app running on a Mac to function. Download from cuebear.app.

**How to Test:**
1. Install CueBearBridge on Mac from cuebear.app
2. Launch CueBearBridge
3. Launch Cue Bear on iPad
4. Connect via WiFi (same network) or USB
5. Open any demo project
6. Tap buttons or drag faders
7. Verify MIDI output in CueBearBridge console

**Demo Projects Available:**
- DJ Set - Electronic Night
- Theater Production - Hamilton
- Worship Service - Sunday Morning
- Studio Session - Hip Hop Production
- Live Band - Rock Concert

---

## 🐛 Known Issues (None blocking)

No critical issues remain. App is ready for submission.

---

## 📞 Support Preparation

### Documentation to Create (After Approval)
- [ ] User guide on website
- [ ] Video tutorials
- [ ] FAQ page
- [ ] Troubleshooting guide
- [ ] MIDI setup instructions

### Support Channels
- [ ] Support email setup
- [ ] Website contact form
- [ ] GitHub issues (optional, for feedback)

---

## 🎯 Next Actions

1. **Perform Critical Testing** - Complete all items in "Critical Testing" section
2. **Take Screenshots** - Use demo projects on iPad Pro 12.9"
3. **Create App Store Connect Listing** - Use APP_STORE_METADATA.md
4. **Upload Screenshots** to App Store Connect
5. **Build Archive** in Xcode (Product → Archive)
6. **Validate Archive** in Organizer
7. **Upload to App Store Connect**
8. **Submit for Review**

---

## ⏱️ Timeline Estimate

- Critical testing: 2-3 hours
- Screenshots: 1-2 hours
- App Store Connect setup: 1 hour
- Build & upload: 30 minutes
- **Total: ~5-7 hours of work**

Apple Review: 1-3 days typically

---

## 📄 Related Files

- `APP_STORE_METADATA.md` - Complete metadata for App Store listing
- `cuebear.app/privacy` - Privacy policy (live)
- `cuebear.app` - Marketing website (live)
- Demo projects - Built into app

---

**Last Updated:** January 5, 2025
**App Status:** Ready for final testing and submission
**Blocking Issues:** None
