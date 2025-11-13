# Cue Bear iPad App - Version 1.1.0 Changelog

**Release Date**: [TBD]
**Build**: Development Build

---

## 🎉 Major New Features

### Bluetooth Pedal Support
- **Full Pedal Integration**: Connect any Bluetooth keyboard-style pedal (AirTurn BT500, PageFlip, etc.)
- **Intelligent Mode Detection**: Pedals work differently based on current mode:
  - **Cue Mode**: Up = Previous cue, Down = GO (trigger cued song and advance)
  - **Navigator Mode**: Up/Down navigate and trigger cues
  - **Regular Mode**: Pedals disabled (no accidental triggers)
- **Hands-Free Performance**: Trigger cues without touching the iPad during performances
- **Zero Configuration**: Pedals work automatically when connected via Bluetooth

### MIDI Note Support
- **MIDI Notes in Addition to CC**: Cues can now send MIDI Note messages instead of Control Change
- **Per-Cue MIDI Type**: Choose CC or Note for each cue independently
- **Velocity Control**: Set custom velocity values (0-127) for note messages
- **Smart Display**: MIDI data display shows either "CC #" or "Note #" based on type

### Dummy Cues (No-MIDI Cues)
- **Visual-Only Cues**: Create cues that don't send any MIDI messages
- **Use Cases**: Section headers, reminders, tempo markers, lighting cues
- **Toggle Control**: "Enable MIDI" toggle in cue editor
- **Visual Feedback**: MIDI data badge hidden when MIDI is disabled
- **Full Integration**: Dummy cues work in all modes (Cue, Navigator, Regular+Remote)

### MIDI Filter System
- **Custom CC Filtering**: Exclude specific CC numbers from auto-assignment
- **Preset Filters**:
  - "Common Controls" - Filters modulation, volume, pan, sustain, etc.
  - "None" - No filtering
- **Custom Filters**: Create and save your own filter presets
- **Filter Management**: Edit descriptions, delete custom filters
- **Smart Assignment**: Auto-assigned CCs skip filtered numbers
- **Access**: Settings menu → MIDI Filter

### Duplicate Cue Function
- **Quick Duplication**: Duplicate any cue with one tap
- **Context Menu**: Long-press a cue in edit mode → Duplicate
- **Edit Sheet Button**: "Duplicate Cue" button in cue editor
- **Smart Copying**: Duplicates all properties (name, subtitle, color, MIDI settings, icon)
- **New ID**: Duplicate gets new UUID to avoid conflicts
- **Auto-Naming**: Adds "(copy)" to duplicated cue name

### MIDI Assignment Table
- **Visual Overview**: See all MIDI assignments in one table
- **Sortable Columns**: Sort by name, CC/Note number, channel, or type
- **Quick Navigation**: Tap any row to jump to that cue's editor
- **Bulk Editing**: Change channels for multiple cues
- **Conflict Detection**: Highlights conflicting MIDI assignments
- **Access**: Settings menu → MIDI Assignments

---

## 🎨 UI/UX Enhancements

### Navigator Mode Enhancement
- **Selection Highlighting**: First cue is now automatically highlighted when entering Navigator mode
- **Visual Feedback**: Selection stroke moves when using arrow buttons or tapping cues
- **Smart Navigation**: Tapping any cue triggers it AND updates the visual selection indicator
- **Clearer Icons**: Navigator pill now uses minus/plus symbols instead of up/down arrows

### Enhanced Selected Cue Appearance
- **20% Taller**: Selected/cued cues are now 103pt tall (up from 86pt)
- **Larger Text**:
  - Title: 22pt → 28pt
  - Subtitle: footnote → headline
- **More Padding**: 8pt → 12pt vertical, 4pt → 6pt horizontal
- **Better Separation**: Easier to identify the active cue during performances

### Play Icon Indicators
- **Active Cue**: Blinking play icon with black stroke (matches text color)
- **Previous Cue**: Steady play icon (until a new cue is triggered)
- **Left Position**: Icons appear to the left of cue text
- **Clear Feedback**: Know exactly which cue is active and which was last triggered

### Icon Picker Enhancements
- **More Musical Icons**: Added comprehensive set of musical instrument icons
  - Guitars, piano keys, brass (horns, trumpets)
  - Microphones and vocals
  - Metronomes and rhythm instruments
  - Music notation symbols
  - Audio equipment (speakers, headphones, amplifiers)
- **Fixed Invalid Icons**: Removed SF Symbols that don't exist (like "music.mic.circle", "guitar")
- **Organized by Category**: Icons grouped logically (Strings & Keys, Brass & Winds, Vocals, Rhythm, etc.)
- **Improved Navigation**: "Text Only" option now appears at the top when selected for easier access

### Visual Polish
- **Adaptive Stroke Colors**:
  - Orange cues now show black stroke in light mode, white stroke in dark mode
  - Improved color detection algorithm for orange-ish colors (RGB component analysis)
  - Default orange cues always get adaptive stroke colors for visibility
- **Better Contrast**: Selection strokes are now always visible against cue backgrounds
- **Subtle Top Gradient**: Added a barely noticeable white gradient (50% opacity fading to transparent) starting just below the menu bar for subtle depth
- **Text Field Cursor Color**: Text field cursors now match title bar button color instead of accent color for consistent UI

---

## 🐛 Bug Fixes

### Edit Mode Improvements
- **Persistent Edit Mode**: Adding new cues via the "+" button no longer exits edit mode
- **Workflow Enhancement**: You can now continuously add multiple cues without interruption
- **Duplicate Button Repositioned**: Moved duplicate cue button next to delete button in edit menu for better UX

### Cue Selection & Interaction
- **"Taken By" Chip Fix**: Cues with MIDI conflict warnings ("Taken by...") can now be selected and triggered normally
- **Click-Through**: The conflict chip no longer blocks tap gestures

### Global MIDI Channel Management
- **Channel Backup/Restore**: When toggling Global MIDI Channel on/off, the app now properly saves and restores original channel assignments
- **Dynamic Channel Updates**: Changing the global channel number (e.g., from 1 to 3) now immediately applies to all cues and controls
- **Smart Loading**: Project loading no longer corrupts channel backups

### MIDI Assignment
- **Smart CC Assignment**: New cues now correctly get the lowest available (non-filtered) MIDI CC number
- **Gap Filling**: The app prioritizes filling gaps in CC assignments rather than always starting from CC 0
- **Consistent Behavior**: MIDI assignment works correctly after adding cues, doing other tasks, and returning to add more

### Navigator Mode Fixes
- **Arrow Direction Fix**: Up arrow triggers previous cue, down arrow triggers next cue (corrected)
- **Boundary Protection**: Navigation arrows respect list boundaries (can't go past first/last cue)
- **Index Synchronization**: Tapping cues in Navigator mode properly updates the tracked index

### Side Menu Cleanup
- **Removed Clutter**:
  - Deleted "Delete Current Project" destructive action
  - Removed redundant "Actions" section from Open Projects sheet
  - Cleaner, more focused menu structure

---

## 🔧 Technical Improvements

### Data Model Enhancements
- **Song Model Updates**:
  - Added `kind: MIDIKind` (.cc or .note)
  - Added `note: Int?` for MIDI note number
  - Added `velocity: Int` for note velocity (default: 127)
  - Added `midiEnabled: Bool` for dummy cues (default: true)
  - Backward compatible decoder for old projects
- **MIDI Filter Storage**: Custom filters saved with project
- **Conflict Detection**: Improved caching and performance

### Code Quality
- **Color Similarity Detection**:
  - Replaced generic `isSimilarTo()` with specific RGB component analysis
  - Detects orange-ish colors: `red > 0.6`, `green > 0.3`, `blue < 0.4`, `red > green`
- **State Management**: Added `isLoadingProject` flag to prevent race conditions during project loading
- **Pedal Input Handling**: Centralized keyboard event handling with mode-aware logic

### Performance
- **Optimized Searches**: MIDI CC assignment starts from 0 to find lowest available number efficiently
- **Reduced Complexity**: Removed unnecessary `lastAssignedNumber` tracking in favor of conflict map analysis
- **Lazy Loading**: MIDI table builds data only when needed

---

## 📊 Implementation Statistics

- **Files Modified**: 5+ main files (ContentView.swift, ControlSubviews.swift, Models.swift, ProjectPayload.swift, etc.)
- **Lines Added**: 1000+ lines of new functionality
- **Major Features**: 6 new feature systems
- **Bug Fixes**: 8+ major issues resolved
- **UX Enhancements**: 10+ significant improvements
- **Data Model Changes**: 4 new fields with backward compatibility

---

## 🧪 Testing Checklist

### Bluetooth Pedal Support
- [ ] Connect Bluetooth pedal (AirTurn, PageFlip, etc.)
- [ ] Cue Mode: Up = Previous, Down = GO
- [ ] Navigator Mode: Up/Down navigate and trigger
- [ ] Regular Mode: Pedals don't trigger
- [ ] Pedal works across mode switches

### MIDI Notes
- [ ] Create cue with Note type
- [ ] Set velocity value (0-127)
- [ ] Trigger cue sends Note On + Note Off
- [ ] MIDI display shows "Note #" instead of "CC #"
- [ ] Mix CC and Note cues in same project

### Dummy Cues
- [ ] Disable MIDI in cue editor
- [ ] MIDI data badge hidden
- [ ] Cue triggers but sends no MIDI
- [ ] Works in all modes
- [ ] Save/load preserves setting

### MIDI Filter
- [ ] Open MIDI Filter settings
- [ ] Select "Common Controls" preset
- [ ] Create custom filter
- [ ] Edit custom filter description
- [ ] Delete custom filter
- [ ] Auto-assignment skips filtered CCs

### Duplicate Cue
- [ ] Long-press cue in edit mode → context menu → Duplicate
- [ ] Edit cue → Duplicate button
- [ ] All properties copied correctly
- [ ] New cue gets unique ID
- [ ] Name appends "(copy)"

### MIDI Assignment Table
- [ ] Open MIDI Assignments from settings
- [ ] Sort by name, CC, channel, type
- [ ] Tap row to edit cue
- [ ] Apply global channel changes
- [ ] Conflict warnings visible

### Navigator Mode
- [ ] First cue highlights automatically on entering Navigator mode
- [ ] Up arrow navigates to previous cue (visual + trigger)
- [ ] Down arrow navigates to next cue (visual + trigger)
- [ ] Tapping cue updates selection and triggers
- [ ] Arrows don't go past list boundaries
- [ ] Selection stroke is visible on all cue colors

### Global MIDI Channel
- [ ] Enable global mode → all items use global channel
- [ ] Change global channel number → all items update immediately
- [ ] Disable global mode → original channels restored
- [ ] Load project with global mode → channels preserved correctly
- [ ] Toggle global mode multiple times → no corruption

### Edit Mode
- [ ] Click "+" → add cue → stay in edit mode
- [ ] Add multiple cues in succession → no exit
- [ ] Cues with "Taken by" chip are clickable
- [ ] Selection works through conflict warnings

### Visual
- [ ] Default orange cues: black stroke (light mode), white stroke (dark mode)
- [ ] Custom orange cues: adaptive stroke
- [ ] Other colored cues: orange stroke
- [ ] All strokes visible at 6pt thickness
- [ ] Play icons show on active/previous cues
- [ ] Text field cursors match button color

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
- ✅ New fields have default values for old projects:
  - `kind` defaults to `.cc`
  - `velocity` defaults to `127`
  - `midiEnabled` defaults to `true`
  - `note` defaults to `nil`
- ✅ Global channel toggle now preserves original channels
- ✅ No data migration required

### Breaking Changes
- None

---

## 🔒 Hidden Features

Some features are fully implemented in the codebase but hidden from the UI. See `HIDDEN_FEATURES.md` for details.

**Theme/Appearance System**:
- ✅ Fully functional theme system with multiple themes (Default, Classical, Jazz, Rock, Electronic, Musical Theatre, etc.)
- ✅ Complete UI for theme selection (AppearanceSheet)
- ❌ Hidden from menu (can be re-enabled by uncommenting code in ContentView.swift line ~2490)
- **Files**: `Models/AppTheme.swift`, `Views/AboutAndAppearanceSheets.swift`
- **Reason**: User uncertain about including in v1.1.0 release

---

## 🐞 Known Issues

*None at this time.*

If you encounter any issues, please test with the following scenarios:
1. Adding 20+ cues and checking MIDI assignment
2. Toggling global channel with complex projects
3. Navigator mode with long setlists
4. Cues with custom colors near orange spectrum
5. Bluetooth pedal connectivity across app restarts

---

## 📱 App Store "What's New" Section

### Version 1.1.0 - Major Feature Update

**Major New Features:**
• Bluetooth pedal support - hands-free triggering with AirTurn, PageFlip, and similar devices
• MIDI Note messages - send notes in addition to CC, with velocity control
• Dummy cues - create visual-only cues without MIDI output
• MIDI filter system - customize which CC numbers are auto-assigned
• Duplicate cue function - quickly copy cues with all settings
• MIDI assignment table - view and manage all MIDI assignments in one place

**Navigator Mode Enhancements:**
• Visual selection highlighting with automatic first-cue selection
• Improved navigation with clearer minus/plus icons
• Selected cues are 20% larger with bigger text
• Play icon indicators show active and previously triggered cues

**Bug Fixes:**
• Fixed "Taken by" conflict warnings blocking cue selection
• Corrected navigation arrow directions (up = previous, down = next)
• Improved Global MIDI Channel backup/restore functionality
• Enhanced MIDI CC assignment to fill gaps intelligently
• Better color contrast for visibility in all lighting conditions

**UI Improvements:**
• Expanded icon library with musical instruments and equipment
• Text field cursors match button colors for consistency
• Reorganized icon picker with logical categories
• Cleaner side menu with reduced clutter
• Better edit mode workflow - stays in edit mode when adding cues

**Performance:**
• Optimized MIDI conflict detection
• Faster project loading with improved state management
• Smoother animations throughout the app

---

## 🙏 Acknowledgments

All features and fixes implemented in collaborative development sessions throughout v1.1.0 development cycle.

---

## 📚 Related Documentation

- **Implementation Plan**: `MULTIPLE_CUE_LISTS_IMPLEMENTATION_PLAN.md` (46KB comprehensive guide)
- **Design System**: `DESIGN_SYSTEM.md` (Complete UI/UX specifications)
- **Hidden Features**: `HIDDEN_FEATURES.md` (Documents implemented but UI-hidden features)

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
