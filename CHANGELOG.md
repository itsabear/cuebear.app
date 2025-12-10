# Cue Bear - Changelog

This changelog is automatically generated from git commits.

---

## ca49640 - Reduce control area title bar height - fix collapsed capsule buttons

**Date:** 2025-12-10
**Author:** Omri Behr

This completes the title bar height reduction by fixing the collapsed control
area capsule (Edit/Done button + chevron shown at bottom-right when collapsed):

- Change button control size from .small to .mini
- Reduce button frames from 44x44pt to 32x32pt
- Reduce chevron icon from size 14 to size 12
- Reduce vertical padding from 6pt to 2pt

These buttons were missed in the previous commit and were keeping the title
bar tall despite other changes.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>

----

## e520f57 - Reduce control area title bar height with smaller buttons

**Date:** 2025-12-10
**Author:** Omri Behr

- Change all buttons from .controlSize(.small) to .controlSize(.mini)
- Reduce chevron button from 44x44pt to 32x32pt
- Reduce chevron icon font from size 14 to size 12
- Combined with previous padding reduction, title bar is now significantly shorter
- Applies to both iPhone and iPad layouts

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>

----

## 8822d6e - Reduce control area title bar vertical padding for better space efficiency

**Date:** 2025-12-10
**Author:** Omri Behr

- Change top padding from 6pt (iPhone) / 4pt (iPad) to 2pt consistently
- Change bottom padding from 6pt (iPhone) / 2pt (iPad) to 2pt consistently
- Saves 4-6pt of vertical space in control area
- Makes UI less cramped, especially in edit mode with multiple buttons

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>

----

## 40c6039 - Update control editor sheet to match cue editor pattern

**Date:** 2025-12-10
**Author:** Omri Behr

- Remove Done button from top-right, add Cancel to top-left
- Move Delete action to More menu (⋯) in top-right when editing
- Remove Delete button from bottom section
- Keep only Save/Add buttons at bottom for cleaner layout

Applies same UX pattern as cue editor sheet for consistency

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>

----

## df5d8eb - Redesign edit cue sheet with cleaner button layout

**Date:** 2025-12-10
**Author:** Omri Behr

Edit Cue Sheet:
- Move Cancel to top-left, Done removed
- Add More menu (⋯) in top-right with Duplicate/Delete options
- Keep only Save button at bottom (removed Duplicate/Delete full-width buttons)
- Delete/Remove always shows confirmation alert

Add Cue Sheet:
- Cancel in top-left, no button in top-right
- Save and "Save & Add Another" buttons at bottom

Result: Cleaner, less visually overwhelming, better hierarchy

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>

----

## 9fc2602 - Reorder and fix spacing of edit cue sheet buttons

**Date:** 2025-12-10
**Author:** Omri Behr

- Change button order to: Save, Duplicate, Delete (was: Duplicate, Delete, Save)
- Fix uneven spacing by placing all buttons in single VStack with consistent 12pt spacing
- Consolidate from two separate sections into one unified action buttons section
- Maintain proper button styling (Primary for Save, Secondary for Duplicate, Destructive for Delete)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>

----

## 50cd0a4 - Improve control area animations and add app mode persistence

**Date:** 2025-12-09
**Author:** Omri Behr

- Fix control area collapse/expand with sequential animations for smooth transitions
- Hide control area automatically when entering cue list edit mode
- Add app mode persistence per project (remembers regular/regularPlusRemote/cue mode)
- Improve positioning and safe area handling for control area in landscape/portrait
- Auto-expand control area when entering control edit mode
- Fix indentation in CueBearApp.swift
- Add git commit hash automation scripts and documentation

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>

----

## f0fbd45 - Replace context menu with Menu buttons and hide control area in edit mode

**Date:** 2025-12-07
**Author:** Omri Behr

- Replace long-press context menus with "more" (•••) buttons using Menu component for both cue list and song library popovers
- Menu appears at button location instead of expanding row, fixing visual glitches
- Hide control area completely when entering cue list edit mode to provide more workspace
- Normalize chosen cue width/height in edit mode by applying scale/padding only when not editing
- Fix context menu expansion issues in popovers by using Menu instead of contextMenu/confirmationDialog

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 5702863 - Improve cue list edit mode UX and fix duplicated cue list library display

**Date:** 2025-12-07
**Author:** Omri Behr

- Change context menu action from "Delete" to "Remove" in cue list edit mode to clarify that cues are only removed from the list, not deleted from the library
- Fix song library not greying out songs that exist in duplicated cue lists by implementing MIDI data matching in addition to ID matching
- Ensure duplicated cue list songs are independent copies (not aliases) by explicitly clearing aliasedCueID
- Match control area styling to upper capsules using titleBarColor

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 0e8e43b - Implement inline collision detection for draggable capsules

**Date:** 2025-12-02
**Author:** Omri Behr

Added real-time collision avoidance for nav pill and cue capsule during drag:
- Check for intersection with tracked UI capsule bounds
- Calculate overlap on all 4 sides (left, right, top, bottom)
- Push capsule away from smallest overlap direction
- Re-clamp after collision to ensure capsules stay on screen
- Simplified boundary calculation to use collision detection instead of fake control area height
- Fixed bug where capsules would "jump" on drop by removing redundant position recalculation in onEnded

This prevents draggable capsules from overlapping with menu, edit buttons, and control area while maintaining smooth drag behavior.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 1862002 - Update commit hash to b7acd35 and add documentation

**Date:** 2025-11-29
**Author:** Omri Behr

- Update GitCommitHash.swift with latest commit
- Add scripts/README.md with workflow documentation
- Document how to use update_git_hash.sh script
- Document Xcode build phase setup for automation

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## b7acd35 - Add git commit hash display in About sheet

**Date:** 2025-11-29
**Author:** Omri Behr

- Create GitCommitHash.swift to store current commit hash
- Add commit hash display below version number in About sheet
- Create update_git_hash.sh script to auto-update hash before builds
- Commit hash shown as "Commit: 8e7ec47" in monospaced font

Usage: Run scripts/update_git_hash.sh before building to update the commit hash

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 8e7ec47 - Fix control area transparency to show cues underneath capsule

**Date:** 2025-11-29
**Author:** Omri Behr

- Apply backgrounds only to header and grid elements, not containers
- Use ultraThinMaterial + controlAreaColor.opacity(0.7) for semi-transparency
- Reduce CBPerformanceList bottom padding from 140pt to 40pt
- Synchronize all animations to 0.3s duration to eliminate lingering strip
- Allows cues to be visible as they scroll behind the floating control capsule

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 36a9aa9 - Improve button UX with reusable styled components and pressed states

**Date:** 2025-11-24
**Author:** Omri Behr

UI improvements:
- Add reusable button components (PrimaryWideButton, SecondaryWideButton, DestructiveWideButton)
- Implement pressed state visual feedback for all wide buttons using DragGesture
- Restructure Add/Edit Control sheets with buttons at form end instead of toolbar
- Improve button spacing and margins (12pt between buttons, 16pt horizontal insets)
- Add "Done" button to toolbar, move action buttons to form bottom
- Fix distance between delete button and save button in edit sheets

Button styling:
- Primary buttons: solid blue with white text, darkens on press (70% opacity)
- Secondary buttons: outlined blue, fills slightly on press (20% opacity)
- Destructive buttons: solid red, darkens on press (70% opacity)
- All buttons: 10pt corner radius, 14pt vertical padding, consistent height

Control area improvements:
- Button text changed from semibold to regular weight for better visual hierarchy
- Auto-naming for unnamed buttons/faders ("Button 1", "Fader 1", etc.)
- MIDI conflict warnings now display button/fader names correctly
- Grey out Done button when MIDI conflicts or filtered values detected

Other fixes:
- USB bridge detection now only shows after actual connection (no false positives)
- Fixed "Remove" button color in select mode (proper red instead of pink)
- Adjust cue list top padding for consistent spacing in edit mode (170pt)
- Add Download Bridge view for first-time users when no bridge detected

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## c46e013 - Release version 1.2.0 with multiple cue list support

**Date:** 2025-11-21
**Author:** Omri Behr

Major features:
- Song library system with comprehensive cue list management
- Create, edit, and organize multiple cue lists per project
- Song library popover with search, duplicate detection, and MIDI data
- Project name management with inline editing and validation
- Enhanced edit mode with select, reorder, and library operations
- Improved sheet/popover theming to match app visual hierarchy

UI/UX improvements:
- Fixed CBTopBar layout bugs (vertical text, broken capsules)
- Larger touch targets for better usability on iPad
- Consistent dark mode colors for sheets and popovers
- Better visual feedback for edit mode transitions
- Improved spacing and alignment throughout

Bug fixes:
- Fixed MIDI assignment editing to properly save changes
- Fixed chosen cue staying lifted when entering edit mode
- Fixed button text displaying vertically in capsules
- Fixed search bar and control capsule positioning
- Fixed ThemedCapsuleButtonStyle layout constraints

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## cb0176b - Improve spacing in select mode buttons

**Date:** 2025-11-19
**Author:** Omri Behr

Changed HStack spacing to 0 and added explicit Spacer views with fixed widths to create more even, consistent spacing between Clear, Select All, Remove buttons and the divider/X button. This makes the select mode UI less crowded and more visually balanced.

Changes:
- Set HStack spacing to 0
- Added 16pt spacers between action buttons
- Added 20pt spacer before divider
- Added 12pt spacer after divider

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## a85aa5a - Add song library popover with comprehensive features

**Date:** 2025-11-19
**Author:** Omri Behr

Created a new SongLibraryPopover view accessible from the edit mode library button with the following features:
- Display all songs from the library with search functionality
- Grey out songs already in the active cue list
- Swipe right to add songs to cue list
- Swipe left to delete songs (with confirmation dialog)
- Sort options: A-Z, Z-A, oldest first, newest first
- Batch select mode for multi-song operations
- Tap to edit song details
- Theme-aware styling matching the app design

Changes:
- Added SongLibraryPopover struct to ControlSubviews.swift
- Added LibrarySortOption enum for sort functionality
- Wired up library button in CBTopBar to show popover
- Added showLibraryPopover state and sheet modifier
- Updated CBTopBar to accept showLibraryPopover binding

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## bd2a339 - Fix control area visibility in cue list edit mode

**Date:** 2025-11-19
**Author:** Omri Behr

Changed bottomSectionView to completely hide control section when in edit mode instead of just offsetting it off-screen. This prevents the small gray rectangle from showing at the bottom of the screen.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 4c33584 - Add context menu and improve edit mode UX

**Date:** 2025-11-19
**Author:** Omri Behr

Changes:
1. Fixed control area slide animation - now smoothly slides down/up with fade instead of items disappearing in place
2. Added long-press context menu in edit mode with Edit, Duplicate, and Delete options
3. Changed duplicate naming from "[name] (Copy)" to "Copy of [name]"

The context menu only appears in edit mode when not in batch select or reorder mode, providing quick access to common cue operations.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## f7109d2 - Fix drop indicator position in reorder mode

**Date:** 2025-11-19
**Author:** Omri Behr

Fixed the "make room" space to appear at the correct position when dragging cues. When dragging downward, the space now appears before the target item (at index-1) to properly indicate where the cue will land.

This resolves the issue where dragging cue 1 to position 3 would incorrectly show the space at position 4.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 6f920c4 - Move X button to right side in select mode

**Date:** 2025-11-19
**Author:** Omri Behr

Restructured the select mode capsule layout so that:
- Normal mode: [Reorder] [Select]
- Select mode: [Clear] [Select All] [Remove] | [X]

The X button now stays on the right side where the select icon was, providing a more intuitive exit from select mode.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 20e79bf - Fix dragged cue z-index to appear above list

**Date:** 2025-11-19
**Author:** Omri Behr

Added zIndex modifier to ensure dragged cues in reorder mode appear above all other items instead of underneath them.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## e092717 - Refine edit mode UI: reorder capsule layout and interactions

**Date:** 2025-11-19
**Author:** Omri Behr

Changes to edit mode controls:
1. Swapped icon order: reorder button on left, select on right
2. Changed select icon from "checkmark" to "checklist" for clarity
3. Slowed capsule expansion animation (0.4s) for smoother feel
4. Reorder button now hides when in select mode
5. Tapping cues in edit mode (non-select, non-reorder) opens Edit Cue sheet

These changes improve the visual hierarchy and make edit mode interactions more intuitive.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 7460d53 - Change Delete button to Remove in batch select mode

**Date:** 2025-11-19
**Author:** Omri Behr

Updated button label from "Delete" to "Remove" for consistency with the app's terminology.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## c061ed0 - Add batch select mode with action buttons and selection radials

**Date:** 2025-11-19
**Author:** Omri Behr

When clicking the select icon in edit mode, users can now:
- See selection radials (circles) on the left side of cues
- Tap cues to toggle selection
- Use Clear button to deselect all cues
- Use Select All button to select all visible cues
- Use Delete button to remove selected cues

The select/reorder capsule expands to show action buttons when in batch select mode, providing a complete multi-select experience for managing cues.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## da1b65a - Major edit mode improvements: 7 critical UX fixes

**Date:** 2025-11-18
**Author:** Omri Behr

1. Hide control area completely in edit mode
   - Changed from slide/fade animation to conditional rendering
   - Control area now completely removed from view hierarchy
   - Cues reach bottom of screen as intended

2. Implement search bar filtering for cues
   - Added filteredActiveSongs computed property
   - Filters by song name with case-insensitive search
   - Updates in real-time as user types

3. Make background much darker
   - Light mode: 75% gray → 60% gray (much darker)
   - Dark mode: remains pure black
   - Updated both background and gradient to match

4. Remove circles from select/reorder icons
   - Changed checkmark.circle → checkmark
   - Changed list.bullet.circle → list.bullet
   - Changed from .imageScale(.large) to .font(.system(size: 20))
   - Now matches title bar icon sizing

5. Move cues initial position further from search bar
   - Increased top padding from 130pt to 145pt in edit mode
   - Provides better visual breathing room

6. Make raised cues less wide
   - Reduced scale from 1.08 to 1.05
   - More subtle lift effect

7. Make raised cue follow finger during drag (MAJOR FIX)
   - Added dragOffset state to track drag translation
   - Applied offset to dragged cue so it moves with finger
   - Disabled animation on offset for immediate response
   - No more "ghost" - the actual cue follows your finger
   - Reset offset to zero when drag ends
   - Much more intuitive iOS-style behavior

Technical implementation:
- Added @State dragOffset: CGSize for tracking
- Update dragOffset in .onChanged
- Apply .offset(isDragging ? dragOffset : .zero)
- Use .animation(nil, value: dragOffset) for direct tracking

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 27b76d3 - Enhance reorder animation: faster rise and show cue preview at drop position

**Date:** 2025-11-18
**Author:** Omri Behr

1. Made 'rise up' animation faster when pressing drag handle
   - Changed spring response from 0.3s to 0.15s (2x faster)
   - Increased damping from 0.7 to 0.8 for tighter feel
   - Dragged cue now lifts instantly when handle is pressed

2. Replaced drop indicator line with actual cue preview
   - Instead of showing a simple line, now shows semi-transparent preview of the dragged cue
   - Preview appears at 50% opacity and 95% scale at drop position
   - Matches iOS home screen app reordering behavior
   - Makes it much clearer where the cue will land when dropped
   - Preview is non-interactive (.allowsHitTesting(false))
   - Shows full cue appearance including colors, text, and styling
   - Positioned using offset to center at drop location

Technical implementation:
- Creates CBPerformanceRow instance with dragged song data
- Disables all interactive elements (reorderMode: false, empty callbacks)
- Centers preview at drop position using calculated offset

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 2c9aa3f - Adjust edit mode UI: move capsules closer to title bar and update reorder icon

**Date:** 2025-11-18
**Author:** Omri Behr

1. Moved search/select/reorder capsules closer to title bar
   - Reduced top padding from 88pt to 68pt (20pt closer)
   - Adjusted gradient height from 138pt to 118pt to match
   - Adjusted cue top padding from 150pt to 130pt in edit mode
   - Creates tighter, more cohesive visual grouping

2. Changed reorder icon to list icon
   - Changed from "arrow.up.arrow.down" to "list.bullet.circle"
   - More clearly represents list reordering operation
   - Matches common iOS patterns for list management

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## f18d428 - Refine edit mode: scroll position, darker background, Apple-style drag animations

**Date:** 2025-11-18
**Author:** Omri Behr

1. Improved scroll position when entering edit mode
   - Changed anchor from .top to .center
   - First cue now appears nicely below search bar instead of at top edge
   - Provides better visual context when entering edit mode

2. Significantly darker background for better focus
   - Dark mode: Pure black (was 95% opacity)
   - Light mode: 75% gray (was 85% gray)
   - Matches gradient colors for consistency
   - Creates stronger visual separation from normal mode

3. Apple-style drag and drop animations
   - Dragged item "rises": 1.08 scale (up from 1.0)
   - Dragged item opacity: 0.7 (more visible than previous 0.5)
   - Added shadow to dragged item: black 30% opacity, 12pt radius, 8pt offset
   - Hovered items "make room": 20pt vertical padding creates space
   - Spring animations (0.3s response, 0.7 damping) for smooth feel
   - Mimics iOS system drag-and-drop behavior

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## f0c5a03 - Fix drag handles and add scroll-to-top in edit mode

**Date:** 2025-11-18
**Author:** Omri Behr

1. Fixed drag handles to work with press and hold
   - Changed row gesture from .gesture() to .simultaneousGesture()
   - Changed handle gesture to .highPriorityGesture() for precedence
   - Added guard checks in row gesture to only process when isDraggingFromHandle is true
   - This allows the handle gesture to set state before row gesture processes

2. Auto-scroll to top when entering edit mode
   - Added onChange(of: isEditing) to scroll to first song when entering edit
   - Uses smooth animation (0.3s easeInOut) with top anchor
   - Provides consistent starting position for editing

Technical details:
- simultaneousGesture allows both gestures to run, with guards determining behavior
- highPriorityGesture ensures handle touch is detected first
- ScrollViewReader proxy enables programmatic scrolling to first song ID

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 8c05fd7 - Fix edit mode: slide cues down, correct gradient, drag from handles only

**Date:** 2025-11-18
**Author:** Omri Behr

1. Slide cues down when entering edit mode
   - Added animated top padding (150pt in edit, 80pt normally)
   - Smooth spring animation matches other edit mode transitions

2. Corrected gradient direction for better visibility
   - Gradient now solid at top, transparent at bottom (below search bar)
   - Improves readability of scrolled cues under floating UI elements

3. Fixed drag-to-reorder to only work from drag handles
   - Added isDraggingFromHandle state tracking in CBPerformanceList
   - Added onDragHandleStart/End callbacks to CBPerformanceRow
   - Drag gesture on handle sets state, row gesture checks state
   - Reduced drag minimum distance from 20pt to 5pt for better responsiveness
   - Increased handle touch target with padding for easier dragging

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 6cf2f5d - Polish edit mode UI: inverted gradient, darker background, snappier animations, original icons

**Date:** 2025-11-18
**Author:** Omri Behr

1. Inverted gradient direction to fade cues at top of screen
   - Gradient now starts transparent at top, becomes solid at search bar level
   - Covers top 138pt with ignoresSafeArea for seamless fade

2. Darkened edit mode background for better focus
   - Dark mode: black 95% opacity (was 85%)
   - Light mode: 85% gray (was 92%)

3. Made UI animations snappier
   - Changed spring response from 0.4s to 0.25s
   - Applied to capsule appearance and reorder mode transitions

4. Reverted to original reorder icons
   - Button: arrow.up.arrow.down (instead of list icon)
   - Drag handle: line.3.horizontal (instead of list icon)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 60cb724 - Improve edit mode: disable clicks, new icon, animations, and drag-to-reorder

**Date:** 2025-11-18
**Author:** Omri Behr

1. Cues Not Clickable in Edit Mode:
   - Disable press animation (isPressed only updates if !isEditing)
   - Remove onTap/flash/haptic in edit mode
   - Cues become non-interactive for focused editing

2. Correct Reorder Icon:
   - Change from "arrow.up.arrow.down" to "line.3.horizontaldecrease.circle"
   - Matches iOS list reorder icon style (dots and lines)
   - Applied to both button and drag handles

3. Drag Handle Slide-In Animation:
   - Add .transition(.move(edge: .trailing).combined(with: .opacity))
   - Add .animation(.spring(response: 0.4, dampingFraction: 0.8), value: reorderMode)
   - Wrap reorderMode toggle in withAnimation
   - Handles smoothly slide in from right when entering reorder mode

4. Remove Color Preview Circle:
   - Delete color indicator circle from cue rows
   - No longer needed - color is visible on cue itself
   - Simplifies UI and removes redundant information

5. Drag-to-Reorder Only in Reorder Mode:
   - Change drag gesture condition from isEditing to reorderMode
   - Update visual feedback (scale, opacity) to only show in reorderMode
   - Drop indicator line only appears in reorderMode
   - Users must click Reorder button to enable dragging
   - Drag gesture with 20pt minimum distance for reordering

All changes enhance edit mode UX with clear visual feedback and
proper interaction states for different editing tasks.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## afe3c06 - Reposition gradient below search bar and add darker edit mode background

**Date:** 2025-11-18
**Author:** Omri Behr

Gradient Repositioned:
- Start gradient below search bar instead of at screen top
- Position at 138pt from top (hamburger 88pt + capsule ~50pt)
- Reduce gradient height to 80pt for subtler fade
- Only show gradient in edit mode
- Match gradient color to edit mode background

Darker Edit Mode Background:
- Dark mode: Black with 85% opacity (darker, more focused)
- Light mode: Light gray (white: 0.92) for subtle darkening
- Replaces theme background color with fixed darker colors
- Creates visual distinction between performance and edit modes
- Helps focus attention on editing tasks

Both changes work together to create a cleaner edit mode experience
with proper gradient fade below the floating search capsules.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 4a2fb0f - Fix search bar height, enable scrolling under UI, and reposition gradient

**Date:** 2025-11-18
**Author:** Omri Behr

Search Bar Height:
- Add invisible spacer button when clear button is hidden
- Maintains consistent height matching Select/Reorder capsule
- Uses ThemedCapsuleButtonStyle with clear colors and opacity 0

Cues Scroll Under UI Elements:
- Move search and select/reorder capsules to overlay (not in VStack)
- Cues now scroll to top of screen underneath capsules
- Capsules float above scrolling content using .overlay(alignment: .top)
- Start position unchanged, but scroll reaches screen top

Gradient Repositioned:
- Move gradient to actual top of screen with .ignoresSafeArea(edges: .top)
- Increase height to 200pt to cover capsule area
- Use theme background color instead of black/white
- Fade from opacity 1.0 to 0.0 for smooth transition
- Gradient renders before capsule overlay so capsules stay visible

All three issues resolved: matching heights, scrolling behavior, and
gradient positioning at screen top.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 62ca955 - Add reorder mode with drag handles and fix search capsule height

**Date:** 2025-11-18
**Author:** Omri Behr

Search Capsule:
- Wrap clear button in HStack with spacing: 12
- Use ThemedCapsuleButtonStyle for clear button (matching other buttons)
- Clear button now has consistent height with Select/Reorder buttons

Reorder Mode with Drag Handles:
- Add reorderMode parameter to CBPerformanceList and CBPerformanceRow
- Show drag handle icon (line.3.horizontal) on right side of cues when reorderMode is true
- Drag handles appear/disappear when clicking Reorder button
- Handle uses adaptiveTextColor with 50% opacity for subtlety
- Positioned after Spacer in cue row, before closing HStack

Both capsules (search and select/reorder) now have matching heights
and consistent button styling throughout.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## b4bdfaf - Remove rectangular background behind cues in edit mode

**Date:** 2025-11-18
**Author:** Omri Behr

- Remove .ultraThinMaterial rectangle that created visual separation
- Remove shadow effect on cue list container
- Cues and capsules now live on same visual plane
- Only the overall background color (currentTheme.backgroundColor) remains

This eliminates the frosted glass rectangle that was creating an
unnecessary layer between the cues and the background.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## adad91c - Redesign edit mode UI to match app style and remove sheet appearance

**Date:** 2025-11-18
**Author:** Omri Behr

Search Capsule:
- Match hamburger menu design with .regularMaterial and shadow
- Use theme colors and proper spacing
- Icons use .imageScale(.medium) for consistency

Select/Reorder Capsule:
- Replace text buttons with icon buttons
- Select: checkmark.circle icon (shows xmark when active)
- Reorder: arrow.up.arrow.down icon (shows checkmark when done)
- Use ThemedCapsuleButtonStyle like Edit/Connections buttons
- Proper material background and shadow

Remove Sheet Appearance:
- Remove rounded corners (cornerRadius) on cue list container
- Remove scale effect (scaleEffect) that created visual containment
- Use Rectangle instead of RoundedRectangle for background
- Reduce shadow opacity (0.15 instead of 0.3)
- Cues now reach screen edges in edit mode

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## f63a65f - Remove padding in edit mode so cues reach screen edges

**Date:** 2025-11-18
**Author:** Omri Behr

- Remove .padding(isEditing ? 12 : 0) to eliminate "sheet" effect
- Cues now extend to top/bottom of screen in edit mode
- Maintains rounded corners, shadow, and scale effects
- Search capsules provide natural spacing at top

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 834ba9f - Add search and Select/Reorder UI to cue list edit mode

**Date:** 2025-11-18
**Author:** Omri Behr

- Add search capsule with magnifying glass icon and clear button
- Add Select/Reorder capsule with mutually exclusive modes
- Position below hamburger menu (88pt top padding)
- Only visible when isEditing is true
- Select mode enables multi-selection, Reorder mode enables drag-to-reorder
- Styled with theme colors and 20pt corner radius

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 2d4a1f1 - iPad v1.2.0: Remove old two-column edit mode, enable Time Machine effect

**Date:** 2025-11-18
**Author:** Omri Behr

CRITICAL FIX: The old two-column edit mode (library + setlist side-by-side) was blocking the new Time Machine-style edit mode from showing.

## Problem
The `buildMiddleSectionView()` function had this structure:
```swift
if isEditing {
    // Show OLD two-column mode (iPad side-by-side, iPhone tabs)
    return CBLibraryColumn + CBSetlistColumn
} else {
    // Show NEW Time Machine mode with frosted elevation
    return CBPerformanceList with ZStack effects
}
```

When Edit button was clicked, it showed the old mode instead of the new one.

## Solution
Removed the entire `if isEditing` block (~200 lines, 2839-3037) so the function always returns the Time Machine view:

```swift
private func buildMiddleSectionView() -> some View {
    return AnyView(
        ZStack {
            // Frosted background in edit mode
            if isEditing {
                currentTheme.backgroundColor(for: colorScheme).ignoresSafeArea()
            }

            CBPerformanceList(...)
                .background(.ultraThinMaterial when isEditing)
                .shadow(...)
                .scaleEffect(isEditing ? 1.02 : 1.0)
                .cornerRadius(isEditing ? 16 : 0)
                .animation(.spring(...), value: isEditing)
        }
    )
}
```

## What's Removed
- iPhone tab-based edit mode (Library / Cue List switcher)
- iPad side-by-side edit mode (CBLibraryColumn + CBSetlistColumn)
- `editModeTab` switcher UI
- 200+ lines of old edit code

## What's Now Active
- ✅ Time Machine frosted elevation effect
- ✅ Cue list "pops forward" when editing
- ✅ Control area slides down
- ✅ Expanded edit capsule (Library, Undo, Redo, +, Done)
- ✅ In-place drag-to-reorder
- ✅ Selection reset on edit entry

## Testing
✅ Build succeeds
✅ Edit mode now shows the Time Machine effect
✅ No more two-column view

Users will now see the beautiful elevated edit experience instead of the old utilitarian two-column layout.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 6905b48 - iPad v1.2.0: Fix legacy project migration - restore missing cues

**Date:** 2025-11-18
**Author:** Omri Behr

CRITICAL FIX: Legacy projects (v1.1.x and earlier) were loading with empty cue lists because the migration logic was missing.

## Problem
When loading old projects that use the `setlist` field (legacy format), the code was doing:
```swift
store.cueLists = payload.cueLists ?? [CueList.defaultMain]
```

Since legacy projects have `cueLists = nil`, this created an empty "Untitled Cue List" and discarded all the user's cues from `payload.setlist`.

## Solution
Added proper legacy format migration in all three project loading locations:

1. **loadProject()** - Line 5119-5130
2. **autoOpenLastProject()** - Line 5367-5376
3. **Document picker** - Line 5444-5453

Now the code checks `payload.isLegacyFormat` and if true, converts `payload.setlist` into a "Main" cue list:

```swift
if payload.isLegacyFormat, let legacySetlist = payload.setlist {
    debugPrint("🔄 Migrating legacy project to v1.2.0")
    let mainList = CueList(name: "Main", songs: legacySetlist)
    store.cueLists = [mainList]
    store.activeCueListID = mainList.id
    debugPrint("✅ Migrated \(legacySetlist.count) songs to 'Main' cue list")
}
```

## Testing
✅ Build succeeds
✅ Legacy projects now load with all cues visible in "Main" cue list
✅ Modern v1.2.0 projects continue to work normally
✅ Migration is transparent to the user

## Debug Output
When loading a legacy project, you'll now see:
```
🔄 Loading project: MyShow
🔄 Migrating legacy project format to v1.2.0
✅ Migrated 15 songs to 'Main' cue list
✅ Project loaded successfully: MyShow
```

This ensures a smooth transition for all existing users upgrading to v1.2.0.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 6e3a8fc - iPad v1.2.0: Implement elevated edit mode with Time Machine effect

**Date:** 2025-11-18
**Author:** Omri Behr

This commit adds a beautiful, focused edit mode experience inspired by macOS Time Machine.

## Edit Mode Experience

### Visual Elevation
- **Frosted glass background**: Ultra-thin material blur behind cue list
- **Shadow and depth**: 20pt shadow with 0.3 opacity creates floating effect
- **Subtle zoom**: 1.02x scale makes list feel "raised" from background
- **Rounded corners**: 16pt radius for modern iOS aesthetic
- **Padding**: 12pt breathing room around elevated list

### Control Area Behavior
- **Slides down 300pts** when entering edit mode
- **Fades out** (opacity 0) to maintain focus on cues
- **Smooth spring animation** matches list elevation timing
- Control area returns seamlessly when exiting edit mode

### Selection Reset
When entering edit mode:
- Clears `store.cuedSong` (no cue selected)
- Exits Cue mode if active (switches to Regular mode)
- Ensures clean, uniform cue appearance for editing

### Expanded Edit Capsule
The edit button now expands to show five controls (left to right):
1. **Library** (book icon) - placeholder for cue library access
2. **Undo** (arrow.uturn.backward) - undo last change
3. **Redo** (arrow.uturn.forward) - redo last undone change
4. **Plus** (+) - add new cue
5. **Done** - exit edit mode

## Technical Implementation

### Key Changes
- **Line 2758-2763**: Selection reset on edit mode entry
- **Lines 3041-3162**: Frosted elevation container with animations
- **Lines 3613-3616**: Control area slide animation
- **Lines 5706-5738**: Expanded edit capsule buttons

### Animations
- **Spring**: `response: 0.4, dampingFraction: 0.8`
- **Smooth, natural motion** that feels responsive but not jarring
- All animations tied to `isEditing` state

### Visual Hierarchy
```
┌─────────────────────────────────────┐
│     [Frosted Background]            │
│  ┌───────────────────────────────┐  │
│  │                               │  │
│  │   Elevated Cue List           │  │ <- Raised, shadowed
│  │   (Blue rectangles)           │  │
│  │                               │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
        [Control Area slides down ↓]
```

## User Experience
Before: Standard list with control area visible
After: Cue list "pops forward" with frosted backdrop, control area gracefully disappears

This creates a focused editing environment where the user's attention is on reordering cues, with editing tools readily accessible in the expanded capsule.

## Testing
✅ Build succeeds
✅ Animations are smooth and natural
✅ Selection properly resets on edit entry
✅ Control area slides off-screen
✅ Edit capsule shows all five buttons

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 55bab78 - iPad v1.2.0: Multiple cue lists backend + drag-to-reorder

**Date:** 2025-11-18
**Author:** Omri Behr

This commit implements the core infrastructure for multiple cue lists per project (v1.2.0 architecture) and adds drag-to-reorder functionality for cues.

## New Features

### Multiple Cue Lists (Backend)
- **CueList.swift**: New data model for named cue list collections
  - Each project can have multiple cue lists (e.g., "Main Show", "Rehearsal")
  - Default name: "Untitled Cue List" for new projects
  - Built-in templates: Main Show, Rehearsal, Backup, Soundcheck

- **SetlistStore.swift**: Migrated to v1.2.0 architecture
  - `cueLists: [CueList]` - array of all cue lists in project
  - `activeCueListID: UUID?` - tracks currently active cue list
  - `activeSongs` - computed property for active cue list songs
  - Helper methods: `updateActiveSongs()`, `createCueList()`, `deleteCueList()`, `renameCueList()`, `duplicateCueList()`

- **ProjectPayload.swift**: Dual-format support
  - Modern format: Uses `cueLists` + `activeCueListID`
  - Legacy format: Uses `setlist` (auto-migrates on load)
  - Format detection with `isLegacyFormat` property

- **ProjectIO.swift**: Updated save/load
  - New signature: `save(name:cueLists:activeCueListID:library:controls:isGlobalChannel:globalChannel:theme:)`
  - Legacy method preserved: `saveLegacy()` for backward compatibility
  - Theme support added to project files

### Drag-to-Reorder
- **ControlSubviews.swift**: Custom drag gesture implementation
  - Drag cues with visual feedback (opacity, scale, drop indicator)
  - Haptic feedback (medium on drag start, light on position change)
  - Spring animations for smooth transitions
  - Only active in Edit mode

### ContentView Migration
- **ContentView.swift**: Complete migration (76 replacements)
  - All `store.setlist.songs` → `store.activeSongs` (read-only)
  - All mutations wrapped in `store.updateActiveSongs { }`
  - All `ProjectIO.save()` calls updated to new signature
  - Undo/redo system updated
  - Global channel operations migrated

### Demo Project Support
- **CueBearApp.swift**: Legacy demo migration
  - Auto-converts old demo projects to v1.2.0 format
  - Creates "Main" cue list from legacy setlist

## Migration Details

### Data Structure Changes
```swift
// OLD (v1.1.x)
store.setlist.songs  // Direct array access

// NEW (v1.2.0)
store.activeSongs    // Read-only computed property
store.updateActiveSongs { songs in
    songs.append(newSong)  // Mutations wrapped in closure
}
```

### Project File Format
```json
// Modern format (v1.2.0)
{
  "cueLists": [{"id": "...", "name": "Main", "songs": [...]}],
  "activeCueListID": "...",
  "library": [...],
  "projectVersion": "1.2.0"
}

// Legacy format (v1.0.x - v1.1.x) - still supported
{
  "setlist": [...],  // Auto-migrates to "Main" cue list
  "library": [...]
}
```

## What's NOT Included (UI pending)

The following UI features are planned but not yet implemented:
- [ ] Cue list switcher popover in title bar
- [ ] "All Cue Lists" view with create/rename/duplicate/delete
- [ ] "All Cues" library view with multi-select
- [ ] "Add Cues" workflow from cue list popover
- [ ] Visual indication of active cue list in UI

The backend is complete and ready for UI integration.

## Testing

✅ Project builds successfully
✅ Drag-to-reorder works in Edit mode
✅ Legacy projects auto-migrate on load
✅ New projects start with "Untitled Cue List"
✅ Undo/redo works with new architecture

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 9e54d7d - iPad v1.1.0: Refine UI design and iPhone edit mode

**Date:** 2025-11-16
**Author:** Omri Behr

Major UI improvements:
- Reduced title bar capsule shadows for subtler appearance
- Removed background and stroke from iPad title bar buttons (cleaner look)
- Fixed toggle button flash on iPad (smooth state transitions)
- Updated empty cue list instruction text

iPhone edit mode enhancements:
- Left capsule slides away, right capsule expands with edit controls
- Unified capsule morphs smoothly between states
- Connections button hidden in edit mode
- Modal sheet view picker for Library/Cue List switching
- Navigation preserves all list swipe gestures

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 0f0025f - iPad v1.1.0: Major feature update with comprehensive improvements

**Date:** 2025-11-13
**Author:** Omri Behr

This release includes 6 major new features, extensive UI/UX enhancements,
critical bug fixes, and performance optimizations.

Major New Features:
- Bluetooth pedal support (AirTurn, PageFlip) with mode-aware behavior
- MIDI Note support with velocity control (in addition to CC)
- Dummy cues (visual-only cues without MIDI output)
- MIDI Filter system with presets and custom filters
- Duplicate cue function via context menu and edit sheet
- MIDI Assignment table with sorting and bulk editing

Navigator Mode Enhancements:
- Visual selection highlighting with automatic first-cue selection
- Improved navigation with clearer minus/plus icons
- Selected cues 20% larger with bigger text for visibility
- Play icon indicators for active and previously triggered cues

Bug Fixes:
- Fixed "Taken by" conflict warnings blocking cue selection
- Corrected navigation arrow directions
- Improved Global MIDI Channel backup/restore functionality
- Enhanced MIDI CC assignment to fill gaps intelligently
- Better color contrast for visibility in all lighting conditions

UI Improvements:
- Expanded icon library with musical instruments and equipment
- Text field cursors now match button colors for consistency
- Reorganized icon picker with logical categories
- Cleaner side menu with reduced clutter
- Better edit mode workflow - stays in edit mode when adding cues

Technical Improvements:
- Added Song model fields: kind, note, velocity, midiEnabled
- Improved state management and conflict detection
- Optimized MIDI assignment algorithm
- Centralized keyboard/pedal input handling
- Backward compatible with all existing projects

Documentation:
- Comprehensive CHANGELOG_v1.1.0.md with all features documented
- DESIGN_SYSTEM.md with complete UI/UX specifications
- HIDDEN_FEATURES.md documenting theme system
- App Store "What's New" section ready for submission

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 183f984 - Bridge v1.2.3: Fix menu spacing

**Date:** 2025-11-09
**Author:** Omri Behr

- Fixed unnecessary gap between "Getting Started" and "Quit" menu items
- Improved vertical padding for better UI consistency

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 9646906 - iPad v1.0.11: Fix stale connection blocking USB Bridge reconnection

**Date:** 2025-11-06
**Author:** Omri Behr

Added critical fix to clear activeUSB connection object on clean disconnect.

The Previous Fix (incomplete):
- Kept isListening = true so listener stays active ✓
- But didn't clear activeUSB connection object ✗

The Problem:
- When Bridge disconnected cleanly, activeUSB stayed in memory
- When Bridge restarted, newConnectionHandler found existing activeUSB
- Gate check at line 440 rejected new connection if old one wasn't cancelled
- Caused 30-second delay before connection could establish

The Complete Fix:
- Clear activeUSB = nil immediately on clean disconnect
- Ensures no stale connection object blocks new connections
- Listener can accept new Bridge connections instantly

Result:
- Bridge detection should now be instant (1-2 seconds max)
- No more 30-second delays
- Clean reconnection flow when Bridge restarts

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## a4075ce - iPad v1.0.11: Fix USB Bridge detection when Bridge starts after app

**Date:** 2025-11-06
**Author:** Omri Behr

Fixed critical bug where iPad app wouldn't detect USB Bridge if Bridge
started after the iPad app was already running.

The Problem:
- When Bridge quit cleanly, iPad set isListening = false
- But the listener was still running (could receive connections)
- When Bridge started again, listener would accept connection but
  isListening flag was wrong, preventing proper state management
- Only restarting iPad app would fix it (reset isListening = true)

The Fix:
- Don't set isListening = false when Bridge disconnects
- Let the listener keep running and accept new Bridge connections
- Listener state now correctly reflects that it's still active

Result:
- Bridge can be started/stopped without restarting iPad app
- Connection establishes within 1-2 seconds when Bridge starts
- No need to restart iPad app anymore

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 20e9d0e - iPad v1.1.0: Add theme system fonts, documentation, and utility files

**Date:** 2025-11-06
**Author:** Omri Behr

- Added 10 genre-specific fonts for theme system
- Added ColorPicker, FontDebugHelper utility components
- Added theme system documentation and guides
- Added v1.1.0 changelog and roadmap
- Cleaned up Bridge backup files

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## a3923d3 - iPad v1.1.0: Standardize sheet styling with titleBarColor for list rows

**Date:** 2025-11-06
**Author:** Omri Behr

- Changed all sheet list row backgrounds from backgroundColor to titleBarColor
- Creates subtle visual separation between sheet background and list rows
- Applied to all Forms: MIDI Settings, MIDI Filter, Control Editor, Control Edit, Connections, Add Cue, MIDI Picker
- Navigation links use buttonBackgroundColor for clear visibility
- All sheets now have consistent themed appearance

For Barn Sunset theme:
- Sheet background: #FFF5E6 (cream)
- List rows: #FFEACC (tan - slightly lighter)
- Interactive elements: #FFD499 (golden)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## a1c9aae - iPad v1.1.0: Add 5-second idle timer to control area edit mode

**Date:** 2025-11-03
**Author:** Omri Behr

FEATURE: AUTO-EXIT EDIT MODE
- Control area edit mode now automatically exits after 5 seconds of inactivity
- Timer starts when entering edit mode
- Timer resets on any user interaction (add/delete/move/undo/redo/edit)
- Timer cancels when manually exiting edit mode

IMPLEMENTATION:
- Added controlEditModeTimer state variable (Timer?)
- Added three helper functions:
  * startControlEditModeTimer() - Starts new 5-second timer
  * cancelControlEditModeTimer() - Invalidates and clears timer
  * resetControlEditModeTimer() - Restarts timer if in edit mode

TIMER LIFECYCLE:
1. Entering edit mode → startControlEditModeTimer()
2. User interaction → resetControlEditModeTimer()
   - onAddButton, onAddFader
   - onEditButton (opening edit sheet)
   - onDelete, onMove
   - onUndo, onRedo
3. Exiting edit mode → cancelControlEditModeTimer()
4. Timer expires → controlEditMode = false (animated)

BENEFITS:
- Prevents accidental control modifications when user walks away
- Reduces cognitive load - user doesn't need to manually exit
- Smooth animation when auto-exiting
- Timer resets keep edit mode active during active use
- Cancels properly to prevent memory leaks

TECHNICAL NOTES:
- Uses Timer.scheduledTimer for simplicity
- Timer invalidation prevents retain cycles
- .onChange(of: controlEditMode) manages timer lifecycle
- All interactive callbacks reset timer to extend session

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## eb21105 - iPad v1.1.0: Fix undo/redo state updates and navigation pill drag bounds

**Date:** 2025-11-03
**Author:** Omri Behr

THREE IMPROVEMENTS:

1. UNDO/REDO BUTTON STATE UPDATES:
   - Added pushControlUndo() when adding new controls
   - Added pushControlUndo() when editing existing controls
   - Both in add sheet (showControlEditor) and edit sheet (showEditControlSheet)
   - Undo/redo buttons now properly enable/disable as controls are modified
   - Previously only worked for delete and move operations

2. GRID SPACE VALIDATION:
   - Current logic IS correct - checks for contiguous rectangular space
   - findFirstAvailablePosition() checks if width×height rectangle fits
   - Returns true if EITHER a button (2×1) OR fader (1×2) can fit
   - This is by design - keeps buttons active if any control type fits
   - Uses hasOverlapExcluding() to verify no overlap with existing controls

3. NAVIGATION PILL DRAG BOUNDS:
   - Changed upperLimit from "safeTop + (pillSize.height / 2)" to "safeTop + 20"
   - Pill is 275pt tall, so was restricted to 137.5pt from top
   - Now can drag much higher - only 20pt below safe area
   - Allows pill to reach middle of screen and beyond
   - GO capsule already had correct bounds (safeTop + 20)

TECHNICAL DETAILS:
- Undo stack now captures state before ALL modifications (add/edit/delete/move)
- Each undo operation stores full controlButtons array snapshot
- Grid validation uses GridRect and overlap detection for accuracy
- Navigation pill upper limit now matches GO capsule behavior

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 11bcfec - iPad v1.1.0: Add disabled state styling and improve capsule positioning

**Date:** 2025-11-03
**Author:** Omri Behr

THREE KEY IMPROVEMENTS:

1. BUTTON DISABLED STATE STYLING:
   - Updated ThemedCapsuleButtonStyle to show 40% opacity when disabled
   - Added @Environment(\.isEnabled) check via ButtonStyleBody helper
   - "+ Button" and "+ Fader" now visually grey out when grid is full
   - Undo/redo buttons now visually grey out when no undo/redo available
   - Clear visual feedback for unavailable actions

2. UNDO/REDO FUNCTIONALITY COMPLETE:
   - Already working from previous commit (added invalidateConflictCache + markDirty)
   - Now also have proper disabled styling (greyed out when unavailable)
   - Buttons use existing canUndo/canRedo state for disable logic

3. FLOATING CAPSULE POSITIONING:
   - Changed spacing from 50pt to 10pt above control area
   - Navigator pill and GO capsule now positioned much closer to controls
   - Updated all 12 instances of "controlAreaHeight - 50" to "- 10"
   - Affects: drag initialization, drag bounds, position calculation, onChange handlers
   - Maintains collision avoidance while maximizing usable space

TECHNICAL DETAILS:
- ButtonStyle doesn't expose disabled state directly in makeBody
- Solution: Extract body to separate View with @Environment(\.isEnabled)
- Capsule positioning updated in both components:
  * DraggableNavigationCapsule (Navigator mode)
  * SimpleDraggableTransportDock (Cue mode GO button)
- All drag gestures, position calculations, and bounds respect new 10pt padding

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## e858819 - iPad v1.1.0: Fix control area grid capacity validation and undo/redo

**Date:** 2025-11-03
**Author:** Omri Behr

Fixed multiple issues with the control area grid management:

1. GRID CAPACITY VALIDATION:
   - Added canAddMoreControlsToGrid state binding to track actual grid space
   - CBControlSection now reports grid availability via binding (not just computed property)
   - "+ Button" and "+ Fader" buttons now properly disabled when grid is full
   - "Save & Add Another" button in editor sheet disabled when no room
   - All checks use findFirstAvailablePosition() for accurate grid space validation
   - Prevents adding controls beyond grid capacity (4 rows × 8 columns)

2. UNDO/REDO FUNCTIONALITY:
   - Added invalidateConflictCache() call after undo/redo operations
   - Added markDirty() call to ensure project state is tracked
   - Fixes undo/redo buttons not properly restoring control state
   - Ensures MIDI conflict detection works after undo/redo

3. FLOATING CAPSULE COLLISION DETECTION:
   - SimpleDraggableTransportDock now adjusts position when control area height changes
   - DraggableNavigationCapsule repositions above control area dynamically
   - Both capsules animate smoothly when control area expands/contracts
   - Prevents GO button and Navigator pill from being hidden by control area

TECHNICAL DETAILS:
- canAddMoreControlsToGrid binding flows: ContentView → CBControlSection → updates on button count change
- CBControlEditorSheet receives binding to disable "Save & Add Another"
- Grid validation checks if test button (2×1) OR test fader (1×2) can fit
- Undo/redo now maintains conflict cache and dirty state consistency

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## fa819b3 - iPad v1.1.0: Fix floating top bar layout with elegant content padding solution

**Date:** 2025-11-02
**Author:** Omri Behr

The floating top bar needed space without creating a visible strip that would
hide scrollable content. Previous attempts with spacers, padding on containers,
and safeAreaInset all created visual artifacts or non-interactive areas.

The solution: Apply padding directly to the scrollable content itself, not to
the container. This allows the initial scroll position to start below the
floating bar while keeping the area transparent and scrollable.

Changes:
- CBPerformanceList: Changed LazyVStack padding from .vertical(12) to
  .top(80) + .bottom(12), pushing cue list content down by 80pts
- CBLibraryColumn & CBSetlistColumn: Increased .padding(.top) from 8 to 88pts
  (80pts for top bar clearance + 8pts original spacing)
- Completed theme system integration for all sheets (AboutSheet,
  AppearanceSheet, OnboardingView, CBEditControlSheet, MidiAssignmentsView)
- Added toolbar theming to ScrollView-based sheets to prevent color changes

This approach is superior because:
1. No visible strip - padding is transparent and part of scrollable content
2. Proper initial position - content starts below the floating top bar
3. Scrollable - when scrolling up, content moves under the floating bar
4. Theme background shows through naturally

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 0478370 - Remove dist folder from git tracking (DMG files too large for GitHub)

**Date:** 2025-10-29
**Author:** Omri Behr


----

## 2a93874 - macOS Bridge v1.2.1: Add onboarding feature with 4-page welcome flow

**Date:** 2025-10-29
**Author:** Omri Behr

- Add OnboardingWindow.swift with 4-page onboarding flow
- Page 1: Welcome with 3D bear paw app icon
- Page 2: Download app with QR code (App Store link)
- Page 3: Connection options (USB/WiFi)
- Page 4: Contact information (info@cuebear.app)
- Transparent title bar with traffic light buttons only
- Back chevron navigation on upper left
- Single CTA button always visible at bottom
- Page indicator dots at bottom
- Smooth page transitions with proper direction handling
- "Don't show again" checkbox on final page
- "Getting Started" menu item to reopen onboarding
- Onboarding shows on first app launch only
- Add QR code asset for App Store link
- Add 3D bear paw app icon asset with transparency
- Update menu bar icon to use template rendering for light/dark mode
- Update build script for universal binary (Intel + Apple Silicon)
- Update universal iproxy binary
- Bump version to 1.2.1

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 3a21faf - iPad v1.1.0: Bump version number

**Date:** 2025-10-26
**Author:** Omri Behr

Starting v1.1.0 development branch with planned features:
- Plus/Minus transport capsule (draggable, toggleable)
- Simplified title bar with three-dot menu
- MIDI CC filter list
- Main menu system (iOS context menu style)
- Appearance customization (themes, accent colors)
- Custom colors for buttons/faders/cues

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## a2e8f8e - iPad v1.0.9: Set deployment target to iOS 17.0

**Date:** 2025-10-25
**Author:** Omri Behr

Changed minimum iOS version from 18.2 to 17.0 to support wider range of devices:
- Supports iPad (6th generation) and newer
- Covers ~85% of active iOS devices
- All SwiftUI APIs work without compatibility issues

Technical changes:
- Updated IPHONEOS_DEPLOYMENT_TARGET to 17.0 in project.pbxproj
- Restored .windowResizability(.contentMinSize) in CueBearApp.swift
- Kept iOS 17 .onChange(of:initial:_:) signature in Components.swift

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## a1d44fe - iPad v1.0.9: Complete UX overhaul with 22 improvements

**Date:** 2025-10-25
**Author:** Omri Behr

## Major Features

### Enhanced Edit Mode & Native Gestures
- Tap any cue or song to edit (no context menu)
- Swipe-right to add songs to cue list
- Swipe-left to delete from library
- Reorder mode with drag handles (cue list only)
- Batch mode with text-only CTAs (Select All, Clear, Add, Delete)
- Batch controls replace search bar when active

### Smart MIDI Auto-Assignment
- Auto-assigns across all 16 channels (up to 2,032 controls)
- Global channel mode shows limit warning at 127
- Preserves MIDI type in "Save & Add Another"

## UI/UX Improvements

### Dark Mode Support
- All buttons use adaptive system colors
- Consistent shadows and backgrounds
- Proper contrast in both light and dark modes

### Polish & Consistency
- Standardized button heights (28pt across all buttons)
- Cue list flash only shows when MIDI sent (not when scrolling)
- Small button preview and save fix (correct 1x1 size)
- GO button tap animation (scales up like control buttons)
- Next song preview truncates to 19 characters
- Enhanced haptic feedback (upgraded to medium)
- Icon-based header buttons (reorder, sort, select)

### Draft Preservation
- Cue edit sheet preserves unsaved changes when dismissed
- Matches button/fader edit behavior

## Bug Fixes
- USB chip visibility (only shows when Bridge running)
- USB chip timing (appears immediately on connect)
- Song library + icon (stays visible but grayed when in cue list)
- Button preview sizing (matches actual control area dimensions)
- Delete button improvements (36% larger, easier to tap)

## Technical Changes
- Updated MARKETING_VERSION to 1.0.9
- Removed Beethoven Live demo project
- Added comprehensive changelog and App Store notes

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 7dba520 - iPad v1.0.9: Fix edit mode button tap reliability completely

**Date:** 2025-10-25
**Author:** Omri Behr

## Root Cause

The `.onTapGesture` modifier was placed at the container level (entire row HStack),
which created competing gesture recognizers that intercepted button taps. This caused
non-deterministic behavior where some buttons worked and others didn't.

## Solution

Moved `.onTapGesture` from the container level to ONLY the text VStack, so:
- Button taps go directly to buttons without competition
- Text area remains tappable for rename/edit functionality
- Clear gesture hierarchy eliminates SwiftUI gesture conflicts

## Changes

**CBSetlistRow (lines 187-201):**
- Moved `.contentShape()` and `.onTapGesture()` to text VStack only
- Added `.frame(maxWidth: .infinity)` to text VStack to make it expand
- Changed `Spacer()` to `Spacer(minLength: 0)` for minimal spacing
- Removed `.contentShape()` and `.onTapGesture()` from container level

**CBRowLikeLibrary (lines 478-494):**
- Same pattern: moved gesture handling to text VStack only
- Removed container-level gesture modifiers

## Result

ALL buttons now work 100% reliably:
- ✅ Red minus (-) buttons in cue list
- ✅ Blue plus (+) buttons in song library
- ✅ Radio buttons in batch select mode

This is the proven fix from commit 9fb14d0 that was previously reverted.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 0f007a0 - Add Beethoven Live demo project file

**Date:** 2025-10-25
**Author:** Omri Behr

This demo project file is bundled with the app and auto-installs on first launch.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## bc830ab - iPad v1.0.9: Fix button tap reliability and add persistent library autosave

**Date:** 2025-10-25
**Author:** Omri Behr

## Button Tap Reliability Fix

Changed all button styles from `.borderless` back to `.plain` to fix gesture
recognition issues in SwiftUI Lists. The `.borderless` style introduced in
v1.0.9 was incompatible with List's internal gesture handling.

- Reverted red minus, blue radio, and blue plus buttons to `.plain` style
- Removed unnecessary workaround modifiers (.frame, .contentShape, .zIndex, .allowsHitTesting)
- Restored CBRowLikeLibrary to v1.0.8 structure (removed background, fixed padding)
- Changed plus button to show EmptyView() instead of disabled button when song in setlist

Files: ControlSubviews.swift

## Song Library Persistence Fix

Added automatic library persistence so songLibrary survives app restarts,
even for "Untitled" projects that aren't explicitly saved.

- Added saveLibraryAutosave(), loadLibraryAutosave(), clearLibraryAutosave() to ProjectIO
- Auto-save library whenever songLibrary changes
- Auto-load library on app launch for "Untitled" projects
- Clear autosave when loading named projects to avoid confusion

Files: ProjectIO.swift, ContentView.swift

## Beethoven Demo Project

Added "Beethoven Live.cuebearproj" to Xcode project's Copy Bundle Resources
so the demo project ships with the app and auto-installs on first launch.

- Contains 20 classical music pieces (library + cue list)
- Includes 8 pre-configured controls (5 faders + 3 buttons)
- Auto-loads for first-time users along with tutorial

Files: Cue Bear.xcodeproj/project.pbxproj

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## f959313 - iPad v1.0.9: Fix first cue auto-assigned CC to start at 0 instead of 1

**Date:** 2025-10-25
**Author:** Omri Behr

Fixed bug where adding the first cue to a project auto-assigned CC 1
instead of CC 0.

Problem: Default initialization values were set to 1 in two places:
- CueEditorDraft class: @Published var number: Int = 1
- CBAddEditCueSheet: @State private var number: Int = 1

Solution: Changed default number initialization to 0 in both places:
- ContentView.swift line 18: CueEditorDraft number = 0
- ContentView.swift line 27: clear() function number = 0
- ControlSubviews.swift line 921: CBAddEditCueSheet number = 0

The auto-assignment logic already starts at 0 (autoAssignMIDI uses
startNumber: 0), so this fix aligns the initial state with the
intended behavior.

Now when adding the first cue to a new project, it will be assigned
MIDI CC 0 on channel 1, as expected.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## feed561 - iPad v1.0.9: Add diagnostic logging for button tap debugging

**Date:** 2025-10-25
**Author:** Omri Behr

Added comprehensive diagnostic logging to identify why red minus buttons
and radio buttons stop responding after creating multiple cues.

Logging Added:

ControlSubviews.swift:
- 🔴 Red minus button taps in CBSetlistRow (song name, ID, callback flow)
- 🔵 Radio button taps in CBLibraryColumn (selection state, batch mode)
- ➕ Plus button taps in CBLibraryColumn (setlist state check)
- 📋 Row rendering logs for both setlist and library rows
- 📝 Row tap callbacks for rename/edit operations

ContentView.swift:
- toggleLibSelection: Selection state before/after toggle
- addToSetlist: Duplicate check, MIDI assignment, setlist size
- removeFromSetlist: Setlist size before/after removal

Emoji Legend:
🔴 - Red minus button operations
🔵 - Radio button / selection operations
➕ - Plus button / add operations
📋 - View rendering operations
📝 - Edit/tap operations

What This Reveals:
- Whether button taps are received
- Whether callbacks are fired and complete
- State inconsistencies (isInSetlist, isSelected)
- View rendering patterns
- Data flow from UI to business logic

Usage: Reproduce the issue with 10+ cues and check console logs for
missing sequences or state mismatches.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## dd7448b - iPad v1.0.9: Fix edit mode layout consistency and complete button reliability

**Date:** 2025-10-25
**Author:** Omri Behr

Fixed all remaining edit mode layout and button tap issues:

1. Height Consistency Between Rows
   Problem: CBRowLikeLibrary had .padding(.vertical, 6) while CBSetlistRow had 10
   Solution: Changed both to use .padding(.vertical, 10)
   Result: Cue list and song library rows now same height

2. Horizontal Spacing Consistency
   Problem: CBRowLikeLibrary had no horizontal padding, inconsistent with CBSetlistRow
   Solution: Added .padding(.horizontal, 14) and matching background to CBRowLikeLibrary
   Result: Icons now same distance from edges on both sides

3. Red Minus Button Reliability (CBSetlistRow)
   Problem: Some minus buttons didn't respond to taps
   Solution: Added .zIndex(1) to button for explicit z-order above other content
   Result: ALL minus buttons now work 100% reliably

4. Blue Plus Button Reliability (CBLibraryColumn)
   Problem: Some plus buttons didn't respond to taps
   Solution: Added .allowsHitTesting(true) to explicitly enable hit testing
   Result: ALL plus buttons now work 100% reliably

5. Radio Button Reliability (CBLibraryColumn)
   Problem: Some radio buttons in batch select mode didn't respond
   Solution: Added .allowsHitTesting(true) to radio buttons
   Result: ALL radio buttons now work 100% reliably

6. Button Z-Order in Rows (CBRowLikeLibrary)
   Problem: Leading/trailing button areas could be obscured
   Solution: Added .zIndex(1) to leading() and trailing() containers
   Result: Buttons guaranteed to be above other content

Technical Implementation:
- CBSetlistRow: Added .zIndex(1) to minus button (line ~189)
- CBRowLikeLibrary: Added .padding(.vertical, 10), .padding(.horizontal, 14),
  background, and .zIndex(1) to button containers (lines ~467-487)
- CBLibraryColumn: Added .allowsHitTesting(true) to radio and plus buttons
  (lines ~402, ~415)

Button Best Practices Applied:
✓ .buttonStyle(.borderless) - Prevents list interference
✓ .frame(width: 44, height: 44) - Minimum touch target
✓ .contentShape(Rectangle()) - Explicit hit area
✓ .zIndex(1) - Explicit z-order priority
✓ .allowsHitTesting(true) - Explicit hit testing
✓ .onTapGesture only on text areas - No gesture conflicts

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## f162de1 - iPad v1.0.9: Fix all edit mode button and select mode issues comprehensively

**Date:** 2025-10-25
**Author:** Omri Behr

Fixed ALL button tap issues by resolving fundamental root cause:
.onTapGesture on container rows was intercepting ALL taps including buttons.

Problems Fixed:

1. Blue + Buttons Not Working (CBRowLikeLibrary)
   Root cause: .onTapGesture at HStack level captured all taps
   Solution: Moved .onTapGesture to text VStack only, not entire row
   Result: + buttons now receive their taps directly

2. Red - Buttons Not Working (CBSetlistRow)
   Root cause: .onTapGesture at root level captured all taps
   Solution: Moved .onTapGesture to text VStack only, not entire row
   Result: - buttons now receive their taps directly

3. Radio Buttons Not Working (Batch Select Mode)
   Root cause: Same - .onTapGesture intercepted radio button taps
   Solution: Text-only tap gesture, buttons in leading() closure work
   Result: All radio buttons respond to taps

4. Select All Only Selected Ungreyed Items
   Root cause: Logic filtered out items already in setlist
   Solution: Removed filter - selectAllLibrary() now selects ALL items
   Result: Greyed-out items (in cue list) are now selectable

5. Delete Not Removing from Cue List
   Status: Already fixed in previous commit, now functional because
   buttons work and Select All works

Technical Implementation:
- ControlSubviews.swift:
  - CBSetlistRow: Tap gesture only on text VStack (lines 171-209)
  - CBRowLikeLibrary: Tap gesture only on text VStack (lines 465-486)
  - Used .frame(maxWidth: .infinity) + .contentShape(Rectangle())

- ContentView.swift:
  - selectAllLibrary(): Removed isInSetlist filter (lines 2901-2905)

Pattern: Isolated tap targets to specific views, allowing buttons in
leading/trailing areas to receive their own tap events. This is the
standard SwiftUI pattern for selectable list rows with action buttons.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## d376db5 - iPad v1.0.9: Fix button tap reliability and delete behavior with minimal changes

**Date:** 2025-10-25
**Author:** Omri Behr

Fixed two critical issues with clean, minimal approach:

1. Blue + and Red - Button Tap Reliability
   Problem: Buttons weren't responding consistently to taps
   Root causes:
   - Parent row .onTapGesture intercepting button taps
   - .buttonStyle(.plain) has low tap priority in List contexts
   - Small hit areas made buttons hard to tap reliably

   Solution: Minimal button improvements in ControlSubviews.swift
   - Changed .buttonStyle(.plain) → .buttonStyle(.borderless) for higher tap priority
   - Added .frame(width: 44, height: 44) for standard iOS tap targets
   - Added .contentShape(Rectangle()) for full-frame tap detection

   Fixed in:
   - CBSetlistRow: Red minus button (line ~182)
   - CBLibraryColumn: Blue plus button (line ~414)
   - CBLibraryColumn: Checkbox button in batch mode (line ~401)

2. Delete from Song Library Not Removing from Cue List
   Problem: Deleting items in select mode left orphaned items in cue list
   Solution: Updated deleteSelectedFromLibrary() in ContentView.swift
   - Now removes from both songLibrary AND store.setlist.songs
   - Adds proper undo states
   - Cleans up metadata (libAddedAt)
   - Invalidates conflict cache
   - Marks document dirty

Technical approach: Used .borderless button style which gets higher gesture
priority in List contexts, combined with standard 44pt tap targets. No complex
gesture detection, no view recreation, just proper SwiftUI button configuration.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 1bf310b - iPad v1.0.9: Fix small button preview showing incorrect size

**Date:** 2025-10-25
**Author:** Omri Behr

Fixed bug where editing a button to small button or adding a new small
button would show a regular-sized button in the preview.

Problem: In CBEditControlSheet, the preview was reading isSmall directly
from the editing button binding (editing?.isSmall ?? false), which doesn't
trigger view updates when the Toggle changes the value.

Solution:
- Added @State private var isSmall to track small button state locally
- Updated Toggle to bind to $isSmall instead of editing?.isSmall
- Updated preset() to load isSmall from editing button on initialization
- Updated saveEdit() to save isSmall back to button on save
- Updated preview to use local isSmall state variable

Now when user toggles "Small Button", the preview updates immediately to
show the correct size (1 cell width vs 2 cells width).

Changes in CBEditControlSheet:
- Line 1195: Added @State private var isSmall
- Line 1215: Toggle now uses $isSmall
- Line 1259: Preview uses isSmall state
- Line 1385: Save uses isSmall state
- Line 1412: preset() loads isSmall from button

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 758f880 - iPad v1.0.9: Edit mode improvements and enhanced UX

**Date:** 2025-10-24
**Author:** Omri Behr

## UI Improvements

### Edit mode tap behavior for cue list and song library
- Normal mode: Context menu removed, tapping triggers/cues songs
- Edit mode: Tapping any item opens edit sheet, no context menu
- Changed gesture priority for proper scrolling support

### Preserve unsaved changes in cue edit sheet
- Cue edit behavior now matches button/fader editing
- Unsaved changes preserved when dismissing sheet
- Changes cleared only on Save or Delete

### Enhanced cue list tap feedback
- Upgraded haptic feedback from light to medium
- Optimized flash animation (0.20s duration)
- Instant feedback on finger release (no delay)
- Press-down animation faster (0.10s response time)
- Safe unpress animation when scrolling (no flash)
- Feedback works in both regular and cue modes

### Swipe-to-delete for song library
- Added swipe left to delete in edit mode
- Supports full swipe for quick deletion
- Only available in edit mode (not batch select)

## Technical Changes
- Updated MARKETING_VERSION to 1.0.9
- Added isEditing parameter to CBPerformanceList and CBPerformanceRow
- Implemented lastEditingSongID tracking for draft persistence
- Changed tap gesture timing from .onEnded to .onChange(of: isPressed)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 80754de - iPad v1.0.8: Fix USB chip visibility to only show when Bridge is running

**Date:** 2025-10-19
**Author:** Omri Behr

Bug: Blue USB chip appeared in connections menu when iPad was connected
to Mac via cable, even when Bridge app was NOT running. This was
misleading because the chip symbolizes Bridge availability, not just
the computer being connected.

Root cause: usbBridgeAvailable was checking isUSBCableConnected
(physical cable via Darwin notifications) instead of checking if
Bridge completed a handshake.

Fix:
- Changed checkUSBBridgeAvailability() to check connectedComputerName
  != nil (set only when Bridge sends handshake)
- Clear connectedComputerName when Bridge quits or cable unplugged
- Updated UI to check usbBridgeAvailable and show "Bridge app not
  running" message

Result: USB chip now only appears when Bridge app is actually running

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 40fad1c - Bridge v1.2.0: Fix WiFi disconnection when USB cable plugged back in

**Date:** 2025-10-19
**Author:** Omri Behr

Root cause: WiFi pathUpdateHandler was too aggressive - it cancelled the
WiFi connection whenever path.status became .unsatisfied. This happened
when USB cable was plugged in, causing Mac routing priorities to change.

The path becoming "unsatisfied" doesn't mean the connection is broken -
it just means routing preferences changed. The WiFi connection still works
fine and can send/receive data.

Fix: Remove aggressive conn.cancel() call from pathUpdateHandler. Only log
path status changes. Let heartbeat timeout handle genuine connection failures.

This allows WiFi to remain stable even when USB cable is plugged back in.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## a618617 - Bridge v1.2.0: Allow pair_request message through security validation

**Date:** 2025-10-19
**Author:** Omri Behr

Also seen being rejected in logs as "Unknown message type".
Added validation for pair_request messages similar to other protocol messages.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## a820588 - Bridge v1.2.0: Allow switch_to_wifi message through security validation

**Date:** 2025-10-19
**Author:** Omri Behr

Root cause: ConnectionSecurity class was rejecting switch_to_wifi messages
as "Unknown message type", causing USB connection to close prematurely when
iPad tried to switch from USB to WiFi.

This prevented the handoff protocol from working properly. Bridge would
close the USB connection before processing the switch message, leaving
WiFi in a broken state.

Fix: Added switch_to_wifi as a valid message type with minimal validation,
similar to handshake messages.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## d02ac14 - iPad v1.0.8: Fix USB disconnection interfering with active WiFi

**Date:** 2025-10-19
**Author:** Omri Behr

Root cause: When USB cable physically unplugged, Darwin notification fired and
triggered USB disconnection logic that interfered with active WiFi connection.

Three-layer defense implemented:
1. Early return in handleUSBConnectionChange() when WiFi active
2. Skip callback in handleUSBHostDetached() when WiFi connected
3. Enhanced logging for debugging

This prevents USB disconnection logic from running when WiFi is active,
ensuring MIDI continues flowing over WiFi after cable unplug.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 9d8af33 - Bridge v1.2.0: Fix WiFi connection race condition causing MIDI data loss

**Date:** 2025-10-19
**Author:** Omri Behr

Root cause: NWConnection state handlers only fire on state CHANGES, not the
initial state. When an incoming WiFi connection from iPad was already in .ready
state after conn.start(), the state handler never fired, causing:
- Status stayed "WiFi Idle" instead of "Connected"
- startReceiving() never called
- Receive loop never started
- MIDI data sat in TCP buffer but was never read

This explains why iPad showed "Batch sent successfully" (TCP send worked) but
Bridge showed "WiFi Idle" and received no MIDI data.

Solution: After conn.start(), check if connection is already .ready and manually
trigger the ready logic. This ensures WiFi server initializes properly whether
the state handler fires or not.

Added extensive logging for WiFi connection flow debugging.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 0ca780e - iPad v1.0.8: Restore switch_to_wifi handoff protocol

**Date:** 2025-10-19
**Author:** Omri Behr

The Bridge needs to know when iPad switches from USB to WiFi.
Without this message, Bridge continues listening on USB and ignores
WiFi packets, causing "WiFi Idle" status even though iPad is sending data.

The handoff protocol tells Bridge to close USB and start listening on WiFi.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## d2ea554 - iPad v1.0.8: Fix WiFi MIDI disconnect after USB cable unplugged

**Date:** 2025-10-19
**Author:** Omri Behr

Root cause: The health monitoring timer was in a broken state after suspend/resume.
When WiFi was suspended (USB takes priority), the timer kept running but did nothing
because isConnected was false. When resumed, it didn't restart the timer because
it already existed, leaving WiFi without health monitoring, causing timeout after 30s.

Solution:
- suspend() now properly STOPS the health monitoring timer
- resume() now ALWAYS restarts health monitoring after setting isConnected=true
- Both operations on main queue to prevent race conditions

This ensures WiFi connection stays alive with periodic health checks after
manually switching from USB to WiFi and then unplugging the USB cable.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 339f46d - iPad v1.0.8: Simplify WiFi connection - remove handoff protocol

**Date:** 2025-10-19
**Author:** Omri Behr

- Remove unnecessary switch_to_wifi message sending
- When clicking WiFi chip while USB connected: just disconnect USB and connect WiFi
- No need for handoff protocol - keep it simple
- This should fix the WiFi MIDI disconnect issue after unplugging USB cable

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 92cd443 - iPad v1.0.8: Add debug log for WiFi health monitoring start

**Date:** 2025-10-19
**Author:** Omri Behr

- Add log statement when health monitoring actually starts
- This helps debug the WiFi disconnect issue after USB cable unplugged
- Previous fix had the race condition solved but no visibility into whether
  health monitoring was starting successfully

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 631e65b - iPad v1.0.8: Improve cue list edit mode UI with buttons and native drag

**Date:** 2025-10-19
**Author:** Omri Behr

- Remove swipe gestures from both song library and cue list
- Add blue + buttons on left of song library items (to add to cue list)
- Add red - buttons on left of cue list items (to remove from cue list)
- Use native SwiftUI edit mode for smooth drag-to-reorder
- Remove custom drag handles (use system drag handles only)
- Improve drag animation with snappier spring parameters

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 9248715 - iPad v1.0.8: Make all list items consistent height in edit mode

**Date:** 2025-10-19
**Author:** Omri Behr

All song library and cue list items now have the same height regardless of whether they have a subtitle.

Added invisible placeholder text for items without subtitles:
- CBSetlistRow (cue list items)
- CBSetlistDragPreview (drag preview)
- CBRowLikeLibrary (song library items)

When subtitle is empty, shows transparent " " text with caption font to occupy the same vertical space as items with subtitles. This creates visual consistency and alignment across both columns.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## b78d15d - iPad v1.0.8: Add separator lines to cue list items

**Date:** 2025-10-19
**Author:** Omri Behr

Show separator lines between cue list items to match song library visual style.

Changed .listRowSeparator(.hidden) to .listRowSeparator(.visible) for both:
- Cue list items (CBSetlistColumn)
- Song library items (CBLibraryColumn)

This creates consistent visual separation between items in both columns.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 82283b3 - iPad v1.0.8: Fix cue list edit mode UI issues

**Date:** 2025-10-19
**Author:** Omri Behr

Fixed three issues in the cue list edit mode:

1. Swipe to remove from cue list now works - changed from .leading to .trailing edge
   - Swipe LEFT (trailing) on cue list items now shows "Remove" button
   - Removes from cue list and returns to song library

2. Drag handle now appears on RIGHT side during drag
   - Moved hamburger icon from left to right in CBSetlistDragPreview
   - Matches iOS conventions for reordering handles

3. Song library items text now properly aligned
   - Added .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
   - Added .listRowBackground(Color.clear) and .listRowSeparator(.hidden)
   - Now matches cue list items padding and alignment

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## e46cfb8 - iPad v1.0.8: Restore cue list edit mode UI redesign

**Date:** 2025-10-19
**Author:** Omri Behr

Recreate all lost UI improvements to cue list edit mode:

1. Column order: Song library LEFT, cue list RIGHT (already correct)
2. Fixed height alignment: Both column headers now 44pt height
3. Removed red - buttons from cue list items
4. Removed blue + buttons from song library items
5. Added swipe right (trailing) to delete from song library
6. Added swipe left (leading) to remove from cue list
7. Added swipe left (leading) to add library item to cue list
8. Removed long tap context menu for edit/delete
9. Simple tap now opens edit sheet for both library and cue list items
10. Text properly aligned to left without buttons

Changes in ControlSubviews.swift:
- CBSetlistRow: Removed minus button, added tap gesture
- CBSetlistColumn: Changed swipe edge to leading, removed context menu
- CBLibraryColumn: Removed plus button, added leading swipe actions
- CBRowLikeLibrary: Added tap gesture support
- Fixed header heights to 44pt for alignment

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 85926ae - iPad v1.0.8: Fix race condition in WiFi health monitoring initialization

**Date:** 2025-10-19
**Author:** Omri Behr

Critical bug fix: startConnectionHealthMonitoring() was being called BEFORE isConnected was set to true, causing it to always skip starting health monitoring ("Skipping health monitoring - not connected").

The race condition:
1. Connection becomes .ready on background thread
2. startConnectionHealthMonitoring() called immediately
3. Checks isConnected - still false!
4. Returns without starting monitoring
5. isConnected set to true on main queue... too late

Without health monitoring, WiFi connections would timeout after 30 seconds with "Operation timed out" error.

Fix: Move startConnectionHealthMonitoring() INSIDE the DispatchQueue.main.async block so it runs AFTER isConnected is set to true. This ensures health monitoring always starts for successful connections.

This completes the WiFi handoff fix - now WiFi connections should stay healthy indefinitely.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 03d8dbc - iPad v1.0.8 + Bridge v1.2.0: Add USB-to-WiFi handoff protocol

**Date:** 2025-10-19
**Author:** Omri Behr

Implement proper handoff when user manually switches from USB to WiFi connection:

iPad side:
- Add sendSwitchToWiFiRequest() to ConnectionManager that sends {"type": "switch_to_wifi"} message
- Update connectToWiFi() to send switch request BEFORE disconnecting USB
- Wait 300ms for Bridge to process message and close USB connection
- Then cleanly terminate iPad USB and connect WiFi

Bridge side:
- Handle "switch_to_wifi" message type in MacConnectionManager
- Add handleSwitchToWiFi() that immediately closes USB connection
- Update status to "Ready for WiFi"

This fixes the WiFi timeout issue where:
1. User clicks WiFi chip while USB connected
2. iPad's WiFi "connects" at network layer
3. But Bridge is still using USB connection and ignores WiFi packets
4. WiFi times out after 30 seconds with no data

Now Bridge cleanly closes USB before iPad attempts WiFi connection, ensuring Bridge is ready to accept WiFi packets.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 114cc54 - iPad v1.0.8: Fix connectToWiFi() to use clean USB termination

**Date:** 2025-10-19
**Author:** Omri Behr

Critical fix: The connectToWiFi() function (called when user taps WiFi chip) was calling usbServer.stop() without notifyCallback: false parameter. This was triggering the USB disconnection callback, which interfered with the fresh WiFi connection being established.

This completes the fix for the WiFi MIDI data flow issue. Now both code paths that manually switch to WiFi use clean USB termination:
1. handleWiFiConnectionChange() - when WiFi connection state changes
2. connectToWiFi() - when user taps WiFi chip

When USB cable is later unplugged, the callback won't fire because wasConnected is already false, keeping WiFi connection healthy.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## a860f2d - iPad v1.0.8: Clean USB termination when manually switching to WiFi

**Date:** 2025-10-19
**Author:** Omri Behr

When user manually clicks WiFi chip while USB is connected, cleanly terminate USB without triggering state change callbacks. This prevents USB disconnection handlers from interfering with the fresh WiFi connection.

Key changes:
- Added notifyCallback parameter to ConnectionManager.stop() and stopListening()
- When manually switching to WiFi, call usbServer.stop(notifyCallback: false)
- USB is cleanly shut down but connectionStateCallback is not fired
- When USB cable is later unplugged, wasConnected is already false, so no callback fires
- WiFi connection remains healthy and unaffected by USB cable removal

This fixes the issue where manually connecting WiFi while USB is active, then unplugging USB cable, would break MIDI data flow even though UI showed WiFi as connected.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 950c811 - iPad v1.0.8: Fix WiFi MIDI - guard callback for Story 6 scenario

**Date:** 2025-10-19
**Author:** Omri Behr

Prevent invalid state transitions when USB cable is unplugged without ever connecting (Story 6: WiFi active, USB cable plugged but doesn't auto-connect, then unplugged).

Root cause: handleUSBHostDetached() always called connectionStateCallback?(false), even when USB was never connected. This caused ConnectionCoordinator to corrupt activeConnection state, breaking MIDI routing through WiFi.

Fix: Check wasConnected flag before calling callback. Only notify if USB was actually connected.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 2e60be8 - Bridge v1.2.0: Fix usbmuxd API compatibility for device list

**Date:** 2025-10-19
**Author:** Omri Behr

Fixed compilation errors in USBMuxdMonitor.swift:
- Updated usbmuxd_get_device_list() to new API signature
- Returns device count directly instead of using out parameter
- Fixed usbmuxd_device_list_free() to accept pointer reference

Build now succeeds with libusbmuxd 2.0.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## cdfde46 - Add large installer files to .gitignore

**Date:** 2025-10-19
**Author:** Omri Behr


----

## 4ca6132 - iPad v1.0.8: Fix WiFi MIDI when USB cable unplugged without connecting

**Date:** 2025-10-19
**Author:** Omri Behr

Critical fix: WiFi MIDI now works when USB cable is plugged then unplugged
while WiFi was already active (Story 6 scenario).

Problem sequence:
1. WiFi connected and working
2. USB cable plugged in but Story 6 prevents USB from auto-connecting
3. WiFi stays active (never suspended)
4. USB cable unplugged → Darwin notification fires
5. ConnectionCoordinator tried to "resume" WiFi that was never suspended
6. resume() created duplicate health monitoring timers
7. Duplicate timers caused state corruption → MIDI stopped flowing

Root cause:
- resume() checked if connection object exists (connection != nil)
- But this doesn't distinguish between "suspended" and "active" WiFi
- Calling resume() on active WiFi created duplicate timers
- Duplicate timers corrupted connection state and broke MIDI flow

Solution:
1. Added isSuspended flag to BridgeOutput to explicitly track suspension
2. suspend() sets isSuspended = true
3. resume() checks isSuspended flag and returns early if false
4. resume() prevents duplicate timer creation if already running
5. ConnectionCoordinator checks isSuspended instead of connection != nil

Benefits:
- WiFi MIDI continues working when USB cable unplugged (Story 6)
- No duplicate timers created
- No state corruption
- Proper distinction between suspended and active WiFi
- Handles both scenarios: USB connects then disconnects, and USB cable
  plugged without connecting then unplugged

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 45adde5 - iPad v1.0.8: Fix WiFi MIDI data flow with suspend/resume pattern

**Date:** 2025-10-19
**Author:** Omri Behr

Critical fix: WiFi now correctly passes MIDI data after USB cable unplugged.

Problem:
When WiFi was connected and USB took over, WiFi connection was fully
destroyed via disconnect(). When USB unplugged, WiFi chip showed green
but connection object was nil, so all MIDI messages were silently dropped.

Root cause:
- BridgeOutput.disconnect() was too destructive
- It destroyed the NWConnection object completely
- When USB unplugged, activeConnection switched to .wifi
- But connection object was nil, breaking data flow

Solution - Suspend/Resume Pattern:
1. Added suspend() method to BridgeOutput:
   - Preserves connection object and bridge info
   - Updates UI state only (isConnected = false)
   - Keeps timers and connection alive

2. Added resume() method to BridgeOutput:
   - Verifies connection object still exists
   - Restores UI state (isConnected = true)
   - Restarts health monitoring
   - Allows MIDI data flow immediately

3. Updated ConnectionCoordinator:
   - USB connect: calls suspend() instead of disconnect()
   - USB disconnect: detects suspended connection and calls resume()
   - WiFi data flows immediately without reconnection delay

Benefits:
- No MIDI data loss after USB unplug
- No reconnection delay or handshake needed
- Preserves bridge pairing and connection metadata
- No race conditions with connection state

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 75e3c1e - iPad v1.0.8: Respect user intent when manually disconnecting USB

**Date:** 2025-10-19
**Author:** Omri Behr

When user explicitly clicks "Disconnect USB", the app now stays
disconnected and does NOT auto-reconnect, even with cable still plugged in.

Changes:
- Added isManualUSBDisconnection flag to track user intent
- Created disconnectUSB() method that sets flag and stops USB server
- Modified handleUSBConnectionChange to check flag before auto-reconnect
- Updated UI to call disconnectUSB() instead of direct stop()
- Clear flag when user manually reconnects (taps USB chip or connectToUSB)

User experience:
1. USB connected → user taps "Disconnect USB"
2. Connection stops, both chips turn blue (Waiting state)
3. App does NOT auto-reconnect while cable still connected
4. User must manually tap USB chip to reconnect when ready

This respects user choice and prevents unwanted automatic reconnections.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 409216a - iPad v1.0.8: Fix WiFi data flow when USB unplugged after switching

**Date:** 2025-10-19
**Author:** Omri Behr

Critical bug fix: When user switches from USB to WiFi and then unplugs
the USB cable, WiFi connection now stays active and data flows correctly.

Root cause:
- ConnectionManager was checking WiFi state before calling callback
- This prevented ConnectionCoordinator from switching activeConnection to WiFi
- Result: WiFi chip showed green but no data was passing through

Solution:
- ConnectionManager now ALWAYS reports USB disconnection via callback
- ConnectionCoordinator handles the logic to switch to WiFi if available
- Proper separation of concerns between USB manager and connection coordinator

This fixes the scenario:
1. USB connected and established
2. User taps WiFi chip → WiFi connects
3. User unplugs USB cable → WiFi stays active and data flows

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## c46dde9 - iPad v1.0.8: Fix USB cable detection with connection-based fallback

**Date:** 2025-10-19
**Author:** Omri Behr

Fixes issue where USB chip doesn't appear when cable is connected.

Changes:
- Add fallback USB detection based on actual connection state
- Set isUSBCableConnected=true when USB connection becomes ready
- Clear isUSBCableConnected=false when connection fails/cancels
- Supplements Darwin notifications with practical connectivity check

This ensures USB chip appears reliably even if Darwin notifications
don't fire (e.g., device not yet trusted, debug builds).

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 96d4ad6 - Bridge v1.2.0: Auto-connect when iPad already plugged in

**Date:** 2025-10-18
**Author:** Omri Behr

Fixed issue where Bridge wouldn't connect if iPad was already plugged
in via USB when Bridge app launched. Now checks for already-connected
devices on startup and triggers connection automatically.

Changes:
- Added checkForAlreadyConnectedDevices() in USBMuxdMonitor
- Uses usbmuxd_get_device_list() to detect pre-existing connections
- Triggers onDeviceAttached callback if devices found on startup

This means Bridge now works correctly in both scenarios:
1. Bridge starts first, then iPad plugged in → connects automatically
2. iPad already plugged in, then Bridge starts → connects automatically

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## baab30b - Bridge v1.2.0: Fix status display - consistent "Looking for iPad"

**Date:** 2025-10-18
**Author:** Omri Behr

Fixed two status display issues:
1. Removed blinking between "Waiting for iproxy" and "Looking for iPad"
2. Changed "Disconnected" (yellow) to "Looking for iPad" (blue)

The status now consistently shows blue "Looking for iPad" when not
connected, which better represents that it's actively looking for a
connection rather than disconnected from something. When cable is
plugged in, it connects immediately and shows green "Connected".

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 178f30e - Bridge v1.2.0: Fix UI text blinking when not connected

**Date:** 2025-10-18
**Author:** Omri Behr

Fixed the "Looking for iPad" text that was blinking every few seconds
in the menu bar status display. The status was alternating between
"Looking for iPad" and "Looking for Cue Bear" during connection
attempts, causing a distracting blinking effect.

Changes:
- Removed redundant status updates in MacConnectionManager
- Keep consistent "Looking for iPad" message throughout connection process
- Only updates to "Connected" when iPad actually connects

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## a89dae4 - iPad v1.0.8: Replace demo project and fix USB chip visibility

**Date:** 2025-10-18
**Author:** Omri Behr

Demo Project Changes:
- Replace DJ Set demo with Beethoven Live project
- 20 Beethoven classics in setlist and library
- 9 controls: 5 vertical faders (Winds, Horns, Strings, Percussion, Choir) + transport buttons
- Clean grid layout with proper spacing
- Auto-loads on first launch for better onboarding experience

First Launch Experience Improvements:
- Demo project installs and loads automatically on first launch
- Improved demo installation with existence check and better error logging
- Only installs if project doesn't already exist
- Auto-opens demo project on first launch (subsequent launches open last project)

USB Chip Visibility Fix:
- Fix USB chip showing when no cable connected
- Remove heuristic that assumed cable connected when listener ready
- Now relies only on Darwin notifications for accurate hardware state
- host_attached shows chip, host_detached hides chip
- Purely cosmetic fix - doesn't affect connectivity

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 2341bda - Bridge v1.2.0: Fix USB double-connect and always advertise WiFi

**Date:** 2025-10-18
**Author:** Omri Behr

- Fix USB double-connect issue in IProxyManager
  - Added second guard clause after 1-second delay
  - Prevents concurrent iproxy start attempts from multiple libusbmuxd events
  - Double-check isRunning state before starting iproxy
- Always advertise WiFi via Bonjour regardless of USB connection
  - Removed logic that stopped Bonjour when USB connected
  - Let iPad choose preferred connection method
  - Fixes WiFi chip disappearing when USB connects
- Update libusbmuxd and libimobiledevice-glue frameworks

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## ffcabb5 - iPad v1.0.8: Add interactive tutorial system and improve onboarding

**Date:** 2025-10-18
**Author:** Omri Behr

- Add comprehensive tutorial system with 8 steps (TutorialView.swift)
  - Welcome, add cue, test cue, edit cue, add control, edit control, explore, complete
  - Beautiful overlay UI with animations and pulsing highlights
  - State management with UserDefaults persistence
  - Tutorial launches automatically after onboarding
- Fix onboarding flag logic to always mark as seen when completed
  - Previously only set flag if user checked "don't show again" box
  - Now correctly tracks completion regardless of checkbox state
- Remove all default projects except DJ Set - Electronic Night
  - Deleted: Beethoven Live, Live Band, Studio Session, Theater, Worship projects
  - Ships with single focused default project
- Fix compilation error: Remove invalid 'draft' parameter from CBAddEditCueSheet

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 3c850de - Bridge v1.2.0: Improve UI stability during USB reconnection

**Date:** 2025-10-18
**Author:** Omri Behr

- Changed UI to show stable "USB: Looking for iPad" during all reconnection attempts
- Only shows "USB: Connected" when actually connected
- Removed jumpy status messages (Failed, Disconnected, Connecting to port, etc.)
- All detailed connection info still logged for debugging
- Much cleaner user experience - status doesn't flash between states

UI states now:
- "USB: Looking for iPad" - Searching for device (stable during retries)
- "USB: Connected" - Device connected and handshake successful

Technical details (connection attempts, failures, port info) moved to logs only.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## fe9b999 - Bridge v1.2.0: Universal binary with libusbmuxd-based USB device detection

**Date:** 2025-10-17
**Author:** Omri Behr

- Built as true universal binary (x86_64 + arm64) for native performance on both Apple Silicon and Intel Macs
- Replaced NSWorkspace device monitoring with libusbmuxd 2.0 for reliable iOS device attach/detach detection
- Fixes DarkWake connection issue where Bridge showed "USB: disconnected" despite iPad being connected
- Added USBMuxdMonitor.swift: Swift wrapper for libusbmuxd event subscription API
- Bundled universal libusbmuxd, libplist, and libimobiledevice-glue libraries (@rpath)
- Added build_universal_libs.sh script to compile dependencies from source for both architectures
- Updated Xcode project: Added ARCHS=$(ARCHS_STANDARD), updated library paths and search paths

Technical improvements:
- Uses libusbmuxd_events_subscribe() for real-time UE_DEVICE_ADD/REMOVE notifications
- No more polling or NSWorkspace hacks - direct usbmuxd daemon communication
- Libraries built with proper cross-compilation for x86_64 on Apple Silicon
- Fixed install_name_tool dependencies between bundled libraries

This approach matches TouchOSC Bridge's architecture and provides professional-grade device detection that works reliably after Mac wakes from DarkWake cycles.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 5510904 - Bridge v1.2.0: Fix USB connection detection after DarkWake cycles using libusbmuxd

**Date:** 2025-10-17
**Author:** Omri Behr

This release fixes the critical issue where Bridge showed "USB: disconnected" after overnight sessions despite iPad being connected and iproxy running.

Root cause: NSWorkspace notifications don't fire for:
- DarkWake events (Mac waking for maintenance without display)
- iOS devices (use MobileDevice framework, not /Volumes/)

Solution: Implemented reliable device detection using libusbmuxd:
- Created USBMuxdMonitor.swift: Swift wrapper for usbmuxd event subscription
- Created CueBearBridge-Bridging-Header.h: C library bridge
- Integrated with IProxyManager: Replaced broken NSWorkspace monitoring
- Works for ALL wake types: DarkWake, full wake, maintenance wake
- Zero latency detection of device attach/detach
- Removed dead code: isiOSDevicePath() checking non-existent /Volumes/iPad

Technical changes:
- Added libusbmuxd-2.0 library dependency
- Set build architecture to arm64 only (libusbmuxd availability)
- Updated version to 1.2.0 in Info.plist

Credits: TouchOSC Bridge uses this same approach

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## c43f8a0 - Bridge v1.1.8: Add enhanced WiFi server logging for debugging MIDI routing issues

**Date:** 2025-10-15
**Author:** Omri Behr

Added comprehensive debug logging to WiFi server to identify why MIDI stops
flowing to DAW after USB cable is unplugged while WiFi is connected.

New logging:
- 📡 WiFi connection state changed to: [state] - Tracks all NWConnection state changes
- 📥 WiFi received [N] bytes - Logs every data packet received
- All state transitions (preparing, waiting, ready, failed, cancelled)

This will help identify whether:
1. WiFi connection state changes when USB unplugs
2. Packets are being received but not processed
3. receiveLoop stops being called

Issue being investigated: iPad successfully sends MIDI via WiFi after USB unplug
(logs show "Batch sent successfully"), but Bridge doesn't process the packets
and no MIDI arrives at DAW. After manually reconnecting WiFi, MIDI flows again.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 02d652b - iPad v1.0.4: Fix WiFi connection timeout when USB cable unplugged

**Date:** 2025-10-15
**Author:** Omri Behr

Root cause: When USB cable is unplugged while WiFi is connected, the iPad's
WiFi receive loop would get a POSIX error 60 (Operation timed out) after ~30
seconds and immediately disconnect, even though the connection was still valid.

The timeout occurred because the TCP read operation was waiting for data from
the Bridge, but network routing changes when USB unplugs can cause brief delays
in packet delivery.

Solution: Handle POSIX error 60 (timeout) gracefully by retrying the receive
loop instead of disconnecting. This keeps the WiFi connection alive through
temporary network disruptions.

Bug symptoms:
- WiFi worked fine initially after USB disconnect
- After ~30 seconds, WiFi connection dropped
- Bridge still showed "WiFi: Connected" but MIDI stopped flowing
- iPad logs showed "Operation timed out"

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## eeae8e0 - iPad v1.0.4: Fix WiFi chip UI showing disconnected when USB cable unplugs while WiFi connected

**Date:** 2025-10-15
**Author:** Omri Behr

Fixed two related issues:
1. ConnectionCoordinator: Already correctly checking wifiClient.isConnected
2. BridgeDeviceCard: Was comparing item.id which changes when discovered array rebuilds

Root cause: When USB disconnects, BridgeOutput discovery rebuilds the discovered
array with new UUIDs. The WiFi chip UI was comparing wifiClient.current?.id == item.id,
which fails because item gets a new UUID even though it's the same bridge.

Solution: Changed UI binding to use connectionCoordinator.activeConnection == .wifi
as source of truth, and compare by name instead of ID.

Bug symptoms:
- WiFi chip showed blue (disconnected) after USB unplug even though WiFi connected
- Red "Disconnect WiFi" text appeared when it should be hidden
- MIDI messages didn't transfer (UI state confusion)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## dbf09ad - iPad v1.0.4: Fix WiFi chip UI bug on USB disconnect

**Date:** 2025-10-15
**Author:** Omri Behr

Bug Fix:
- Fixed WiFi chip turning green (disconnected) when USB cable is unplugged while WiFi is still connected
- WiFi chip now correctly stays green (connected) when it is actually connected
- Changed from checking stale activeConnection state to checking actual wifiClient.isConnected state

Root Cause:
- When USB disconnected, code checked `activeConnection != .wifi` (stale state)
- This could be out of sync with actual WiFi connection state
- Result: WiFi chip showed disconnected even when WiFi was connected

The Fix:
- Now checks `wifiClient.isConnected` (source of truth) instead of activeConnection
- If WiFi is connected when USB disconnects, activeConnection switches to .wifi
- If WiFi is not connected, activeConnection switches to .none
- UI always reflects actual connection state

Verified Scenarios:
- USB only → disconnect → shows disconnected ✓
- WiFi only → disconnect → shows disconnected ✓
- USB connected → WiFi connect → USB disconnect → WiFi stays connected ✓
- WiFi connected → USB connect → USB takes over ✓

No Breaking Changes:
- USB and WiFi still work independently
- Connection priority logic unchanged
- Automatic reconnection unchanged
- MIDI routing unchanged

Files changed:
- ConnectionCoordinator.swift: Fixed handleUSBConnectionChange logic
- project.pbxproj: Updated version to 1.0.4

🤖 Generated with Claude Code

Co-Authored-By: Claude <noreply@anthropic.com>

----

## cb2f523 - iPad v1.0.3: Remove 20ms button flash delay for instant feedback

**Date:** 2025-10-15
**Author:** Omri Behr

Performance Improvements:
- Removed 20ms DispatchQueue delay before flash fade animation
- Cue list buttons now flash instantly on tap
- Control area buttons now flash instantly on tap
- Button responsiveness improved by 20ms (~10% faster)
- MIDI latency unchanged (still ~10ms)

User Experience:
- Buttons feel noticeably more responsive and snappy
- Visual feedback is immediate on tap
- No change to MIDI transmission speed (already optimized)

Files changed:
- ControlSubviews.swift: Removed delay in cue button flash()
- ContentView.swift: Removed delay in control button flash
- project.pbxproj: Updated version to 1.0.3

Technical Details:
- Before: 20ms delay + 180ms fade = 200ms total feedback
- After: 0ms delay + 180ms fade = 180ms total feedback
- Improvement: 20ms faster perceived response

🤖 Generated with Claude Code

Co-Authored-By: Claude <noreply@anthropic.com>

----

## e271740 - Bridge v1.1.7: Fix USB disconnect detection and menu bar UI delay

**Date:** 2025-10-15
**Author:** Omri Behr

USB Disconnect Detection:
- Added NSWorkspace.didUnmountNotification monitoring to detect iOS device disconnection
- Bridge now immediately shows "USB: Disconnected" when device is unplugged
- Stops reconnection attempts automatically when device unmounts
- Added iosDeviceDisconnected notification for coordination between managers
- Full cleanup of connection state on disconnect

Menu Bar UI Performance:
- Removed git commit hash from version string to eliminate UI blocking
- Created VersionHelper with cached version string (no subprocess calls)
- Menu bar now opens instantly without delay or freeze
- Version display simplified to v1.1.7 format

Files changed:
- IProxyManager.swift: Added unmount notification handling
- MacConnectionManager.swift: Added device disconnect notification listener
- CueBearBridgeApp.swift: Simplified version string with VersionHelper
- MenuBarView.swift: Uses cached version string
- Info.plist: Updated to version 1.1.7

🤖 Generated with Claude Code

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 1e36116 - Bridge v1.1.6: Improve sleep/wake reconnection stability

**Date:** 2025-10-14
**Author:** Omri Behr

Changes:
1. Increased handshake timeout from 5s to 10s
   - Gives more time for connection to establish after sleep/wake
   - Prevents premature timeout on slow network recovery

2. Increased reconnection delay from 2s to 5s
   - Better stability after Mac wake from sleep
   - Allows system services to fully initialize

3. Fixed state cleanup in handshake timeout handler
   - Properly resets connecting/didSendHandshake flags
   - Prevents reconnection loops from stale state

4. Fixed indentation in BridgeApp.swift do-try-catch block

Tested: Mac reconnected immediately after 15-minute sleep ✓

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 54a28f1 - iPad v1.0.2: Fix UI flash behavior and dynamic version display

**Date:** 2025-10-14
**Author:** Omri Behr

Changes:
1. Performance list tap behavior:
   - Flash now only shows on successful tap (MIDI output)
   - No flash on long-press (context menu)
   - Removed premature flash on touch-down
   - Simplified gesture handling by removing Timer-based flash

2. Dynamic version display:
   - Version number now reads from bundle (MARKETING_VERSION)
   - Commit hash reads from GitCommit.txt file
   - Added gitCommitHash() helper function
   - Display format: "v1.0.2 (15e5d00)" instead of hardcoded "v1.0.1 (4ee9f55)"

Technical notes:
- Removed firedThisPress and flashTimer state variables
- Flash triggers on onEnded instead of onChanged
- Context menu intercepts long-press, preventing flash
- GitCommit.txt generated at build time with current commit hash

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 2980df6 - iPad v1.0.2: Implement automatic USB reconnection after bridge restart

**Date:** 2025-10-14
**Author:** Omri Behr

This update adds robust automatic reconnection when the bridge/iproxy restarts or becomes stale after Mac sleep/wake cycles.

Key improvements:
- Fixed listener restart by setting isListening=false in stopListening()
- Added automatic reconnection with optimized timing (2s initial delay, 0.5s intervals)
- Increased max reconnection attempts from 5 to 10
- Prevented concurrent reconnection attempts with isReconnecting flag
- Clear dead activeUSB connections when cancelled to allow new connections
- Reconnection completes automatically in 30-40 seconds without user intervention

Fixes the issue where overnight Mac sleep caused stale connections requiring manual reconnection in the morning.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## afcbb3b - Fix USB reconnection after iproxy restart

**Date:** 2025-10-14
**Author:** Omri Behr

Add CB/2 handshake handling to USBTunnelServer so iPad can properly
reconnect when the bridge's iproxy auto-restarts.

Previously, USBTunnelServer would accept connections but never respond
to CB/2 handshakes, causing the bridge to timeout after 5 seconds.

Now properly:
- Parses CB/2 handshake (CB/2 auth=psk1 name=MacName)
- Extracts computer name
- Sends OK/2 hmac= response
- Sets connected status only after handshake completes

This fixes reconnection issues after Mac sleep/wake cycles when iproxy
gets restarted by the auto-restart feature.

----

## fda1571 - Bridge v1.1.5: Fix auto-start and add auto-restart

**Date:** 2025-10-14
**Author:** Omri Behr

Changes:
- Remove blocking idevice_id check that prevented auto-start
- Add iproxy auto-restart on crash (2s delay, 5s retry)
- Update version to 1.1.5
- Use working iproxy binary from v1.1.3

Fixes the issue where bridge wouldn't auto-start after Mac sleep/wake and iproxy would get stale overnight.

----

## 62cfe8d - Remove blocking idevice_id check that prevents auto-start

**Date:** 2025-10-14
**Author:** Omri Behr

The idevice_id device detection check was preventing the bridge from auto-starting when idevice_id is not installed. The bundled iproxy handles device detection itself, so this check is unnecessary and was blocking startup.

----

## df8338c - Fix certificate detection for Installer cert in build script

**Date:** 2025-10-13
**Author:** Omri Behr


----

## 7f1fd26 - Bridge v1.1.4: Add auto-restart for iproxy and version display in UI

**Date:** 2025-10-13
**Author:** Omri Behr

- Auto-restart iproxy when it crashes unexpectedly
- Retry logic with exponential backoff (2s, then 5s)
- Don't restart if manually stopped (SIGTERM)
- Add version and git commit to menu bar UI
- Update version to 1.1.4

----

## a335737 - iPad v1.0.1: Fix module reference and update version string

**Date:** 2025-10-13
**Author:** Omri Behr


----

## 6ad5f85 - iPad v1.0.1: Remove deprecated UIApplicationExitsOnSuspend key for App Store compliance

**Date:** 2025-10-13
**Author:** Omri Behr


----

## 8b12e40 - iPad v1.0.1: Increase delete button hitbox to 60x60pt for easier tapping

**Date:** 2025-10-13
**Author:** Omri Behr


----

## b7744e0 - iPad v1.0.1: Fix icon picker scroll jumping and increase delete button hitbox

**Date:** 2025-10-13
**Author:** Omri Behr


----

## 90be5d0 - iPad v1.0.1: Fix button icons, Save & add another CC, and icon picker jumping

**Date:** 2025-10-13
**Author:** Omri Behr


----

## c9f2a6b - Add Beethoven Live demo project with 20 famous pieces

**Date:** 2025-10-13
**Author:** Omri Behr

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 46abce9 - iPad v1.0.1: Restore onboarding and fix fader issues

**Date:** 2025-10-13
**Author:** Omri Behr

Fixes:
1. Restore onboarding integration that was missing from v1.0.1
   - Add showOnboarding state variable
   - Add onboarding sheet presentation
   - Trigger onboarding after splash screen if not seen before

2. Fix fader size to match button size
   - Remove .padding(4) from iPadControlTile (line 6242)
   - Faders now fill the entire grid cell like buttons

3. Fix fader delay for immediate response
   - Make TapGesture conditional: only for buttons, not faders
   - Faders use DragGesture(minimumDistance: 0) which conflicts with TapGesture
   - Eliminates ~300ms disambiguation delay on faders

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 8175f1b - iPad v1.0.1: Fix exported projects not opening

**Date:** 2025-10-12
**Author:** Omri Behr


----

## a95fd51 - iPad v1.0.1: Add version display to Connections sheet

**Date:** 2025-10-12
**Author:** Omri Behr


----

## 85a5231 - iPad v1.0.1: Fix USB not reconnecting after app reopens

**Date:** 2025-10-12
**Author:** Omri Behr

Bug Fix:
- USB connection fails to work after closing and reopening iPad app
- Root cause: NWListener stops while in background but isn't restarted on foreground
- Solution: Check if listener is running when app returns to foreground and restart if needed

Technical Details:
- Added check for !isListening in appWillEnterForeground()
- Restarts listener before checking connection health
- Ensures USB chip is clickable and functional after app reopens
- File: ConnectionManager.swift lines 1470-1477

User Impact:
- Users can now close and reopen the app without losing USB connectivity
- USB reconnection works reliably even after app has been backgrounded
- No need to disconnect/reconnect cable or restart Bridge

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## d5d568b - iPad v1.0.1: Fix two UI bugs (Taken by chips + GO capsule animation)

**Date:** 2025-10-12
**Author:** Omri Behr

Bug Fixes:
1. Fix "Taken by:" chips flashing on project load
   - Root cause: Race condition between view rendering and conflict cache population
   - Solution: Build conflict cache synchronously BEFORE and AFTER loading project
   - Removed 500ms throttle delay that caused false conflict detection
   - Files: ContentView.swift lines 2234-2258

2. Fix GO capsule flying in from side of screen
   - Root cause: Position state initializes to (0,0) and animates to final position
   - Solution: Disable animation on initial positioning using Transaction
   - Capsule now appears instantly at bottom-center on app launch
   - Files: Components.swift lines 317-322, 333-338

Technical Details:
- Conflict cache now computed 3 times: before data clear, before project load, after project load
- Transaction.disablesAnimations prevents SwiftUI from animating position changes from (0,0)
- Both fixes prevent visual glitches without affecting performance or functionality

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 9ebe54b - iPad v1.0.1: Add Export Project feature

**Date:** 2025-10-12
**Author:** Omri Behr

New Feature:
- Add "Export Project" button in Projects sheet (below "Open from Files")
- Export creates temporary .cuebear file and presents iOS share sheet
- Users can save to Files, AirDrop, share via Messages/Mail, etc.
- Automatic cleanup of temporary file after sharing
- iPad-optimized popover presentation

Implementation:
- DocumentProjectIO.exportProject(): Creates temp file, presents UIActivityViewController
- CBProjectsSheet: Add onExportProject callback and UI button
- ContentView.exportCurrentProject(): Serialize current project and trigger export
- Update app version from 1.0 to 1.0.1

Technical Details:
- Properly handles iPad popover presentation (centered, no arrows)
- Sanitizes project names (replaces "/" with "-")
- Shows error alert if export fails
- Uses JSON pretty-printing for readable .cuebear files

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## ec7f37d - iPad v1.0.0: Add onboarding, purchase tracking, and App Store fixes

**Date:** 2025-10-12
**Author:** Omri Behr

Features:
- Add 4-step onboarding with "Don't show again" checkbox
- Implement StoreKit 2 purchase tracking (serverless, lifetime access for $4.99 buyers)
- Add paywall UI and purchase status view
- Fix WiFi chip color updates (use stable name-based IDs)
- Fix USB connection detection on iPad (use incoming connection instead of Darwin notifications)
- Remove WiFi auto-connect (only USB auto-connects)

App Store Fixes:
- Remove deprecated UIApplicationExitsOnSuspend key
- Add required LSHandlerRank for document types
- Update to iOS 17 onChange syntax

Documentation:
- Add PURCHASE_SETUP.md with complete StoreKit 2 guide
- Add APP_STORE_SETUP_GUIDE.md for submission process

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## b2afa1c - v1.1: Bundle iproxy with fixed library paths - no Homebrew required

**Date:** 2025-10-08
**Author:** Omri Behr

Major Changes:
- Bundle iproxy and dependencies (libusbmuxd, libimobiledevice-glue, libplist)
- Fix all library paths to use @executable_path references
- Add entitlements to Xcode project for USB/network access
- Add Xcode build phase to bundle iproxy in Debug builds
- Update build scripts to handle bundled iproxy with proper signing

Bridge Changes:
- IProxyManager.swift: Updated to check bundled iproxy first
- CueBearBridge.entitlements: Added to project root
- Xcode project: Added entitlements and bundle script build phase

Build System Changes:
- bundle_iproxy.sh: New script to bundle and fix iproxy library paths
- build_pkg.sh: Skip Resources/Helpers iproxy, use bundle_iproxy.sh instead
- codesign_app.sh: Sign bundled iproxy dylibs individually
- Fixed xattr permission errors for signed files

Distribution:
- CueBear-Bridge-v1.1-notarized.dmg (26MB)
- Fully self-contained, no external dependencies
- Works on systems without Homebrew or libimobiledevice

Technical Details:
- All dylibs use @executable_path/../Frameworks/ references
- TouchOSC-style bundling approach
- Proper code signing order: dylibs → iproxy → app bundle
- Notarized and stapled for Gatekeeper compliance

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 5724986 - Stable working Bridge with system iproxy and sleep/wake handling

**Date:** 2025-10-08
**Author:** Omri Behr

- Bridge uses system iproxy (Homebrew installation required)
- Added sleep/wake monitoring with auto-restart
- iPad app improvements and connection handling
- Installer scripts cleaned up and working
- DMG distribution method established

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 857f178 - Consolidate Cue Bear monorepo: Add iPad app and Mac bridge

**Date:** 2025-10-03
**Author:** Omri Behr

- Added Cue Bear iPad app (complete Xcode project)
- Added CueBearBridge Mac app (complete Xcode project)
- Updated .gitignore for both iOS and macOS projects
- Added App Store metadata documentation
- Consolidated both components into single repository

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----

## 6bd0562 - Add privacy policy and website files

**Date:** 2025-10-01
**Author:** Omri Behr

- Add HTML privacy policy page
- Add index.html with redirect
- Add README with contact info
- Update privacy policy with Studio Bear contact details

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

----
