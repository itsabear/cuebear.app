//
//  CueRowDesignPreview.swift
//  Cue Bear
//
//  Preview for testing cue list row design options in Xcode Canvas.
//  This file is in Preview Content and will NOT be included in the app bundle.
//

import SwiftUI

// MARK: - Sample Data

private let sampleSongs: [Song] = [
    Song(name: "Intro", subtitle: "120 BPM - Key of C", cc: 0, channel: 1),
    Song(name: "Verse 1", cc: 1, channel: 1),
    Song(name: "Chorus", subtitle: "Big energy", cc: 2, channel: 1),
    Song(name: "Bridge", cc: 3, channel: 1),
    Song(name: "Outro", subtitle: "Fade out", cc: 4, channel: 1),
]

private func coloredSong(_ name: String, hex: String, cc: Int) -> Song {
    var s = Song(name: name, cc: cc, channel: 1)
    s.colorHex = hex
    return s
}

private let coloredSongs: [Song] = [
    coloredSong("Red Cue", hex: "#FF1744", cc: 10),
    coloredSong("Blue Cue", hex: "#2979FF", cc: 11),
    coloredSong("Green Cue", hex: "#00E676", cc: 12),
    coloredSong("Purple Cue", hex: "#D500F9", cc: 13),
    coloredSong("Yellow Cue", hex: "#FFFF00", cc: 14),
    coloredSong("Pastel Pink", hex: "#FFB3BA", cc: 15),
    coloredSong("Dark Brown", hex: "#5D4037", cc: 16),
    coloredSong("White", hex: "#FFFFFF", cc: 17),
]

// MARK: - Palette Card Style (from reference image)

/// A cue row styled like the color palette reference image:
/// narrow rounded corners, Helvetica font, generous whitespace, subtitle top-left, name large bottom-left
private struct PaletteCardRow: View {
    let name: String
    let subtitle: String?
    let colorHex: String
    let isCued: Bool
    let showMIDILabel: String?

    private var textColor: Color {
        Color(hex: colorHex).needsDarkText() ? .black : .white
    }

    private var secondaryTextColor: Color {
        textColor.opacity(0.6)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: colorHex))
                .opacity(isCued ? 1.0 : 0.90)

            HStack {
                // Left column: subtitle top, name bottom
                VStack(alignment: .leading, spacing: 0) {
                    if let sub = subtitle, !sub.isEmpty {
                        Text(sub)
                            .font(.custom("Helvetica", size: 14))
                            .foregroundColor(secondaryTextColor)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(name)
                        .font(.custom("Helvetica-Bold", size: 28))
                        .foregroundColor(textColor)
                        .lineLimit(1)
                }

                Spacer()

                // Right: MIDI data, vertically centered
                if let midi = showMIDILabel {
                    Text(midi)
                        .font(.custom("Helvetica", size: 13))
                        .foregroundColor(secondaryTextColor)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(height: 110)
        .overlay(
            Group {
                if isCued {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black, lineWidth: 5)
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: 3)
                }
            }
        )
        .animation(.spring(response: 0.15, dampingFraction: 0.75), value: isCued)
    }
}

// MARK: - Floating Top Bar (Palette Style)

private struct PaletteTopBar: View {
    let title: String
    let isEditing: Bool
    var onMenuTap: () -> Void = {}
    var onEditTap: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            // Left: hamburger + project name
            HStack(spacing: 0) {
                Button(action: onMenuTap) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }

                Text(title)
                    .font(.custom("Helvetica", size: 16))
                    .foregroundColor(.white)
                    .padding(.trailing, 14)
            }
            .background(Capsule().fill(.regularMaterial))
            .clipShape(Capsule())

            Spacer()

            // Right: connection indicator + edit button
            HStack(spacing: 8) {
                // Connection badge
                Button(action: {}) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("USB")
                            .font(.custom("Helvetica", size: 13))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .frame(height: 44)
                    .padding(.horizontal, 14)
                }
                .background(Capsule().fill(.regularMaterial))
                .clipShape(Capsule())

                // Edit button
                Button(action: onEditTap) {
                    Image(systemName: isEditing ? "checkmark" : "pencil")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                .background(Capsule().fill(.regularMaterial))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Control Area (Palette Style - uses real ControlButton model)

// MARK: - Palette-styled control tile data

private struct PaletteControl: Identifiable {
    let id = UUID()
    let title: String
    let symbol: String
    let midiLabel: String
    var colorHex: String? = nil
    var isFader: Bool = false
    var faderValue: Double = 0.66
}

private let sampleControls: [PaletteControl] = [
    PaletteControl(title: "Verse", symbol: "music.note", midiLabel: "1 • CC 20"),
    PaletteControl(title: "Chorus", symbol: "music.note.list", midiLabel: "1 • CC 21"),
    PaletteControl(title: "Bridge", symbol: "arrow.triangle.branch", midiLabel: "1 • CC 22"),
    PaletteControl(title: "FX 1", symbol: "waveform", midiLabel: "1 • CC 30", colorHex: "#FF1744"),
    PaletteControl(title: "FX 2", symbol: "waveform.circle", midiLabel: "1 • CC 31", colorHex: "#00E5FF"),
    PaletteControl(title: "Strobe", symbol: "bolt.fill", midiLabel: "1 • CC 40", colorHex: "#FFFF00"),
    PaletteControl(title: "Dimmer", symbol: "slider.vertical.3", midiLabel: "1 • CC 50", isFader: true, faderValue: 0.7),
    PaletteControl(title: "Master", symbol: "slider.vertical.3", midiLabel: "1 • CC 51", colorHex: "#00E676", isFader: true, faderValue: 0.9),
]

// MARK: - Palette-styled button tile (filled background, 8pt corners, Helvetica)

private struct PaletteControlTile: View {
    let control: PaletteControl
    let accentColor: Color

    private var tileColor: Color {
        if let hex = control.colorHex { return Color(hex: hex) }
        return accentColor
    }

    private var textColor: Color {
        tileColor.needsDarkText() ? .black : .white
    }

    var body: some View {
        if control.isFader {
            faderBody
        } else {
            buttonBody
        }
    }

    private var buttonBody: some View {
        VStack(spacing: 4) {
            Spacer(minLength: 0)

            Image(systemName: control.symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(textColor)

            Text(control.title)
                .font(.custom("Helvetica-Bold", size: 12))
                .foregroundColor(textColor)
                .lineLimit(1)

            Text(control.midiLabel)
                .font(.custom("Helvetica", size: 9))
                .foregroundColor(textColor.opacity(0.5))

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(tileColor.opacity(0.9))
        )
    }

    private var faderBody: some View {
        ZStack(alignment: .bottom) {
            // Track background
            RoundedRectangle(cornerRadius: 8)
                .fill(tileColor.opacity(0.2))

            // Fill level
            GeometryReader { geo in
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 8)
                        .fill(tileColor.opacity(0.85))
                        .frame(height: geo.size.height * control.faderValue)
                }
            }

            // Labels
            VStack(spacing: 2) {
                Text(control.title)
                    .font(.custom("Helvetica-Bold", size: 11))
                    .foregroundColor(textColor)
                Text(control.midiLabel)
                    .font(.custom("Helvetica", size: 9))
                    .foregroundColor(textColor.opacity(0.5))
            }
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Palette-styled control grid

/// Palette-styled control area: filled tiles, 8pt corners, Helvetica font
private struct PaletteControlGrid: View {
    let controls: [PaletteControl]
    let accentColor: Color
    var onCollapse: () -> Void

    private let cellSpacing: CGFloat = 10

    var body: some View {
        VStack(spacing: 0) {
            // Header - matches real mainHeader (68pt)
            HStack(spacing: 8) {
                // Page indicator capsule (left)
                HStack(spacing: 0) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                        .frame(width: 36, height: 44)

                    Text("1 / 1")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(minWidth: 32)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                        .frame(width: 36, height: 44)
                }
                .background(.regularMaterial)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)

                Spacer()

                // Edit button capsule
                Text("Edit")
                    .font(.custom("Helvetica", size: 15))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)

                // Collapse button
                Button(action: onCollapse) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                .background(.regularMaterial)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .frame(height: 68)

            // Button/fader grid — 4 columns
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: cellSpacing), count: 4),
                spacing: cellSpacing
            ) {
                ForEach(controls) { ctrl in
                    PaletteControlTile(control: ctrl, accentColor: accentColor)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Full App Layout Preview Wrapper

private struct PaletteAppLayout: View {
    let cues: [PaletteCue]
    let backgroundHex: String
    let showMIDI: Bool
    let title: String

    @State private var selectedID: UUID? = nil
    @State private var controlCollapsed: Bool = true

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Color(hex: backgroundHex).ignoresSafeArea()

            // Cue list
            ScrollView {
                VStack(spacing: 10) {
                    // Top padding for floating bar
                    Color.clear.frame(height: 56)

                    ForEach(cues) { cue in
                        PaletteCardRow(
                            name: cue.name,
                            subtitle: cue.subtitle,
                            colorHex: cue.colorHex,
                            isCued: selectedID == cue.id,
                            showMIDILabel: showMIDI ? cue.midiLabel : nil
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.15, dampingFraction: 0.75)) {
                                selectedID = selectedID == cue.id ? nil : cue.id
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, controlCollapsed ? 80 : 280)
            }

            // Top gradient fade
            VStack {
                LinearGradient(
                    colors: [Color(hex: backgroundHex), Color(hex: backgroundHex).opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
                .ignoresSafeArea()
                Spacer()
            }
            .allowsHitTesting(false)

            // Floating top bar
            VStack {
                PaletteTopBar(title: title, isEditing: false)
                    .padding(.top, 4)
                Spacer()
            }

            // Floating control area (bottom)
            VStack {
                Spacer()

                if controlCollapsed {
                    // Collapsed: floating capsule button
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                controlCollapsed = false
                            }
                        }) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Circle().fill(.regularMaterial))
                                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 21)
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    // Expanded: control grid (height = 68pt header + grid rows + padding)
                    PaletteControlGrid(
                        controls: sampleControls,
                        accentColor: Color(hex: "0A84FF"),
                        onCollapse: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                controlCollapsed = true
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
}

// MARK: - Interactive Palette Data

private struct PaletteCue: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String?
    let colorHex: String
    let midiLabel: String?
}

private let beachCues: [PaletteCue] = [
    PaletteCue(name: "Intro", subtitle: "120 BPM - Key of C", colorHex: "#D8BA98", midiLabel: "Ch 1  CC 0"),
    PaletteCue(name: "Verse 1", subtitle: nil, colorHex: "#7F0303", midiLabel: "Ch 1  CC 1"),
    PaletteCue(name: "Chorus", subtitle: "Big energy", colorHex: "#EFE8DF", midiLabel: "Ch 1  CC 2"),
    PaletteCue(name: "Bridge", subtitle: nil, colorHex: "#96C0CE", midiLabel: "Ch 1  CC 3"),
    PaletteCue(name: "Outro", subtitle: "Fade out", colorHex: "#0F414A", midiLabel: "Ch 1  CC 4"),
]

private let neonCues: [PaletteCue] = [
    PaletteCue(name: "Drop", subtitle: "Heavy bass", colorHex: "#FF1744", midiLabel: "Ch 1  CC 10"),
    PaletteCue(name: "Build Up", subtitle: nil, colorHex: "#00E5FF", midiLabel: "Ch 1  CC 11"),
    PaletteCue(name: "Breakdown", subtitle: "Strip it back", colorHex: "#D500F9", midiLabel: "Ch 1  CC 12"),
    PaletteCue(name: "Finale", subtitle: nil, colorHex: "#00FF41", midiLabel: "Ch 1  CC 13"),
    PaletteCue(name: "Blackout", subtitle: "All lights off", colorHex: "#212121", midiLabel: "Ch 1  CC 14"),
]

// MARK: - Full App Previews

#Preview("Full App - Beach Theme") {
    PaletteAppLayout(
        cues: beachCues,
        backgroundHex: "#1C1C1E",
        showMIDI: true,
        title: "Sunday Set"
    )
    .preferredColorScheme(.dark)
}

#Preview("Full App - Neon Theme") {
    PaletteAppLayout(
        cues: neonCues,
        backgroundHex: "#1C1C1E",
        showMIDI: true,
        title: "EDM Night"
    )
    .preferredColorScheme(.dark)
}

#Preview("Full App - No MIDI") {
    PaletteAppLayout(
        cues: beachCues,
        backgroundHex: "#1C1C1E",
        showMIDI: false,
        title: "Sunday Set"
    )
    .preferredColorScheme(.dark)
}

#Preview("Full App - Light Background") {
    PaletteAppLayout(
        cues: beachCues,
        backgroundHex: "#F2F2F7",
        showMIDI: true,
        title: "Sunday Set"
    )
    .preferredColorScheme(.light)
}

// MARK: - Comparison Previews

#Preview("Palette vs Current - Side by Side") {
    struct Wrapper: View {
        @State private var paletteSelectedIndex: Int? = nil
        @State private var currentSelectedIndex: Int? = nil

        private let compareCues: [PaletteCue] = [
            PaletteCue(name: "Intro", subtitle: "120 BPM", colorHex: "#0A84FF", midiLabel: "Ch 1  CC 0"),
            PaletteCue(name: "Chorus", subtitle: "Big energy", colorHex: "#0A84FF", midiLabel: "Ch 1  CC 2"),
            PaletteCue(name: "Outro", subtitle: nil, colorHex: "#0A84FF", midiLabel: "Ch 1  CC 4"),
        ]
        private let compareSongs: [Song] = [
            Song(name: "Intro", subtitle: "120 BPM", cc: 0, channel: 1),
            Song(name: "Chorus", subtitle: "Big energy", cc: 2, channel: 1),
            Song(name: "Outro", cc: 4, channel: 1),
        ]

        var body: some View {
            ScrollView {
                VStack(spacing: 24) {
                    Text("PALETTE STYLE (tap to select)")
                        .font(.custom("Helvetica-Bold", size: 12))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)

                    VStack(spacing: 10) {
                        ForEach(Array(compareCues.enumerated()), id: \.element.id) { index, cue in
                            PaletteCardRow(
                                name: cue.name, subtitle: cue.subtitle,
                                colorHex: cue.colorHex,
                                isCued: paletteSelectedIndex == index,
                                showMIDILabel: cue.midiLabel
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.15, dampingFraction: 0.75)) {
                                    paletteSelectedIndex = paletteSelectedIndex == index ? nil : index
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    Divider().background(Color.gray)

                    Text("CURRENT STYLE (tap to select)")
                        .font(.custom("Helvetica-Bold", size: 12))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)

                    VStack(spacing: 8) {
                        ForEach(Array(compareSongs.enumerated()), id: \.element.id) { index, song in
                            CBPerformanceRow(
                                song: song, songLibrary: compareSongs,
                                isCued: currentSelectedIndex == index, isCueMode: false,
                                isEditing: false, reorderMode: false,
                                batchSelectMode: false, isSelected: false,
                                takenBy: nil, shouldFlash: false, isLastPlayed: false,
                                accentColor: .blue, defaultCueColor: Color(hex: "0A84FF"),
                                themeFont: { size, weight in .system(size: size, weight: weight) },
                                selectionStrokeColor: .white, backgroundColorHex: "#1C1C1E",
                                defaultCueColorHex: "#0A84FF", showMIDIData: true,
                                cueHeight: 70, fontSize: 1.0,
                                onTap: {
                                    withAnimation(.spring(response: 0.15, dampingFraction: 0.75)) {
                                        currentSelectedIndex = currentSelectedIndex == index ? nil : index
                                    }
                                },
                                onLongPressChangeMIDI: {}, onRename: {}, onDelete: {},
                                onDuplicate: {}, onDragHandleChanged: { _ in }, onDragHandleEnded: { _ in }, onToggleSelection: {}
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .padding(.vertical, 20)
            }
            .background(Color(hex: "1C1C1E"))
        }
    }
    return Wrapper()
        .preferredColorScheme(.dark)
}

// MARK: - Top Bar Button Style Explorations

/// Style A: Solid Matte — like physical mixing console buttons
/// No blur/transparency, subtle inner shadow for depth, slightly rounded rect
private struct MatteTopBar: View {
    let title: String
    let surfaceColor: Color  // slightly elevated from background
    let textColor: Color

    var body: some View {
        HStack(spacing: 8) {
            // Left: menu + title
            HStack(spacing: 0) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(textColor)
                    .frame(width: 42, height: 42)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textColor)
                    .padding(.trailing, 14)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(surfaceColor)
                    .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Cue list chooser
            HStack(spacing: 6) {
                Text("Sunday Set")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textColor)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(textColor.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(surfaceColor)
                    .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Spacer()

            // Connection
            HStack(spacing: 6) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
                Text("USB")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(surfaceColor)
                    .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Edit
            Image(systemName: "pencil")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(textColor)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(surfaceColor)
                        .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 16)
    }
}

/// Style B: Outlined — thin border, no fill, technical/DAW feel
private struct OutlinedTopBar: View {
    let title: String
    let borderColor: Color
    let textColor: Color

    var body: some View {
        HStack(spacing: 8) {
            // Left: menu + title
            HStack(spacing: 0) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(textColor)
                    .frame(width: 42, height: 42)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textColor)
                    .padding(.trailing, 14)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: 1)
                    .background(RoundedRectangle(cornerRadius: 10).fill(borderColor.opacity(0.08)))
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Cue list chooser
            HStack(spacing: 6) {
                Text("Sunday Set")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textColor)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(textColor.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: 1)
                    .background(RoundedRectangle(cornerRadius: 10).fill(borderColor.opacity(0.08)))
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Spacer()

            // Connection
            HStack(spacing: 6) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
                Text("USB")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: 1)
                    .background(RoundedRectangle(cornerRadius: 10).fill(borderColor.opacity(0.08)))
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Edit
            Image(systemName: "pencil")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(textColor)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(borderColor, lineWidth: 1)
                        .background(RoundedRectangle(cornerRadius: 10).fill(borderColor.opacity(0.08)))
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 16)
    }
}

/// Style C: Pill with accent underline — solid fill + colored bottom edge
private struct UnderlineTopBar: View {
    let title: String
    let surfaceColor: Color
    let accentColor: Color
    let textColor: Color

    var body: some View {
        HStack(spacing: 8) {
            // Left: menu + title
            HStack(spacing: 0) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(textColor)
                    .frame(width: 42, height: 42)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textColor)
                    .padding(.trailing, 14)
            }
            .background(
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 10).fill(surfaceColor)
                    VStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 1)
                            .fill(accentColor)
                            .frame(height: 2)
                            .padding(.horizontal, 6)
                            .padding(.bottom, 4)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Cue list chooser
            HStack(spacing: 6) {
                Text("Sunday Set")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textColor)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(textColor.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 10).fill(surfaceColor)
                    VStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 1)
                            .fill(accentColor)
                            .frame(height: 2)
                            .padding(.horizontal, 6)
                            .padding(.bottom, 4)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Spacer()

            // Connection
            HStack(spacing: 6) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
                Text("USB")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 10).fill(surfaceColor)
                    VStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 1)
                            .fill(accentColor)
                            .frame(height: 2)
                            .padding(.horizontal, 6)
                            .padding(.bottom, 4)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Edit
            Image(systemName: "pencil")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(textColor)
                .frame(width: 42, height: 42)
                .background(
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 10).fill(surfaceColor)
                        VStack {
                            Spacer()
                            RoundedRectangle(cornerRadius: 1)
                                .fill(accentColor)
                                .frame(height: 2)
                                .padding(.horizontal, 6)
                                .padding(.bottom, 4)
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 16)
    }
}

/// Style D: Connected segmented bar — buttons joined in a single strip with dividers
private struct SegmentedTopBar: View {
    let title: String
    let surfaceColor: Color
    let textColor: Color

    var body: some View {
        HStack(spacing: 0) {
            // Left group: menu | title | cue list — joined
            HStack(spacing: 0) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(textColor)
                    .frame(width: 42, height: 42)

                Rectangle().fill(textColor.opacity(0.15)).frame(width: 1, height: 24)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textColor)
                    .padding(.horizontal, 12)

                Rectangle().fill(textColor.opacity(0.15)).frame(width: 1, height: 24)

                HStack(spacing: 4) {
                    Text("Sunday Set")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(textColor)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(textColor.opacity(0.5))
                }
                .padding(.horizontal, 12)
            }
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(surfaceColor)
                    .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Spacer()

            // Right group: connection | edit — joined
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 16))
                        .foregroundColor(.green)
                    Text("USB")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 12)

                Rectangle().fill(textColor.opacity(0.15)).frame(width: 1, height: 24)

                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(textColor)
                    .frame(width: 42, height: 42)
            }
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(surfaceColor)
                    .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 16)
    }
}

/// Style E: Current Apple-style (baseline for comparison)
private struct CurrentAppleTopBar: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            // Left: menu + title (capsule)
            HStack(spacing: 0) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.trailing, 14)
            }
            .background(Capsule().fill(.regularMaterial))
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)

            // Cue list chooser
            HStack(spacing: 6) {
                Text("Sunday Set")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Capsule().fill(.regularMaterial))
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)

            Spacer()

            // Connection
            HStack(spacing: 6) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 18))
                    .foregroundColor(.green)
                Text("USB")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Capsule().fill(.regularMaterial))
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)

            // Edit
            Image(systemName: "pencil")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Capsule().fill(.regularMaterial))
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Button Style Comparison Previews

#Preview("Button Styles — Dark") {
    ScrollView {
        VStack(spacing: 32) {
            Group {
                Text("E: CURRENT (Apple-style capsules)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                CurrentAppleTopBar(title: "Live Show")
            }

            Group {
                Text("A: SOLID MATTE (mixing console)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                MatteTopBar(
                    title: "Live Show",
                    surfaceColor: Color(hex: "2C2C2E"),
                    textColor: .white.opacity(0.9)
                )
            }

            Group {
                Text("B: OUTLINED (DAW / technical)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                OutlinedTopBar(
                    title: "Live Show",
                    borderColor: Color.white.opacity(0.25),
                    textColor: .white.opacity(0.9)
                )
            }

            Group {
                Text("C: ACCENT UNDERLINE (tab-style)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                UnderlineTopBar(
                    title: "Live Show",
                    surfaceColor: Color(hex: "2C2C2E"),
                    accentColor: Color(hex: "0A84FF"),
                    textColor: .white.opacity(0.9)
                )
            }

            Group {
                Text("D: SEGMENTED BAR (pro-tools)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                SegmentedTopBar(
                    title: "Live Show",
                    surfaceColor: Color(hex: "2C2C2E"),
                    textColor: .white.opacity(0.9)
                )
            }
        }
        .padding(.vertical, 24)
    }
    .background(Color(hex: "1C1C1E"))
    .preferredColorScheme(.dark)
}

#Preview("Button Styles — Light") {
    ScrollView {
        VStack(spacing: 32) {
            Group {
                Text("E: CURRENT (Apple-style capsules)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                CurrentAppleTopBar(title: "Live Show")
            }

            Group {
                Text("A: SOLID MATTE (mixing console)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                MatteTopBar(
                    title: "Live Show",
                    surfaceColor: Color(hex: "E8E8ED"),
                    textColor: Color.black.opacity(0.85)
                )
            }

            Group {
                Text("B: OUTLINED (DAW / technical)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                OutlinedTopBar(
                    title: "Live Show",
                    borderColor: Color.black.opacity(0.2),
                    textColor: Color.black.opacity(0.85)
                )
            }

            Group {
                Text("C: ACCENT UNDERLINE (tab-style)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                UnderlineTopBar(
                    title: "Live Show",
                    surfaceColor: Color(hex: "E8E8ED"),
                    accentColor: Color(hex: "0A84FF"),
                    textColor: Color.black.opacity(0.85)
                )
            }

            Group {
                Text("D: SEGMENTED BAR (pro-tools)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                SegmentedTopBar(
                    title: "Live Show",
                    surfaceColor: Color(hex: "E8E8ED"),
                    textColor: Color.black.opacity(0.85)
                )
            }
        }
        .padding(.vertical, 24)
    }
    .background(Color(hex: "F2F2F7"))
    .preferredColorScheme(.light)
}

// MARK: - Original CBPerformanceRow Previews

#Preview("Current Rows - Default Theme") {
    ScrollView {
        VStack(spacing: 8) {
            ForEach(Array(sampleSongs.enumerated()), id: \.element.id) { index, song in
                CBPerformanceRow(
                    song: song, songLibrary: sampleSongs,
                    isCued: index == 2, isCueMode: false,
                    isEditing: false, reorderMode: false,
                    batchSelectMode: false, isSelected: false,
                    takenBy: nil, shouldFlash: false, isLastPlayed: index == 1,
                    accentColor: .blue, defaultCueColor: Color(hex: "0A84FF"),
                    themeFont: { size, weight in .system(size: size, weight: weight) },
                    selectionStrokeColor: .white, backgroundColorHex: "#1C1C1E",
                    defaultCueColorHex: "#0A84FF", showMIDIData: true,
                    cueHeight: 70, fontSize: 1.0,
                    onTap: {}, onLongPressChangeMIDI: {}, onRename: {}, onDelete: {},
                    onDuplicate: {}, onDragHandleChanged: { _ in }, onDragHandleEnded: { _ in }, onToggleSelection: {}
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
    }
    .background(Color(hex: "1C1C1E"))
    .preferredColorScheme(.dark)
}

#Preview("Current Rows - Custom Colors") {
    ScrollView {
        VStack(spacing: 8) {
            ForEach(Array(coloredSongs.enumerated()), id: \.element.id) { index, song in
                CBPerformanceRow(
                    song: song, songLibrary: coloredSongs,
                    isCued: index == 0, isCueMode: false,
                    isEditing: false, reorderMode: false,
                    batchSelectMode: false, isSelected: false,
                    takenBy: index == 3 ? "Fader 1" : nil,
                    shouldFlash: false, isLastPlayed: false,
                    accentColor: .blue, defaultCueColor: Color(hex: "0A84FF"),
                    themeFont: { size, weight in .system(size: size, weight: weight) },
                    selectionStrokeColor: .white, backgroundColorHex: "#1C1C1E",
                    defaultCueColorHex: "#0A84FF", showMIDIData: true,
                    cueHeight: 70, fontSize: 1.0,
                    onTap: {}, onLongPressChangeMIDI: {}, onRename: {}, onDelete: {},
                    onDuplicate: {}, onDragHandleChanged: { _ in }, onDragHandleEnded: { _ in }, onToggleSelection: {}
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
    }
    .background(Color(hex: "1C1C1E"))
    .preferredColorScheme(.dark)
}
