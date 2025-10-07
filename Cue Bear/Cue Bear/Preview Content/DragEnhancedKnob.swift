//
//  DragEnhancedKnob.swift - Preview Only
//  Cue Bear
//
//  EXPERIMENTAL: Drag-enhanced knob controller
//  Based on PRD: Tap + drag in any direction to adjust parameter
//  Lives in Preview Content so it's excluded from production builds
//

import SwiftUI

// MARK: - Drag-Enhanced Knob Controller
/// A knob that uses distance-based drag (not circular rotation) for intuitive touchscreen control
struct DragEnhancedKnob: View {
    // Configuration
    let title: String
    let cc: Int
    let channel: Int
    let minValue: Int
    let maxValue: Int
    let defaultValue: Int
    let sensitivity: CGFloat  // Distance in points needed to change by 1 unit
    let dragMode: DragMode

    // State
    @State private var currentValue: Int
    @State private var isDragging: Bool = false
    @State private var dragStartPosition: CGPoint = .zero
    @State private var smoothedValue: CGFloat = 0.0  // Smooth floating point value

    enum DragMode {
        case anyDirection  // Drag in any direction (uses distance from origin)
        case vertical      // Up/down only
        case horizontal    // Left/right only
    }

    init(
        title: String,
        cc: Int,
        channel: Int,
        minValue: Int = 0,
        maxValue: Int = 127,
        defaultValue: Int = 0,  // Changed to 0
        sensitivity: CGFloat = 1.5,  // Adjusted for better feel
        dragMode: DragMode = .anyDirection
    ) {
        self.title = title
        self.cc = cc
        self.channel = channel
        self.minValue = minValue
        self.maxValue = maxValue
        self.defaultValue = defaultValue
        self.sensitivity = sensitivity
        self.dragMode = dragMode
        self._currentValue = State(initialValue: defaultValue)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Value display above knob
            Text("\(currentValue)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(isDragging ? .accentColor : .primary)
                .frame(height: 24)

            // Knob graphic
            ZStack {
                // Outer ring - shows full range
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                    .frame(width: 100, height: 100)

                // Value arc - shows current value as partial circle
                Circle()
                    .trim(from: 0, to: normalizedValue)
                    .stroke(
                        isDragging ? Color.accentColor : Color.accentColor.opacity(0.8),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90)) // Start from top
                    // No animation during drag to prevent jitter
                    .animation(isDragging ? nil : .easeOut(duration: 0.1), value: currentValue)

                // Inner knob body
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                isDragging ? Color(UIColor.systemGray4) : Color(UIColor.systemGray5),
                                isDragging ? Color(UIColor.systemGray2) : Color(UIColor.systemGray3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                    .overlay(
                        // Indicator line showing current position
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: 3, height: 25)
                            .offset(y: -22.5)
                            .rotationEffect(.degrees(rotationAngle))
                    )
                    .shadow(color: isDragging ? .accentColor.opacity(0.3) : .black.opacity(0.2), radius: isDragging ? 8 : 4, x: 0, y: 2)

                // Active state glow
                if isDragging {
                    Circle()
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 12)
                        .frame(width: 110, height: 110)
                        .blur(radius: 6)
                }
            }
            // CUTE POP ANIMATION - scales up when touched, sticks to finger
            .scaleEffect(isDragging ? 1.15 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDragging)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            // Start of drag - reset to 0 and record initial position
                            isDragging = true
                            dragStartPosition = value.startLocation
                            smoothedValue = 0.0
                            currentValue = 0  // Always start at 0
                        }

                        // Calculate distance from initial tap position (magnitude of vector)
                        let dx = value.location.x - dragStartPosition.x
                        let dy = value.location.y - dragStartPosition.y
                        let distance = sqrt(dx * dx + dy * dy)

                        // Calculate raw value from distance
                        let rawValue = distance / sensitivity

                        // Apply exponential smoothing to reduce jitter
                        // Higher smoothing factor = smoother but less responsive
                        let smoothingFactor: CGFloat = 0.3
                        smoothedValue = smoothedValue + smoothingFactor * (rawValue - smoothedValue)

                        // Convert to integer with proper clamping
                        let newValue = clamp(Int(smoothedValue.rounded()))

                        // Only update if value actually changed (reduces update frequency)
                        if newValue != currentValue {
                            currentValue = newValue
                            // In real implementation, send MIDI here:
                            // sendMIDI(channel: channel, cc: cc, value: currentValue)
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .simultaneousGesture(
                // Double-tap to reset to default
                TapGesture(count: 2)
                    .onEnded {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            currentValue = defaultValue
                        }
                    }
            )

            // Title and MIDI info
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primary)

                Text("\(channel)•\(cc)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Helpers

    /// Normalized value (0.0 to 1.0) for visual feedback
    private var normalizedValue: CGFloat {
        CGFloat(currentValue - minValue) / CGFloat(maxValue - minValue)
    }

    /// Rotation angle in degrees (0° to 270°, with 45° dead zone at bottom)
    private var rotationAngle: Double {
        let range = 270.0  // 270 degrees of rotation (leaving 90° gap at bottom)
        let startAngle = -135.0  // Start at bottom-left
        return startAngle + (Double(normalizedValue) * range)
    }

    /// Clamp value to min/max range
    private func clamp(_ value: Int) -> Int {
        max(minValue, min(maxValue, value))
    }
}

// MARK: - Grid-Sized Drag Knob (1x1 tile)
struct GridDragKnob: View {
    let title: String
    let cc: Int
    let channel: Int
    let minValue: Int
    let maxValue: Int
    let defaultValue: Int
    let sensitivity: CGFloat

    @State private var currentValue: Int
    @State private var isDragging: Bool = false
    @State private var dragStartPosition: CGPoint = .zero
    @State private var smoothedValue: CGFloat = 0.0  // Smooth floating point value

    init(
        title: String,
        cc: Int,
        channel: Int,
        minValue: Int = 0,
        maxValue: Int = 127,
        defaultValue: Int = 0,  // Changed to 0
        sensitivity: CGFloat = 2.0
    ) {
        self.title = title
        self.cc = cc
        self.channel = channel
        self.minValue = minValue
        self.maxValue = maxValue
        self.defaultValue = defaultValue
        self.sensitivity = sensitivity
        self._currentValue = State(initialValue: defaultValue)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 4) {
                // Compact value display
                Text("\(currentValue)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(isDragging ? .accentColor : .primary)

                // Compact knob
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 4)

                    Circle()
                        .trim(from: 0, to: normalizedValue)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    Circle()
                        .fill(Color(UIColor.systemGray5))
                        .frame(width: geometry.size.width * 0.5, height: geometry.size.width * 0.5)
                        .overlay(
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(width: 2, height: geometry.size.width * 0.2)
                                .offset(y: -geometry.size.width * 0.15)
                                .rotationEffect(.degrees(rotationAngle))
                        )
                }
                // CUTE POP ANIMATION - scales up when touched, sticks to finger
                .scaleEffect(isDragging ? 1.15 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDragging)
                .padding(8)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                // Start of drag - reset to 0 and record initial position
                                isDragging = true
                                dragStartPosition = value.startLocation
                                smoothedValue = 0.0
                                currentValue = 0  // Always start at 0
                            }

                            // Calculate distance from initial tap position (magnitude of vector)
                            let dx = value.location.x - dragStartPosition.x
                            let dy = value.location.y - dragStartPosition.y
                            let distance = sqrt(dx * dx + dy * dy)

                            // Calculate raw value from distance
                            let rawValue = distance / sensitivity

                            // Apply exponential smoothing to reduce jitter
                            // Higher smoothing factor = smoother but less responsive
                            let smoothingFactor: CGFloat = 0.3
                            smoothedValue = smoothedValue + smoothingFactor * (rawValue - smoothedValue)

                            // Convert to integer with proper clamping
                            let newValue = clamp(Int(smoothedValue.rounded()))

                            // Only update if value actually changed (reduces update frequency)
                            if newValue != currentValue {
                                currentValue = newValue
                                // In real implementation, send MIDI here:
                                // sendMIDI(channel: channel, cc: cc, value: currentValue)
                            }
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
                .simultaneousGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                currentValue = defaultValue
                            }
                        }
                )

                // Title and MIDI
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)

                Text("\(channel)•\(cc)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(6)
        }
    }

    private var normalizedValue: CGFloat {
        CGFloat(currentValue - minValue) / CGFloat(maxValue - minValue)
    }

    private var rotationAngle: Double {
        let range = 270.0
        let startAngle = -135.0
        return startAngle + (Double(normalizedValue) * range)
    }

    private func clamp(_ value: Int) -> Int {
        max(minValue, min(maxValue, value))
    }
}

// MARK: - Grid Preview with Drag Knobs
struct GridWithDragKnobsPreview: View {
    let columns: Int = 8
    let gridPadding: CGFloat = 16
    let columnSpacing: CGFloat = 8
    let rowSpacing: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            let totalSpacing = CGFloat(columns - 1) * columnSpacing
            let availableWidth = geometry.size.width - (2 * gridPadding) - totalSpacing
            let cellSize = floor(availableWidth / CGFloat(columns))

            VStack(spacing: 16) {
                Text("Drag-Enhanced Knob in Grid")
                    .font(.headline)
                    .padding(.top)

                Text("Drag up/down to adjust • Double-tap to reset")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Grid with knobs
                ZStack(alignment: .topLeading) {
                    // Grid background
                    Rectangle()
                        .fill(Color(UIColor.systemGray6).opacity(0.3))
                        .frame(height: cellSize * 2 + rowSpacing)

                    // Row 1: 8 knobs (Filter, Resonance, Attack, Decay, Sustain, Release, Volume, Pan)
                    HStack(spacing: columnSpacing) {
                        GridDragKnob(title: "Cutoff", cc: 74, channel: 1)
                            .frame(width: cellSize, height: cellSize)

                        GridDragKnob(title: "Res", cc: 71, channel: 1)
                            .frame(width: cellSize, height: cellSize)

                        GridDragKnob(title: "Attack", cc: 73, channel: 1)
                            .frame(width: cellSize, height: cellSize)

                        GridDragKnob(title: "Decay", cc: 75, channel: 1)
                            .frame(width: cellSize, height: cellSize)

                        GridDragKnob(title: "Sustain", cc: 79, channel: 1)
                            .frame(width: cellSize, height: cellSize)

                        GridDragKnob(title: "Release", cc: 72, channel: 1)
                            .frame(width: cellSize, height: cellSize)

                        GridDragKnob(title: "Volume", cc: 7, channel: 1)
                            .frame(width: cellSize, height: cellSize)

                        GridDragKnob(title: "Pan", cc: 10, channel: 1)
                            .frame(width: cellSize, height: cellSize)
                    }
                    .padding(gridPadding)

                    // Row 2: 8 more knobs for additional parameters
                    HStack(spacing: columnSpacing) {
                        GridDragKnob(title: "Reverb", cc: 91, channel: 1)
                            .frame(width: cellSize, height: cellSize)

                        GridDragKnob(title: "Delay", cc: 92, channel: 1)
                            .frame(width: cellSize, height: cellSize)

                        GridDragKnob(title: "Chorus", cc: 93, channel: 1)
                            .frame(width: cellSize, height: cellSize)

                        GridDragKnob(title: "Drive", cc: 94, channel: 1)
                            .frame(width: cellSize, height: cellSize)

                        GridDragKnob(title: "Rate", cc: 76, channel: 1)
                            .frame(width: cellSize, height: cellSize)

                        GridDragKnob(title: "Depth", cc: 77, channel: 1)
                            .frame(width: cellSize, height: cellSize)

                        GridDragKnob(title: "Feedback", cc: 78, channel: 1)
                            .frame(width: cellSize, height: cellSize)

                        GridDragKnob(title: "Mix", cc: 95, channel: 1)
                            .frame(width: cellSize, height: cellSize)
                    }
                    .padding(gridPadding)
                    .offset(y: cellSize + rowSpacing + gridPadding)
                }
                .padding(gridPadding)

                // Usage info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Features:")
                        .font(.caption.weight(.semibold))
                    Text("• Drag up to decrease, down to increase")
                    Text("• Smooth, predictable control")
                    Text("• Double-tap any knob to reset to 64")
                    Text("• Visual feedback: arc shows current value")
                    Text("• Works perfectly on touchscreen (no awkward circular motions)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)

                Spacer()
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - Full Control Area Preview with Drag Knobs
struct FullControlAreaWithDragKnobs: View {
    let columns = 8
    let spacing: CGFloat = 8

    // Calculate cell size based on common iPad width (landscape)
    var cellSize: CGFloat {
        let screenWidth: CGFloat = 1024 - 40  // iPad landscape minus padding
        return (screenWidth - (CGFloat(columns - 1) * spacing)) / CGFloat(columns)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Full Control Area with Drag Knobs")
                    .font(.title2.weight(.bold))

                Text("8-column grid showing drag knobs alongside existing controls")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ZStack {
                    // Grid dots overlay (like edit mode)
                    Canvas { context, size in
                        let rows = 8
                        for row in 0...rows {
                            for col in 0...columns {
                                let x = CGFloat(col) * (cellSize + spacing)
                                let y = CGFloat(row) * (cellSize + spacing)
                                let rect = CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)
                                context.fill(
                                    Path(ellipseIn: rect),
                                    with: .color(.gray.opacity(0.3))
                                )
                            }
                        }
                    }
                    .frame(
                        width: CGFloat(columns) * cellSize + CGFloat(columns - 1) * spacing,
                        height: 8 * cellSize + 7 * spacing
                    )

                    // Grid content
                    VStack(spacing: spacing) {
                        // Row 1: Transport buttons
                        HStack(spacing: spacing) {
                            MockGridButton(title: "Play", color: .green, cellSize: cellSize, columns: 2, rows: 1)
                            MockGridButton(title: "Stop", color: .red, cellSize: cellSize, columns: 2, rows: 1)
                            MockGridButton(title: "Record", color: .red, cellSize: cellSize, columns: 2, rows: 1)
                            MockGridButton(title: "Loop", color: .orange, cellSize: cellSize, columns: 2, rows: 1)
                        }

                        // Row 2: Drag knobs row 1 (Synth parameters)
                        HStack(spacing: spacing) {
                            GridDragKnob(title: "Cutoff", cc: 74, channel: 1)
                                .frame(width: cellSize, height: cellSize)
                            GridDragKnob(title: "Res", cc: 71, channel: 1)
                                .frame(width: cellSize, height: cellSize)
                            GridDragKnob(title: "Attack", cc: 73, channel: 1)
                                .frame(width: cellSize, height: cellSize)
                            GridDragKnob(title: "Decay", cc: 75, channel: 1)
                                .frame(width: cellSize, height: cellSize)
                            GridDragKnob(title: "Sustain", cc: 79, channel: 1)
                                .frame(width: cellSize, height: cellSize)
                            GridDragKnob(title: "Release", cc: 72, channel: 1)
                                .frame(width: cellSize, height: cellSize)
                            GridDragKnob(title: "Volume", cc: 7, channel: 1)
                                .frame(width: cellSize, height: cellSize)
                            GridDragKnob(title: "Pan", cc: 10, channel: 1)
                                .frame(width: cellSize, height: cellSize)
                        }

                        // Row 3: Drag knobs row 2 (FX parameters)
                        HStack(spacing: spacing) {
                            GridDragKnob(title: "Reverb", cc: 91, channel: 1)
                                .frame(width: cellSize, height: cellSize)
                            GridDragKnob(title: "Delay", cc: 92, channel: 1)
                                .frame(width: cellSize, height: cellSize)
                            GridDragKnob(title: "Chorus", cc: 93, channel: 1)
                                .frame(width: cellSize, height: cellSize)
                            GridDragKnob(title: "Drive", cc: 94, channel: 1)
                                .frame(width: cellSize, height: cellSize)
                            GridDragKnob(title: "Rate", cc: 76, channel: 1)
                                .frame(width: cellSize, height: cellSize)
                            GridDragKnob(title: "Depth", cc: 77, channel: 1)
                                .frame(width: cellSize, height: cellSize)
                            GridDragKnob(title: "Mix", cc: 95, channel: 1)
                                .frame(width: cellSize, height: cellSize)
                            GridDragKnob(title: "FB", cc: 78, channel: 1)
                                .frame(width: cellSize, height: cellSize)
                        }

                        // Row 4-6: Faders (1x3 vertical) alongside drag knobs
                        HStack(alignment: .top, spacing: spacing) {
                            // 4 Faders
                            MockGridFader(title: "Vol 1", cellSize: cellSize)
                            MockGridFader(title: "Vol 2", cellSize: cellSize)
                            MockGridFader(title: "Vol 3", cellSize: cellSize)
                            MockGridFader(title: "Vol 4", cellSize: cellSize)

                            // Additional drag knobs on the side
                            VStack(spacing: spacing) {
                                GridDragKnob(title: "LFO 1", cc: 80, channel: 1)
                                    .frame(width: cellSize, height: cellSize)
                                GridDragKnob(title: "LFO 2", cc: 81, channel: 1)
                                    .frame(width: cellSize, height: cellSize)
                                GridDragKnob(title: "Mod", cc: 1, channel: 1)
                                    .frame(width: cellSize, height: cellSize)
                            }

                            VStack(spacing: spacing) {
                                GridDragKnob(title: "Exp", cc: 11, channel: 1)
                                    .frame(width: cellSize, height: cellSize)
                                GridDragKnob(title: "Env", cc: 82, channel: 1)
                                    .frame(width: cellSize, height: cellSize)
                                GridDragKnob(title: "VCA", cc: 83, channel: 1)
                                    .frame(width: cellSize, height: cellSize)
                            }

                            // Mock buttons in remaining columns
                            VStack(spacing: spacing) {
                                MockGridButton(title: "Mute 1", color: .yellow, cellSize: cellSize, columns: 1, rows: 1)
                                MockGridButton(title: "Solo 1", color: .blue, cellSize: cellSize, columns: 1, rows: 1)
                                MockGridButton(title: "Arm 1", color: .red, cellSize: cellSize, columns: 1, rows: 1)
                            }

                            VStack(spacing: spacing) {
                                MockGridButton(title: "Mute 2", color: .yellow, cellSize: cellSize, columns: 1, rows: 1)
                                MockGridButton(title: "Solo 2", color: .blue, cellSize: cellSize, columns: 1, rows: 1)
                                MockGridButton(title: "Arm 2", color: .red, cellSize: cellSize, columns: 1, rows: 1)
                            }
                        }

                        // Row 7: Scene buttons
                        HStack(spacing: spacing) {
                            MockGridButton(title: "Scene 1", color: .purple, cellSize: cellSize, columns: 2, rows: 1)
                            MockGridButton(title: "Scene 2", color: .purple, cellSize: cellSize, columns: 2, rows: 1)
                            MockGridButton(title: "Scene 3", color: .purple, cellSize: cellSize, columns: 2, rows: 1)
                            MockGridButton(title: "Scene 4", color: .purple, cellSize: cellSize, columns: 2, rows: 1)
                        }

                        // Row 8: More drag knobs (Master controls)
                        HStack(spacing: spacing) {
                            GridDragKnob(title: "Master", cc: 7, channel: 2, defaultValue: 100)
                                .frame(width: cellSize, height: cellSize)
                            GridDragKnob(title: "Tempo", cc: 84, channel: 1, minValue: 60, maxValue: 180, defaultValue: 120)
                                .frame(width: cellSize, height: cellSize)
                            GridDragKnob(title: "Swing", cc: 85, channel: 1)
                                .frame(width: cellSize, height: cellSize)
                            GridDragKnob(title: "Gate", cc: 86, channel: 1)
                                .frame(width: cellSize, height: cellSize)

                            MockGridButton(title: "Tap", color: .cyan, cellSize: cellSize, columns: 1, rows: 1)
                            MockGridButton(title: "Sync", color: .cyan, cellSize: cellSize, columns: 1, rows: 1)
                            MockGridButton(title: "Reset", color: .orange, cellSize: cellSize, columns: 1, rows: 1)
                            MockGridButton(title: "Save", color: .green, cellSize: cellSize, columns: 1, rows: 1)
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(16)

                // Legend
                VStack(alignment: .leading, spacing: 8) {
                    Text("Features:")
                        .font(.caption.weight(.semibold))
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Circular knobs = Drag knobs with pop animation")
                            Text("• Drag up/down to adjust values")
                            Text("• Double-tap any knob to reset")
                            Text("• Visual arc shows current value")
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Colored boxes = Mock buttons (Play, Stop, etc.)")
                            Text("• Vertical bars = Mock faders (1x3)")
                            Text("• Gray dots = Grid alignment overlay")
                            Text("• 8-column responsive grid layout")
                        }
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)

                Text("Drag knobs integrate seamlessly with buttons and faders in the grid system")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - Edit Mode Grid Preview
struct EditModeGridPreview: View {
    let columns = 8
    let spacing: CGFloat = 8
    @State private var isEditMode: Bool = true
    @State private var wobbleAnimation: Bool = false

    // Calculate cell size based on common iPad width
    var cellSize: CGFloat {
        let screenWidth: CGFloat = 1024 - 40
        return (screenWidth - (CGFloat(columns - 1) * spacing)) / CGFloat(columns)
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with edit mode controls
                HStack {
                    Text(isEditMode ? "Edit Control Layout" : "Control Area")
                        .font(.title2.weight(.bold))

                    Spacer()

                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isEditMode.toggle()
                            if isEditMode {
                                wobbleAnimation = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    wobbleAnimation = false
                                }
                            }
                        }
                    }) {
                        Text(isEditMode ? "Done" : "Edit")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(isEditMode ? Color.green : Color.accentColor)
                            .cornerRadius(20)
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))

                ScrollView {
                    VStack(spacing: 16) {
                        // Edit mode instructions
                        if isEditMode {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.accentColor)
                                Text("Tap and hold to drag controls around the grid. Tap the + button to add new controls.")
                                    .font(.caption)
                            }
                            .padding()
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }

                        // Grid with controls
                        ZStack(alignment: .topLeading) {
                            // Grid dots overlay (visible in edit mode)
                            if isEditMode {
                                Canvas { context, size in
                                    let rows = 12
                                    for row in 0...rows {
                                        for col in 0...columns {
                                            let x = CGFloat(col) * (cellSize + spacing)
                                            let y = CGFloat(row) * (cellSize + spacing)
                                            let rect = CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)
                                            context.fill(
                                                Path(ellipseIn: rect),
                                                with: .color(.gray.opacity(0.4))
                                            )
                                        }
                                    }
                                }
                                .frame(
                                    width: CGFloat(columns) * cellSize + CGFloat(columns - 1) * spacing,
                                    height: 12 * cellSize + 11 * spacing
                                )
                            }

                            // Grid content
                            VStack(spacing: spacing) {
                                // Row 1-2: Drag knobs (Synth controls)
                                VStack(spacing: spacing) {
                                    HStack(spacing: spacing) {
                                        ForEach(0..<8) { index in
                                            GridDragKnob(
                                                title: ["Cutoff", "Res", "Attack", "Decay", "Sustain", "Release", "Volume", "Pan"][index],
                                                cc: [74, 71, 73, 75, 79, 72, 7, 10][index],
                                                channel: 1
                                            )
                                            .frame(width: cellSize, height: cellSize)
                                            .rotationEffect(wobbleAnimation ? .degrees(Double.random(in: -2...2)) : .degrees(0))
                                            .animation(wobbleAnimation ? .spring(response: 0.15, dampingFraction: 0.3).repeatCount(3) : .default, value: wobbleAnimation)
                                        }
                                    }

                                    HStack(spacing: spacing) {
                                        ForEach(0..<8) { index in
                                            GridDragKnob(
                                                title: ["Reverb", "Delay", "Chorus", "Drive", "Rate", "Depth", "Mix", "FB"][index],
                                                cc: [91, 92, 93, 94, 76, 77, 95, 78][index],
                                                channel: 1
                                            )
                                            .frame(width: cellSize, height: cellSize)
                                            .rotationEffect(wobbleAnimation ? .degrees(Double.random(in: -2...2)) : .degrees(0))
                                            .animation(wobbleAnimation ? .spring(response: 0.15, dampingFraction: 0.3).repeatCount(3) : .default, value: wobbleAnimation)
                                        }
                                    }
                                }

                                // Row 3: Mix of buttons and knobs
                                HStack(spacing: spacing) {
                                    MockGridButton(title: "Play", color: .green, cellSize: cellSize, columns: 1, rows: 1)
                                        .rotationEffect(wobbleAnimation ? .degrees(Double.random(in: -2...2)) : .degrees(0))
                                        .animation(wobbleAnimation ? .spring(response: 0.15, dampingFraction: 0.3).repeatCount(3) : .default, value: wobbleAnimation)

                                    MockGridButton(title: "Stop", color: .red, cellSize: cellSize, columns: 1, rows: 1)
                                        .rotationEffect(wobbleAnimation ? .degrees(Double.random(in: -2...2)) : .degrees(0))
                                        .animation(wobbleAnimation ? .spring(response: 0.15, dampingFraction: 0.3).repeatCount(3) : .default, value: wobbleAnimation)

                                    GridDragKnob(title: "LFO 1", cc: 80, channel: 1)
                                        .frame(width: cellSize, height: cellSize)
                                        .rotationEffect(wobbleAnimation ? .degrees(Double.random(in: -2...2)) : .degrees(0))
                                        .animation(wobbleAnimation ? .spring(response: 0.15, dampingFraction: 0.3).repeatCount(3) : .default, value: wobbleAnimation)

                                    GridDragKnob(title: "LFO 2", cc: 81, channel: 1)
                                        .frame(width: cellSize, height: cellSize)
                                        .rotationEffect(wobbleAnimation ? .degrees(Double.random(in: -2...2)) : .degrees(0))
                                        .animation(wobbleAnimation ? .spring(response: 0.15, dampingFraction: 0.3).repeatCount(3) : .default, value: wobbleAnimation)

                                    MockGridButton(title: "Record", color: .red, cellSize: cellSize, columns: 1, rows: 1)
                                        .rotationEffect(wobbleAnimation ? .degrees(Double.random(in: -2...2)) : .degrees(0))
                                        .animation(wobbleAnimation ? .spring(response: 0.15, dampingFraction: 0.3).repeatCount(3) : .default, value: wobbleAnimation)

                                    MockGridButton(title: "Loop", color: .orange, cellSize: cellSize, columns: 1, rows: 1)
                                        .rotationEffect(wobbleAnimation ? .degrees(Double.random(in: -2...2)) : .degrees(0))
                                        .animation(wobbleAnimation ? .spring(response: 0.15, dampingFraction: 0.3).repeatCount(3) : .default, value: wobbleAnimation)

                                    GridDragKnob(title: "Mod", cc: 1, channel: 1)
                                        .frame(width: cellSize, height: cellSize)
                                        .rotationEffect(wobbleAnimation ? .degrees(Double.random(in: -2...2)) : .degrees(0))
                                        .animation(wobbleAnimation ? .spring(response: 0.15, dampingFraction: 0.3).repeatCount(3) : .default, value: wobbleAnimation)

                                    GridDragKnob(title: "Exp", cc: 11, channel: 1)
                                        .frame(width: cellSize, height: cellSize)
                                        .rotationEffect(wobbleAnimation ? .degrees(Double.random(in: -2...2)) : .degrees(0))
                                        .animation(wobbleAnimation ? .spring(response: 0.15, dampingFraction: 0.3).repeatCount(3) : .default, value: wobbleAnimation)
                                }

                                // Row 4: More knobs
                                HStack(spacing: spacing) {
                                    GridDragKnob(title: "Env", cc: 82, channel: 1)
                                        .frame(width: cellSize, height: cellSize)
                                        .rotationEffect(wobbleAnimation ? .degrees(Double.random(in: -2...2)) : .degrees(0))
                                        .animation(wobbleAnimation ? .spring(response: 0.15, dampingFraction: 0.3).repeatCount(3) : .default, value: wobbleAnimation)

                                    GridDragKnob(title: "VCA", cc: 83, channel: 1)
                                        .frame(width: cellSize, height: cellSize)
                                        .rotationEffect(wobbleAnimation ? .degrees(Double.random(in: -2...2)) : .degrees(0))
                                        .animation(wobbleAnimation ? .spring(response: 0.15, dampingFraction: 0.3).repeatCount(3) : .default, value: wobbleAnimation)

                                    MockGridButton(title: "Mute", color: .yellow, cellSize: cellSize, columns: 1, rows: 1)
                                        .rotationEffect(wobbleAnimation ? .degrees(Double.random(in: -2...2)) : .degrees(0))
                                        .animation(wobbleAnimation ? .spring(response: 0.15, dampingFraction: 0.3).repeatCount(3) : .default, value: wobbleAnimation)

                                    MockGridButton(title: "Solo", color: .blue, cellSize: cellSize, columns: 1, rows: 1)
                                        .rotationEffect(wobbleAnimation ? .degrees(Double.random(in: -2...2)) : .degrees(0))
                                        .animation(wobbleAnimation ? .spring(response: 0.15, dampingFraction: 0.3).repeatCount(3) : .default, value: wobbleAnimation)

                                    GridDragKnob(title: "Master", cc: 7, channel: 2)
                                        .frame(width: cellSize, height: cellSize)
                                        .rotationEffect(wobbleAnimation ? .degrees(Double.random(in: -2...2)) : .degrees(0))
                                        .animation(wobbleAnimation ? .spring(response: 0.15, dampingFraction: 0.3).repeatCount(3) : .default, value: wobbleAnimation)

                                    GridDragKnob(title: "Tempo", cc: 84, channel: 1)
                                        .frame(width: cellSize, height: cellSize)
                                        .rotationEffect(wobbleAnimation ? .degrees(Double.random(in: -2...2)) : .degrees(0))
                                        .animation(wobbleAnimation ? .spring(response: 0.15, dampingFraction: 0.3).repeatCount(3) : .default, value: wobbleAnimation)

                                    MockGridButton(title: "Scene 1", color: .purple, cellSize: cellSize, columns: 1, rows: 1)
                                        .rotationEffect(wobbleAnimation ? .degrees(Double.random(in: -2...2)) : .degrees(0))
                                        .animation(wobbleAnimation ? .spring(response: 0.15, dampingFraction: 0.3).repeatCount(3) : .default, value: wobbleAnimation)

                                    MockGridButton(title: "Scene 2", color: .purple, cellSize: cellSize, columns: 1, rows: 1)
                                        .rotationEffect(wobbleAnimation ? .degrees(Double.random(in: -2...2)) : .degrees(0))
                                        .animation(wobbleAnimation ? .spring(response: 0.15, dampingFraction: 0.3).repeatCount(3) : .default, value: wobbleAnimation)
                                }
                            }
                        }
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)

                        // Add control button (visible in edit mode)
                        if isEditMode {
                            Button(action: {}) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                    Text("Add Control")
                                        .font(.body.weight(.semibold))
                                }
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.accentColor)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }

                        // Info
                        VStack(alignment: .leading, spacing: 8) {
                            Text(isEditMode ? "Edit Mode Features:" : "Control Features:")
                                .font(.caption.weight(.semibold))
                            if isEditMode {
                                Text("• All controls wobble to indicate they're editable")
                                Text("• Grid dots show alignment points")
                                Text("• Drag controls to rearrange them")
                                Text("• Tap + to add new controls (knobs, buttons, faders)")
                            } else {
                                Text("• Drag knobs in any direction to adjust values")
                                Text("• Distance-based control with velocity sensitivity")
                                Text("• Double-tap any knob to reset to 0")
                                Text("• Visual arc and rotation show current value")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        Spacer(minLength: 20)
                    }
                }
            }
        }
    }
}

// MARK: - SwiftUI Previews
#Preview("Drag-Enhanced Knob (Large)") {
    VStack(spacing: 32) {
        Text("Drag-Enhanced Knob")
            .font(.title.weight(.bold))

        Text("Drag in any direction to adjust\nDouble-tap to reset")
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)

        DragEnhancedKnob(
            title: "Filter Cutoff",
            cc: 74,
            channel: 1,
            sensitivity: 2.0,
            dragMode: .anyDirection
        )
    }
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}

#Preview("Grid with Drag Knobs") {
    GridWithDragKnobsPreview()
}

#Preview("Drag Modes Comparison") {
    ScrollView {
        VStack(spacing: 32) {
            Text("Drag Mode Comparison")
                .font(.title.weight(.bold))
                .padding(.top)

            VStack(alignment: .leading, spacing: 16) {
                Text("Any Direction Mode")
                    .font(.headline)
                Text("Drag anywhere - vertical component determines change")
                    .font(.caption)
                    .foregroundColor(.secondary)

                DragEnhancedKnob(
                    title: "Filter",
                    cc: 74,
                    channel: 1,
                    sensitivity: 2.0,
                    dragMode: .anyDirection
                )
            }

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                Text("Vertical Only Mode")
                    .font(.headline)
                Text("Up/down drag only (best for touchscreen)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                DragEnhancedKnob(
                    title: "Volume",
                    cc: 7,
                    channel: 1,
                    sensitivity: 2.0,
                    dragMode: .vertical
                )
            }

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                Text("Horizontal Only Mode")
                    .font(.headline)
                Text("Left/right drag only")
                    .font(.caption)
                    .foregroundColor(.secondary)

                DragEnhancedKnob(
                    title: "Pan",
                    cc: 10,
                    channel: 1,
                    sensitivity: 2.0,
                    dragMode: .horizontal
                )
            }
        }
        .padding()
    }
    .background(Color(UIColor.systemGroupedBackground))
}

#Preview("Full Control Area with Drag Knobs") {
    FullControlAreaWithDragKnobs()
}

#Preview("Edit Mode Grid Preview") {
    EditModeGridPreview()
}
