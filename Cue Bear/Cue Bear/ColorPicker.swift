// ColorPicker.swift - Custom color picker with predefined colors
import SwiftUI

// MARK: - Inline Color Picker (for DisclosureGroup)
struct CBColorPickerInline: View {
    @Binding var selectedColorHex: String?
    
    // Color palettes from the reference image
    private let pastelColors: [(String, String)] = [
        ("#FFB3BA", "Pastel"),
        ("#FFB3D9", "Pastel"),
        ("#FFC785", "Pastel"),
        ("#FFF9A8", "Pastel"),
        ("#B3E5FC", "Pastel"),
        ("#B3D9FF", "Pastel"),
        ("#B3E0C3", "Pastel"),
        ("#D4B3FF", "Pastel"),
        ("#FFCCB3", "Pastel"),
        ("#C3F0CA", "Pastel"),
        ("#E0B3FF", "Pastel"),
        ("#FFF4B3", "Pastel")
    ]

    private let neonColors: [(String, String)] = [
        ("#FF1744", "Neon"),
        ("#FF4081", "Neon"),
        ("#FFFF00", "Neon"),
        ("#00FF41", "Neon"),
        ("#00E5FF", "Neon"),
        ("#00B0FF", "Neon"),
        ("#2979FF", "Neon"),
        ("#D500F9", "Neon"),
        ("#FF9100", "Neon"),
        ("#FF3D00", "Neon"),
        ("#76FF03", "Neon"),
        ("#00E5FF", "Neon")
    ]

    private let basicColors: [(String, String)] = [
        ("#F44336", "Basic"),
        ("#9C27B0", "Basic"),
        ("#3F51B5", "Basic"),
        ("#03A9F4", "Basic"),
        ("#009688", "Basic"),
        ("#4CAF50", "Basic"),
        ("#FFEB3B", "Basic"),
        ("#FF9800", "Basic"),
        ("#795548", "Basic"),
        ("#FF5722", "Basic"),
        ("#8BC34A", "Basic"),
        ("#2196F3", "Basic")
    ]

    private let desaturatedColors: [(String, String)] = [
        ("#5D4037", "Desaturated"),
        ("#8D6E63", "Desaturated"),
        ("#BCAAA4", "Desaturated"),
        ("#78909C", "Desaturated"),
        ("#90A4AE", "Desaturated"),
        ("#607D8B", "Desaturated"),
        ("#AED581", "Desaturated"),
        ("#FFF176", "Desaturated"),
        ("#D7CCC8", "Desaturated"),
        ("#A1887F", "Desaturated"),
        ("#BDBDBD", "Desaturated"),
        ("#E0E0E0", "Desaturated")
    ]

    private let grayscaleColors: [(String, String)] = [
        ("#000000", "Grayscale"),
        ("#212121", "Grayscale"),
        ("#424242", "Grayscale"),
        ("#616161", "Grayscale"),
        ("#757575", "Grayscale"),
        ("#9E9E9E", "Grayscale"),
        ("#BDBDBD", "Grayscale"),
        ("#E0E0E0", "Grayscale"),
        ("#EEEEEE", "Grayscale"),
        ("#F5F5F5", "Grayscale"),
        ("#FAFAFA", "Grayscale"),
        ("#FFFFFF", "Grayscale")
    ]

    private let modernColors: [(String, String)] = [
        ("#FF6B6B", "Modern"),
        ("#FFAA85", "Modern"),
        ("#FFD369", "Modern"),
        ("#7FC8A9", "Modern"),
        ("#5DADE2", "Modern"),
        ("#6495ED", "Modern"),
        ("#8E7CC3", "Modern"),
        ("#C77EB5", "Modern"),
        ("#FF7EB3", "Modern"),
        ("#52B2CF", "Modern"),
        ("#A8E6A3", "Modern")
    ]

    private var allColors: [(String?, String)] {
        var colors: [(String?, String)] = [(nil, "Default")]
        colors.append(contentsOf: pastelColors)
        colors.append(contentsOf: neonColors)
        colors.append(contentsOf: basicColors)
        colors.append(contentsOf: desaturatedColors)
        colors.append(contentsOf: grayscaleColors)
        colors.append(contentsOf: modernColors)
        return colors
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 12), spacing: 8) {
            ForEach(allColors.indices, id: \.self) { index in
                ColorTile(
                    colorHex: allColors[index].0,
                    isSelected: selectedColorHex == allColors[index].0
                )
                .onTapGesture {
                    selectedColorHex = allColors[index].0
                    debugPrint("🎨 ColorPicker: Selected color \(allColors[index].0 ?? "nil")")
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
                    .cornerRadius(8)
            } else {
                // Default/None tile - show checkered pattern
                ZStack {
                    Color.gray.opacity(0.2)
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
                .aspectRatio(1, contentMode: .fit)
                .cornerRadius(8)
            }

            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue, lineWidth: 3)
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
}
