//
//  Color+CueBear.swift — Cue Bear
//

import SwiftUI
@_exported import Foundation
import UIKit

// MARK: - Color Extension for Similarity Check
extension Color {
    /// Check if this color is similar to another color (for stroke visibility)
    func isSimilarTo(_ other: Color) -> Bool {
        // Convert both colors to RGB components
        guard let selfComponents = self.cgColor?.components,
              let otherComponents = other.cgColor?.components,
              selfComponents.count >= 3,
              otherComponents.count >= 3 else {
            return false
        }

        // Calculate color distance using simple Euclidean distance
        let rDiff = selfComponents[0] - otherComponents[0]
        let gDiff = selfComponents[1] - otherComponents[1]
        let bDiff = selfComponents[2] - otherComponents[2]
        let distance = sqrt(rDiff * rDiff + gDiff * gDiff + bDiff * bDiff)

        // Consider colors similar if distance is less than 0.5 (threshold)
        // Increased from 0.3 to 0.5 to be more liberal in detecting similar colors
        return distance < 0.5
    }

    /// Calculate WCAG relative luminance for a color
    /// Based on WCAG 2.1 specification for contrast ratio calculation
    func relativeLuminance() -> Double {
        guard let components = cgColor?.components, components.count >= 3 else {
            return 0.0
        }

        func adjust(_ component: CGFloat) -> Double {
            let c = Double(component)
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }

        let r = adjust(components[0])
        let g = adjust(components[1])
        let b = adjust(components[2])

        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    /// Determine if this color needs dark text (true) or light text (false) for optimal readability
    /// Uses WCAG relative luminance to ensure proper contrast
    func needsDarkText() -> Bool {
        let luminance = relativeLuminance()
        // Use 0.5 as threshold - colors brighter than this need dark text
        // This matches the approach used in color_analysis_tool.py
        return luminance > 0.5
    }
}

// MARK: - Color Extension (Hex Support)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }

    // Calculate relative luminance and return appropriate text color
    // Uses WCAG formula for luminance calculation
    var contrastingTextColor: Color {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return .white
        }

        // Get RGB components
        let r = components[0]
        let g = components[1]
        let b = components[2]

        // Calculate relative luminance using WCAG formula
        // https://www.w3.org/TR/WCAG20/#relativeluminancedef
        func adjust(_ component: CGFloat) -> CGFloat {
            if component <= 0.03928 {
                return component / 12.92
            }
            return pow((component + 0.055) / 1.055, 2.4)
        }

        let luminance = 0.2126 * adjust(r) + 0.7152 * adjust(g) + 0.0722 * adjust(b)

        // If luminance is greater than 0.5, use dark text, otherwise use white text
        return luminance > 0.5 ? .black : .white
    }

    // Adjust brightness by a percentage (-1.0 to 1.0)
    func adjust(brightness delta: Double) -> Color {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return self
        }

        let r = max(0, min(1, components[0] + delta))
        let g = max(0, min(1, components[1] + delta))
        let b = max(0, min(1, components[2] + delta))
        let a = components.count >= 4 ? components[3] : 1.0

        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
