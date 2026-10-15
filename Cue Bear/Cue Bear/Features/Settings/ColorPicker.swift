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
struct ColorTile: View {
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
