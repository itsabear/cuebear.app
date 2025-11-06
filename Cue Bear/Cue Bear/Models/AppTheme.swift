import SwiftUI

// MARK: - Dark Mode Behavior
enum DarkModeBehavior: String, Codable {
    case standard  // Responds to system dark mode normally
    case inverted  // Dark in light mode, light in dark mode (future use)
    case fixed     // Ignores system dark mode, always uses light mode colors
}

// MARK: - Theme Models
struct AppTheme: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let genre: String
    let fontName: String
    let darkModeBehavior: DarkModeBehavior  // NEW: Controls dark mode response

    // Light mode colors
    let accentColorHex: String           // Selection stroke color
    let backgroundColorHex: String       // Main app background
    let defaultCueColorHex: String       // Default color for new cues
    let titleBarColorHex: String         // Title bar background (also used for control area and side menu)
    let buttonBackgroundColorHex: String // Control button background

    // Dark mode colors
    let darkAccentColorHex: String
    let darkBackgroundColorHex: String
    let darkDefaultCueColorHex: String
    let darkTitleBarColorHex: String
    let darkButtonBackgroundColorHex: String

    let isDefault: Bool

    // Helper methods to get colors based on color scheme
    func accentColor(for colorScheme: ColorScheme) -> Color {
        let hex = shouldUseDarkMode(for: colorScheme) ? darkAccentColorHex : accentColorHex
        return Color(hex: hex)
    }

    func backgroundColor(for colorScheme: ColorScheme) -> Color {
        let hex = shouldUseDarkMode(for: colorScheme) ? darkBackgroundColorHex : backgroundColorHex
        return Color(hex: hex)
    }

    func backgroundColorHexValue(for colorScheme: ColorScheme) -> String {
        return shouldUseDarkMode(for: colorScheme) ? darkBackgroundColorHex : backgroundColorHex
    }

    func defaultCueColor(for colorScheme: ColorScheme) -> Color {
        let hex = shouldUseDarkMode(for: colorScheme) ? darkDefaultCueColorHex : defaultCueColorHex
        return Color(hex: hex)
    }

    func defaultCueColorHexValue(for colorScheme: ColorScheme) -> String {
        return shouldUseDarkMode(for: colorScheme) ? darkDefaultCueColorHex : defaultCueColorHex
    }

    func titleBarColor(for colorScheme: ColorScheme) -> Color {
        let hex = shouldUseDarkMode(for: colorScheme) ? darkTitleBarColorHex : titleBarColorHex
        return Color(hex: hex)
    }

    func buttonBackgroundColor(for colorScheme: ColorScheme) -> Color {
        let hex = shouldUseDarkMode(for: colorScheme) ? darkButtonBackgroundColorHex : buttonBackgroundColorHex
        return Color(hex: hex)
    }

    // Navigation link tint - darkens background in light mode, lightens in dark mode for subtle contrast
    func navigationLinkColor(for colorScheme: ColorScheme) -> Color {
        let bgHex = shouldUseDarkMode(for: colorScheme) ? darkBackgroundColorHex : backgroundColorHex
        let adjustedHex: String

        if shouldUseDarkMode(for: colorScheme) {
            // Dark mode: lighten the background by 40% for visible links
            adjustedHex = lightenColor(hex: bgHex, by: 0.40)
        } else {
            // Light mode: darken the background by 30% for visible links
            adjustedHex = darkenColor(hex: bgHex, by: 0.30)
        }

        return Color(hex: adjustedHex)
    }

    // NEW: Determine if dark mode colors should be used based on behavior
    private func shouldUseDarkMode(for colorScheme: ColorScheme) -> Bool {
        switch darkModeBehavior {
        case .standard:
            return colorScheme == .dark
        case .fixed:
            return false  // Always use light mode colors
        case .inverted:
            return colorScheme == .light  // Swap light/dark
        }
    }

    // NEW: Determine preferred color scheme for text based on background luminance
    func preferredColorScheme(for systemColorScheme: ColorScheme) -> ColorScheme {
        let backgroundHex = shouldUseDarkMode(for: systemColorScheme) ? darkBackgroundColorHex : backgroundColorHex
        let luminance = relativeLuminance(hex: backgroundHex)

        // If background is dark (low luminance), use dark color scheme to get light text
        // If background is light (high luminance), use light color scheme to get dark text
        return luminance < 0.5 ? .dark : .light
    }

    // Helper: Calculate relative luminance of a color
    private func relativeLuminance(hex: String) -> Double {
        let rgb = hexToRGB(hex)
        func adjust(_ c: Double) -> Double {
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let r = adjust(Double(rgb.0) / 255.0)
        let g = adjust(Double(rgb.1) / 255.0)
        let b = adjust(Double(rgb.2) / 255.0)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    // Helper: Convert hex to RGB
    private func hexToRGB(_ hex: String) -> (Int, Int, Int) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let r = Int((int >> 16) & 0xFF)
        let g = Int((int >> 8) & 0xFF)
        let b = Int(int & 0xFF)
        return (r, g, b)
    }

    // Helper: Convert RGB to hex
    private func rgbToHex(_ r: Int, _ g: Int, _ b: Int) -> String {
        return String(format: "%02X%02X%02X", r, g, b)
    }

    // Helper: Lighten a hex color by a percentage (0.0 to 1.0)
    private func lightenColor(hex: String, by percentage: Double) -> String {
        let (r, g, b) = hexToRGB(hex)
        let newR = min(255, Int(Double(r) + (255.0 - Double(r)) * percentage))
        let newG = min(255, Int(Double(g) + (255.0 - Double(g)) * percentage))
        let newB = min(255, Int(Double(b) + (255.0 - Double(b)) * percentage))
        return rgbToHex(newR, newG, newB)
    }

    // Helper: Darken a hex color by a percentage (0.0 to 1.0)
    private func darkenColor(hex: String, by percentage: Double) -> String {
        let (r, g, b) = hexToRGB(hex)
        let newR = max(0, Int(Double(r) * (1.0 - percentage)))
        let newG = max(0, Int(Double(g) * (1.0 - percentage)))
        let newB = max(0, Int(Double(b) * (1.0 - percentage)))
        return rgbToHex(newR, newG, newB)
    }

    // Get button background color as a slightly lighter version of title bar color
    func lightButtonBackgroundColor(for colorScheme: ColorScheme) -> Color {
        let titleBarHex = shouldUseDarkMode(for: colorScheme) ? darkTitleBarColorHex : titleBarColorHex
        let lightenedHex = lightenColor(hex: titleBarHex, by: 0.15)  // 15% lighter
        return Color(hex: lightenedHex)
    }

    // NEW: Get selection stroke color that contrasts with cue background
    func selectionStrokeColor(for cueColorHex: String?, colorScheme: ColorScheme) -> Color {
        // If no custom color, use accent color
        guard let cueHex = cueColorHex else {
            return accentColor(for: colorScheme)
        }

        // Calculate contrast between accent and cue color
        let accentHex = shouldUseDarkMode(for: colorScheme) ? darkAccentColorHex : accentColorHex
        let accentLuminance = relativeLuminance(hex: accentHex)
        let cueLuminance = relativeLuminance(hex: cueHex)
        let contrast = max(accentLuminance, cueLuminance) / (min(accentLuminance, cueLuminance) + 0.05) + 0.05

        // If accent has good contrast with cue (3:1 or better), use accent
        if contrast >= 3.0 {
            return accentColor(for: colorScheme)
        }

        // Otherwise, choose white or black based on cue luminance
        return cueLuminance > 0.5 ? Color.black : Color.white
    }

    // NEW: Get appropriate text color (primary/secondary) based on actual background luminance
    func primaryTextColor(for colorScheme: ColorScheme) -> Color {
        let backgroundHex = shouldUseDarkMode(for: colorScheme) ? darkBackgroundColorHex : backgroundColorHex
        let luminance = relativeLuminance(hex: backgroundHex)
        // If background is dark, use white text; if light, use black text
        return luminance < 0.5 ? Color.white : Color.black
    }

    func secondaryTextColor(for colorScheme: ColorScheme) -> Color {
        let backgroundHex = shouldUseDarkMode(for: colorScheme) ? darkBackgroundColorHex : backgroundColorHex
        let luminance = relativeLuminance(hex: backgroundHex)
        // If background is dark, use light gray; if light, use dark gray
        return luminance < 0.5 ? Color.white.opacity(0.7) : Color.black.opacity(0.6)
    }

    // Helper method to get font
    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if fontName == "System" {
            return .system(size: size, weight: weight)
        } else {
            return .custom(fontName, size: size)
        }
    }

    static func == (lhs: AppTheme, rhs: AppTheme) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Available Themes
extension AppTheme {
    static let allThemes: [AppTheme] = [
        // Classic (Default)
        AppTheme(
            id: "default",
            name: "Classic",
            genre: "Default",
            fontName: "System",
            darkModeBehavior: .standard,
            // Light mode (Optimized for WCAG AA: 4.5:1 minimum contrast)
            accentColorHex: "FFFFFF",  // White - maximum contrast with blue cues (10.1:1)
            backgroundColorHex: "F2F2F7",
            defaultCueColorHex: "0A84FF",  // Original v1.0.9 blue
            titleBarColorHex: "E5E5EA",
            buttonBackgroundColorHex: "D1D1D6",
            // Dark mode
            darkAccentColorHex: "FFFFFF",  // White for consistency
            darkBackgroundColorHex: "000000",
            darkDefaultCueColorHex: "0A84FF",
            darkTitleBarColorHex: "1C1C1E",
            darkButtonBackgroundColorHex: "2C2C2E",
            isDefault: true
        ),

        // Neon Glow (Pop)
        AppTheme(
            id: "pop",
            name: "Neon Glow",
            genre: "Pop",
            fontName: "Montserrat-Bold",
            darkModeBehavior: .fixed,
            // Light mode (Optimized for WCAG AA: 4.5:1 minimum contrast)
            accentColorHex: "000000",  // Black - maximum contrast with pink cues (7.8:1)
            backgroundColorHex: "1A0A14",
            defaultCueColorHex: "FF66B2",
            titleBarColorHex: "2D1524",
            buttonBackgroundColorHex: "3D2034",
            // Dark mode
            darkAccentColorHex: "000000",  // Same black
            darkBackgroundColorHex: "1A0A14",
            darkDefaultCueColorHex: "FF66B2",
            darkTitleBarColorHex: "2D1524",
            darkButtonBackgroundColorHex: "3D2034",
            isDefault: false
        ),

        // Golden Hour (Hip-Hop)
        AppTheme(
            id: "hiphop",
            name: "Golden Hour",
            genre: "Hip-Hop",
            fontName: "BebasNeue-Regular",
            darkModeBehavior: .standard,
            // Light mode (Optimized for WCAG AA: 4.5:1 minimum contrast)
            accentColorHex: "000000",  // Black - good contrast with gold cues (4.7:1)
            backgroundColorHex: "FFF9E6",
            defaultCueColorHex: "997000",
            titleBarColorHex: "FFF0CC",
            buttonBackgroundColorHex: "FFDC99",
            // Dark mode
            darkAccentColorHex: "FFFFFF",  // White for dark mode
            darkBackgroundColorHex: "1A1508",
            darkDefaultCueColorHex: "FFD93D",
            darkTitleBarColorHex: "2A2210",
            darkButtonBackgroundColorHex: "3A3220",
            isDefault: false
        ),

        // Amp Red (Rock)
        AppTheme(
            id: "rock",
            name: "Amp Red",
            genre: "Rock",
            fontName: "Oswald-Regular",
            darkModeBehavior: .standard,
            // Light mode (Optimized for WCAG AA: 4.5:1 minimum contrast)
            accentColorHex: "FFFFFF",  // White - maximum contrast with red cues (8.9:1)
            backgroundColorHex: "FFE5E5",
            defaultCueColorHex: "990000",
            titleBarColorHex: "FFCCCC",
            buttonBackgroundColorHex: "FF9999",
            // Dark mode
            darkAccentColorHex: "FFFFFF",  // White for dark mode
            darkBackgroundColorHex: "1A0505",
            darkDefaultCueColorHex: "FF3333",
            darkTitleBarColorHex: "2A0F0F",
            darkButtonBackgroundColorHex: "3A1F1F",
            isDefault: false
        ),

        // Cyber Cyan (Electronic)
        AppTheme(
            id: "edm",
            name: "Cyber Cyan",
            genre: "Electronic",
            fontName: "Exo2-ExtraBold",
            darkModeBehavior: .fixed,
            // Light mode (Optimized for WCAG AA: 4.5:1 minimum contrast)
            accentColorHex: "000000",  // Black - maximum contrast with cyan cues (13.2:1)
            backgroundColorHex: "001A1F",
            defaultCueColorHex: "33E0FF",
            titleBarColorHex: "0A2A32",
            buttonBackgroundColorHex: "1A3A42",
            // Dark mode
            darkAccentColorHex: "000000",  // Same black
            darkBackgroundColorHex: "001A1F",
            darkDefaultCueColorHex: "33E0FF",
            darkTitleBarColorHex: "0A2A32",
            darkButtonBackgroundColorHex: "1A3A42",
            isDefault: false
        ),

        // Velvet Soul (R&B)
        AppTheme(
            id: "rnb",
            name: "Velvet Soul",
            genre: "R&B",
            fontName: "PlayfairDisplay-Regular",
            darkModeBehavior: .standard,
            // Light mode (Optimized for WCAG AA: 4.5:1 minimum contrast)
            accentColorHex: "FFFFFF",  // White - maximum contrast with purple cues (10.5:1)
            backgroundColorHex: "F3E6FF",
            defaultCueColorHex: "5F1B87",
            titleBarColorHex: "E8CCFF",
            buttonBackgroundColorHex: "D099FF",
            // Dark mode
            darkAccentColorHex: "FFFFFF",  // White for dark mode
            darkBackgroundColorHex: "120A16",
            darkDefaultCueColorHex: "B366E0",
            darkTitleBarColorHex: "22152A",
            darkButtonBackgroundColorHex: "32253A",
            isDefault: false
        ),

        // Barn Sunset (Country)
        AppTheme(
            id: "country",
            name: "Barn Sunset",
            genre: "Country",
            fontName: "Bitter-Regular",
            darkModeBehavior: .standard,
            // Light mode (Optimized for WCAG AA: 4.5:1 minimum contrast)
            accentColorHex: "FFFFFF",  // White - maximum contrast with brown cues (6.1:1)
            backgroundColorHex: "FFF5E6",
            defaultCueColorHex: "8B5615",
            titleBarColorHex: "FFEACC",
            buttonBackgroundColorHex: "FFD499",
            // Dark mode
            darkAccentColorHex: "FFFFFF",  // White for dark mode
            darkBackgroundColorHex: "1A120A",
            darkDefaultCueColorHex: "E6A85C",
            darkTitleBarColorHex: "2A1F14",
            darkButtonBackgroundColorHex: "3A2F24",
            isDefault: false
        ),

        // Sunset Rhythm (Latin)
        AppTheme(
            id: "latin",
            name: "Sunset Rhythm",
            genre: "Latin",
            fontName: "FredokaOne-Regular",
            darkModeBehavior: .standard,
            // Light mode (Optimized for WCAG AA: 4.5:1 minimum contrast)
            accentColorHex: "FFFFFF",  // White - maximum contrast with orange cues (5.5:1)
            backgroundColorHex: "FFF0E6",
            defaultCueColorHex: "B34700",
            titleBarColorHex: "FFE4CC",
            buttonBackgroundColorHex: "FFCC99",
            // Dark mode
            darkAccentColorHex: "FFFFFF",  // White for dark mode
            darkBackgroundColorHex: "1F0F00",
            darkDefaultCueColorHex: "FF8533",
            darkTitleBarColorHex: "331A0A",
            darkButtonBackgroundColorHex: "432A1A",
            isDefault: false
        ),

        // Hallyu Pink (K-Pop)
        AppTheme(
            id: "kpop",
            name: "Hallyu Pink",
            genre: "K-Pop",
            fontName: "NunitoSans-Black",
            darkModeBehavior: .fixed,
            // Light mode (Optimized for WCAG AA: 4.5:1 minimum contrast)
            accentColorHex: "000000",  // Black - maximum contrast with pink cues (9.7:1)
            backgroundColorHex: "1F0A1A",
            defaultCueColorHex: "FF85E0",
            titleBarColorHex: "33152A",
            buttonBackgroundColorHex: "43253A",
            // Dark mode
            darkAccentColorHex: "000000",  // Black for dark mode
            darkBackgroundColorHex: "1F0A1A",
            darkDefaultCueColorHex: "FF85E0",
            darkTitleBarColorHex: "33152A",
            darkButtonBackgroundColorHex: "43253A",
            isDefault: false
        ),

        // Bourbon Smoke (Jazz)
        AppTheme(
            id: "jazz",
            name: "Bourbon Smoke",
            genre: "Jazz",
            fontName: "CormorantGaramond-Italic",
            darkModeBehavior: .standard,
            // Light mode (Optimized for WCAG AA: 4.5:1 minimum contrast)
            accentColorHex: "FFFFFF",  // White - maximum contrast with wine red cues (10.5:1)
            backgroundColorHex: "FFE6EB",
            defaultCueColorHex: "7A1929",
            titleBarColorHex: "FFCCD6",
            buttonBackgroundColorHex: "FF99AD",
            // Dark mode
            darkAccentColorHex: "FFFFFF",  // White for dark mode
            darkBackgroundColorHex: "14050A",
            darkDefaultCueColorHex: "E6687F",
            darkTitleBarColorHex: "240F18",
            darkButtonBackgroundColorHex: "341F28",
            isDefault: false
        ),

        // Lo-Fi Teal (Indie)
        AppTheme(
            id: "indie",
            name: "Lo-Fi Teal",
            genre: "Indie",
            fontName: "SpaceGrotesk-Medium",
            darkModeBehavior: .standard,
            // Light mode (Optimized for WCAG AA: 4.5:1 minimum contrast)
            accentColorHex: "FFFFFF",  // White - maximum contrast with teal cues (6.4:1)
            backgroundColorHex: "E6F7F2",
            defaultCueColorHex: "1A6B56",
            titleBarColorHex: "CCF0E6",
            buttonBackgroundColorHex: "99E0CC",
            // Dark mode
            darkAccentColorHex: "FFFFFF",  // White for dark mode
            darkBackgroundColorHex: "0A1512",
            darkDefaultCueColorHex: "52D9B8",
            darkTitleBarColorHex: "14251F",
            darkButtonBackgroundColorHex: "24352F",
            isDefault: false
        ),

    ]

    static let defaultTheme = allThemes[0]
}

