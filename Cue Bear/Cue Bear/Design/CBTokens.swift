//
//  CBTokens.swift — Cue Bear design foundation
//
//  Every screen takes its type sizes, spacing, corner shapes and colors from here.
//  This is the skeleton look: plain, dark and consistent. When the real design language
//  arrives, change the values in this file (and CBComponents.swift) and the whole app follows.
//
//  Rules:
//  - No literal font sizes in screens: use Font.cb(.size, weight), Font.cbIcon or Font.cbMono.
//  - No literal corner radii: use CBRadius.
//  - Chrome colors come from CBColor. Cue colors (chosen by the user) stay per cue.
//

import SwiftUI
import UIKit

// MARK: - Type

/// The type scale. Nine sizes cover everything from badges to the stage screen.
enum CBTextSize: CGFloat {
    case micro = 10     // badges, tiny labels
    case caption = 12   // secondary lines, section labels
    case small = 14     // supporting text, footers
    case body = 16      // default text, buttons, rows
    case large = 18     // emphasized rows, sheet titles
    case title = 22     // card titles
    case heading = 28   // screen headings
    case display = 40   // stage: current song
    case hero = 64      // stage: GO
}

/// The interface typeface (Sora). Sora ships in Regular and Bold; semibold and heavier map to Bold.
enum CBTypeface {
    static let regular = "Sora-Regular"
    static let bold = "Sora-Bold"

    static func name(for weight: Font.Weight) -> String {
        [Font.Weight.semibold, .bold, .heavy, .black].contains(weight) ? bold : regular
    }

    static func uiFont(_ size: CBTextSize, bold isBold: Bool = false) -> UIFont {
        UIFont(name: isBold ? bold : regular, size: size.rawValue)
            ?? .systemFont(ofSize: size.rawValue, weight: isBold ? .bold : .regular)
    }
}

extension Font {
    /// Interface text at a size from the scale.
    static func cb(_ size: CBTextSize, _ weight: Font.Weight = .regular) -> Font {
        .custom(CBTypeface.name(for: weight), size: size.rawValue)
    }

    /// Interface text at a computed size (for views that scale with their container).
    static func cb(points: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom(CBTypeface.name(for: weight), size: points)
    }

    /// SF Symbols at a size from the scale.
    static func cbIcon(_ size: CBTextSize, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size.rawValue, weight: weight)
    }

    /// SF Symbols at a computed size.
    static func cbIcon(points: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: points, weight: weight)
    }

    /// Numbers that must not jump around (MIDI values, counters).
    static func cbMono(_ size: CBTextSize, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size.rawValue, weight: weight, design: .monospaced)
    }
}

// MARK: - Spacing

enum CBSpace {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

// MARK: - Shape

enum CBRadius {
    /// Badges, swatches, small fields
    static let small: CGFloat = 8
    /// Buttons, chips, text fields, list rows
    static let control: CGFloat = 10
    /// Cards, tiles, panels inside a screen
    static let card: CGFloat = 14
    /// Sheets, dialogs, popovers
    static let panel: CGFloat = 20
}

enum CBSize {
    /// Minimum touch target
    static let touch: CGFloat = 44
    /// Standard button and chip height
    static let control: CGFloat = 44
    /// Large primary buttons
    static let largeControl: CGFloat = 52
    /// Stroke widths
    static let hairline: CGFloat = 1
    static let selection: CGFloat = 2
}

// MARK: - Color

/// Chrome colors. Dark by default (the app runs in its dark Classic theme).
enum CBColor {
    // Backgrounds, from back to front
    /// Stage screens (Show mode): true black, least light on stage
    static let stage = Color.black
    /// Screen and sheet background
    static let background = Color(hex: "1C1C1E")
    /// Cards, list rows, tiles
    static let surface = Color(hex: "2C2C2E")
    /// Something raised on a surface (a field inside a card)
    static let surfaceRaised = Color(hex: "3A3A3C")
    /// Floating chips over content (top bar, toolbars)
    static let chip = Color.black.opacity(0.5)
    static let chipPressed = Color.black.opacity(0.7)

    // Lines
    static let stroke = Color.white.opacity(0.2)
    static let strokeStrong = Color.white.opacity(0.4)
    static let separator = Color.white.opacity(0.12)

    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.45)
    static let textDisabled = Color.white.opacity(0.3)

    // Actions
    /// Primary button fill (text on it: onPrimary)
    static let primary = Color.white
    static let onPrimary = Color.black
    /// Selection, "now playing", active state
    static let highlight = Color(hex: "0A84FF")
    static let onHighlight = Color.white

    // Status
    static let success = Color(hex: "32D74B")
    static let warning = Color(hex: "FF9F0A")
    static let danger = Color(hex: "FF453A")

    // Connection types
    static let usb = success
    static let wifi = highlight
}

// MARK: - System appearance

/// UIKit pieces SwiftUI doesn't style (navigation titles, segmented controls).
enum CBAppearance {
    static func apply() {
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.titleTextAttributes = [.font: CBTypeface.uiFont(.large, bold: true), .foregroundColor: UIColor.white]
        nav.largeTitleTextAttributes = [.font: CBTypeface.uiFont(.heading, bold: true), .foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav

        let seg = UISegmentedControl.appearance()
        seg.setTitleTextAttributes([.font: CBTypeface.uiFont(.small)], for: .normal)
        seg.setTitleTextAttributes([.font: CBTypeface.uiFont(.small, bold: true), .foregroundColor: UIColor.black], for: .selected)
        seg.selectedSegmentTintColor = .white
    }
}
