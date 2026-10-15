//
//  PerformanceList.swift — Cue Bear
//

import SwiftUI
@_exported import Foundation

// MARK: - Performance List (instant touch-down flash; long-press Change MIDI…)
struct CBPerformanceList: View {
    let songs: [Song]
    let songLibrary: [Song]  // Full song library for resolving alias references
    let isCueMode: Bool
    let cuedID: UUID?
    let isEditing: Bool
    let reorderMode: Bool  // Show drag handles when true
    let batchSelectMode: Bool  // Show selection radials when true
    let selectedSongs: Set<UUID>  // Set of selected song IDs
    let flashingCueID: UUID?  // ID of cue that should flash
    let lastPlayedID: UUID?  // ID of last played cue (for steady play icon)
    let accentColor: Color  // Theme accent color for selection stroke
    let defaultCueColor: Color  // Theme default cue color
    let themeFont: (CGFloat, Font.Weight) -> Font  // Theme font function
    let selectionStrokeColor: (String?) -> Color  // Closure to compute contrasting selection color based on cue color
    let backgroundColorHex: String  // Theme background color hex for contrast calculation
    let defaultCueColorHex: String  // Theme default cue color hex for color preview
    let showMIDIData: Bool  // Toggle for showing MIDI data
    let cueHeight: Double  // Customizable cue height
    let fontSize: Double  // Font size multiplier
    let controlAreaCollapsed: Bool  // Is control area collapsed (for dynamic bottom padding)
    let controlAreaHeight: CGFloat  // Height of control area when expanded (for dynamic bottom padding)
    var onTapSong: (Song) -> Void
    var onLongPressChangeMIDI: (Song) -> Void
    var onRename: (Song) -> Void
    var onDelete: (Song) -> Void
    var onDuplicate: (Song) -> Void
    var onMove: (IndexSet, Int) -> Void  // Callback for reordering cues
    var onToggleSelection: (Song) -> Void  // Callback for toggling selection
    let conflictFor: [MIDIKey: String]

    // Drag state for reordering
    @State private var draggedSong: Song? = nil
    @State private var hoveredIndex: Int? = nil
    // isDraggingFromHandle removed — drag logic moved entirely into handle gesture callbacks
    @State private var dragOffset: CGSize = .zero  // Track drag offset for preview
    @State private var dragStartY: CGFloat = 0  // Track initial Y position of dragged item
    @State private var dragCurrentY: CGFloat = 0  // Track current Y position during drag

    @Environment(\.verticalSizeClass) private var verticalSizeClass  // Detect orientation

    var body: some View {
        let horizontalPadding: CGFloat = 16

        return GeometryReader { geometry in
            ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 10) {
                    // Empty state when no cues exist
                    if songs.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "music.note.list")
                                .font(.cbIcon(.hero, .regular))
                                .foregroundColor(.gray.opacity(0.5))

                            Text("You still have no cues in your cue list")
                                .font(.cb(.large))
                                .foregroundStyle(CBColor.textTertiary)

                            Text("Cues are MIDI buttons arranged like a scrollable set list. Click \"Edit\" to add your first cues.")
                                .font(.cb(.body))
                                .foregroundColor(.gray.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 120)
                    }

                    ForEach(Array(songs.enumerated()), id: \.element.id) { index, s in
                        let key = (s.kind == .note)
                            ? MIDIKey(kind: .note, channel: s.channel, number: s.note ?? 0)
                            : MIDIKey(kind: .cc,   channel: s.channel, number: s.cc)
                        let takenBy = conflictFor[key]
                        let filteredTakenBy: String? = {
                            guard let takenBy = takenBy else { return nil }
                            // Filter out current song's name from the conflict list
                            if takenBy.contains("|||") {
                                // Multiple owners - split and filter
                                let owners = takenBy.split(separator: "|||").map(String.init).filter { $0 != s.name }
                                guard !owners.isEmpty else { return nil }
                                if owners.count == 1 {
                                    return owners[0]
                                } else if owners.count == 2 {
                                    return "\(owners[0]) and \(owners[1])"
                                } else {
                                    return owners.dropLast().joined(separator: ", ") + ", and " + owners.last!
                                }
                            } else if takenBy == s.name {
                                // Single owner and it's us
                                return nil
                            }
                            return takenBy
                        }()

                        // Determine if this row should show the drop indicator line
                        let showDropIndicator: Bool = {
                            guard let hoveredIndex = hoveredIndex,
                                  let draggedSong = draggedSong,
                                  let fromIndex = songs.firstIndex(where: { $0.id == draggedSong.id }) else {
                                return false
                            }

                            // Show line below the cue that will be BEFORE the dropped cue
                            // When dragging downward, show line below hoveredIndex (which is where it will land after)
                            if hoveredIndex > fromIndex {
                                return index == hoveredIndex
                            }
                            // When dragging upward, show line below hoveredIndex - 1 (the cue before drop position)
                            else if hoveredIndex < fromIndex {
                                return hoveredIndex > 0 && index == hoveredIndex - 1
                            }
                            return false
                        }()

                        CBPerformanceRow(
                            song: s,
                            songLibrary: songLibrary,  // Pass full song library for alias resolution
                            isCued: cuedID == s.id,  // Show stroke in both Cue and Navigator modes
                            isCueMode: isCueMode,
                            isEditing: isEditing,
                            reorderMode: reorderMode,  // Pass reorder mode for drag handles
                            batchSelectMode: batchSelectMode,  // Pass batch select mode
                            isSelected: selectedSongs.contains(s.id),  // Check if selected
                            takenBy: filteredTakenBy,
                            shouldFlash: flashingCueID == s.id,  // Flash when triggered
                            isLastPlayed: lastPlayedID == s.id,  // Show steady play icon on last played
                            accentColor: accentColor,  // Pass theme accent color
                            defaultCueColor: defaultCueColor,  // Pass theme default cue color
                            themeFont: themeFont,  // Pass theme font function
                            selectionStrokeColor: selectionStrokeColor(s.colorHex),  // Compute contrasting selection stroke color
                            backgroundColorHex: backgroundColorHex,  // Pass background color hex for contrast
                            defaultCueColorHex: defaultCueColorHex,  // Pass default cue color hex for preview
                            showMIDIData: showMIDIData,  // Pass MIDI data visibility setting
                            cueHeight: cueHeight,  // Pass customizable cue height
                            fontSize: fontSize,  // Pass font size multiplier
                            onTap: { onTapSong(s) },
                            onLongPressChangeMIDI: { onLongPressChangeMIDI(s) },
                            onRename: { onRename(s) },
                            onDelete: { onDelete(s) },
                            onDuplicate: { onDuplicate(s) },
                            onDragHandleChanged: { value in
                                if draggedSong == nil {
                                    draggedSong = s
                                    dragStartY = value.startLocation.y
                                    dragCurrentY = value.startLocation.y
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                }
                                dragOffset = value.translation
                                dragCurrentY = value.location.y
                                let cueHeightWithSpacing = CGFloat(cueHeight + 10)
                                let indexOffset = Int(round(value.translation.height / cueHeightWithSpacing))
                                let newIndex = max(0, min(songs.count - 1, index + indexOffset))
                                if hoveredIndex != newIndex {
                                    hoveredIndex = newIndex
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            },
                            onDragHandleEnded: { _ in
                                if let draggedSong = draggedSong,
                                   let fromIndex = songs.firstIndex(where: { $0.id == draggedSong.id }),
                                   let toIndex = hoveredIndex,
                                   fromIndex != toIndex {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        onMove(IndexSet(integer: fromIndex), toIndex > fromIndex ? toIndex + 1 : toIndex)
                                    }
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                }
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    self.draggedSong = nil
                                    self.hoveredIndex = nil
                                    self.dragOffset = .zero
                                    self.dragStartY = 0
                                    self.dragCurrentY = 0
                                }
                            },
                            onToggleSelection: { onToggleSelection(s) }  // Toggle selection in batch mode
                        )
                        // Make dragged item semi-transparent in place
                        .opacity(draggedSong?.id == s.id ? 0.3 : 1.0)
                        // Keep dragged item in place - show drop location with line indicator only
                        .overlay(alignment: .bottom) {
                            // Show line indicator at drop position (centered between cues)
                            if showDropIndicator && reorderMode && draggedSong != nil {
                                Rectangle()
                                    .fill(defaultCueColor)
                                    .frame(height: 4)
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 16)
                                    .offset(y: 8)  // Position line in middle of gap (spacing is 12, so offset by 12/2 + height/2 = 6 + 2 = 8)
                                    .shadow(color: defaultCueColor.opacity(0.5), radius: 3, x: 0, y: 0)
                            }
                        }
                        // No row-level drag gesture — reorder is handled entirely
                        // by the drag handle's gesture to avoid blocking ScrollView
                        .id(s.id)
                    }
                    Color.clear.frame(height: 8)
                }
                .padding(.horizontal, horizontalPadding)  // Apply horizontal padding to content
                .padding(.top, isEditing ? 150 : 80)  // Slide down in edit mode - equal spacing with top bar
                .padding(.bottom, controlAreaCollapsed ? 134 : controlAreaHeight + CGFloat(cueHeight) + 24)  // Dynamic padding: collapsed (100pt + 34pt safe area) or expanded (control height + cue height + 2x cue spacing so bottom cue scrolls above control area)
                .animation(.spring(response: 0.15, dampingFraction: 0.85), value: isEditing)
            }
            .scrollDisabled(false)  // Explicitly enable scrolling
            .frame(width: geometry.size.width, height: geometry.size.height)  // Explicit frame for ScrollView
            .onChange(of: cuedID) { _, newID in
                // Scroll to selected cue in both Cue mode and Nav mode
                guard let id = newID else { return }
                withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(id, anchor: .center) }
            }
            .onChange(of: isEditing) { _, isNowEditing in
                // Scroll so first cue appears below search bar when entering edit mode
                if isNowEditing, let firstSong = songs.first {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(firstSong.id, anchor: .center)
                    }
                }
            }
            .overlay {
                // Drag preview - raised semi-transparent copy that follows drag
                if let draggedSong = draggedSong, dragOffset != .zero {
                    dragPreviewView(for: draggedSong)
                }
            }
            }  // End ScrollViewReader
        }  // End GeometryReader
    }

    // Helper to build drag preview
    @ViewBuilder
    private func dragPreviewView(for song: Song) -> some View {
        // Check if the song exists in the list
        if songs.contains(where: { $0.id == song.id }) {
            // Find the index of the dragged song to calculate its original position
            if let index = songs.firstIndex(where: { $0.id == song.id }) {
                let cueHeightWithSpacing = CGFloat(cueHeight + 10)
                let topPadding: CGFloat = isEditing ? 170 : 80

                // Calculate the center Y position of the original cue
                let originalCenterY = topPadding + (CGFloat(index) * cueHeightWithSpacing) + (CGFloat(cueHeight) / 2)

                // Add the drag translation to get the current center position
                let currentCenterY = originalCenterY + dragOffset.height

                CBPerformanceRow(
                    song: song,
                    songLibrary: songLibrary,
                    isCued: false,
                    isCueMode: isCueMode,
                    isEditing: isEditing,
                    reorderMode: reorderMode,
                    batchSelectMode: false,
                    isSelected: false,
                    takenBy: nil,
                    shouldFlash: false,
                    isLastPlayed: false,
                    accentColor: accentColor,
                    defaultCueColor: defaultCueColor,
                    themeFont: themeFont,
                    selectionStrokeColor: defaultCueColor,
                    backgroundColorHex: backgroundColorHex,
                    defaultCueColorHex: defaultCueColorHex,
                    showMIDIData: showMIDIData,
                    cueHeight: cueHeight,
                    fontSize: fontSize,
                    onTap: {},
                    onLongPressChangeMIDI: {},
                    onRename: {},
                    onDelete: {},
                    onDuplicate: {},
                    onDragHandleChanged: { _ in },
                    onDragHandleEnded: { _ in },
                    onToggleSelection: {}
                )
                .frame(height: CGFloat(cueHeight))
                .padding(.horizontal, 36)
                .opacity(0.7)
                .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
                .position(x: UIScreen.main.bounds.width / 2, y: currentCenterY)
                .allowsHitTesting(false)
                .zIndex(1000)
            }
        }
    }
}

struct CBPerformanceRow: View {
    let song: Song
    let songLibrary: [Song]  // Full song library for resolving alias references
    let isCued: Bool
    let isCueMode: Bool
    let isEditing: Bool
    let reorderMode: Bool  // Show drag handles when true
    let batchSelectMode: Bool  // Show selection radials when true
    let isSelected: Bool  // Is this cue selected in batch mode?
    let takenBy: String?
    let shouldFlash: Bool  // Trigger from parent to flash the row
    let isLastPlayed: Bool  // Is this the last played cue?
    let accentColor: Color  // Theme accent color for selection stroke
    let defaultCueColor: Color  // Theme default cue color
    let themeFont: (CGFloat, Font.Weight) -> Font  // Theme font function
    let selectionStrokeColor: Color  // Contrasting selection stroke color based on cue background
    let backgroundColorHex: String  // Theme background color hex for contrast calculation
    let defaultCueColorHex: String  // Theme default cue color hex for preview
    let showMIDIData: Bool  // Toggle for showing MIDI data
    let cueHeight: Double  // Customizable cue height
    let fontSize: Double  // Font size multiplier
    var onTap: () -> Void
    var onLongPressChangeMIDI: () -> Void
    var onRename: () -> Void
    var onDelete: () -> Void
    var onDuplicate: () -> Void
    var onDragHandleChanged: (DragGesture.Value) -> Void  // Called during handle drag
    var onDragHandleEnded: (DragGesture.Value) -> Void  // Called when handle drag ends
    var onToggleSelection: () -> Void  // Called when selection radial is tapped

    @GestureState private var isPressed = false
    @State private var didDrag = false
    @State private var flashOpacity: Double = 0.0
    @State private var playIconOpacity: Double = 1.0  // For blinking animation
    @Environment(\.colorScheme) private var colorScheme
    private let corner: CGFloat = 8

    /// Adaptive text color based on cue background brightness
    /// Uses WCAG luminance calculation to ensure readable contrast
    private var adaptiveTextColor: Color {
        // Get the base color (custom or default)
        let backgroundHex = song.colorHex ?? defaultCueColorHex
        let backgroundColor = Color(hex: backgroundHex)

        // Use WCAG-compliant contrast calculation
        if backgroundColor.needsDarkText() {
            // Bright background needs dark text
            return Color.black
        } else {
            // Dark background needs light text
            return Color.white
        }
    }

    var body: some View {
        // Tap handler function
        let handleTap = {
            // In batch select mode: toggle selection
            if batchSelectMode {
                onToggleSelection()
            }
            // In edit mode (not batch select or reorder): open Edit Cue sheet
            else if isEditing && !reorderMode {
                onRename()
            } else if isEditing {
                // Reorder mode: do nothing (handled by drag handles)
            } else {
                // Normal mode: send MIDI on quick tap
                // Only flash/haptic when actually sending MIDI (regular mode, not cued)
                if !isCueMode {
                    flash()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                onTap()
            }
        }

        // Use custom color if set, otherwise use theme default cue color
        let baseColor: Color = {
            if let hex = song.colorHex {
                return Color(hex: hex)
            }
            return defaultCueColor  // Theme default cue color
        }()

        ZStack(alignment: .center) {
            RoundedRectangle(cornerRadius: corner)
                .fill(baseColor)
                .frame(maxWidth: .infinity, minHeight: cueHeight)
                .opacity((isCued && !isEditing) ? 1.0 : 0.90)
                .animation(.spring(response: 0.15, dampingFraction: 0.75), value: isCued)
                .animation(.spring(response: 0.15, dampingFraction: 0.75), value: isEditing)

            HStack(spacing: 14) {
                // Selection radial - show in batch select mode
                if batchSelectMode {
                    ZStack {
                        Circle()
                            .strokeBorder(adaptiveTextColor.opacity(0.5), lineWidth: 2)
                            .frame(width: 24, height: 24)
                        if isSelected {
                            Circle()
                                .fill(adaptiveTextColor)
                                .frame(width: 16, height: 16)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                // Left column: subtitle top, name large bottom (palette card style)
                VStack(alignment: .leading, spacing: 0) {
                    // Subtitle at top
                    if let sub = song.subtitle, !sub.isEmpty {
                        Text(sub)
                            .font(.cb(points: 14 * fontSize))
                            .foregroundColor(adaptiveTextColor.opacity(0.6))
                            .lineLimit(1)
                    }
                    // Alias info at top
                    if let aliasedID = song.aliasedCueID {
                        if let originalCue = songLibrary.first(where: { $0.id == aliasedID }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.turn.down.right")
                                    .font(.cbIcon(points: 12 * fontSize, .semibold))
                                Text("Copy of \(originalCue.name)")
                                    .font(.cb(points: 14 * fontSize))
                            }
                            .foregroundColor(adaptiveTextColor.opacity(0.6))
                            .lineLimit(1)
                        }
                    } else if let subtitle = song.subtitle, subtitle.hasPrefix("copy of ") {
                        Image(systemName: "doc.on.doc")
                            .font(.cbIcon(points: 12 * fontSize, .semibold))
                            .foregroundColor(adaptiveTextColor.opacity(0.6))
                    }

                    Spacer()

                    // Name large at bottom
                    HStack(spacing: 6) {
                        Text(song.name)
                            .font(.cb(points: 21 * fontSize, .bold))
                            .foregroundColor(adaptiveTextColor)
                            .lineLimit(1)
                        // v1.3 (Cue Bear Next): this song has notes, extras or remembered levels
                        if song.hasSongDetails {
                            Image(systemName: "music.note.list")
                                .font(.cbIcon(points: 13 * fontSize, .semibold))
                                .foregroundColor(adaptiveTextColor.opacity(0.7))
                                .accessibilityLabel("Has notes or extras")
                        }
                    }
                }

                Spacer(minLength: 12)

                // Right: MIDI data, vertically centered
                if showMIDIData && song.midiEnabled {
                    VStack(alignment: .trailing, spacing: 4) {
                        let midiText: String = {
                            if song.kind == .cc {
                                return "Ch \(song.channel)  •  CC \(song.cc)"
                            } else {
                                let noteName = (song.note ?? 0).midiNoteName
                                return "Ch \(song.channel)  •  \(noteName)"
                            }
                        }()
                        Text(midiText)
                            .font(.cb(points: 13 * fontSize))
                            .foregroundColor(adaptiveTextColor.opacity(0.6))

                        // Show conflict warning below MIDI data
                        if let owner = takenBy {
                            Text("⚠️ MIDI taken by: \(owner)")
                                .font(.cb(.micro))
                                .foregroundColor(adaptiveTextColor.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                }

                // Drag handle - show only in reorder mode with slide-in animation
                if reorderMode {
                    Image(systemName: "line.3.horizontal")
                        .font(.cbIcon(points: 20 * fontSize, .semibold))
                        .foregroundColor(adaptiveTextColor.opacity(0.5))
                        .padding(.leading, 8)
                        .padding(.vertical, 8)
                        .padding(.trailing, -8)
                        .contentShape(Rectangle())
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    onDragHandleChanged(value)
                                }
                                .onEnded { value in
                                    onDragHandleEnded(value)
                                }
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: reorderMode)

            RoundedRectangle(cornerRadius: corner)
                .fill(Color(uiColor: .systemBackground))
                .opacity(flashOpacity)
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        // Selection stroke: black inner + white outer (palette card style)
        .overlay(
            Group {
                if isCued && !isEditing {
                    RoundedRectangle(cornerRadius: corner)
                        .stroke(Color.black, lineWidth: 5)
                    RoundedRectangle(cornerRadius: corner)
                        .stroke(Color.white, lineWidth: 3)
                }
            }
        )
        .scaleEffect(isPressed ? 0.985 : 1.0)
        .animation(.spring(response: 0.15, dampingFraction: 0.75), value: isCued)
        .animation(.spring(response: 0.15, dampingFraction: 0.75), value: isEditing)
        .animation(.spring(response: 0.10, dampingFraction: 0.85), value: isPressed)
        .zIndex(isCued ? 1 : 0)
        .contentShape(Rectangle())  // Ensure full row is tappable
        .onTapGesture(perform: handleTap)  // Tap detection - must come before drag gesture
        .contextMenu {
            // Show context menu only in edit mode (not in batch select or reorder mode)
            if isEditing && !batchSelectMode && !reorderMode {
                Button(action: onRename) {
                    Label("Edit", systemImage: "pencil")
                }
                // v1.3 (Cue Bear Next): notes, song-only controls, remembered fader levels
                Button(action: {
                    NotificationCenter.default.post(name: Notification.Name("cbOpenSongDetails"),
                                                    object: nil, userInfo: ["songID": song.id])
                }) {
                    Label("Notes & Extras", systemImage: "music.note.list")
                }
                Button(action: onDuplicate) {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
        .accessibilityLabel("\(song.name), \(song.kind == .cc ? "CC \(song.cc)" : "Note \(song.note ?? 0)")")
        .onChange(of: shouldFlash) { _, newValue in
            if newValue {
                flash()
            }
        }
        .onChange(of: isCued && isCueMode) { _, shouldBlink in
            // Start blinking animation when cue becomes active in Cue mode
            if shouldBlink {
                playIconOpacity = 0.3
            } else {
                playIconOpacity = 1.0
            }
        }
        .onAppear {
            // Initialize blinking state if cue is already active in Cue mode
            if isCued && isCueMode {
                playIconOpacity = 0.3
            }
        }
    }

    private func flash() {
        flashOpacity = 0.4  // Subtle flash instead of full white
        // v1.0.9: Balanced flash duration - noticeable but snappy
        withAnimation(.easeOut(duration: 0.20)) { flashOpacity = 0.0 }
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
}
