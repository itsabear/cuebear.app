// ColorPicker.swift - Custom color picker with predefined colors
import SwiftUI

// Curated 24-color palette — pastels, vivids, rich deeps, darks
// Shared across color pickers and auto-assign logic
let curatedColorPalette: [String] = [
    // Row 1: Lights — cream, pastel pink, sand, sage, sky, wheat
    "#EFE8DF", "#FFB3BA", "#D8BA98", "#A8B5A2", "#96C0CE", "#C9B99A",
    // Row 2: Vivids — red, blue, green, purple, cyan, yellow
    "#FF1744", "#2979FF", "#00E676", "#D500F9", "#00E5FF", "#FFFF00",
    // Row 3: Deeps — maroon, burnt orange, forest, deep teal, deep purple, deep rose
    "#7F0303", "#E65100", "#4A6741", "#00796B", "#6A1B9A", "#AD1457",
    // Row 4: Darks — espresso, midnight teal, navy, charcoal, near black, black
    "#5D4037", "#0F414A", "#2C3E50", "#37474F", "#212121", "#1A1A1C",
]

// MARK: - Inline Color Picker (for DisclosureGroup)
struct CBColorPickerInline: View {
    @Binding var selectedColorHex: String?

    private var allColors: [String?] {
        var colors: [String?] = [nil]  // Default/None tile
        colors.append(contentsOf: curatedColorPalette)
        return colors
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
            ForEach(allColors.indices, id: \.self) { index in
                ColorTile(
                    colorHex: allColors[index],
                    isSelected: selectedColorHex == allColors[index]
                )
                .onTapGesture {
                    selectedColorHex = allColors[index]
                    debugPrint("🎨 ColorPicker: Selected color \(allColors[index] ?? "nil")")
                }
            }
        }
    }
}

// MARK: - Color Tile
private struct ColorTile: View {
    let colorHex: String?
    let isSelected: Bool

    var body: some View {
        ZStack {
            if let hex = colorHex {
                Color(hex: hex)
                    .aspectRatio(1, contentMode: .fit)
                    .cornerRadius(CBRadius.small)
            } else {
                // Default/None tile - show checkered pattern
                ZStack {
                    Color.gray.opacity(0.2)
                    Image(systemName: "xmark")
                        .foregroundStyle(CBColor.textSecondary)
                }
                .aspectRatio(1, contentMode: .fit)
                .cornerRadius(CBRadius.small)
            }

            if isSelected {
                RoundedRectangle(cornerRadius: CBRadius.small)
                    .stroke(Color.white, lineWidth: 3)
            }
        }
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
