import SwiftUI
import UIKit

// MARK: - Theme Admin Panel
// DEBUG ONLY: This view is only accessible in development builds
// Access via: Long press on "About" button in side menu (hold for 3 seconds)

#if DEBUG
struct ThemeAdminPanel: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""
    @State private var selectedThemeIndex = 0
    @State private var editingMode: EditMode = .light
    @State private var showContrastCheck = false

    enum EditMode {
        case light, dark
    }

    private var currentTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    private var selectedTheme: AppTheme {
        AppTheme.allThemes[selectedThemeIndex]
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "paintpalette.fill")
                            .font(.cbIcon(.display, .regular))
                            .foregroundColor(currentTheme.accentColor(for: colorScheme))
                        Text("Theme Admin Panel")
                            .font(.cb(.heading, .bold))
                            .foregroundColor(currentTheme.primaryTextColor(for: colorScheme))
                        Text("🔒 Debug Mode Only")
                            .font(.cb(.caption))
                            .foregroundStyle(CBColor.warning)
                    }
                    .padding(.top)

                    Divider()

                    // Theme Selector
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Theme")
                            .font(.cb(.body, .semibold))
                            .foregroundColor(currentTheme.primaryTextColor(for: colorScheme))

                        Picker("Theme", selection: $selectedThemeIndex) {
                            ForEach(0..<AppTheme.allThemes.count, id: \.self) { index in
                                Text(AppTheme.allThemes[index].name).tag(index)
                            }
                        }
                        .pickerStyle(.menu)

                        // Theme Info
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ID: \(selectedTheme.id)")
                                .font(.cbMono(.caption))
                            Text("Genre: \(selectedTheme.genre)")
                                .font(.cbMono(.caption))
                            Text("Font: \(selectedTheme.fontName)")
                                .font(.cbMono(.caption))
                            Text("Dark Mode: \(selectedTheme.darkModeBehavior.rawValue)")
                                .font(.cbMono(.caption))
                        }
                        .foregroundColor(currentTheme.secondaryTextColor(for: colorScheme))
                        .padding()
                        .background(currentTheme.titleBarColor(for: colorScheme))
                        .cornerRadius(CBRadius.small)
                    }
                    .padding(.horizontal)

                    // Mode Toggle
                    Picker("Edit Mode", selection: $editingMode) {
                        Text("Light Mode").tag(EditMode.light)
                        Text("Dark Mode").tag(EditMode.dark)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Color Display
                    ColorDisplaySection(
                        theme: selectedTheme,
                        mode: editingMode,
                        systemColorScheme: colorScheme
                    )

                    // Contrast Checker
                    ContrastCheckerSection(
                        theme: selectedTheme,
                        mode: editingMode
                    )

                    // Export Options
                    ExportSection(theme: selectedTheme)

                    Spacer().frame(height: 50)
                }
            }
            .background(currentTheme.backgroundColor(for: colorScheme))
            .navigationTitle("Admin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(currentTheme.backgroundColor(for: colorScheme), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(currentTheme.defaultCueColor(for: colorScheme))
                }
            }
            .tint(currentTheme.buttonBackgroundColor(for: colorScheme, customAccentHex: customDefaultCueColorStorage))
        }
        .preferredColorScheme(currentTheme.preferredColorScheme(for: colorScheme))
    }
}

// MARK: - Color Display Section
struct ColorDisplaySection: View {
    let theme: AppTheme
    let mode: ThemeAdminPanel.EditMode
    let systemColorScheme: ColorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"

    private var currentTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    private var colors: [(String, String, Bool)] {
        let colorScheme: ColorScheme = mode == .light ? .light : .dark

        if mode == .light {
            return [
                // Base UI colors
                ("Background", theme.backgroundColorHex, false),
                ("Accent", theme.accentColorHex, false),
                ("Default Cue", theme.defaultCueColorHex, false),
                ("Title Bar / Control / Menu", theme.titleBarColorHex, false),
                ("Button BG", theme.buttonBackgroundColorHex, false),
                // Semantic colors
                ("Warning", theme.warningColorHex, false),
                ("Error", theme.errorColorHex, false),
                ("Success", theme.successColorHex, false),
                // Derived colors (computed)
                ("Light Button BG (derived)", theme.lightButtonBackgroundColor(for: colorScheme).toHex() ?? "N/A", true),
                ("Navigation Link (derived)", theme.navigationLinkColor(for: colorScheme).toHex() ?? "N/A", true),
                ("Primary Text (derived)", theme.primaryTextColor(for: colorScheme).toHex() ?? "N/A", true),
                ("Secondary Text (derived)", theme.secondaryTextColor(for: colorScheme).toHex() ?? "N/A", true)
            ]
        } else {
            return [
                // Base UI colors
                ("Background", theme.darkBackgroundColorHex, false),
                ("Accent", theme.darkAccentColorHex, false),
                ("Default Cue", theme.darkDefaultCueColorHex, false),
                ("Title Bar / Control / Menu", theme.darkTitleBarColorHex, false),
                ("Button BG", theme.darkButtonBackgroundColorHex, false),
                // Semantic colors
                ("Warning", theme.darkWarningColorHex, false),
                ("Error", theme.darkErrorColorHex, false),
                ("Success", theme.darkSuccessColorHex, false),
                // Derived colors (computed)
                ("Light Button BG (derived)", theme.lightButtonBackgroundColor(for: colorScheme).toHex() ?? "N/A", true),
                ("Navigation Link (derived)", theme.navigationLinkColor(for: colorScheme).toHex() ?? "N/A", true),
                ("Primary Text (derived)", theme.primaryTextColor(for: colorScheme).toHex() ?? "N/A", true),
                ("Secondary Text (derived)", theme.secondaryTextColor(for: colorScheme).toHex() ?? "N/A", true)
            ]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Colors")
                .font(.cb(.body, .semibold))
                .foregroundColor(currentTheme.primaryTextColor(for: systemColorScheme))
                .padding(.horizontal)

            ForEach(colors, id: \.0) { name, hex, isDerived in
                ColorRow(name: name, hex: hex, isDerived: isDerived)
            }
        }
    }
}

struct ColorRow: View {
    let name: String
    let hex: String
    let isDerived: Bool
    @State private var copied = false
    @State private var showColorPicker = false
    @State private var selectedColor: Color

    init(name: String, hex: String, isDerived: Bool = false) {
        self.name = name
        self.hex = hex
        self.isDerived = isDerived
        self._selectedColor = State(initialValue: Color(hex: hex))
    }

    var body: some View {
        HStack {
            // Color swatch (tappable to open color picker only for base colors)
            RoundedRectangle(cornerRadius: CBRadius.small)
                .fill(Color(hex: hex))
                .frame(width: 60, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: CBRadius.small)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .onTapGesture {
                    if !isDerived {
                        showColorPicker = true
                    }
                }
                .opacity(isDerived ? 0.7 : 1.0)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.cb(.small))
                    .italic(isDerived)
                    .foregroundColor(isDerived ? .secondary : .primary)
                Text("#\(hex)")
                    .font(.cbMono(.caption))
                    .foregroundStyle(CBColor.textSecondary)
            }

            Spacer()

            Button(action: {
                UIPasteboard.general.string = "#\(hex)"
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    copied = false
                }
            }) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .foregroundColor(copied ? .green : .blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(CBRadius.small)
        .padding(.horizontal)
        .popover(isPresented: $showColorPicker) {
            VStack(spacing: 16) {
                Text("Color Picker (Preview Only)")
                    .font(.cb(.body, .semibold))
                ColorPicker("Select Color", selection: $selectedColor)
                    .padding()

                Text("New Hex: \(selectedColor.toHex() ?? hex)")
                    .font(.cbMono(.caption))
                    .foregroundStyle(CBColor.textSecondary)

                HStack {
                    Button("Copy New Hex") {
                        if let newHex = selectedColor.toHex() {
                            UIPasteboard.general.string = "#\(newHex)"
                        }
                        showColorPicker = false
                    }
                    .buttonStyle(.bordered)

                    Button("Close") {
                        showColorPicker = false
                    }
                    .buttonStyle(.bordered)
                }

                Text("Note: Changes are not saved. Copy the hex code and update AppTheme.swift manually.")
                    .font(.cb(.caption))
                    .foregroundStyle(CBColor.warning)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .frame(width: 320)
        }
    }
}

// MARK: - Contrast Checker
struct ContrastCheckerSection: View {
    let theme: AppTheme
    let mode: ThemeAdminPanel.EditMode

    private var background: String {
        mode == .light ? theme.backgroundColorHex : theme.darkBackgroundColorHex
    }

    private var accent: String {
        mode == .light ? theme.accentColorHex : theme.darkAccentColorHex
    }

    private var cue: String {
        mode == .light ? theme.defaultCueColorHex : theme.darkDefaultCueColorHex
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contrast Ratios (WCAG)")
                .font(.cb(.body, .semibold))
                .padding(.horizontal)

            VStack(spacing: 8) {
                ContrastRow(
                    label: "Accent vs Background",
                    ratio: calculateContrast(accent, background)
                )
                ContrastRow(
                    label: "Cue vs Background",
                    ratio: calculateContrast(cue, background)
                )
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(CBRadius.card)
            .padding(.horizontal)

            Text("Standards: AAA ≥7.0 | AA ≥4.5 | Large AA ≥3.0")
                .font(.cb(.caption))
                .foregroundStyle(CBColor.textSecondary)
                .padding(.horizontal)
        }
    }

    private func calculateContrast(_ color1: String, _ color2: String) -> Double {
        let l1 = relativeLuminance(hex: color1)
        let l2 = relativeLuminance(hex: color2)
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }

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

    private func hexToRGB(_ hex: String) -> (Int, Int, Int) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let r = Int((int >> 16) & 0xFF)
        let g = Int((int >> 8) & 0xFF)
        let b = Int(int & 0xFF)
        return (r, g, b)
    }
}

struct ContrastRow: View {
    let label: String
    let ratio: Double

    private var rating: (String, Color) {
        if ratio >= 7.0 {
            return ("AAA", .green)
        } else if ratio >= 4.5 {
            return ("AA", .blue)
        } else if ratio >= 3.0 {
            return ("Large AA", .orange)
        } else {
            return ("FAIL", .red)
        }
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.cb(.small))
            Spacer()
            Text(String(format: "%.2f:1", ratio))
                .font(.cbMono(.small))
                .foregroundStyle(CBColor.textSecondary)
            Text(rating.0)
                .font(.cb(.caption, .bold))
                .foregroundStyle(CBColor.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(rating.1)
                .cornerRadius(4)
        }
    }
}

// MARK: - Export Section
struct ExportSection: View {
    let theme: AppTheme
    @State private var showExportSheet = false
    @State private var exportedCode = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export")
                .font(.cb(.body, .semibold))
                .padding(.horizontal)

            Button(action: {
                exportedCode = generateSwiftCode()
                showExportSheet = true
            }) {
                HStack {
                    Image(systemName: "arrow.up.doc")
                    Text("Export Theme as Swift Code")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundStyle(CBColor.textPrimary)
                .cornerRadius(CBRadius.card)
            }
            .padding(.horizontal)

            Button(action: {
                exportedCode = generateJSONCode()
                showExportSheet = true
            }) {
                HStack {
                    Image(systemName: "curlybraces")
                    Text("Export Theme as JSON")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .foregroundStyle(CBColor.textPrimary)
                .cornerRadius(CBRadius.card)
            }
            .padding(.horizontal)
        }
        .sheet(isPresented: $showExportSheet) {
            ExportCodeView(code: exportedCode)
        }
    }

    private func generateSwiftCode() -> String {
        return """
        AppTheme(
            id: "\(theme.id)",
            name: "\(theme.name)",
            genre: "\(theme.genre)",
            fontName: "\(theme.fontName)",
            darkModeBehavior: .\(theme.darkModeBehavior.rawValue),
            // Light mode
            accentColorHex: "\(theme.accentColorHex)",
            backgroundColorHex: "\(theme.backgroundColorHex)",
            defaultCueColorHex: "\(theme.defaultCueColorHex)",
            titleBarColorHex: "\(theme.titleBarColorHex)",
            buttonBackgroundColorHex: "\(theme.buttonBackgroundColorHex)",
            // Dark mode
            darkAccentColorHex: "\(theme.darkAccentColorHex)",
            darkBackgroundColorHex: "\(theme.darkBackgroundColorHex)",
            darkDefaultCueColorHex: "\(theme.darkDefaultCueColorHex)",
            darkTitleBarColorHex: "\(theme.darkTitleBarColorHex)",
            darkButtonBackgroundColorHex: "\(theme.darkButtonBackgroundColorHex)",
            isDefault: \(theme.isDefault)
        )
        """
    }

    private func generateJSONCode() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(theme),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "{}"
    }
}

struct ExportCodeView: View {
    @Environment(\.dismiss) var dismiss
    let code: String
    @State private var copied = false

    var body: some View {
        NavigationView {
            ScrollView {
                Text(code)
                    .font(.cbMono(.caption))
                    .padding()
                    .textSelection(.enabled)
            }
            .navigationTitle("Exported Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        UIPasteboard.general.string = code
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            copied = false
                        }
                    }) {
                        Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct ThemeAdminPanel_Previews: PreviewProvider {
    static var previews: some View {
        ThemeAdminPanel()
    }
}
#endif
