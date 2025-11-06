import SwiftUI

// MARK: - Theme Models
struct AppTheme: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let genre: String
    let fontName: String

    // Light mode colors
    let accentColorHex: String           // Selection stroke color
    let backgroundColorHex: String       // Main app background
    let defaultCueColorHex: String       // Default color for new cues
    let titleBarColorHex: String         // Title bar background
    let controlAreaColorHex: String      // Control button area background
    let sideMenuColorHex: String         // Side menu background
    let buttonBackgroundColorHex: String // Control button background

    // Dark mode colors
    let darkAccentColorHex: String
    let darkBackgroundColorHex: String
    let darkDefaultCueColorHex: String
    let darkTitleBarColorHex: String
    let darkControlAreaColorHex: String
    let darkSideMenuColorHex: String
    let darkButtonBackgroundColorHex: String

    let isDefault: Bool

    // Helper methods to get colors based on color scheme
    func accentColor(for colorScheme: ColorScheme) -> Color {
        Color(hex: colorScheme == .dark ? darkAccentColorHex : accentColorHex)
    }

    func backgroundColor(for colorScheme: ColorScheme) -> Color {
        Color(hex: colorScheme == .dark ? darkBackgroundColorHex : backgroundColorHex)
    }

    func defaultCueColor(for colorScheme: ColorScheme) -> Color {
        Color(hex: colorScheme == .dark ? darkDefaultCueColorHex : defaultCueColorHex)
    }

    func titleBarColor(for colorScheme: ColorScheme) -> Color {
        Color(hex: colorScheme == .dark ? darkTitleBarColorHex : titleBarColorHex)
    }

    func controlAreaColor(for colorScheme: ColorScheme) -> Color {
        Color(hex: colorScheme == .dark ? darkControlAreaColorHex : controlAreaColorHex)
    }

    func sideMenuColor(for colorScheme: ColorScheme) -> Color {
        Color(hex: colorScheme == .dark ? darkSideMenuColorHex : sideMenuColorHex)
    }

    func buttonBackgroundColor(for colorScheme: ColorScheme) -> Color {
        Color(hex: colorScheme == .dark ? darkButtonBackgroundColorHex : buttonBackgroundColorHex)
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
        // Default Theme
        AppTheme(
            id: "default",
            name: "Classic",
            genre: "Default",
            fontName: "System",
            // Light mode
            accentColorHex: "007AFF",
            backgroundColorHex: "F2F2F7",
            defaultCueColorHex: "0A84FF",
            titleBarColorHex: "E5E5EA",
            controlAreaColorHex: "E5E5EA",
            sideMenuColorHex: "E5E5EA",
            buttonBackgroundColorHex: "D1D1D6",
            // Dark mode
            darkAccentColorHex: "0A84FF",
            darkBackgroundColorHex: "000000",
            darkDefaultCueColorHex: "0A84FF",
            darkTitleBarColorHex: "1C1C1E",
            darkControlAreaColorHex: "1C1C1E",
            darkSideMenuColorHex: "1C1C1E",
            darkButtonBackgroundColorHex: "2C2C2E",
            isDefault: true
        ),

        // Pop
        AppTheme(
            id: "pop",
            name: "Neon Glow",
            genre: "Pop",
            fontName: "Montserrat-Bold",
            // Light mode
            accentColorHex: "FF3399",
            backgroundColorHex: "FFE5F0",
            defaultCueColorHex: "FF66B2",
            titleBarColorHex: "FFD1E8",
            controlAreaColorHex: "FFD1E8",
            sideMenuColorHex: "FFBDDB",
            buttonBackgroundColorHex: "FFA8CF",
            // Dark mode
            darkAccentColorHex: "FF3399",
            darkBackgroundColorHex: "1A0A14",
            darkDefaultCueColorHex: "FF66B2",
            darkTitleBarColorHex: "2D1524",
            darkControlAreaColorHex: "2D1524",
            darkSideMenuColorHex: "2D1524",
            darkButtonBackgroundColorHex: "3D2034",
            isDefault: false
        ),

        // Hip-Hop / Rap
        AppTheme(
            id: "hiphop",
            name: "Golden Hour",
            genre: "Hip-Hop",
            fontName: "BebasNeue-Regular",
            accentColorHex: "D9B327",             // Gold
            backgroundColorHex: "FFF9E6",          // Light Gold/Cream
            defaultCueColorHex: "FFD93D",          // Bright Gold
            titleBarColorHex: "FFF0CC",            // Lighter Gold
            controlAreaColorHex: "FFF0CC",         // Lighter Gold
            sideMenuColorHex: "FFE6B3",            // Medium Gold
            buttonBackgroundColorHex: "FFDC99",    // Soft Gold
            // Dark mode
            darkAccentColorHex: "D9B327",
            darkBackgroundColorHex: "1A1508",
            darkDefaultCueColorHex: "FFD93D",
            darkTitleBarColorHex: "2A2210",
            darkControlAreaColorHex: "2A2210",
            darkSideMenuColorHex: "2A2210",
            darkButtonBackgroundColorHex: "3A3220",
            isDefault: false
        ),

        // Rock
        AppTheme(
            id: "rock",
            name: "Amp Red",
            genre: "Rock",
            fontName: "Oswald-Regular",
            accentColorHex: "CC1A1A",             // Bright Red
            backgroundColorHex: "FFE5E5",          // Light Red/Pink
            defaultCueColorHex: "FF3333",          // Fire Red
            titleBarColorHex: "FFCCCC",            // Lighter Red
            controlAreaColorHex: "FFCCCC",         // Lighter Red
            sideMenuColorHex: "FFB3B3",            // Medium Red
            buttonBackgroundColorHex: "FF9999",    // Soft Red
            // Dark mode
            darkAccentColorHex: "CC1A1A",
            darkBackgroundColorHex: "1A0505",
            darkDefaultCueColorHex: "FF3333",
            darkTitleBarColorHex: "2A0F0F",
            darkControlAreaColorHex: "2A0F0F",
            darkSideMenuColorHex: "2A0F0F",
            darkButtonBackgroundColorHex: "3A1F1F",
            isDefault: false
        ),

        // Electronic / EDM
        AppTheme(
            id: "edm",
            name: "Cyber Cyan",
            genre: "Electronic",
            fontName: "Exo2-ExtraBold",
            accentColorHex: "00CCFF",             // Cyan
            backgroundColorHex: "E6F7FF",          // Light Cyan
            defaultCueColorHex: "33E0FF",          // Bright Cyan
            titleBarColorHex: "CCF0FF",            // Lighter Cyan
            controlAreaColorHex: "CCF0FF",         // Lighter Cyan
            sideMenuColorHex: "B3E9FF",            // Medium Cyan
            buttonBackgroundColorHex: "99E0FF",    // Soft Cyan
            // Dark mode
            darkAccentColorHex: "00CCFF",
            darkBackgroundColorHex: "001A1F",
            darkDefaultCueColorHex: "33E0FF",
            darkTitleBarColorHex: "0A2A32",
            darkControlAreaColorHex: "0A2A32",
            darkSideMenuColorHex: "0A2A32",
            darkButtonBackgroundColorHex: "1A3A42",
            isDefault: false
        ),

        // R&B
        AppTheme(
            id: "rnb",
            name: "Velvet Soul",
            genre: "R&B",
            fontName: "PlayfairDisplay-Regular",
            accentColorHex: "8C4DB3",             // Purple
            backgroundColorHex: "F3E6FF",          // Light Purple/Lavender
            defaultCueColorHex: "B366E0",          // Bright Purple
            titleBarColorHex: "E8CCFF",            // Lighter Purple
            controlAreaColorHex: "E8CCFF",         // Lighter Purple
            sideMenuColorHex: "DCB3FF",            // Medium Purple
            buttonBackgroundColorHex: "D099FF",    // Soft Purple
            // Dark mode
            darkAccentColorHex: "8C4DB3",
            darkBackgroundColorHex: "120A16",
            darkDefaultCueColorHex: "B366E0",
            darkTitleBarColorHex: "22152A",
            darkControlAreaColorHex: "22152A",
            darkSideMenuColorHex: "22152A",
            darkButtonBackgroundColorHex: "32253A",
            isDefault: false
        ),

        // Country
        AppTheme(
            id: "country",
            name: "Barn Sunset",
            genre: "Country",
            fontName: "Bitter-Regular",
            accentColorHex: "BF8C4D",             // Tan/Brown
            backgroundColorHex: "FFF5E6",          // Light Tan/Cream
            defaultCueColorHex: "E6A85C",          // Bright Tan
            titleBarColorHex: "FFEACC",            // Lighter Tan
            controlAreaColorHex: "FFEACC",         // Lighter Tan
            sideMenuColorHex: "FFDFB3",            // Medium Tan
            buttonBackgroundColorHex: "FFD499",    // Soft Tan
            // Dark mode
            darkAccentColorHex: "BF8C4D",
            darkBackgroundColorHex: "1A120A",
            darkDefaultCueColorHex: "E6A85C",
            darkTitleBarColorHex: "2A1F14",
            darkControlAreaColorHex: "2A1F14",
            darkSideMenuColorHex: "2A1F14",
            darkButtonBackgroundColorHex: "3A2F24",
            isDefault: false
        ),

        // Latin
        AppTheme(
            id: "latin",
            name: "Sunset Rhythm",
            genre: "Latin",
            fontName: "FredokaOne-Regular",
            accentColorHex: "FF6600",             // Orange
            backgroundColorHex: "FFF0E6",          // Light Orange/Peach
            defaultCueColorHex: "FF8533",          // Bright Orange
            titleBarColorHex: "FFE4CC",            // Lighter Orange
            controlAreaColorHex: "FFE4CC",         // Lighter Orange
            sideMenuColorHex: "FFD8B3",            // Medium Orange
            buttonBackgroundColorHex: "FFCC99",    // Soft Orange
            // Dark mode
            darkAccentColorHex: "FF6600",
            darkBackgroundColorHex: "1F0F00",
            darkDefaultCueColorHex: "FF8533",
            darkTitleBarColorHex: "331A0A",
            darkControlAreaColorHex: "331A0A",
            darkSideMenuColorHex: "331A0A",
            darkButtonBackgroundColorHex: "432A1A",
            isDefault: false
        ),

        // K-Pop
        AppTheme(
            id: "kpop",
            name: "Hallyu Pink",
            genre: "K-Pop",
            fontName: "NunitoSans-Black",
            accentColorHex: "F266CC",             // Bright Pink
            backgroundColorHex: "FFEBF7",          // Light Pink/White
            defaultCueColorHex: "FF85E0",          // Pastel Pink
            titleBarColorHex: "FFD6F0",            // Lighter Pink
            controlAreaColorHex: "FFD6F0",         // Lighter Pink
            sideMenuColorHex: "FFC2E8",            // Medium Pink
            buttonBackgroundColorHex: "FFADE0",    // Soft Pink
            // Dark mode
            darkAccentColorHex: "F266CC",
            darkBackgroundColorHex: "1F0A1A",
            darkDefaultCueColorHex: "FF85E0",
            darkTitleBarColorHex: "33152A",
            darkControlAreaColorHex: "33152A",
            darkSideMenuColorHex: "33152A",
            darkButtonBackgroundColorHex: "43253A",
            isDefault: false
        ),

        // Jazz
        AppTheme(
            id: "jazz",
            name: "Bourbon Smoke",
            genre: "Jazz",
            fontName: "CormorantGaramond-Italic",
            accentColorHex: "991F33",             // Deep Red
            backgroundColorHex: "FFE6EB",          // Light Burgundy/Rose
            defaultCueColorHex: "CC3D5C",          // Wine Red
            titleBarColorHex: "FFCCD6",            // Lighter Burgundy
            controlAreaColorHex: "FFCCD6",         // Lighter Burgundy
            sideMenuColorHex: "FFB3C2",            // Medium Burgundy
            buttonBackgroundColorHex: "FF99AD",    // Soft Burgundy
            // Dark mode
            darkAccentColorHex: "991F33",
            darkBackgroundColorHex: "14050A",
            darkDefaultCueColorHex: "CC3D5C",
            darkTitleBarColorHex: "240F18",
            darkControlAreaColorHex: "240F18",
            darkSideMenuColorHex: "240F18",
            darkButtonBackgroundColorHex: "341F28",
            isDefault: false
        ),

        // Indie / Alternative
        AppTheme(
            id: "indie",
            name: "Lo-Fi Teal",
            genre: "Indie",
            fontName: "SpaceGrotesk-Medium",
            accentColorHex: "33A88C",             // Teal
            backgroundColorHex: "E6F7F2",          // Light Teal/Mint
            defaultCueColorHex: "52D9B8",          // Bright Teal
            titleBarColorHex: "CCF0E6",            // Lighter Teal
            controlAreaColorHex: "CCF0E6",         // Lighter Teal
            sideMenuColorHex: "B3E8D9",            // Medium Teal
            buttonBackgroundColorHex: "99E0CC",    // Soft Teal
            // Dark mode
            darkAccentColorHex: "33A88C",
            darkBackgroundColorHex: "0A1512",
            darkDefaultCueColorHex: "52D9B8",
            darkTitleBarColorHex: "14251F",
            darkControlAreaColorHex: "14251F",
            darkSideMenuColorHex: "14251F",
            darkButtonBackgroundColorHex: "24352F",
            isDefault: false
        )
    ]

    static let defaultTheme = allThemes[0]
}
