# Cue Bear design foundation (skeleton)

Every screen gets its look from two files in `Cue Bear/Cue Bear/Design/`:

- `CBTokens.swift`: type sizes, spacing, corner shapes, colors, and the UIKit appearance.
- `CBComponents.swift`: the standard pieces built from those values.

The current values are a plain dark skeleton: consistent, not final. When the real design
language is ready, change the values here and every screen follows.

## Tokens

| Group | Values |
| --- | --- |
| Type (Sora) | micro 10 · caption 12 · small 14 · body 16 · large 18 · title 22 · heading 28 · display 40 · hero 64 |
| Weights | Regular, and Bold for semibold and heavier (Sora ships two weights) |
| Spacing | 2 · 4 · 8 · 12 · 16 · 24 · 32 · 48 |
| Corners | small 8 · control 10 · card 14 · panel 20 |
| Sizes | touch target 44 · control 44 · large control 52 · hairline 1 · selection 2 |

| Color | Use |
| --- | --- |
| `stage` | Show mode background (black) |
| `background` | screens and sheets |
| `surface` / `surfaceRaised` | cards, rows, tiles / fields on a card |
| `chip` | floating chips over content (top bar) |
| `stroke`, `strokeStrong`, `separator` | lines |
| `textPrimary`, `textSecondary`, `textTertiary`, `textDisabled` | text |
| `primary` / `onPrimary` | the main action (white, black text), and GO |
| `highlight` | selection, "now", active, links |
| `success`, `warning`, `danger` | status; `usb` and `wifi` for the connection tags |

Cue colors are content, not chrome: they stay per cue (chosen by the user).

## Components

| Piece | Use it for |
| --- | --- |
| `.cbChip()` | buttons floating over content (top bar, toolbars) |
| `.cbCard(fill:outline:)` | a block of content on a screen |
| `.cbRow()` | rows in a Form or List |
| `.cbFormChrome()` | a Form or List on the screen background |
| `.cbSheetChrome()` | the root of every sheet: background, dark scheme, type, tint |
| `CBSheetHeader` | the header of every sheet (Cancel / title / Done) |
| `CBButtonStyle` (`.cbPrimary`, `.cbSecondary`, `.cbDestructive`, `.cbHighlight`) | buttons |
| `CBSheetButton`, `CBSheetIconButton`, `CBSheetIconMenu` | header and toolbar buttons |
| `CBSectionLabel` | small uppercase label above a group |
| `CBPill`, `CBTag`, `CBStatusDot` | status, badges |
| `CBTextFieldStyle` | text fields on a card |
| `CBDialog` (`.cbDialog`) | alerts and text prompts |

## Rules for new screens

1. No literal font sizes: `Font.cb(.body, .semibold)`, `Font.cbIcon(...)` for SF Symbols, `Font.cbMono(...)` for numbers.
2. No literal corner radii: `CBRadius`.
3. No system colors for chrome (`.secondary`, `.blue`, `Color.gray`...): `CBColor`.
4. Sheets: `CBSheetHeader` + `.cbSheetChrome()`, presented with `.presentationBackground(CBColor.background)`.
5. One primary (white) button per screen at most.
