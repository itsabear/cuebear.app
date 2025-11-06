# Dark Mode Strategy Options for Cue Bear Themes

## Current Situation
- Some themes (like Golden Hour, Cyber Cyan) look washed out in light mode
- You want some themes to have dark backgrounds by default
- iOS system dark mode complicates this

## Three Implementation Strategies

### Strategy 1: Theme-Based Dark Mode Behavior (RECOMMENDED)

Add a property to each theme that controls dark mode behavior:

```swift
enum DarkModeBehavior {
    case standard      // Responds to system dark mode normally
    case inverted      // Dark in light mode, light in dark mode
    case fixed         // Ignores system dark mode, always uses light mode colors
}
```

**Example Themes:**

**Classic** (standard behavior):
- Light mode: Light background
- Dark mode: Dark background

**Noir/Stage** (inverted behavior):
- Light mode: Dark background (your desired look)
- Dark mode: Medium-light background (still readable)

**Neon Glow** (fixed behavior):
- Light mode: Dark background with bright neon colors
- Dark mode: Same (doesn't change)

### Strategy 2: Manual Dark Mode Toggle

Add a setting: "Ignore System Dark Mode"
- When enabled, app always uses light mode colors regardless of system setting
- Users who want dark themes can enable this
- Simpler to implement but less flexible

### Strategy 3: Per-Theme Dark Mode Switch

In the Appearance sheet, each theme preview shows:
- Default look
- Toggle: "Use dark version" (per theme)

Users can mix and match:
- Classic → Follow system
- Neon Glow → Always dark
- Golden Hour → Always light

## Recommendation for Live Performance App

**Use Strategy 1 (Theme-Based Behavior)** because:

1. **Stage Visibility** - Some themes (like a "blackout" or "noir" theme) NEED dark backgrounds for stage use
2. **Automatic Adaptation** - Themes can be smart about readability in both modes
3. **User Control** - You can add an override toggle later if needed
4. **Professional** - Matches how pro audio/video apps handle this

## Example Implementation

For a "Stage Noir" theme you want:

```swift
AppTheme(
    id: "noir",
    name: "Stage Noir",
    genre: "Performance",
    fontName: "System",
    darkModeBehavior: .inverted,  // <- New property

    // Light mode = DARK stage look
    accentColorHex: "00D4FF",        // Bright cyan accent
    backgroundColorHex: "0A0A0A",    // Near black
    defaultCueColorHex: "FFD700",    // Gold cues
    // ...

    // Dark mode = Readable but still dark
    darkAccentColorHex: "00D4FF",    // Same cyan
    darkBackgroundColorHex: "1A1A1A", // Slightly lighter for readability
    darkDefaultCueColorHex: "FFE44D",  // Brighter gold
    // ...
)
```

### Benefits:
- ✅ You get dark themes in light mode
- ✅ Still accessible in dark mode
- ✅ Each theme can choose its behavior
- ✅ No confusing user settings
- ✅ Professional approach

## Implementation Effort

**Small Change:**
1. Add `DarkModeBehavior` enum
2. Add `darkModeBehavior` property to `AppTheme`
3. Update color helper methods to respect behavior
4. Set behavior for each theme

**Time:** ~30 minutes

## Alternative: Just Don't Support Dark Mode on Some Themes

If a theme is designed to be dark (like Neon Glow), you could:
- Only provide light mode colors
- Set dark mode colors to be identical
- Theme stays consistent regardless of system setting

**Simpler but less flexible**

---

## My Recommendation

**Implement Strategy 1** with these theme behaviors:

- **Classic, Rock, Country, Jazz** → Standard (follow system)
- **Neon Glow, Cyber Cyan, K-Pop** → Fixed (stay vibrant, ignore dark mode)
- **Any future "Noir" or "Stage" themes** → Inverted (dark by default, readable in dark mode)

This gives you maximum flexibility while keeping themes professional and accessible.

Would you like me to implement this?
