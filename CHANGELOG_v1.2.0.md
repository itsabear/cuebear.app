# Cue Bear iPad App - Version 1.2.0 Changelog

**Release Date**: [TBD]
**Build**: Development Build

---

## 🎉 Major New Features

### Multiple Cue Lists Support
- **Multiple Set Lists**: Create and manage multiple cue lists within a single project
- **Quick Switching**: Switch between cue lists with a dedicated pill button in title bar
- **Independent Management**: Each cue list has its own songs and edit mode
- **Visual Feedback**: Current cue list name shown in title (format: "Project - Cue List")
- **Smart Navigation**: Cue list selector only appears when 2+ lists exist

### Song Library System
- **Centralized Library**: All songs stored in a shared library accessible across cue lists
- **Add from Library**: Popover button to add songs from library to active cue list
- **Smart Filtering**:
  - Songs already in cue list shown with checkmark and disabled state
  - Search functionality to quickly find songs
  - Sort by name, date added, or last modified
- **Batch Operations**:
  - Select multiple songs to add at once
  - "Select All" and "Clear" buttons for efficient selection
  - Visual count of selected items
- **Context Menus**: Long-press songs for quick actions (Add/Remove from Cue List, Edit, Delete)

### Control Area Preview Collapse
- **Collapsible Previews**: Preview section in Add/Edit Button/Fader sheets now collapsible
- **Collapsed by Default**: Previews start collapsed to reduce clutter
- **On-Demand Viewing**: Expand preview only when needed during editing

---

## 🎨 UI/UX Enhancements

### Connections Menu Improvements
- **Download Bridge View**: Special view when no bridge detected
  - "Ready to Connect?" welcome message
  - QR code for easy mobile download
  - Direct link to cuebear.app/bridge
  - Automatic display when connections available
- **Removed Icon**: Cleaner title without redundant link icon
- **No Navigation Title**: Streamlined header for better space usage

### Cue List Edit Mode Improvements
- **Better Remove Button Color**: "Remove" button in Select mode now uses theme error color (proper red) instead of pink
- **Theme-Aware Destructive Actions**: All destructive actions use consistent theme colors

---

## 🐛 Bug Fixes

### MIDI Assignments Updates
- **Live Control Updates**: MIDI value changes in MIDI Assignments sheet now immediately update on control buttons/faders
- **Binding Fix**: Changed `controlButtons` to use proper @Binding with array replacement for SwiftUI change detection
- **Visual Refresh**: Enhanced `.id()` modifier to include MIDI parameters (kind, channel, number) for forced view updates

### MIDI Filter System
- **Default Filters Enabled**: All recommended MIDI filters now ON by default (CC 1, 7, 10, 11, 64, 120-127)
- **Conflict Warnings Fixed**: "Taken by" warnings now work correctly in MIDI Assignments sheet
- **Filtered MIDI Warnings**:
  - Edit sheet shows warnings when selecting filtered CC/Note numbers
  - Warnings appear below ownership conflicts: "⚠️ This CC is filtered. Turn off filter to use it."
  - Control buttons/faders display "Filtered CC" or "Filtered Note" badge when using filtered values
  - Combined display when both conflict and filter warnings exist: "Taken by X • Filtered CC"

### USB Bridge Detection
- **False Positive Fix**: USB bridge no longer shows in simulator or on first launch
- **Smart Detection**: Bridge chip only appears after actual connection has been established
- **Persistent Display**: Once connected, USB option stays visible even when using WiFi

---

## 🔧 Technical Improvements

### Data Model Enhancements
- **SetList Arrays**: Each cue list stored independently in `activeSongSets: [[Song]]`
- **Active Index Tracking**: `activeSetIndex` tracks currently selected cue list
- **Library Integration**: Global `songLibrary: [Song]` accessible from all cue lists
- **Backward Compatibility**: Projects load with single cue list if none defined

### State Management
- **Cue List Isolation**: Each cue list maintains its own:
  - Edit mode state
  - Selection state
  - Batch operation state
  - Search text
- **Shared Controls**: Control area buttons/faders shared across all cue lists
- **Smart Defaults**: New projects start with one empty cue list named "Set 1"

### Performance Optimizations
- **Lazy View Updates**: Views only refresh when relevant data changes
- **Efficient Filtering**: Song library filtering optimized for large libraries
- **Cached Computations**: Reduced redundant calculations in MIDI conflict detection

---

## 🔮 Future Roadmap

### Planned for Future Releases
- Cue list reordering (drag to reorder lists)
- Cue list duplication
- Export/import individual cue lists
- Cue list templates
- Color coding for cue lists

---

## 📝 Migration Notes

### Backward Compatibility
- ✅ All changes are backward compatible
- ✅ Existing projects automatically migrate to single cue list structure
- ✅ Song library created from existing cue list on first load
- ✅ No data loss during migration
- ✅ Control buttons/faders preserved exactly as before

### Data Structure Changes
- Projects now store `activeSongSets: [[Song]]` instead of `activeSongs: [Song]`
- New field: `activeSetIndex: Int` for tracking current cue list
- New field: `songLibrary: [Song]` for centralized song storage
- Legacy projects with `activeSongs` auto-convert to `activeSongSets[0]`

---

## 🧪 Testing Checklist

### Multiple Cue Lists
- [ ] Create new cue list
- [ ] Switch between cue lists
- [ ] Rename cue lists
- [ ] Delete cue list (with confirmation)
- [ ] Each cue list maintains independent edit mode
- [ ] Control area shared across all lists

### Song Library
- [ ] Open song library popover
- [ ] Search for songs
- [ ] Add single song to cue list
- [ ] Batch select and add multiple songs
- [ ] Songs in cue list show checkmark and disabled
- [ ] Context menu: Add to Cue List
- [ ] Context menu: Remove from Cue List
- [ ] Context menu: Edit song
- [ ] Context menu: Delete from library

### MIDI Filters
- [ ] Default filters active on new project
- [ ] Conflict warnings show in MIDI Assignments
- [ ] Filtered MIDI warnings show in edit sheet
- [ ] Control buttons display "Filtered CC" badge
- [ ] Combined warnings display correctly

### UI Polish
- [ ] Preview section collapsed by default
- [ ] Preview section expands/collapses smoothly
- [ ] Remove button uses proper red color
- [ ] Download Bridge view appears when no bridge
- [ ] QR code displays correctly
- [ ] USB bridge only shows after connection

### Backward Compatibility
- [ ] Old projects load correctly
- [ ] Single cue list projects work as before
- [ ] Control buttons preserved
- [ ] MIDI settings maintained

---

## 📱 App Store "What's New" Section

### Version 1.2.0 - Multiple Cue Lists & Enhanced MIDI

**Major New Features:**
• Multiple cue lists per project - organize songs into separate sets
• Song library system - centralized song management across cue lists
• Smart MIDI filters - default filters for common controllers (mod wheel, volume, sustain)
• Enhanced MIDI assignments - immediate visual updates when changing values

**UI Improvements:**
• Collapsible preview sections in button/fader editors
• Improved connections menu with download instructions and QR code
• Better visual feedback for destructive actions (proper red colors)
• Cleaner interface with removed redundant elements

**Bug Fixes:**
• MIDI assignment changes now update control buttons/faders immediately
• Filtered MIDI warnings display correctly in all editors
• USB bridge detection no longer shows false positives
• "Taken by" conflict warnings work properly in MIDI settings

**Performance:**
• Optimized view updates for better responsiveness
• Faster MIDI conflict detection
• Smoother cue list switching

---

## 🙏 Acknowledgments

All features and fixes implemented in collaborative development sessions throughout v1.2.0 development cycle.

---

## 📚 Related Documentation

- **Previous Version**: `CHANGELOG_v1.1.0.md`
- **Implementation Plan**: `MULTIPLE_CUE_LISTS_IMPLEMENTATION_PLAN.md`
- **Design System**: `DESIGN_SYSTEM.md`

---

*End of Changelog v1.2.0*
