import SwiftUI
@_exported import Foundation

// MARK: - Helper Functions for Contrast Calculation
private func hexToRGB(_ hex: String) -> (Int, Int, Int) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int = UInt64()
    Scanner(string: hex).scanHexInt64(&int)
    let r = Int((int >> 16) & 0xFF)
    let g = Int((int >> 8) & 0xFF)
    let b = Int(int & 0xFF)
    return (r, g, b)
}

private func relativeLuminance(_ rgb: (Int, Int, Int)) -> Double {
    func adjust(_ c: Double) -> Double {
        return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    let r = adjust(Double(rgb.0) / 255.0)
    let g = adjust(Double(rgb.1) / 255.0)
    let b = adjust(Double(rgb.2) / 255.0)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b
}

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
    @State private var isDraggingFromHandle: Bool = false  // Track if drag started from handle
    @State private var dragOffset: CGSize = .zero  // Track drag translation for visual feedback

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 12) {
                    // Empty state when no cues exist
                    if songs.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.5))

                            Text("You still have no cues in your cue list")
                                .font(.title3)
                                .foregroundColor(.gray)

                            Text("To add cues, click the edit button on the top right corner and then + to add your first cue")
                                .font(.body)
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

                        let isDragging = draggedSong?.id == s.id

                        // Determine if this row should show the "make room" space
                        let isHovered: Bool = {
                            guard let hoveredIndex = hoveredIndex,
                                  let draggedSong = draggedSong,
                                  let fromIndex = songs.firstIndex(where: { $0.id == draggedSong.id }) else {
                                return false
                            }

                            // When dragging downward, the space should appear BEFORE the hovered item
                            // (because items shift up to fill the dragged item's original space)
                            if hoveredIndex > fromIndex {
                                // Show space before the target (which is at the previous index)
                                return index == hoveredIndex - 1
                            }
                            // When dragging upward, show space at the target
                            else {
                                return index == hoveredIndex
                            }
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
                            onDragHandleStart: { isDraggingFromHandle = true },  // Track handle drag start
                            onDragHandleEnd: { isDraggingFromHandle = false },  // Track handle drag end
                            onToggleSelection: { onToggleSelection(s) }  // Toggle selection in batch mode
                        )
                        // Apple-style drag animations
                        .opacity(isDragging ? 0.7 : 1.0)  // Dragged item slightly transparent
                        .scaleEffect(isDragging ? 1.05 : 1.0)  // Dragged item "rises" - slightly less wide
                        .offset(isDragging ? dragOffset : .zero)  // Follow finger during drag
                        .zIndex(isDragging ? 1000 : 0)  // Dragged item appears above all others
                        .shadow(
                            color: isDragging ? Color.black.opacity(0.3) : Color.clear,
                            radius: isDragging ? 12 : 0,
                            x: 0,
                            y: isDragging ? 8 : 0
                        )
                        .padding(.vertical, isHovered && reorderMode && draggedSong != nil ? 20 : 0)  // Hovered items "make room"
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
                        .animation(.spring(response: 0.15, dampingFraction: 0.8), value: isDragging)  // Faster rise animation
                        .animation(nil, value: dragOffset)  // Don't animate offset - follow finger directly
                        .overlay(alignment: .top) {
                            // Show preview of dragged cue at drop position (iOS-style)
                            if isHovered && reorderMode && draggedSong != nil, let draggedSong = draggedSong {
                                CBPerformanceRow(
                                    song: draggedSong,
                                    songLibrary: songLibrary,
                                    isCued: false,
                                    isCueMode: false,
                                    isEditing: isEditing,
                                    reorderMode: false,  // Hide drag handle in preview
                                    batchSelectMode: false,  // No selection radial in preview
                                    isSelected: false,
                                    takenBy: nil,
                                    shouldFlash: false,
                                    isLastPlayed: false,
                                    accentColor: accentColor,
                                    defaultCueColor: defaultCueColor,
                                    themeFont: themeFont,
                                    selectionStrokeColor: selectionStrokeColor(draggedSong.colorHex),
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
                                    onDragHandleStart: {},
                                    onDragHandleEnd: {},
                                    onToggleSelection: {}
                                )
                                .opacity(0.5)  // Semi-transparent preview
                                .scaleEffect(0.95)  // Slightly smaller
                                .allowsHitTesting(false)  // Don't intercept touches
                                .offset(y: -CGFloat(cueHeight + 12) / 2)  // Center at drop position
                            }
                        }
                        .simultaneousGesture(
                            reorderMode ? DragGesture(minimumDistance: 5)
                                .onChanged { value in
                                    // Only process if drag started from handle
                                    guard isDraggingFromHandle else { return }

                                    if draggedSong == nil {
                                        draggedSong = s
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    }

                                    // Update drag offset so cue follows finger
                                    dragOffset = value.translation

                                    // Calculate which index we're hovering over
                                    let cueHeightWithSpacing = CGFloat(cueHeight + 12)
                                    let offset = value.translation.height
                                    let indexOffset = Int(round(offset / cueHeightWithSpacing))
                                    let newIndex = max(0, min(songs.count - 1, index + indexOffset))

                                    if hoveredIndex != newIndex {
                                        hoveredIndex = newIndex
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                }
                                .onEnded { _ in
                                    // Only process if drag started from handle
                                    guard isDraggingFromHandle else { return }

                                    // Perform the move
                                    if let draggedSong = draggedSong,
                                       let fromIndex = songs.firstIndex(where: { $0.id == draggedSong.id }),
                                       let toIndex = hoveredIndex,
                                       fromIndex != toIndex {

                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            onMove(IndexSet(integer: fromIndex), toIndex > fromIndex ? toIndex + 1 : toIndex)
                                        }

                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    }

                                    // Reset drag state
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        self.draggedSong = nil
                                        self.hoveredIndex = nil
                                        self.dragOffset = .zero
                                    }
                                }
                            : nil
                        )
                        .id(s.id)
                    }
                    Color.clear.frame(height: 8)
                }
                .padding(.horizontal, 36)
                .padding(.top, isEditing ? 145 : 80)  // Slide down in edit mode - further below search bar
                .padding(.bottom, 12)
                .animation(.spring(response: 0.25, dampingFraction: 0.85), value: isEditing)
            }
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
    var onDragHandleStart: () -> Void  // Called when drag starts from handle
    var onDragHandleEnd: () -> Void  // Called when drag ends from handle
    var onToggleSelection: () -> Void  // Called when selection radial is tapped

    @GestureState private var isPressed = false
    @State private var didDrag = false
    @State private var flashOpacity: Double = 0.0
    @State private var playIconOpacity: Double = 1.0  // For blinking animation
    @Environment(\.colorScheme) private var colorScheme
    private let corner: CGFloat = 20

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
        let press = DragGesture(minimumDistance: 0)
            .updating($isPressed) { _, state, _ in
                // Only allow press animation if not in edit mode
                if !isEditing && !state {
                    state = true
                }
            }
            .onChanged { value in
                let delta = abs(value.translation.width) + abs(value.translation.height)
                if delta > 8 {
                    didDrag = true
                }
            }
            .onEnded { _ in
                // In batch select mode: toggle selection
                if batchSelectMode {
                    if !didDrag {
                        onToggleSelection()
                    }
                }
                // In edit mode (not batch select or reorder): open Edit Cue sheet
                else if isEditing && !reorderMode {
                    if !didDrag {
                        onRename()
                    }
                } else if isEditing {
                    // Reorder mode: do nothing (handled by drag handles)
                } else {
                    // Normal mode: send MIDI on quick tap (allow taps even with conflicts)
                    if !didDrag {
                        // Only flash/haptic when actually sending MIDI (regular mode, not cued)
                        if !isCueMode {
                            flash()
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                        onTap()
                    }
                }

                // Delay resetting didDrag to ensure flash check completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    didDrag = false
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
                .frame(maxWidth: .infinity, minHeight: isCued ? cueHeight * 1.4 : cueHeight)
                .opacity(isCued ? 1.0 : 0.90)  // Always use normal opacity, regardless of conflicts
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isCued)

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

                // Play icon - show on chosen cue or last played cue
                if isCued || isLastPlayed {
                    Image(systemName: "play.fill")
                        .font(.system(size: 24 * fontSize, weight: .bold))
                        .foregroundColor(adaptiveTextColor)
                        .opacity(isCued && isCueMode ? playIconOpacity : 1.0)  // Blink if cued in Cue mode, steady otherwise
                        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isCued)  // Smooth size transition
                        .id("\(song.id)-play-icon")  // Force clean transitions when switching cues
                        .transition(.opacity)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 6) {
                        // Show shortcut icon for alias cues
                        if song.aliasedCueID != nil {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.system(size: 18 * fontSize, weight: .semibold))
                                .foregroundColor(adaptiveTextColor.opacity(0.7))
                        }
                        Text(song.name)
                            .font(themeFont(22 * fontSize, .bold))
                            .foregroundColor(adaptiveTextColor)
                            .lineLimit(1)

                        // Show "Copy of [cue name]" for alias cues
                        if let aliasedID = song.aliasedCueID {
                            if let originalCue = songLibrary.first(where: { $0.id == aliasedID }) {
                                Text("Copy of \(originalCue.name)")
                                    .font(themeFont(14 * fontSize, .regular))
                                    .italic()
                                    .foregroundColor(adaptiveTextColor.opacity(0.6))
                                    .lineLimit(1)
                            }
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isCued)
                    if let sub = song.subtitle, !sub.isEmpty {
                        Text(sub)
                            .font(themeFont(14 * fontSize, .medium))
                            .foregroundColor(adaptiveTextColor.opacity(0.85))
                            .lineLimit(1)
                            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isCued)
                    }
                }
                Spacer(minLength: 12)

                if showMIDIData && song.midiEnabled {
                    VStack(alignment: .trailing, spacing: 4) {
                        let subtitle: String = {
                            if song.kind == .cc {
                                return "Ch \(song.channel)  •  CC \(song.cc)"
                            } else {
                                let noteName = (song.note ?? 0).midiNoteName
                                return "Ch \(song.channel)  •  \(noteName)"
                            }
                        }()
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundColor(adaptiveTextColor.opacity(0.9))
                            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isCued)

                        // Show conflict warning below MIDI data
                        if let owner = takenBy {
                            Text("⚠️ MIDI taken by: \(owner)")
                                .font(.caption2)
                                .foregroundColor(adaptiveTextColor.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                }

                // Drag handle - show only in reorder mode with slide-in animation
                if reorderMode {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20 * fontSize, weight: .semibold))
                        .foregroundColor(adaptiveTextColor.opacity(0.5))
                        .padding(.leading, 8)
                        .padding(.vertical, 8)  // Increase touch target
                        .padding(.trailing, -8)  // Compensate for added padding
                        .contentShape(Rectangle())  // Make entire padded area tappable
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    onDragHandleStart()
                                }
                                .onEnded { _ in
                                    onDragHandleEnd()
                                }
                        )
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: reorderMode)

            RoundedRectangle(cornerRadius: corner)
                .fill(Color(uiColor: .systemBackground))
                .opacity(flashOpacity)
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        // Add extra padding when selected to push other cues aside
        .padding(.vertical, isCued ? 12 : 0)
        .padding(.horizontal, isCued ? 6 : 0)
        // Uniform scale: slightly bigger without stretching text
        .scaleEffect(
            isCued ? 1.08 : (isPressed ? 0.985 : 1.0),
            anchor: .center
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isCued)
        .animation(.spring(response: 0.10, dampingFraction: 0.85), value: isPressed)
        // Shadow in light themes, colored glow in dark themes
        .shadow(
            color: {
                if !isCued { return Color.clear }
                // Use background luminance to detect dark theme
                let bgLuminance = relativeLuminance(hex: backgroundColorHex)
                if bgLuminance < 0.5 {
                    // Dark background: use colored glow with cue color
                    return baseColor.opacity(0.6)
                } else {
                    // Light background: use black shadow
                    return Color.black.opacity(0.3)
                }
            }(),
            radius: isCued ? 12 : 0,
            x: 0,
            y: {
                if !isCued { return 0 }
                let bgLuminance = relativeLuminance(hex: backgroundColorHex)
                return bgLuminance < 0.5 ? 0 : 6  // No y-offset for glow, offset for shadow
            }()
        )
        .zIndex(isCued ? 1 : 0)  // Elevate selected cue above others
        .simultaneousGesture(press)
        // No context menu in either mode (Option A: disabled in both normal and edit mode)
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

// MARK: - Setlist Row (simple row for swipe gestures)
struct CBSetlistRow: View {
    let song: Song
    let themeFont: ((CGFloat, Font.Weight) -> Font)?  // Optional theme font function
    let conflictFor: [MIDIKey: String]
    var onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(song.name)
                    .font(themeFont?(18, .bold) ?? .body.bold())
                    .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let sub = song.subtitle, !sub.isEmpty {
                    Text(sub)
                        .font(.caption)
                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text(" ").font(.caption).foregroundColor(.clear)
                }
            }
            Spacer()

            // Show MIDI info and conflict warning
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 16) {
                    // Always show MIDI info
                    let midiInfo: String = {
                        if song.kind == .cc {
                            return "Ch \(song.channel) • CC \(song.cc)"
                        } else {
                            let noteName = (song.note ?? 0).midiNoteName
                            return "Ch \(song.channel) • \(noteName)"
                        }
                    }()
                    Text(midiInfo)
                        .font(.caption2)
                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))

                    // Color indicator circle (always reserve space for alignment)
                    Group {
                        if let hex = song.colorHex {
                            Circle()
                                .fill(Color(hex: hex))
                                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        } else {
                            Circle()
                                .fill(Color.clear)
                        }
                    }
                    .frame(width: 20, height: 20)
                }

                // Show conflict warning below MIDI info
                if let owner = filteredTakenBy() {
                    Text("⚠️ MIDI taken by: \(owner)")
                        .font(.caption2)
                        .foregroundColor(selectedTheme.errorColor(for: colorScheme))
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    private func filteredTakenBy() -> String? {
        let key = (song.kind == .note)
            ? MIDIKey(kind: .note, channel: song.channel, number: song.note ?? 0)
            : MIDIKey(kind: .cc, channel: song.channel, number: song.cc)
        guard let takenBy = conflictFor[key] else { return nil }

        // Filter out current song's name from the conflict list
        if takenBy.contains("|||") {
            // Multiple owners - split and filter
            let owners = takenBy.split(separator: "|||").map(String.init).filter { $0 != song.name }
            guard !owners.isEmpty else { return nil }
            if owners.count == 1 {
                return owners[0]
            } else if owners.count == 2 {
                return "\(owners[0]) and \(owners[1])"
            } else {
                return owners.dropLast().joined(separator: ", ") + ", and " + owners.last!
            }
        } else if takenBy == song.name {
            // Single owner and it's us
            return nil
        }
        return takenBy
    }
}

// MARK: - Custom Drag Preview (no white border)
struct CBSetlistDragPreview: View {
    let song: Song
    let themeFont: ((CGFloat, Font.Weight) -> Font)?  // Optional theme font function

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(song.name)
                    .font(themeFont?(18, .bold) ?? .body.bold())
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let sub = song.subtitle, !sub.isEmpty {
                    Text(sub)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text(" ").font(.caption).foregroundColor(.clear)
                }
            }
            Spacer()
            // Show drag handle on the right during drag
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary)
                .font(.title3)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .frame(width: 300, alignment: .leading) // Fixed width for preview
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.15))
                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Editor: Setlist column
struct CBSetlistColumn: View {
    let songs: [Song]
    let themeFont: ((CGFloat, Font.Weight) -> Font)?  // Optional theme font function
    let conflictFor: [MIDIKey: String]
    @Binding var searchText: String
    @Binding var reorderMode: Bool
    @Binding var batchMode: Bool
    @Binding var selected: Set<UUID>
    var onRename: (Song) -> Void
    var onRemove: (Song) -> Void
    var onMove: (IndexSet, Int) -> Void
    var onAdd: () -> Void
    var onToggleSelect: (UUID) -> Void
    var onSelectAll: (() -> Void)?
    var onClearSelection: (() -> Void)?
    var onBatchRemove: (() -> Void)?
    var onDuplicate: ((Song) -> Void)?  // Optional callback for duplicating a cue

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("Cue List")
                    .font(themeFont?(17, .semibold) ?? .headline)
                    .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                Spacer()

                Button {
                    withAnimation(.easeInOut) {
                        reorderMode.toggle()
                        if reorderMode {
                            batchMode = false
                            selected.removeAll()
                        }
                    }
                } label: {
                    Image(systemName: reorderMode ? "checkmark" : "list.dash")
                        .font(.system(size: 17))
                        .frame(width: 24, height: 24)
                        .foregroundStyle(selectedTheme.defaultCueColor(for: colorScheme))
                }
                .buttonStyle(ThemedCapsuleButtonStyle(backgroundColor: selectedTheme.lightButtonBackgroundColor(for: colorScheme), strokeColor: selectedTheme.defaultCueColor(for: colorScheme)))

                Button {
                    withAnimation(.easeInOut) {
                        batchMode.toggle()
                        if batchMode {
                            reorderMode = false
                        }
                        if !batchMode {
                            selected.removeAll()
                        }
                    }
                } label: {
                    Image(systemName: batchMode ? "xmark" : "checkmark.circle")
                        .font(.system(size: 17))
                        .frame(width: 24, height: 24)
                        .foregroundStyle(selectedTheme.defaultCueColor(for: colorScheme))
                }
                .buttonStyle(ThemedCapsuleButtonStyle(backgroundColor: selectedTheme.lightButtonBackgroundColor(for: colorScheme), strokeColor: selectedTheme.defaultCueColor(for: colorScheme)))
                .padding(.trailing, 16)
            }
            .frame(height: 44) // Match library column header height

            // Batch controls replace search bar when in batch mode
            if batchMode {
                HStack(spacing: 20) {
                    Button("Select All") {
                        onSelectAll?()
                    }
                    .foregroundColor(Color(hex: "0A84FF"))  // Default cue color

                    Button("Clear") {
                        onClearSelection?()
                    }
                    .foregroundColor(Color(hex: "0A84FF"))  // Default cue color

                    Spacer()

                    Button("Remove") {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onBatchRemove?()
                    }
                    .foregroundColor(selected.isEmpty ? .gray : .red)
                    .disabled(selected.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            } else {
                // Search TextField
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.body)

                    TextField("Search cues...", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .font(.body)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selectedTheme.titleBarColor(for: colorScheme).opacity(0.8))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }

            List {
                ForEach(songs) { s in
                    HStack(spacing: 12) {
                        // Show selection circle in batch mode
                        if batchMode {
                            ZStack {
                                Circle()
                                    .strokeBorder(Color.gray.opacity(0.5), lineWidth: 2)
                                    .frame(width: 24, height: 24)
                                if selected.contains(s.id) {
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 24, height: 24)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(width: 24, height: 24)
                            .onTapGesture {
                                onToggleSelect(s.id)
                            }
                        }

                        CBSetlistRow(
                            song: s,
                            themeFont: themeFont,
                            conflictFor: conflictFor,
                            onTap: {
                                if batchMode {
                                    onToggleSelect(s.id)
                                } else {
                                    onRename(s)
                                }
                            }
                        )
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
                    .listRowSeparator(.visible)
                    .listRowSeparatorTint(.gray)
                    .contextMenu {
                        if reorderMode {
                            Button {
                                onRename(s)
                            } label: {
                                Label("Edit Cue", systemImage: "pencil")
                            }

                            Button {
                                onDuplicate?(s)
                            } label: {
                                Label("Duplicate", systemImage: "doc.on.doc")
                            }

                            Button(role: .destructive) {
                                onRemove(s)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if !reorderMode && !batchMode {
                            Button(role: .destructive) {
                                onRemove(s)
                            } label: {
                                Label("Remove", systemImage: "minus.circle")
                            }
                        }
                    }
                }
                .onMove { inds, newOffset in
                    if searchText.isEmpty && reorderMode {
                        onMove(inds, newOffset)
                    }
                }
            }
            .environment(\.editMode, .constant(reorderMode && searchText.isEmpty ? .active : .inactive))
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(selectedTheme.backgroundColor(for: colorScheme))
            .tint(.gray) // Drag handles same color as search icon
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Editor: Library column
struct CBLibraryColumn: View {
    let rows: [CBLibraryRow]
    let themeFont: ((CGFloat, Font.Weight) -> Font)?  // Optional theme font function
    let conflictFor: [MIDIKey: String]
    @Binding var isEditing: Bool
    @Binding var batchMode: Bool
    @Binding var selected: Set<UUID>
    @Binding var sortMode: LibrarySortMode
    @Binding var searchText: String

    var onToggleSelect: (UUID) -> Void
    var onAddToSetlist: (Song) -> Void
    var onDeleteFromLibrary: (Song) -> Void
    var onRename: (Song) -> Void
    var onSelectAll: (() -> Void)?
    var onClearSelection: (() -> Void)?
    var onBatchAddToSetlist: (() -> Void)?
    var onBatchDelete: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("Song Library")
                    .font(themeFont?(17, .semibold) ?? .headline)
                    .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                Spacer()

                Menu {
                    Picker("Sort", selection: $sortMode) {
                        ForEach(LibrarySortMode.allCases) { mode in Text(mode.label).tag(mode) }
                    }
                    .tint(selectedTheme.defaultCueColor(for: colorScheme))
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 17))
                        .frame(width: 24, height: 24)
                        .foregroundStyle(selectedTheme.defaultCueColor(for: colorScheme))
                }
                .buttonStyle(ThemedCapsuleButtonStyle(backgroundColor: selectedTheme.lightButtonBackgroundColor(for: colorScheme), strokeColor: selectedTheme.defaultCueColor(for: colorScheme)))

                Button {
                    withAnimation(.easeInOut) { batchMode.toggle() }
                    if !batchMode { selected.removeAll() }
                } label: {
                    Image(systemName: batchMode ? "xmark" : "checkmark.circle")
                        .font(.system(size: 17))
                        .frame(width: 24, height: 24)
                        .foregroundStyle(selectedTheme.defaultCueColor(for: colorScheme))
                }
                .buttonStyle(ThemedCapsuleButtonStyle(backgroundColor: selectedTheme.lightButtonBackgroundColor(for: colorScheme), strokeColor: selectedTheme.defaultCueColor(for: colorScheme)))
                .padding(.trailing, 16)
            }
            .frame(height: 44) // Match cue list column header height

            // v1.0.9: Batch controls replace search bar when in batch mode
            if batchMode {
                HStack(spacing: 20) {
                    Button("Select All") {
                        onSelectAll?()
                    }
                    .foregroundColor(Color(hex: "0A84FF"))  // Default cue color

                    Button("Clear") {
                        onClearSelection?()
                    }
                    .foregroundColor(Color(hex: "0A84FF"))  // Default cue color

                    Spacer()

                    Button("Add") {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onBatchAddToSetlist?()
                    }
                    .foregroundColor(selected.isEmpty ? .gray : Color(hex: "0A84FF"))  // Default cue color
                    .disabled(selected.isEmpty)

                    Button("Delete") {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onBatchDelete?()
                    }
                    .foregroundColor(selected.isEmpty ? .gray : .red)
                    .disabled(selected.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            } else {
                // Search TextField
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.body)

                    TextField("Search songs...", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .font(.body)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selectedTheme.titleBarColor(for: colorScheme).opacity(0.8))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }

            List {
                ForEach(rows, id: \.id) { row in
                    HStack(spacing: 12) {
                        // Show selection circle in batch mode
                        if batchMode {
                            ZStack {
                                Circle()
                                    .strokeBorder(Color.gray.opacity(0.5), lineWidth: 2)
                                    .frame(width: 24, height: 24)
                                if row.isSelected {
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 24, height: 24)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(width: 24, height: 24)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.song.name)
                                .font(themeFont?(18, .bold) ?? .body.bold())
                                .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                                .lineLimit(1)
                                .truncationMode(.tail)
                            if let sub = row.song.subtitle, !sub.isEmpty {
                                Text(sub)
                                    .font(.caption)
                                    .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            } else {
                                Text(" ").font(.caption).foregroundColor(.clear)
                            }
                        }
                        Spacer()

                        // Show MIDI info and conflict warning
                        VStack(alignment: .trailing, spacing: 4) {
                            HStack(spacing: 16) {
                                // Always show MIDI info
                                let midiInfo: String = {
                                    if row.song.kind == .cc {
                                        return "Ch \(row.song.channel) • CC \(row.song.cc)"
                                    } else {
                                        let noteName = (row.song.note ?? 0).midiNoteName
                                        return "Ch \(row.song.channel) • \(noteName)"
                                    }
                                }()
                                Text(midiInfo)
                                    .font(.caption2)
                                    .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))

                                // Color indicator circle (always reserve space for alignment)
                                Group {
                                    if let hex = row.song.colorHex {
                                        Circle()
                                            .fill(Color(hex: hex))
                                            .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                    } else {
                                        Circle()
                                            .fill(Color.clear)
                                    }
                                }
                                .frame(width: 20, height: 20)
                            }

                            // Show conflict warning below MIDI info
                            if let owner = filteredTakenBy(for: row.song) {
                                Text("⚠️ MIDI taken by: \(owner)")
                                    .font(.caption2)
                                    .foregroundColor(selectedTheme.errorColor(for: colorScheme))
                                    .lineLimit(1)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 6)
                    .opacity(row.isInSetlist ? 0.55 : 1.0)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
                    .listRowSeparator(.visible)
                    .listRowSeparatorTint(.gray)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        if !row.isInSetlist && !batchMode {
                            Button {
                                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                                onAddToSetlist(row.song)
                            } label: {
                                Label("Add to Cue List", systemImage: "plus.circle.fill")
                            }
                            .tint(.accentColor)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if !batchMode {
                            Button(role: .destructive) {
                                onDeleteFromLibrary(row.song)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onTapGesture {
                        if batchMode {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onToggleSelect(row.song.id)
                        } else {
                            onRename(row.song)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(selectedTheme.backgroundColor(for: colorScheme))
            .onReceive(NotificationCenter.default.publisher(for: .init("CBRemoveFromSetlist"))) { _ in }
        }
        .frame(maxWidth: .infinity)
    }

    private func filteredTakenBy(for song: Song) -> String? {
        let key = (song.kind == .note)
            ? MIDIKey(kind: .note, channel: song.channel, number: song.note ?? 0)
            : MIDIKey(kind: .cc, channel: song.channel, number: song.cc)
        guard let takenBy = conflictFor[key] else { return nil }

        // Filter out current song's name from the conflict list
        if takenBy.contains("|||") {
            // Multiple owners - split and filter
            let owners = takenBy.split(separator: "|||").map(String.init).filter { $0 != song.name }
            guard !owners.isEmpty else { return nil }
            if owners.count == 1 {
                return owners[0]
            } else if owners.count == 2 {
                return "\(owners[0]) and \(owners[1])"
            } else {
                return owners.dropLast().joined(separator: ", ") + ", and " + owners.last!
            }
        } else if takenBy == song.name {
            // Single owner and it's us
            return nil
        }
        return takenBy
    }
}

struct CBRowLikeLibrary<Leading: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    var leading: () -> Leading
    var trailing: () -> Trailing
    var onTap: (() -> Void)?

    init(title: String, subtitle: String?,
         @ViewBuilder leading: @escaping () -> Leading = { EmptyView() },
         @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() },
         onTap: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading
        self.trailing = trailing
        self.onTap = onTap
    }

    var body: some View {
        HStack(spacing: 12) {
            leading()
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.bold()).foregroundColor(.primary)
                if let sub = subtitle, !sub.isEmpty {
                    Text(sub).font(.caption).foregroundColor(.secondary)
                } else {
                    Text(" ").font(.caption).foregroundColor(.clear)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                // Only trigger tap on text area, not on buttons
                onTap?()
            }
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Full-width batch toolbar
struct CBBatchToolbar: View {
    let selectedCount: Int
    var onSelectAll: () -> Void
    var onClear: () -> Void
    var onAddToSetlist: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Button("Select All", action: onSelectAll)
                    .buttonStyle(WhiteCapsuleButtonStyle())
                    .foregroundColor(.blue)
                Button("Clear", action: onClear)
                    .buttonStyle(WhiteCapsuleButtonStyle())
                    .foregroundColor(.blue)
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onAddToSetlist()
                } label: { Label("Add to Setlist", systemImage: "plus.circle.fill") }
                .buttonStyle(.borderedProminent)
                .disabled(selectedCount == 0)

                Button(role: .destructive) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onDelete()
                } label: { Label("Delete", systemImage: "trash") }
                .buttonStyle(WhiteCapsuleButtonStyle())
                .foregroundColor(.blue)
                .disabled(selectedCount == 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Bridge Device Card
private struct BridgeDeviceCard: View {
    let computerName: String
    let isConnected: Bool
    let isConnecting: Bool
    let isClickable: Bool
    let connectionType: ConnectionType
    let onTap: (() -> Void)?
    
    enum ConnectionType {
        case usb, wifi
        
        var color: Color {
            return Color(hex: "0A84FF")  // Default cue color
        }
        
        var connectedColor: Color {
            return .green
        }
        
        var icon: String {
            return "bearpaw_32x32"
        }
    }
    
    init(computerName: String, isConnected: Bool, isConnecting: Bool = false, connectionType: ConnectionType, isClickable: Bool = false, onTap: (() -> Void)? = nil) {
        self.computerName = computerName
        self.isConnected = isConnected
        self.isConnecting = isConnecting
        self.connectionType = connectionType
        self.isClickable = isClickable
        self.onTap = onTap
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Bear paw icon with loading animation
            if isConnecting {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: connectionType.color))
                    .scaleEffect(0.8)
                    .frame(width: 20, height: 20)
            } else {
                Image(connectionType.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(isConnected ? connectionType.connectedColor : connectionType.color)
                    .frame(width: 20, height: 20)
            }
            
            // Computer name
            VStack(alignment: .leading, spacing: 2) {
                Text(computerName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isConnected ? connectionType.connectedColor : connectionType.color)
                    .lineLimit(2)
                    .truncationMode(.tail)
                
                Text(connectionType == .usb ? "USB Bridge" : "WiFi Bridge")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Connection status indicator
            Circle()
                .fill(isConnected ? connectionType.connectedColor : .gray.opacity(0.3))
                .frame(width: 8, height: 8)
                .scaleEffect(isConnected ? 1.0 : 0.8)
                .animation(.easeInOut(duration: 0.2), value: isConnected)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isConnected ? 
                    LinearGradient(
                        colors: [connectionType.connectedColor.opacity(0.08), connectionType.connectedColor.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) : 
                    LinearGradient(
                        colors: [connectionType.color.opacity(0.08), connectionType.color.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isConnected ? 
                        LinearGradient(
                            colors: [connectionType.connectedColor.opacity(0.3), connectionType.connectedColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) : 
                        LinearGradient(
                            colors: [connectionType.color.opacity(0.3), connectionType.color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                    lineWidth: 0.5
                )
        )
        .shadow(
            color: isConnected ? connectionType.connectedColor.opacity(0.1) : connectionType.color.opacity(0.1),
            radius: 2,
            x: 0,
            y: 1
        )
        .scaleEffect(isClickable ? 1.0 : 1.0)
        .onTapGesture {
            if isClickable, let onTap = onTap {
                withAnimation(.easeInOut(duration: 0.1)) {
                    onTap()
                }
            }
        }
    }
}

// The following sheets are moved out for clarity
struct CBConnectionsSheet: View {
    @ObservedObject var usbServer: ConnectionManager
    @ObservedObject var wifiClient: BridgeOutput
    @ObservedObject var connectionCoordinator: ConnectionCoordinator

    var onDisconnectWifi: () -> Void
    var onConnectWifiItem: (BridgeOutput.Item) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("USB").foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))) {
                    KeyValueRow("Status", connectionCoordinator.activeConnection == .usb ? "Connected" : "Waiting")
                        .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                    if connectionCoordinator.activeConnection == .usb {
                        Button("Disconnect USB", role: .destructive) {
                            connectionCoordinator.disconnectUSB()
                        }
                        .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                    }


                    // Bridge device card for USB connection - show ONLY when Bridge app is running
                    if usbServer.usbBridgeAvailable {
                        BridgeDeviceCard(
                            computerName: usbServer.connectedComputerName ?? "Bear Bridge",
                            isConnected: connectionCoordinator.activeConnection == .usb,
                            isConnecting: usbServer.isConnecting,
                            connectionType: .usb,
                            isClickable: connectionCoordinator.activeConnection != .usb, // Clickable when not connected
                            onTap: {
                                if connectionCoordinator.activeConnection != .usb {
                                    // Force USB connection attempt
                                    connectionCoordinator.forceUSBReconnection()
                                }
                            }
                        )
                        .transition(.scale.combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.2), value: usbServer.usbBridgeAvailable)
                        .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                    } else {
                        Text("Bridge app not running")
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.2), value: usbServer.usbBridgeAvailable)
                            .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                    }
                }

                Section(header: Text("Wi-Fi").foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))) {
                    KeyValueRow("Status", connectionCoordinator.activeConnection == .wifi ? "Connected" : "Not Connected")
                        .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                    if connectionCoordinator.activeConnection == .wifi {
                        Button("Disconnect Wi-Fi", role: .destructive) { onDisconnectWifi() }
                            .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                    }


                    if wifiClient.discovered.isEmpty {
                        Text("Searching on local network…").foregroundColor(.secondary)
                            .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                    } else {
                        ForEach(wifiClient.discovered, id: \.id) { item in
                            BridgeDeviceCard(
                                computerName: item.name,
                                // v1.0.4: Fix WiFi chip showing disconnected when USB unplugs
                                // Use connectionCoordinator.activeConnection as source of truth instead of item.id comparison
                                // because discovered array rebuilds with new IDs after USB disconnect
                                isConnected: connectionCoordinator.activeConnection == .wifi && wifiClient.current?.name == item.name,
                                isConnecting: wifiClient.isConnecting && wifiClient.current?.name == item.name,
                                connectionType: .wifi,
                                isClickable: true,
                                onTap: {
                                    debugPrint("🔌 DEBUG: Bridge tapped - \(item.name)")
                                    connectionCoordinator.connectToWiFi(bridge: item)
                                }
                            )
                            .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                        }
                    }
                }

            }
            .scrollContentBackground(.hidden)
            .background(selectedTheme.backgroundColor(for: colorScheme))
            .navigationTitle("Connections")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(selectedTheme.defaultCueColor(for: colorScheme))
                }
            }
            .tint(selectedTheme.defaultCueColor(for: colorScheme))
        }
        .preferredColorScheme(selectedTheme.preferredColorScheme(for: colorScheme))
    }
    
    
    private func KeyValueRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
            Spacer()
            Text(value).foregroundColor(.secondary)
        }
    }

    private func gitCommitHash() -> String {
        // Try to read git commit hash from build-time generated file
        if let path = Bundle.main.path(forResource: "GitCommit", ofType: "txt"),
           let hash = try? String(contentsOfFile: path, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) {
            return String(hash.prefix(7))
        }
        // Fallback to build number if git hash not available
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}


struct CBProjectsSheet: View {
    @Binding var projectName: String
    let projects: [String]
    @Binding var isDirty: Bool

    var onTapTitleWhenUnsaved: () -> Void
    var onLoad: (String) -> Void
    var onDelete: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""
    @State private var confirmDelete: String? = nil

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Text("Project")
                            .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                        Spacer()
                        if projectName == "Untitled" || isDirty {
                            Button(projectName) { onTapTitleWhenUnsaved() }
                                .foregroundColor(selectedTheme.defaultCueColor(for: colorScheme))
                        } else {
                            Text(projectName)
                                .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                        }
                    }
                }
                .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))

                Section(header: Text("Saved Projects").foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))) {
                    if projects.isEmpty {
                        Text("No saved projects yet.")
                            .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                            .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                    } else {
                        ForEach(projects, id: \.self) { name in
                            HStack {
                                Button(name) { onLoad(name); dismiss() }
                                    .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                                Spacer()
                                Button {
                                    debugPrint("🗑️ Delete button tapped for project: \(name)")
                                    confirmDelete = name
                                    debugPrint("🗑️ Set confirmDelete to: \(name)")
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(selectedTheme.errorColor(for: colorScheme))
                                }
                                .buttonStyle(.plain)
                            }
                            .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(selectedTheme.backgroundColor(for: colorScheme))
            .navigationTitle("Projects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(selectedTheme.backgroundColor(for: colorScheme), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(selectedTheme.defaultCueColor(for: colorScheme))
                }
            }
            .tint(selectedTheme.defaultCueColor(for: colorScheme))
            .alert("Delete Project", isPresented: Binding(get: { confirmDelete != nil }, set: { newVal in if !newVal { confirmDelete = nil } })) {
                Button("Delete", role: .destructive) {
                    debugPrint("🗑️ Delete confirmed for project: \(confirmDelete ?? "nil")")
                    if let n = confirmDelete { 
                        debugPrint("🗑️ Calling onDelete with: \(n)")
                        onDelete(n) 
                    }
                    confirmDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    debugPrint("🗑️ Delete cancelled for project: \(confirmDelete ?? "nil")")
                    confirmDelete = nil
                }
            } message: {
                if let name = confirmDelete {
                    Text("Are you sure you want to delete '\(name)'? This action cannot be undone.")
                }
            }
        }
        .preferredColorScheme(selectedTheme.preferredColorScheme(for: colorScheme))
    }
}

struct CBAddEditCueSheet: View {
    @Binding var editingSong: Song?
    let conflictFor: [MIDIKey: String]
    var currentOwnerName: (MIDIKey) -> String?
    let defaultName: String
    var onSave: (Song, Bool) -> Void  // Added Bool parameter for andAddAnother
    var onCancel: () -> Void
    var onDelete: ((Song) -> Void)? = nil
    var onDuplicate: ((Song) -> Void)? = nil  // Callback for duplicating cue

    // Global channel support
    let isGlobalChannel: Bool
    let globalChannel: Int
    let midiFilter: Set<Int>

    @State private var name: String = ""
    @State private var subtitle: String = ""
    @State private var kind: MIDIKind = .cc
    @State private var number: Int = 0
    @State private var channel: Int = 1
    @State private var velocity: Int = 127
    @State private var midiEnabled: Bool = true
    @State private var autoAssign: Bool = true
    @State private var colorHex: String? = nil
    @State private var showColorPicker: Bool = false
    @State private var error: String? = nil
    @State private var showDeleteAlert: Bool = false
    @State private var showGlobalModeMaxReachedAlert: Bool = false
    @State private var lastEditingSongID: UUID? = nil  // Track which song we're editing to preserve unsaved changes

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("SONG").foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))) {
                    TextField("Name", text: $name, prompt: Text(defaultName).foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme)))
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(false)
                        .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                        .foregroundStyle(selectedTheme.primaryTextColor(for: colorScheme))
                    TextField("Subtitle (Tempo/Key/Notes)", text: $subtitle, prompt: Text("Subtitle (Tempo/Key/Notes)").foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme)))
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(false)
                        .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                        .foregroundStyle(selectedTheme.primaryTextColor(for: colorScheme))

                    // Color Picker - Inline Disclosure
                    DisclosureGroup(
                        isExpanded: $showColorPicker,
                        content: {
                            // Inline color picker
                            CBColorPickerInline(selectedColorHex: $colorHex)
                                .padding(.vertical, 8)
                        },
                        label: {
                            HStack {
                                Text("Color")
                                Spacer()
                                if let hex = colorHex {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 24, height: 24)
                                        .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                } else {
                                    Text("Default")
                                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                                }
                            }
                        }
                    )
                    .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                }
                Section(header: Text("MIDI").foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))) {
                    Toggle(isOn: $midiEnabled) {
                        Text("Enable MIDI")
                    }
                    .toggleStyle(SwitchToggleStyle(tint: selectedTheme.successColor(for: colorScheme)))
                    .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))

                    if midiEnabled {
                        Toggle(isOn: $autoAssign) {
                            Text("Assign MIDI automatically")
                        }
                        .toggleStyle(SwitchToggleStyle(tint: selectedTheme.successColor(for: colorScheme)))
                        .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                    }

                    if midiEnabled {
                        Picker("Type", selection: $kind) {
                            Text("Control Change").tag(MIDIKind.cc)
                            Text("Note").tag(MIDIKind.note)
                        }
                        .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                        .tint(selectedTheme.secondaryTextColor(for: colorScheme))
                        .foregroundStyle(selectedTheme.primaryTextColor(for: colorScheme))

                        ChannelPicker(title: "Channel", channel: $channel, disabled: false)
                            .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))

                        MIDINumberPicker(
                            kind: kind,
                            number: $number,
                            disabled: autoAssign,
                            channel: channel,
                            currentOwnerName: currentOwnerName,
                            editingControl: nil,
                            editingSong: editingSong
                        )
                        .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))

                        if kind == .note {
                            VelocityPicker(velocity: $velocity, disabled: false)
                                .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                        }
                    }
                }
                if let err = error {
                    Text(err).foregroundColor(selectedTheme.errorColor(for: colorScheme))
                        .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                }

                // Duplicate & Delete section - only show when editing existing cue
                if editingSong != nil {
                    Section {
                        // Duplicate button
                        if onDuplicate != nil {
                            Button {
                                if let song = editingSong {
                                    onDuplicate?(song)
                                }
                            } label: {
                                HStack {
                                    Spacer()
                                    Image(systemName: "doc.on.doc")
                                    Text("Duplicate Cue")
                                    Spacer()
                                }
                                .foregroundColor(selectedTheme.defaultCueColor(for: colorScheme))
                            }
                            .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                        }

                        // Delete button
                        if onDelete != nil {
                            Button(role: .destructive) {
                                showDeleteAlert = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("Delete Cue")
                                    Spacer()
                                }
                            }
                            .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(selectedTheme.backgroundColor(for: colorScheme))
            .navigationTitle(editingSong == nil ? "Add Cue" : "Edit Cue")
            .tint(selectedTheme.defaultCueColor(for: colorScheme))
            .alert("Delete Cue", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let song = editingSong {
                        onDelete?(song)
                        // Clear the draft tracking since we deleted
                        lastEditingSongID = nil
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete '\(name.isEmpty ? defaultName : name)'? This action cannot be undone.")
            }
            .alert("Maximum Controls Reached", isPresented: $showGlobalModeMaxReachedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You've reached the maximum of 127 controls in Global MIDI Channel mode. Turn off Global MIDI Channel mode to continue auto-assigning on additional channels.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onCancel() } }
                if editingSong == nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Save & Add Another") { save(andAddAnother: true) }
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { save(andAddAnother: false) } }
            }
            .onAppear {
                // Always call preset() to ensure form is properly initialized
                // This handles: editing different songs, switching to/from add mode, and reopening add mode
                debugPrint("🎬 [CUE] Sheet appeared, editingSong: \(editingSong?.name ?? "nil"), lastEditingSongID: \(lastEditingSongID?.uuidString ?? "nil")")
                preset()
                lastEditingSongID = editingSong?.id
            }
            .onChange(of: editingSong) { oldValue, newValue in
                // When editingSong changes, check if we need to preset
                let oldID = oldValue?.id
                let newID = newValue?.id
                if oldID != newID {
                    preset()
                    lastEditingSongID = newID
                }
            }
            .onChange(of: autoAssign) { _, newValue in
                if newValue {
                    let result = autoAssignMIDI(for: kind, startChannel: channel, startNumber: 0)
                    if result.reachedLimit {
                        showGlobalModeMaxReachedAlert = true
                        autoAssign = false
                    } else {
                        channel = result.channel
                        number = result.number
                    }
                }
            }
            .onChange(of: kind) { _, newValue in
                if autoAssign {
                    let result = autoAssignMIDI(for: newValue, startChannel: channel, startNumber: 0)
                    if result.reachedLimit {
                        showGlobalModeMaxReachedAlert = true
                        autoAssign = false
                    } else {
                        channel = result.channel
                        number = result.number
                    }
                }
            }
            .onChange(of: channel) { _, newValue in
                if autoAssign {
                    let result = autoAssignMIDI(for: kind, startChannel: newValue, startNumber: 0)
                    if result.reachedLimit {
                        showGlobalModeMaxReachedAlert = true
                        autoAssign = false
                    } else {
                        channel = result.channel
                        number = result.number
                    }
                }
            }
        }
        .preferredColorScheme(selectedTheme.preferredColorScheme(for: colorScheme))
    }

    private func preset() {
        debugPrint("📋 [CUE] preset() called, editingSong: \(editingSong != nil ? "exists" : "nil")")
        if let s = editingSong {
            name = s.name
            subtitle = s.subtitle ?? ""
            kind = s.kind
            number = (s.kind == .note) ? (s.note ?? 60) : s.cc
            channel = s.channel
            velocity = s.velocity
            colorHex = s.colorHex
            midiEnabled = s.midiEnabled
            // For existing songs, disable auto-assign to allow manual editing
            autoAssign = false
        } else {
            name = ""
            subtitle = ""
            kind = .cc
            colorHex = nil
            // FIX: Use global channel if enabled, otherwise default to 1
            channel = isGlobalChannel ? globalChannel : 1
            velocity = 127
            // For new songs, enable auto-assign and find free MIDI
            autoAssign = true
            // Always start from 0 to find the lowest available (fill gaps first)
            debugPrint("  🆕 [CUE] No editing state, finding lowest available \(kind) on ch\(channel)")
            let result = autoAssignMIDI(for: kind, startChannel: channel, startNumber: 0)

            if result.reachedLimit {
                showGlobalModeMaxReachedAlert = true
                autoAssign = false
            } else {
                channel = result.channel
                number = result.number
                debugPrint("  ✅ [CUE] preset() set channel=\(result.channel), number=\(result.number)")
            }
        }
    }

    // Result type for auto-assign with channel increment support
    private struct AutoAssignResult {
        let channel: Int
        let number: Int
        let reachedLimit: Bool  // true if hit 127 in global mode
    }

    // New auto-assign function that can increment channel when reaching 127
    private func autoAssignMIDI(for kind: MIDIKind, startChannel: Int, startNumber: Int = 0) -> AutoAssignResult {
        debugPrint("🔍 [CUE] Auto-assigning \(kind) starting from channel \(startChannel), number \(startNumber)")
        debugPrint("  📝 [CUE] editingSong: \(editingSong?.name ?? "nil")")

        // In global mode, we can't increment channel
        if isGlobalChannel {
            // Search only on the global channel
            for n in startNumber...127 {
                // Skip filtered CC numbers (only for CC type, not notes)
                if kind == .cc && midiFilter.contains(n) {
                    debugPrint("  🚫 [CUE] CC \(n) is filtered, skipping")
                    continue
                }

                let key = MIDIKey(kind: kind, channel: globalChannel, number: n)
                let owner = currentOwnerName(key)
                debugPrint("  🔍 [CUE] Checking \(n): owner=\(owner ?? "nil")")
                if let owner = owner {
                    if owner != editingSong?.name {
                        debugPrint("  ✗ [CUE] \(n) is taken by '\(owner)', skipping")
                        continue
                    }
                    debugPrint("  ✓ [CUE] \(n) is taken by editing song, available")
                }
                debugPrint("  ✅ [CUE] Assigned: channel \(globalChannel), number \(n)")
                return AutoAssignResult(channel: globalChannel, number: n, reachedLimit: false)
            }
            // Reached limit in global mode
            debugPrint("  ⚠️ [CUE] Reached limit of 127 in global mode")
            return AutoAssignResult(channel: globalChannel, number: 0, reachedLimit: true)
        }

        // Non-global mode: can increment channel when reaching 127
        var currentChannel = startChannel
        var currentNumber = startNumber

        // Try up to 16 channels
        for _ in 0..<16 {
            // Search from currentNumber to 127 on current channel
            for n in currentNumber...127 {
                // Skip filtered CC numbers (only for CC type, not notes)
                if kind == .cc && midiFilter.contains(n) {
                    debugPrint("  🚫 [CUE] CC \(n) is filtered, skipping")
                    continue
                }

                let key = MIDIKey(kind: kind, channel: currentChannel, number: n)
                let owner = currentOwnerName(key)
                debugPrint("  🔍 [CUE] Checking \(n) on ch\(currentChannel): owner=\(owner ?? "nil")")
                if let owner = owner {
                    if owner != editingSong?.name {
                        debugPrint("  ✗ [CUE] \(n) is taken by '\(owner)', skipping")
                        continue
                    }
                    debugPrint("  ✓ [CUE] \(n) is taken by editing song, available")
                }
                debugPrint("  ✅ [CUE] Assigned: channel \(currentChannel), number \(n)")
                return AutoAssignResult(channel: currentChannel, number: n, reachedLimit: false)
            }

            // Reached end of current channel, increment and start from 0
            debugPrint("  🔄 [CUE] Channel \(currentChannel) full, moving to channel \(currentChannel + 1)")
            currentChannel += 1
            if currentChannel > 16 {
                currentChannel = 1  // Wrap around
            }
            currentNumber = 0  // Reset to start of new channel
        }

        // Exhausted all channels (unlikely but handle it)
        debugPrint("  ⚠️ [CUE] No free slots found across all channels")
        return AutoAssignResult(channel: startChannel, number: 0, reachedLimit: false)
    }

    // Legacy function for compatibility
    private func firstFreeNumber(for kind: MIDIKind, channel: Int) -> Int {
        let result = autoAssignMIDI(for: kind, startChannel: channel, startNumber: 0)
        return result.number
    }

    private func conflictOwner() -> String? {
        let key = MIDIKey(kind: kind, channel: channel, number: number)
        guard let ownersString = currentOwnerName(key) else { return nil }

        // Get the cue name to filter out - try editingSong first, then fall back to form name
        let cueNameToFilter = (editingSong?.name ?? name).trimmingCharacters(in: .whitespacesAndNewlines)

        debugPrint("🔍 [CONFLICT] Checking conflict: ownersString='\(ownersString)', editingSong?.name='\(editingSong?.name ?? "nil")', form name='\(name)', cueNameToFilter='\(cueNameToFilter)'")

        // Normalize strings for comparison (case-insensitive, trimmed)
        let normalizedOwners = ownersString.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCueName = cueNameToFilter

        // Filter out this cue's name from the conflict list
        if !normalizedCueName.isEmpty {
            if ownersString.contains("|||") {
                // Multiple owners - split and filter
                let owners = ownersString.split(separator: "|||")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { $0 != normalizedCueName }
                guard !owners.isEmpty else {
                    debugPrint("✅ [CONFLICT] All owners filtered out, returning nil")
                    return nil
                }
                debugPrint("⚠️ [CONFLICT] Remaining owners after filter: \(owners)")
                if owners.count == 1 {
                    return owners[0]
                } else if owners.count == 2 {
                    return "\(owners[0]) and \(owners[1])"
                } else {
                    return owners.dropLast().joined(separator: ", ") + ", and " + owners.last!
                }
            } else if normalizedOwners == normalizedCueName {
                // Single owner and it's this cue itself
                debugPrint("✅ [CONFLICT] Single owner matches editing cue, returning nil")
                return nil
            }
        }

        debugPrint("❌ [CONFLICT] Returning ownersString: '\(ownersString)'")
        return ownersString
    }

    private func ownerFor(kind: MIDIKind, number: Int, channel: Int) -> String? {
        // If we're editing an existing song and checking its current MIDI assignment, no conflict
        if let edit = editingSong {
            let editNumber = (edit.kind == .note) ? (edit.note ?? 60) : edit.cc
            if edit.kind == kind && edit.channel == channel && editNumber == number {
                return nil
            }
        }
        let key = MIDIKey(kind: kind, channel: channel, number: number)
        return currentOwnerName(key)
    }

    private func save(andAddAnother: Bool) {
        error = nil
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? defaultName : trimmed

        var song = editingSong ?? Song(name: finalName, subtitle: subtitle.isEmpty ? nil : subtitle, cc: 0, channel: channel)
        song.name = finalName
        song.subtitle = subtitle.isEmpty ? nil : subtitle
        song.kind = kind
        song.channel = channel
        song.velocity = velocity
        song.colorHex = colorHex
        song.midiEnabled = midiEnabled

        // Set cc or note based on kind
        if kind == .note {
            song.note = number
            song.cc = 0  // Reset cc when using note
        } else {
            song.cc = number
            song.note = nil  // Reset note when using cc
        }

        onSave(song, andAddAnother)

        // Clear the draft tracking since we saved
        lastEditingSongID = nil

        if andAddAnother {
            debugPrint("➕ [CUE] Save & Add Another clicked")
            // CRITICAL FIX: Clear editingSong BEFORE calling autoAssignMIDI
            // This ensures the MIDI we just assigned is now considered "taken"
            let savedName = song.name
            editingSong = nil

            // Calculate next channel and number
            debugPrint("  🔢 [CUE] Calculating next free number (ignoring previously saved '\(savedName)')")
            let nextChannel = isGlobalChannel ? globalChannel : 1
            let savedKind = kind

            // Reset all form fields to defaults
            name = ""
            subtitle = ""
            colorHex = nil
            // v1.0.8: Preserve MIDI kind (CC vs Note) for "Add Another"
            // This ensures next cue uses same MIDI type as the one just saved
            kind = savedKind
            velocity = 127
            autoAssign = true
            error = nil

            // Find lowest available number (starting from 0 to fill gaps)
            // Uses savedKind to find next available CC or Note number
            let result = autoAssignMIDI(for: savedKind, startChannel: nextChannel, startNumber: 0)
            if result.reachedLimit {
                showGlobalModeMaxReachedAlert = true
                autoAssign = false
                channel = nextChannel
                number = 0
            } else {
                channel = result.channel
                number = result.number
                debugPrint("  ✅ [CUE] Set channel=\(result.channel), number=\(result.number)")
            }
        }
    }
}

struct CBMIDIPickerSheet: View {
    let title: String
    @State var kind: MIDIKind
    @State var number: Int
    @State var channel: Int
    @State var velocity: Int
    let conflictFor: [MIDIKey: String]
    var currentOwnerName: (MIDIKey) -> String?
    var onSave: (MIDIKind, Int, Int, Int) -> Void
    var onCancel: () -> Void
    var editingSongName: String? = nil  // Optional: name of song being edited to filter from conflicts

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        NavigationView {
            Form {
                Picker("Type", selection: $kind) {
                    Text("Control Change").tag(MIDIKind.cc)
                    Text("Note").tag(MIDIKind.note)
                }
                .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                Stepper(value: $number, in: 0...127) {
                    Text(kind == .cc ? "CC Number: \(number)" : "Note Number: \(number)")
                }
                .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                Stepper(value: $channel, in: 1...16) { Text("Channel: \(channel)") }
                    .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                if kind == .note {
                    Stepper(value: $velocity, in: 1...127) { Text("Velocity: \(velocity)") }
                        .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                }
                if let owner = conflictOwner() {
                    Text("⚠️ MIDI taken by: \(owner)").foregroundColor(selectedTheme.warningColor(for: colorScheme))
                        .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                }
            }
            .scrollContentBackground(.hidden)
            .background(selectedTheme.backgroundColor(for: colorScheme))
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .foregroundColor(Color(hex: "0A84FF"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(kind, number, channel, velocity) }
                        .foregroundColor(Color(hex: "0A84FF"))
                        .disabled(conflictOwner() != nil)
                }
            }
            .tint(selectedTheme.defaultCueColor(for: colorScheme))
        }
        .preferredColorScheme(selectedTheme.preferredColorScheme(for: colorScheme))
    }

    private func conflictOwner() -> String? {
        let key = MIDIKey(kind: kind, channel: channel, number: number)
        guard let ownersString = currentOwnerName(key) else {
            debugPrint("🔍 [MIDI PICKER] No owner found for key")
            return nil
        }

        debugPrint("🔍 [MIDI PICKER] ownersString='\(ownersString)', editingSongName='\(editingSongName ?? "nil")'")

        // Filter out the editing song's name if provided
        guard let editingName = editingSongName else {
            debugPrint("❌ [MIDI PICKER] No editingSongName provided, returning ownersString")
            return ownersString
        }

        // Trim whitespace for comparison
        let trimmedEditingName = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOwnersString = ownersString.trimmingCharacters(in: .whitespacesAndNewlines)

        debugPrint("🔍 [MIDI PICKER] Comparing: trimmedOwners='\(trimmedOwnersString)' vs trimmedEditingName='\(trimmedEditingName)'")
        debugPrint("🔍 [MIDI PICKER] Are they equal? \(trimmedOwnersString == trimmedEditingName)")

        // Check if the owners string contains the separator (multiple owners)
        if ownersString.contains("|||") {
            debugPrint("🔍 [MIDI PICKER] Multiple owners detected")
            // Multiple owners - split and filter
            let owners = ownersString.split(separator: "|||")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0 != trimmedEditingName }
            guard !owners.isEmpty else {
                debugPrint("✅ [MIDI PICKER] All owners filtered, returning nil")
                return nil
            }
            debugPrint("⚠️ [MIDI PICKER] Remaining owners: \(owners)")
            if owners.count == 1 {
                return owners[0]
            } else if owners.count == 2 {
                return "\(owners[0]) and \(owners[1])"
            } else {
                return owners.dropLast().joined(separator: ", ") + ", and " + owners.last!
            }
        } else if trimmedOwnersString == trimmedEditingName {
            // Single owner and it's the editing song
            debugPrint("✅ [MIDI PICKER] Single owner matches editing song, returning nil")
            return nil
        }

        debugPrint("❌ [MIDI PICKER] No match, returning ownersString: '\(ownersString)'")
        return ownersString
    }
}

// MARK: - Drop Delegate for reordering without edit mode
struct ReorderDropDelegate: DropDelegate {
    let song: Song
    let songs: [Song]
    @Binding var draggedSong: Song?
    let onMove: (Int, Int) -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        // Provide visual feedback by triggering layout updates
        guard let draggedSong = draggedSong,
              let fromIndex = songs.firstIndex(where: { $0.id == draggedSong.id }),
              let toIndex = songs.firstIndex(where: { $0.id == song.id }),
              fromIndex != toIndex else {
            return
        }

        // Call onMove to provide real-time visual feedback as user drags
        // This makes the list reorder dynamically during the drag
        // Use a snappier spring animation for better responsiveness
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85, blendDuration: 0.1)) {
            onMove(fromIndex, toIndex)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        // Clear the dragged song reference
        self.draggedSong = nil
        // Return true to indicate drop was handled
        // Note: The actual reordering already happened in dropEntered()
        return true
    }
}

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

