# Cue Bear - Hidden Features Documentation

This document tracks features that are fully implemented in the codebase but hidden from the user interface. These features can be re-enabled in the future if needed.

---

## Theme/Appearance System

**Status**: ✅ Fully Implemented & Functional (Hidden from UI as of v1.1.0)

**Decision Date**: 2025-01-08

**Reason for Hiding**: User is uncertain about including the theme feature in the initial release. Feature is complete and working, but access has been removed from the UI to allow for future consideration.

### Implementation Details

#### Files Involved:
1. **Models/AppTheme.swift** - Complete theme system with multiple themes
   - Default theme
   - Classical theme
   - Jazz theme
   - Rock theme
   - Electronic theme
   - Musical Theatre theme
   - And more...

2. **Views/AboutAndAppearanceSheets.swift** - Theme selection UI
   - `AppearanceSheet` - Full theme picker with preview cards
   - `ThemePreviewCard` - Individual theme preview component
   - Live preview as you tap themes
   - Cancel/Done buttons for theme selection

3. **ContentView.swift** - Integration points
   - `@State private var showAppearanceSheet = false` (line 1968)
   - Sheet presentation (line 3078-3080)
   - Menu button (COMMENTED OUT at line 2484-2496)

#### How It Works:
- Theme selection is stored in `@AppStorage("selectedThemeID")`
- Themes define colors, fonts, and visual styling
- The entire app responds to theme changes dynamically
- Themes include:
  - Background colors
  - Title bar colors
  - Button colors
  - Accent colors
  - Default cue colors
  - Font families (different genres use different fonts)
  - Color scheme preferences (light/dark/auto)

#### Current State:
- ✅ All theme logic is active and functional
- ✅ Default theme is applied on app launch
- ✅ Theme persistence works via @AppStorage
- ❌ UI access point is commented out (no menu button)
- ❌ Users cannot change themes

### How to Re-Enable:

To restore theme selection UI access, follow these steps:

1. **Uncomment the menu button** in ContentView.swift (around line 2490-2496):
   ```swift
   sideMenuButton("Appearance...", icon: "paintbrush", action: {
       if isEditing { isEditing = false }
       showAppearanceSheet = true
       closeMenu()
   })
   ```

2. **Optional**: Add documentation to user-facing help/onboarding
3. **Optional**: Update changelog to announce the theme feature

That's it! The feature will be immediately available to users.

### Testing Notes:
- Theme system was fully tested during v1.1.0 development
- All themes render correctly across light/dark modes
- Theme preview sheet works perfectly
- Cancel button properly restores original theme
- No known bugs or issues

### Future Considerations:
- Could add more themes
- Could allow users to create custom themes
- Could add theme import/export
- Could add per-project theme preferences

---

## Notes for Future Development

When considering whether to re-enable this feature:

**Pros:**
- Gives users personalization options
- Different genres/styles feel appropriate for different musical contexts
- Fully implemented with zero technical debt
- No performance impact
- Professional appearance with smooth animations

**Cons:**
- Adds complexity to settings
- May not be essential for core functionality
- Could distract from main MIDI cueing purpose

**Recommendation**: Consider re-enabling once the app has established its core feature set and user base. The theme system adds polish and personalization without compromising functionality.

---

*Last Updated: 2025-01-08*
*Version: 1.1.0*
