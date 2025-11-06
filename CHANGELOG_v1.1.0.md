# Cue Bear iPad App - Version 1.1.0 Changelog

**Release Date**: [TBD]
**Build**: Development Build

---

## 🎉 New Features

### Navigator Mode Enhancement
- **Selection Highlighting**: First cue is now automatically highlighted when entering Navigator mode
- **Visual Feedback**: Selection stroke moves when using arrow buttons or tapping cues
- **Smart Navigation**: Tapping any cue triggers it AND updates the visual selection indicator

### Global MIDI Channel Management
- **Channel Backup/Restore**: When toggling Global MIDI Channel on/off, the app now properly saves and restores original channel assignments
- **Dynamic Channel Updates**: Changing the global channel number (e.g., from 1 to 3) now immediately applies to all cues and controls
- **Smart Loading**: Project loading no longer corrupts channel backups

---

## 🐛 Bug Fixes

### Edit Mode Improvements
- **Persistent Edit Mode**: Adding new cues via the "+" button no longer exits edit mode
- **Workflow Enhancement**: You can now continuously add multiple cues without interruption

### Cue Selection & Interaction
- **"Taken By" Chip Fix**: Cues with MIDI conflict warnings ("Taken by...") can now be selected and triggered normally
- **Click-Through**: The conflict chip no longer blocks tap gestures

### Visual & Appearance
- **Adaptive Stroke Colors**:
  - Orange cues now show black stroke in light mode, white stroke in dark mode
  - Improved color detection algorithm for orange-ish colors (RGB component analysis)
  - Default orange cues always get adaptive stroke colors for visibility
- **Better Contrast**: Selection strokes are now always visible against cue backgrounds

### MIDI Assignment
- **Smart CC Assignment**: New cues now correctly get the lowest available (non-filtered) MIDI CC number
- **Gap Filling**: The app prioritizes filling gaps in CC assignments rather than always starting from CC 0
- **Consistent Behavior**: MIDI assignment works correctly after adding cues, doing other tasks, and returning to add more

### Navigator Mode Fixes
- **Arrow Direction Fix**: Up arrow triggers previous cue, down arrow triggers next cue (corrected)
- **Boundary Protection**: Navigation arrows respect list boundaries (can't go past first/last cue)
- **Index Synchronization**: Tapping cues in Navigator mode properly updates the tracked index

---

## 🔧 Technical Improvements

### Code Quality
- **Color Similarity Detection**:
  - Replaced generic `isSimilarTo()` with specific RGB component analysis
  - Detects orange-ish colors: `red > 0.6`, `green > 0.3`, `blue < 0.4`, `red > green`
- **State Management**: Added `isLoadingProject` flag to prevent race conditions during project loading
- **Conflict Cache**: Improved MIDI conflict detection and caching

### Performance
- **Optimized Searches**: MIDI CC assignment starts from 0 to find lowest available number efficiently
- **Reduced Complexity**: Removed unnecessary `lastAssignedNumber` tracking in favor of conflict map analysis

---

## 🎨 UI/UX Polish

### Navigator Mode
- **Visual Consistency**: Selection stroke appears immediately on startup
- **Touch Feedback**: Smooth animations when navigating with arrows or taps
- **Status Clarity**: Current cue is always clearly indicated

### Edit Mode
- **Streamlined Workflow**: Reduced friction when adding multiple cues
- **Better Feedback**: Selection states are more visible and consistent

### Side Menu Cleanup
- **Removed Clutter**:
  - Deleted "Delete Current Project" destructive action
  - Removed redundant "Actions" section from Open Projects sheet
  - Cleaner, more focused menu structure

---

## 📊 Implementation Statistics

- **Files Modified**: 2 main files (ContentView.swift, ControlSubviews.swift)
- **Lines Added**: ~250+ lines of new functionality
- **Bug Fixes**: 6 major issues resolved
- **UX Enhancements**: 4 significant improvements
- **Code Refactors**: 3 architectural improvements

---

## 🧪 Testing Notes

### Recommended Test Cases

#### Navigator Mode
- [ ] First cue highlights automatically on entering Navigator mode
- [ ] Up arrow navigates to previous cue (visual + trigger)
- [ ] Down arrow navigates to next cue (visual + trigger)
- [ ] Tapping cue updates selection and triggers
- [ ] Arrows don't go past list boundaries
- [ ] Selection stroke is visible on all cue colors

#### Global MIDI Channel
- [ ] Enable global mode → all items use global channel
- [ ] Change global channel number → all items update immediately
- [ ] Disable global mode → original channels restored
- [ ] Load project with global mode → channels preserved correctly
- [ ] Toggle global mode multiple times → no corruption

#### Edit Mode
- [ ] Click "+" → add cue → stay in edit mode
- [ ] Add multiple cues in succession → no exit
- [ ] Cues with "Taken by" chip are clickable
- [ ] Selection works through conflict warnings

#### MIDI Assignment
- [ ] Add cues → get sequential CCs (0, 2, 3, 4...)
- [ ] Delete cue with CC 2 → next cue gets CC 2 (fills gap)
- [ ] Filtered CCs (1, 7, 10, 11, 64, 120-127) are skipped
- [ ] Works after closing/reopening add cue sheet

#### Visual
- [ ] Default orange cues: black stroke (light mode), white stroke (dark mode)
- [ ] Custom orange cues: adaptive stroke
- [ ] Other colored cues: orange stroke
- [ ] All strokes visible at 6pt thickness

---

## 🔮 Future Roadmap

### Planned for Future Releases
See `MULTIPLE_CUE_LISTS_IMPLEMENTATION_PLAN.md` for:
- Multiple cue lists per project
- Cue list name editing
- Cue list switching with + button
- Title format: "[Project Name] - [Cue List Name]"

---

## 📝 Migration Notes

### Backward Compatibility
- ✅ All changes are backward compatible
- ✅ Existing projects load without issues
- ✅ Global channel toggle now preserves original channels
- ✅ No data migration required

### Breaking Changes
- None

---

## 🙏 Acknowledgments

All features and fixes implemented in collaborative development session on October 30, 2024.

### Key Contributors
- Feature design and requirements
- Implementation and testing
- Documentation and code review

---

## 📚 Related Documentation

- **Implementation Plan**: `MULTIPLE_CUE_LISTS_IMPLEMENTATION_PLAN.md` (46KB comprehensive guide)
- **Roadmap**: `v1.1.0-roadmap.md`
- **Revert Strategy**: `REVERT_STRATEGY_title_bar_simplification.md`

---

## 🐞 Known Issues

*None at this time.*

If you encounter any issues, please test with the following scenarios:
1. Adding 20+ cues and checking MIDI assignment
2. Toggling global channel with complex projects
3. Navigator mode with long setlists
4. Cues with custom colors near orange spectrum

---

## 📦 Build Information

**Development Environment**:
- Xcode: [Version]
- iOS Deployment Target: 17.0
- Swift: [Version]
- Platform: iPad

**Build Commands**:
```bash
# Clean build
xcodebuild clean -project "Cue Bear/Cue Bear.xcodeproj" -scheme "Cue Bear"

# Build for testing
xcodebuild build -project "Cue Bear/Cue Bear.xcodeproj" -scheme "Cue Bear" -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)'
```

---

*End of Changelog v1.1.0*
