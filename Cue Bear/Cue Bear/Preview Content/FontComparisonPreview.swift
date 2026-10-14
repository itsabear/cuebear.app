//
//  FontComparisonPreview.swift
//  Cue Bear
//
//  Preview for comparing font options across real UI elements.
//  This file is in Preview Content and will NOT be included in the app bundle.
//
//  NOTE: Fonts marked with ⬇️ require downloading and bundling .otf/.ttf files.
//  iOS built-in fonts (marked ✅) work immediately in this preview.
//

import SwiftUI

// MARK: - Font Option Definition

private struct FontOption: Identifiable {
    let id = UUID()
    let name: String
    let regular: String
    let bold: String
    let isBuiltIn: Bool  // true = iOS built-in, false = needs bundling
    let note: String
    var systemDesign: Font.Design? = nil  // For SF Rounded, SF Mono, New York, etc.

    func regularFont(_ size: CGFloat) -> Font {
        if let design = systemDesign {
            return .system(size: size, weight: .regular, design: design)
        }
        return .custom(regular, size: size)
    }
    func boldFont(_ size: CGFloat) -> Font {
        if let design = systemDesign {
            return .system(size: size, weight: .bold, design: design)
        }
        return .custom(bold, size: size)
    }
}

// MARK: - Font Options

// Built-in iOS fonts that are simple, modern, and have unique character
private let fontOptions: [FontOption] = [
    // Current
    // ── Current ──
    FontOption(name: "Helvetica (current)", regular: "Helvetica", bold: "Helvetica-Bold", isBuiltIn: true,
               note: "Current app font — clean but generic"),

    // ── ✅ Built-in iOS — Geometric / Modern ──
    FontOption(name: "Avenir", regular: "Avenir-Roman", bold: "Avenir-Heavy", isBuiltIn: true,
               note: "Lighter, airier than Avenir Next. Frutiger's geometric masterpiece. Great all-rounder."),
    FontOption(name: "Avenir Next", regular: "AvenirNext-Regular", bold: "AvenirNext-Bold", isBuiltIn: true,
               note: "Refined Avenir with better weight range. Slightly sharper."),
    FontOption(name: "Avenir Next Condensed", regular: "AvenirNextCondensed-Regular", bold: "AvenirNextCondensed-Bold", isBuiltIn: true,
               note: "Tighter — fits more text in cue rows and MIDI labels."),
    FontOption(name: "Futura", regular: "Futura-Medium", bold: "Futura-Bold", isBuiltIn: true,
               note: "Iconic geometric sans. Supreme, Dolce & Gabbana. Very distinctive perfect-circle O's."),

    // ── ✅ Built-in iOS — Humanist / Warm ──
    FontOption(name: "Gill Sans", regular: "GillSans", bold: "GillSans-Bold", isBuiltIn: true,
               note: "British humanist, warm and elegant. BBC, Rolls-Royce. Distinctive lowercase 'a' and 'g'."),
    FontOption(name: "Optima", regular: "Optima-Regular", bold: "Optima-Bold", isBuiltIn: true,
               note: "Unique hybrid — sans-serif with subtle stroke contrast. Very elegant, used on Vietnam Veterans Memorial."),
    FontOption(name: "Verdana", regular: "Verdana", bold: "Verdana-Bold", isBuiltIn: true,
               note: "Designed by Matthew Carter for screens. Exceptionally readable at small sizes. Wide letterforms."),
    FontOption(name: "Trebuchet MS", regular: "TrebuchetMS", bold: "TrebuchetMS-Bold", isBuiltIn: true,
               note: "Humanist with quirky details — angled 'e' crossbar, distinctive 'g'. Good personality."),

    // ── ✅ Built-in iOS — Technical / Industrial ──
    FontOption(name: "DIN Alternate", regular: "DINAlternate-Bold", bold: "DINAlternate-Bold", isBuiltIn: true,
               note: "German industrial standard. Clean, technical, excellent for numbers/MIDI data. Only has bold weight."),
    FontOption(name: "DIN Condensed", regular: "DINCondensed-Bold", bold: "DINCondensed-Bold", isBuiltIn: true,
               note: "Narrow DIN — very space-efficient. Great for tight MIDI labels and dense UIs."),
    FontOption(name: "Menlo", regular: "Menlo-Regular", bold: "Menlo-Bold", isBuiltIn: true,
               note: "Monospace — every character same width. Great for MIDI numbers aligning perfectly."),

    // ── ✅ Built-in iOS — Apple System Variants ──
    FontOption(name: "SF Pro (System Default)", regular: "", bold: "", isBuiltIn: true,
               note: "Apple's default. Extremely polished, optical sizes, dynamic tracking. The gold standard.",
               systemDesign: .default),
    FontOption(name: "SF Rounded", regular: "", bold: "", isBuiltIn: true,
               note: "Apple's rounded system font. Friendly and modern. Used in Apple Fitness+.",
               systemDesign: .rounded),
    FontOption(name: "SF Mono", regular: "", bold: "", isBuiltIn: true,
               note: "Apple's monospace. Every character same width — MIDI numbers align perfectly.",
               systemDesign: .monospaced),
    FontOption(name: "New York (Serif)", regular: "", bold: "", isBuiltIn: true,
               note: "Apple's modern serif. Warm, literary feel. Could be interesting for cue names as a contrast.",
               systemDesign: .serif),

    // ── ✅ Built-in iOS — Elegant / Refined ──
    FontOption(name: "Didot", regular: "Didot", bold: "Didot-Bold", isBuiltIn: true,
               note: "High-contrast serif. Vogue, Harper's Bazaar. Extremely elegant, fashion-forward."),
    FontOption(name: "Baskerville", regular: "Baskerville", bold: "Baskerville-Bold", isBuiltIn: true,
               note: "Transitional serif. Timeless elegance, used by Canadian government and Penguin Books."),
    FontOption(name: "Georgia", regular: "Georgia", bold: "Georgia-Bold", isBuiltIn: true,
               note: "Screen-optimized serif. Elegant but highly readable at all sizes. Classic web typography."),
    FontOption(name: "Palatino", regular: "Palatino-Roman", bold: "Palatino-Bold", isBuiltIn: true,
               note: "Calligraphic serif by Hermann Zapf. Warm, refined, excellent readability. Book typography staple."),
    // ── ✅ Built-in iOS — Display / Character ──
    FontOption(name: "Copperplate", regular: "Copperplate", bold: "Copperplate-Bold", isBuiltIn: true,
               note: "Small caps with elegant serifs. Very distinctive — used for a premium, engraved look."),
    FontOption(name: "Rockwell", regular: "Rockwell-Regular", bold: "Rockwell-Bold", isBuiltIn: true,
               note: "Geometric slab serif. Bold, confident, very distinctive. Think hardware/studio gear labels."),
    FontOption(name: "Phosphate", regular: "Phosphate-Inline", bold: "Phosphate-Solid", isBuiltIn: true,
               note: "Bold display font with inline/solid variants. Very distinctive for headers — probably too much for body."),

    // ── ✅ Built-in iOS — Less Common Gems ──
    FontOption(name: "Kohinoor Devanagari", regular: "KohinoorDevanagari-Regular", bold: "KohinoorDevanagari-Semibold", isBuiltIn: true,
               note: "Indian Type Foundry. Clean, modern Latin glyphs with subtle warmth. Hidden gem."),
    FontOption(name: "Mukta Mahee", regular: "MuktaMahee-Regular", bold: "MuktaMahee-Bold", isBuiltIn: true,
               note: "Open, airy letterforms. Designed for screen readability. Another hidden gem from ITF."),
    FontOption(name: "Noto Sans Kannada", regular: "NotoSansKannada-Regular", bold: "NotoSansKannada-Bold", isBuiltIn: true,
               note: "Google's Noto family. Very clean modern Latin, designed for universal readability."),
    FontOption(name: "Kailasa", regular: "Kailasa", bold: "Kailasa-Bold", isBuiltIn: true,
               note: "Clean Latin subset with distinctive character. Worth a look for something unexpected."),

    // ── Bundled (downloaded from Google Fonts / Fontshare) ──
    FontOption(name: "Satoshi", regular: "Satoshi-Regular", bold: "Satoshi-Bold", isBuiltIn: true,
               note: "Geometric with subtle quirks. Trending in design-forward apps. Free from Fontshare."),
    FontOption(name: "General Sans", regular: "GeneralSans-Regular", bold: "GeneralSans-Bold", isBuiltIn: true,
               note: "Clean geometric with unique letter shapes. Free from Fontshare."),
    FontOption(name: "Space Grotesk", regular: "SpaceGrotesk-Regular", bold: "SpaceGrotesk-Bold", isBuiltIn: true,
               note: "Techy, distinctive. Great for music/MIDI apps. Free from Google Fonts."),
    FontOption(name: "Plus Jakarta Sans", regular: "PlusJakartaSans-Regular", bold: "PlusJakartaSans-Bold", isBuiltIn: true,
               note: "Warm geometric, trending in creative apps. Free from Google Fonts."),
    FontOption(name: "Outfit", regular: "Outfit-Regular", bold: "Outfit-Bold", isBuiltIn: true,
               note: "Friendly but sharp geometric. Great weight range. Free from Google Fonts."),
    FontOption(name: "Inter", regular: "Inter-Regular", bold: "Inter-Bold", isBuiltIn: true,
               note: "Designed specifically for screens. GitHub, Linear, Figma use it. Free from Google Fonts."),
    FontOption(name: "Manrope", regular: "Manrope-Regular", bold: "Manrope-Bold", isBuiltIn: true,
               note: "Quirky geometric with unique curves. Free from Google Fonts."),
    FontOption(name: "Sora", regular: "Sora-Regular", bold: "Sora-Bold", isBuiltIn: true,
               note: "Japanese-inspired geometric. Clean with subtle personality. Free from Google Fonts."),
]

// MARK: - Mock Cue Row

private struct MockCueRow: View {
    let font: FontOption
    let name: String
    let subtitle: String?
    let colorHex: String
    let isCued: Bool
    let midiLabel: String?

    private var bgColor: Color { Color(hex: colorHex) }
    private var textColor: Color { bgColor.needsDarkText() ? .black : .white }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(bgColor.opacity(isCued ? 1.0 : 0.90))

            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    if let sub = subtitle, !sub.isEmpty {
                        Text(sub)
                            .font(font.regularFont(14))
                            .foregroundColor(textColor.opacity(0.6))
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(name)
                        .font(font.boldFont(28))
                        .foregroundColor(textColor)
                        .lineLimit(1)
                }
                .padding(.leading, 16)
                .padding(.vertical, 10)

                Spacer()

                if let midi = midiLabel {
                    Text(midi)
                        .font(font.regularFont(9))
                        .foregroundColor(textColor.opacity(0.5))
                        .padding(.trailing, 12)
                }
            }
        }
        .frame(height: 80)
    }
}

// MARK: - Mock Control Button

private struct MockControlButton: View {
    let font: FontOption
    let title: String
    let symbol: String
    let midiLabel: String
    let colorHex: String
    let size: CGFloat

    private var bgColor: Color { Color(hex: colorHex) }
    private var textColor: Color { bgColor.needsDarkText() ? .black : .white }

    var body: some View {
        VStack(spacing: 4) {
            Spacer(minLength: 0)
            if !symbol.isEmpty {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(textColor)
            }
            if !title.isEmpty {
                Text(title)
                    .font(font.boldFont(12))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text(midiLabel)
                .font(font.regularFont(9))
                .foregroundColor(textColor.opacity(0.5))
            Spacer(minLength: 0)
        }
        .frame(width: size, height: size)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(bgColor)
        )
    }
}

// MARK: - Font Comparison Card

private struct FontComparisonCard: View {
    let font: FontOption
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(font.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                if font.isBuiltIn {
                    Text("✅ Built-in")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.green.opacity(0.15)))
                } else {
                    Text("Needs download")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange.opacity(0.15)))
                }
            }

            Text(font.note)
                .font(.caption)
                .foregroundColor(.secondary)

            // Type specimen
            VStack(alignment: .leading, spacing: 4) {
                Text("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
                    .font(font.regularFont(13))
                Text("abcdefghijklmnopqrstuvwxyz 0123456789")
                    .font(font.regularFont(13))
                Text("The quick brown bear cues a lazy fox")
                    .font(font.boldFont(16))
            }
            .foregroundColor(.primary)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(.systemGray6)))

            // Cue rows
            VStack(spacing: 4) {
                MockCueRow(font: font, name: "Intro", subtitle: "120 BPM - Key of C", colorHex: "#2979FF", isCued: true, midiLabel: "1•0")
                MockCueRow(font: font, name: "Chorus", subtitle: "Big energy", colorHex: "#FF1744", isCued: false, midiLabel: "1•2")
                MockCueRow(font: font, name: "Bridge", subtitle: nil, colorHex: "#00E676", isCued: false, midiLabel: "1•3")
            }

            // Control buttons
            HStack(spacing: 6) {
                MockControlButton(font: font, title: "Verse", symbol: "music.note", midiLabel: "1•5", colorHex: "#7C4DFF", size: 72)
                MockControlButton(font: font, title: "FX Send", symbol: "waveform", midiLabel: "1•10", colorHex: "#FF6D00", size: 72)
                MockControlButton(font: font, title: "", symbol: "stop.fill", midiLabel: "1•20", colorHex: "#455A64", size: 72)
                MockControlButton(font: font, title: "Mute", symbol: "speaker.slash.fill", midiLabel: "1•30", colorHex: "#D500F9", size: 72)
            }

            // MIDI data readability test (small sizes)
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MIDI Labels (9pt):")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        Text("1•0").font(font.regularFont(9))
                        Text("1•127").font(font.regularFont(9))
                        Text("16•64").font(font.regularFont(9))
                        Text("CC").font(font.boldFont(9))
                        Text("Note").font(font.boldFont(9))
                    }
                    .foregroundColor(.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Button labels (11pt):")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        Text("Button 1").font(font.boldFont(11))
                        Text("Fader 3").font(font.boldFont(11))
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
    }
}

// MARK: - Main Preview

struct FontComparisonPreview: View {
    @State private var showBuiltInOnly = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Font Comparison")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.top, 20)

                Text("Scroll to compare each font across cue rows,\ncontrol buttons, and MIDI labels")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Filter toggle
                Toggle("Built-in only (no download needed)", isOn: $showBuiltInOnly)
                    .font(.caption)
                    .padding(.horizontal, 24)

                let filtered = showBuiltInOnly ? fontOptions.filter(\.isBuiltIn) : fontOptions

                Text("\(filtered.count) fonts")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                ForEach(filtered) { option in
                    FontComparisonCard(font: option)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
    }
}

#Preview("Font Comparison - Light") {
    FontComparisonPreview()
        .preferredColorScheme(.light)
}

#Preview("Font Comparison - Dark") {
    FontComparisonPreview()
        .preferredColorScheme(.dark)
}
