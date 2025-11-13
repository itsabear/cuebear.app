# Cue Bear Design System
**Version 1.1.0 | iPad Application**

---

## Table of Contents
1. [Overview](#overview)
2. [Color System](#color-system)
3. [Typography](#typography)
4. [Spacing & Layout](#spacing--layout)
5. [Components](#components)
6. [Animations & Interactions](#animations--interactions)
7. [States & Variants](#states--variants)
8. [Implementation Notes](#implementation-notes)

---

## Overview

### App Purpose
Cue Bear is a professional MIDI cueing system for iPad, designed for live performers, theatrical productions, and studio musicians. The design emphasizes clarity, speed, and reliability during live performances.

### Design Philosophy
- **Performance-First**: All UI elements prioritize speed and clarity during live shows
- **High Contrast**: Ensure visibility in various lighting conditions (dark theaters, bright stages)
- **Touch-Optimized**: Large, easy-to-hit targets for accurate tapping during performances
- **Minimal Distraction**: Clean interface that doesn't distract from the performance

### Platform
- **Device**: iPad (all sizes)
- **iOS Version**: 17.0+
- **Orientation**: Landscape (primary), Portrait (supported)

---

## Color System

### Primary Colors

#### Background Colors
- **App Background**: `#1C1C1E` (Dark gray, almost black)
- **Title Bar**: `#2C2C2E` (Slightly lighter gray)
- **Secondary Background**: `#3A3A3C` (Mid gray)

#### Accent Colors
- **Primary Accent**: `#FF9500` (Orange)
  - Used for: Selected items, highlights, primary actions
- **Success/Active**: `#34C759` (Green)
  - Used for: Connection indicators, success states
- **Warning**: `#FF9F0A` (Amber)
  - Used for: Warnings, alerts
- **Error/Disconnect**: `#FF3B30` (Red)
  - Used for: Errors, disconnection states

#### Semantic Colors (Theme-Based)
All warning, error, and success colors are now theme parameters, ensuring visual consistency across the app:
- **Warning Colors**: Theme-specific amber/orange tones for warnings and alerts
- **Error Colors**: Theme-specific red tones for errors and destructive actions
- **Success Colors**: Theme-specific green tones for success states and positive indicators

Each theme defines its own semantic colors in both light and dark mode variants. See `AppTheme.swift` for complete color definitions per theme.

#### Text Colors
- **Primary Text**: `#FFFFFF` (White)
  - Used on: Cue buttons, primary labels
- **Secondary Text**: `#98989D` (Light gray)
  - Used for: Subtitles, metadata, secondary information
- **Tertiary Text**: `#636366` (Medium gray)
  - Used for: Disabled states, placeholder text

#### Cue Colors (Default Palette)
- **Default Orange**: `#FF9500`
- **Blue**: `#007AFF`
- **Purple**: `#BF5AF2`
- **Pink**: `#FF2D55`
- **Red**: `#FF3B30`
- **Green**: `#34C759`
- **Yellow**: `#FFD60A`
- **Teal**: `#64D2FF`
- **Indigo**: `#5E5CE6`
- **Gray**: `#8E8E93`

### Color Usage Guidelines

#### Selection Strokes
- **Orange Cues**: Black stroke (light mode), White stroke (dark mode)
- **Other Colors**: Orange stroke (`#FF9500`) at 6pt thickness
- **Adaptive Logic**: RGB analysis determines if stroke should be black or white based on luminance

#### Opacity Values
- **Normal Cues**: 90% opacity
- **Selected/Active Cues**: 100% opacity
- **Conflicted Cues**: 55% opacity
- **Button Press**: 70% opacity (temporary)

---

## Typography

### Font System
- **System Font**: San Francisco (SF Pro)
- **Fallback**: System default

### Font Scales

#### Cue Buttons
- **Title (Normal)**: 22pt, Bold
- **Title (Selected)**: 28pt, Bold
- **Subtitle (Normal)**: 12pt (Footnote), Regular
- **Subtitle (Selected)**: 17pt (Headline), Semibold

#### Top Bar
- **Project Name**: 17pt, Semibold
- **Button Labels**: 15pt, Medium

#### Control Buttons
- **Title**: 17pt, Bold
- **Subtitle**: 13pt, Regular

#### MIDI Info (on cues)
- **Channel**: 13pt, Semibold
- **Note/CC Number**: 17pt, Bold

### Line Height
- **Cue Titles**: 1.1 (tight)
- **Cue Subtitles**: 1.2
- **Body Text**: 1.4
- **Button Labels**: 1.0 (single line)

### Font Weight Scale
- **Black**: Reserved for genre badges in themes
- **Bold**: Primary titles, emphasized text
- **Semibold**: Secondary titles, important labels
- **Medium**: Standard buttons, labels
- **Regular**: Body text, subtitles

---

## Spacing & Layout

### Grid System
- **Base Unit**: 4pt
- **Standard Spacing**: Multiples of 4 (4, 8, 12, 16, 20, 24, 32, 40)

### Component Spacing

#### Cue List
- **Horizontal Padding**: 36pt (left/right of scrollview)
- **Vertical Spacing**: 8pt between cues
- **Selected Cue Extra Padding**:
  - Vertical: 12pt (top/bottom)
  - Horizontal: 6pt (left/right)

#### Top Bar
- **Height**: ~64pt (including padding)
- **Horizontal Padding**: 16pt
- **Vertical Padding**: 10pt
- **Capsule Spacing**: 12pt between elements within capsule
- **Corner Radius**: 20pt

#### Control Area
- **Grid Spacing**: 12pt between buttons
- **Per Row**: 4 buttons default (adjustable 2-6)
- **Padding**: 16pt around grid

### Corner Radius Scale
- **Small**: 8pt (chips, small buttons)
- **Medium**: 12pt (standard buttons)
- **Large**: 20pt (cue buttons, capsules)
- **Extra Large**: 26pt (app icon corners)

### Shadows
- **Top Bar Capsules**:
  - Color: Black @ 10% opacity
  - Radius: 8pt
  - Offset: (0, 2)
- **Selected Cues**:
  - Color: Accent color @ 30% opacity
  - Radius: 6pt
  - Offset: (0, 3)

---

## Components

### 1. Cue Button (CBPerformanceRow)

#### Dimensions
- **Height (Normal)**: 86pt
- **Height (Selected)**: 103.2pt (20% taller)
- **Width**: Full width minus 36pt padding on each side
- **Corner Radius**: 20pt

#### Structure
```
┌─────────────────────────────────────────────────────┐
│  [Play Icon] [Cue Title]              [CH] [Note/CC]│
│              [Subtitle]                     [Kind]   │
│              [Taken By Chip if conflict]            │
└─────────────────────────────────────────────────────┘
```

#### Elements
1. **Play Icon** (left, if active/last played)
   - Size: 28pt (selected), 24pt (last played)
   - Color: White with black stroke (4-way offset)
   - Blinks in Cue mode (opacity 0.3 ↔ 1.0, 0.6s)

2. **Title Text** (left-aligned)
   - Font: 28pt Bold (selected), 22pt Bold (normal)
   - Color: White
   - Line limit: 1

3. **Subtitle Text** (below title)
   - Font: Headline (selected), Footnote (normal)
   - Color: White @ 85% opacity
   - Line limit: 1

4. **Channel Display** (top-right)
   - Label: "CH" in 13pt Semibold
   - Value: Channel number in 17pt Bold
   - Color: White @ 70% opacity

5. **Note/CC Display** (center-right)
   - Value: Note or CC number in 17pt Bold
   - Color: White

6. **Kind Label** (bottom-right)
   - Text: "NOTE" or "CC" in 11pt, All caps
   - Color: White @ 60% opacity

7. **Taken By Chip** (if MIDI conflict)
   - Background: Black @ 40% opacity
   - Text: "Taken by [Name]" in white
   - Padding: 8pt horizontal, 4pt vertical
   - Corner radius: 8pt

#### Selection Stroke
- **Thickness**: 6pt
- **Color**: Orange (or adaptive black/white for orange cues)
- **Inset**: 3pt from edge

#### States
- **Normal**: 90% opacity, 86pt height
- **Selected/Cued**: 100% opacity, 103.2pt height, stroke visible
- **Conflicted**: 55% opacity
- **Flashing** (when triggered): White overlay fades from 100% to 0% over 0.2s

---

### 2. Top Bar (CBTopBar)

#### Left Capsule (Menu + Project Name)
```
┌──────────────────────────────┐
│  [≡] Project Name            │
└──────────────────────────────┘
```

- **Background**: Ultra thin material + titleBarColor @ 30%
- **Padding**: 16pt horizontal, 10pt vertical
- **Corner Radius**: 20pt
- **Shadow**: Black @ 10%, 8pt radius, (0, 2) offset

**Elements**:
1. Menu Button (hamburger/X icon)
   - Size: Large (system)
   - Color: Primary text color

2. Project Name
   - Font: 17pt Semibold
   - Color: Theme text color
   - Tappable (opens rename dialog)

#### Right Capsule (Context Controls)

**Performance Mode**:
```
┌──────────────────────────────────────┐
│  [Edit] [Undo] [Redo] [+] [•••]     │
└──────────────────────────────────────┘
```

**Edit Mode**:
```
┌──────────────────────────────────────┐
│  [Done] [Undo] [Redo] [+]           │
└──────────────────────────────────────┘
```

- **Same styling as left capsule**
- **Button spacing**: 12pt between buttons
- **Transition**: Asymmetric slide from trailing edge

---

### 3. Control Area Buttons (CBControlButton)

#### Dimensions
- **Aspect Ratio**: 1:1 (square)
- **Size**: Responsive based on grid and screen width
- **Corner Radius**: 12pt
- **Grid**: 2-6 buttons per row (default: 4)

#### Structure
```
┌──────────────┐
│   [Icon]     │
│   Title      │
│   Subtitle   │
│   [CH] [CC]  │
└──────────────┘
```

#### Elements
1. **Icon** (top, if present)
   - SF Symbol
   - Size: 28pt
   - Color: White

2. **Title** (center)
   - Font: 17pt Bold
   - Color: White
   - Line limit: 2

3. **Subtitle** (below title)
   - Font: 13pt Regular
   - Color: White @ 85%
   - Line limit: 1

4. **MIDI Info** (bottom)
   - Channel + CC/Note display
   - Same styling as cue buttons

#### Button Types
1. **CC Momentary**: Sends value on press, 0 on release
2. **CC Toggle**: Toggles between 0 and 127
3. **CC Fader**: Shows slider overlay when pressed
4. **Program Change**: Sends program change message

#### States
- **Normal**: Default color with 90% opacity
- **Active** (toggle on): Full opacity with glow
- **Pressed**: 70% opacity
- **Disabled**: 50% opacity, grayed out

---

### 4. Navigation Capsule (DraggableNavigationCapsule)

**Used in**: Navigator mode (regularPlusRemote)

#### Dimensions
- **Width**: 125pt
- **Height**: 275pt
- **Corner Radius**: 62.5pt (fully rounded)

#### Structure (Vertical)
```
╭─────╮
│  −  │  Previous
│     │
│     │
│  GO │  Trigger
│     │
│     │
│  +  │  Next
╰─────╯
```

#### Elements
1. **Previous Button** (top)
   - Icon: "minus" SF Symbol
   - Size: 35pt Bold
   - Color: White

2. **Go Button** (center, larger)
   - Text: "GO"
   - Font: 32pt Black
   - Color: White
   - Slightly larger hit area

3. **Next Button** (bottom)
   - Icon: "plus" SF Symbol
   - Size: 35pt Bold
   - Color: White

#### Behavior
- **Draggable**: Can be repositioned anywhere on screen
- **Persistent**: Position saved between sessions
- **Disabled States**: Grayed out when at list boundaries
- **Haptic**: Medium impact feedback on press

---

### 5. Transport Dock (SimpleDraggableTransportDock)

**Used in**: Cue mode

#### Dimensions
- **Similar to Navigation Capsule**
- **4 buttons**: Prev, Go, Next, Clear

#### Structure
```
╭─────╮
│  <  │  Previous Cue
│ GO  │  Trigger Cued
│  >  │  Next Cue
│  ×  │  Clear Selection
╰─────╯
```

#### Special Features
- Shows cued song name in center when a cue is selected
- Clear button only visible when a cue is selected
- Same draggable behavior as Navigation Capsule

---

### 6. Side Menu

#### Dimensions
- **Width**: 300pt
- **Slide Animation**: 0.3s ease-in-out
- **Background Blur**: 3pt blur on main content when open

#### Structure
```
┌─────────────────────────────┐
│  [X] Cue Bear               │  Header
├─────────────────────────────┤
│  Project                    │  Section
│    New Project              │
│    Save                     │
│    Save As...               │
│    Open...                  │
│    Import...                │
│    Export...                │
├─────────────────────────────┤
│  Settings                   │  Section
│    MIDI Settings...         │
│    [Appearance...] Hidden   │
├─────────────────────────────┤
│  Help                       │  Section
│    Getting Started          │
│    About Cue Bear           │
└─────────────────────────────┘
```

#### Button Styling
- **Padding**: 12pt vertical, 16pt horizontal
- **Icon Size**: 20pt
- **Font**: 17pt Regular
- **Icon-Text Spacing**: 12pt
- **Hover/Press**: Slight highlight

---

### 7. Mode Selector (Segmented Control)

#### Modes
1. **Regular Mode**: Standard triggering
2. **Cue Mode**: Select then trigger
3. **Navigator Mode**: Remote-style navigation

#### Styling
- **Height**: 32pt
- **Font**: 15pt Medium
- **Corner Radius**: 8pt
- **Background**: Ultra thin material
- **Selected**: Accent color background

---

### 8. Chips & Badges

#### "Taken By" Conflict Chip
- **Background**: Black @ 40%
- **Text**: White, 11pt Semibold
- **Padding**: 8pt horizontal, 4pt vertical
- **Corner Radius**: 8pt
- **Position**: Bottom left of cue button

#### Global Channel Badge
- **Text**: "GLOBAL CH [N]"
- **Style**: Similar to conflict chip
- **Color**: Orange background

---

### 9. Sheets & Modals

#### Standard Sheet
- **Background**: Theme background color
- **Navigation Bar**: Inline title
- **Toolbar**: Cancel (left), Done (right)
- **Tint**: Theme accent color

#### Common Sheets
1. **Add/Edit Cue Sheet**
   - Form-based layout
   - Sections: Name, MIDI, Appearance
   - Color picker grid (4 columns)

2. **MIDI Settings Sheet**
   - Table layout
   - Filter toggles
   - Connection status

3. **Appearance Sheet** (Hidden)
   - Grid of theme preview cards (2 columns)
   - Live preview on tap
   - Cancel restores original

---

## Animations & Interactions

### Animation Timings

#### Fast (UI Feedback)
- **Duration**: 0.15-0.25s
- **Curve**: Ease-out
- **Use**: Button presses, small state changes

#### Standard (Transitions)
- **Duration**: 0.3s
- **Curve**: Ease-in-out
- **Use**: Mode changes, sheet presentations, menu slides

#### Smooth (Emphasis)
- **Duration**: 0.3-0.6s
- **Curve**: Spring (response: 0.3, damping: 0.75)
- **Use**: Cue selection, size changes

#### Continuous (Feedback)
- **Duration**: 0.6s repeating
- **Curve**: Ease-in-out
- **Use**: Play icon blinking

### Spring Animations
- **Selection Changes**: Response 0.3, Damping 0.75
- **Size Changes**: Response 0.3, Damping 0.75
- **Theme Changes**: Response 0.3, Damping 0.7

### Flash Effects
- **Cue Flash** (on trigger): White overlay, 0.2s fade out
- **Duration**: 0.20s
- **Curve**: Ease-out

### Haptic Feedback

#### Impact Feedback
- **Medium Impact**: Cue triggers, navigation
- **Heavy Impact**: Mode changes, critical actions
- **Selection Changed**: Cue selection in Cue mode

#### When to Use
- Button presses (in performance context)
- Successful MIDI sends
- Mode transitions
- Drag start/end

---

## States & Variants

### Cue Button States

| State | Opacity | Height | Stroke | Animation |
|-------|---------|--------|--------|-----------|
| Normal | 90% | 86pt | None | - |
| Selected | 100% | 103.2pt | 6pt colored | Spring transition |
| Flashing | 100% | Current | Current | White overlay fade |
| Conflicted | 55% | 86pt | None | - |
| Last Played | 90% | 86pt | None | Steady play icon |

### Button States

| State | Opacity | Scale | Visual |
|-------|---------|-------|--------|
| Normal | 100% | 1.0 | Default |
| Pressed | 70% | 0.95 | Slightly smaller |
| Disabled | 50% | 1.0 | Grayed out |
| Active (toggle) | 100% | 1.0 | Full brightness |

### Connection States

| State | Color | Icon |
|-------|-------|------|
| Connected (WiFi) | Green | wifi.circle.fill |
| Connected (USB) | Green | cable.connector |
| Disconnected | Red | wifi.slash |
| Searching | Orange | Animated dots |

---

## Implementation Notes

### File Locations

#### Core Components
- **Cue Buttons**: `Views/ControlSubviews.swift` (CBPerformanceRow, CBPerformanceList)
- **Top Bar**: `Views/ContentView.swift` (CBTopBar)
- **Control Buttons**: `Views/ControlAreaView.swift` (CBControlButton, CBControlSection)
- **Navigation/Transport**: `Views/ContentView.swift` (DraggableNavigationCapsule, SimpleDraggableTransportDock)

#### Theme System (Hidden)
- **Theme Definitions**: `Models/AppTheme.swift`
- **Theme UI**: `Views/AboutAndAppearanceSheets.swift`
- **Storage**: `@AppStorage("selectedThemeID")`

#### Models
- **Song**: `Models/Song.swift`
- **ControlButton**: `Models/ControlButton.swift`
- **AppMode**: `Models/AppStore.swift`

### Color Implementation

Colors are implemented through the theme system:
```swift
// Base UI colors
currentTheme.backgroundColor(for: colorScheme)
currentTheme.accentColor(for: colorScheme)
currentTheme.primaryTextColor(for: colorScheme)
currentTheme.secondaryTextColor(for: colorScheme)

// Semantic colors
currentTheme.warningColor(for: colorScheme)
currentTheme.errorColor(for: colorScheme)
currentTheme.successColor(for: colorScheme)
```

For cue colors:
```swift
Color(hex: song.colorHex ?? defaultCueColorHex)
```

**Important**: Always use theme color methods instead of hardcoded colors like `.orange`, `.red`, or `.green` to ensure visual consistency across all themes.

### Responsive Behavior

#### Control Area Grid
- Automatically adjusts button size based on available width
- Maintains square aspect ratio
- Supports 2-6 buttons per row

#### Cue List
- Full-width cues with horizontal padding
- Scrollable vertical list
- Selected cue gets extra vertical padding (pushes others away)

#### Floating Elements
- Top bar: Fixed at top
- Navigation/Transport: Draggable, position persisted
- Side menu: Slides from left

---

## Design Tokens (for Designers)

### Quick Reference

```json
{
  "colors": {
    "background": "#1C1C1E",
    "titleBar": "#2C2C2E",
    "accentOrange": "#FF9500",
    "successGreen": "#34C759",
    "errorRed": "#FF3B30",
    "textPrimary": "#FFFFFF",
    "textSecondary": "#98989D"
  },
  "spacing": {
    "base": 4,
    "small": 8,
    "medium": 16,
    "large": 24,
    "xlarge": 36
  },
  "borderRadius": {
    "small": 8,
    "medium": 12,
    "large": 20,
    "pill": 62.5
  },
  "typography": {
    "cueTitleNormal": "22pt Bold",
    "cueTitleSelected": "28pt Bold",
    "cueSubtitleNormal": "Footnote",
    "cueSubtitleSelected": "Headline",
    "buttonLabel": "17pt Bold"
  },
  "dimensions": {
    "cueHeightNormal": 86,
    "cueHeightSelected": 103.2,
    "topBarHeight": 64,
    "navCapsuleWidth": 125,
    "navCapsuleHeight": 275
  }
}
```

---

## Version History

### v1.1.1 (Current)
- **Semantic Color System**: Added theme-based warning, error, and success colors
  - All 11 themes now include dedicated semantic color parameters
  - Both light and dark mode variants for each semantic color
  - ThemeAdminPanel updated to display all semantic colors
  - Color standardization across all UI elements
- Improved visual organization and consistency

### v1.1.0
- Added play icon indicators
- Enhanced selected cue appearance (20% taller, larger text)
- Added subtle top gradient
- Improved navigation icons (minus/plus)
- Fixed theme preview sheet (hidden from UI)
- Improved stroke color contrast system

### v1.0.x
- Initial design system
- Cue mode implementation
- Navigator mode with capsule
- Control area buttons
- Theme system (complete but hidden)

---

## Contact & Feedback

For design questions or suggestions:
- **Email**: support@cuebear.app
- **Website**: https://cuebear.app

---

**Generated**: January 8, 2025
**Version**: 1.1.0
**Platform**: iPad (iOS 17.0+)

*This design system is a living document and will be updated as the app evolves.*
