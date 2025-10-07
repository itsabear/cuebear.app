//
//  ExperimentalController.swift - Preview Only
//  Cue Bear
//
//  EXPERIMENTAL: This file is for testing new controller ideas
//  Lives in Preview Content so it's excluded from production builds
//

import SwiftUI

// MARK: - Experimental XY Pad Controller
/// A 2D touchpad controller that sends two CC values (X and Y position)
struct ExperimentalXYPadController: View {
    let title: String
    let ccX: Int  // CC number for X axis
    let ccY: Int  // CC number for Y axis
    let channel: Int

    @State private var position: CGPoint = CGPoint(x: 0.5, y: 0.5) // Normalized 0-1
    @State private var isDragging: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.primary)

            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(UIColor.systemGray6))

                // Grid lines for visual reference
                Path { path in
                    // Vertical center line
                    path.move(to: CGPoint(x: 150, y: 0))
                    path.addLine(to: CGPoint(x: 150, y: 300))
                    // Horizontal center line
                    path.move(to: CGPoint(x: 0, y: 150))
                    path.addLine(to: CGPoint(x: 300, y: 150))
                }
                .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))

                // Touch indicator (crosshair)
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .position(
                        x: position.x * 300,
                        y: (1.0 - position.y) * 300  // Invert Y for natural touch behavior
                    )
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

                // Border
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isDragging ? Color.accentColor : Color.gray.opacity(0.5), lineWidth: 2)
            }
            .frame(width: 300, height: 300)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        // Normalize to 0-1 range
                        let normalizedX = max(0, min(1, value.location.x / 300))
                        let normalizedY = max(0, min(1, 1.0 - (value.location.y / 300))) // Invert Y
                        position = CGPoint(x: normalizedX, y: normalizedY)

                        // In real implementation, send MIDI here:
                        // sendMIDI(channel: channel, cc: ccX, value: Int(normalizedX * 127))
                        // sendMIDI(channel: channel, cc: ccY, value: Int(normalizedY * 127))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )

            // Value display
            HStack(spacing: 16) {
                Text("X: \(Int(position.x * 127))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Y: \(Int(position.y * 127))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // MIDI info
            Text("\(channel)•\(ccX)•\(ccY)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Experimental Encoder/Knob Controller
/// A rotary encoder-style controller with endless rotation
struct ExperimentalEncoderController: View {
    let title: String
    let cc: Int
    let channel: Int

    @State private var rotation: Double = 0.0  // Continuous rotation in degrees
    @State private var lastAngle: Double = 0.0
    @State private var currentValue: Int = 64  // MIDI value 0-127

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.primary)

            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 120, height: 120)

                // Value arc (shows current MIDI value as partial circle)
                Circle()
                    .trim(from: 0, to: CGFloat(currentValue) / 127.0)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90)) // Start from top

                // Center knob
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(UIColor.systemGray5), Color(UIColor.systemGray3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .overlay(
                        // Indicator line
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: 3, height: 30)
                            .offset(y: -25)
                    )
                    .rotationEffect(.degrees(rotation))
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Calculate angle from center
                        let vector = CGSize(
                            width: value.location.x - 60,
                            height: value.location.y - 60
                        )
                        let angle = atan2(vector.height, vector.width) * 180 / .pi

                        // Calculate delta rotation
                        var delta = angle - lastAngle
                        if delta > 180 { delta -= 360 }
                        if delta < -180 { delta += 360 }

                        rotation += delta
                        lastAngle = angle

                        // Update MIDI value (increment/decrement based on rotation)
                        let valueChange = Int(delta / 10) // Adjust sensitivity
                        currentValue = max(0, min(127, currentValue + valueChange))

                        // In real implementation, send MIDI here:
                        // sendMIDI(channel: channel, cc: cc, value: currentValue)
                    }
                    .onEnded { _ in
                        lastAngle = 0
                    }
            )

            // Value display
            Text("\(currentValue)")
                .font(.title2.weight(.bold))
                .foregroundColor(.primary)

            // MIDI info
            Text("\(channel)•\(cc)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Preview Container
struct ExperimentalControllersPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Text("Experimental Controllers")
                    .font(.title.weight(.bold))
                    .padding(.top)

                // XY Pad
                VStack(alignment: .leading, spacing: 8) {
                    Text("XY Pad Controller")
                        .font(.headline)
                    Text("2D touch surface - controls two CCs simultaneously (like filter cutoff + resonance)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ExperimentalXYPadController(
                        title: "Filter XY",
                        ccX: 74,  // Cutoff
                        ccY: 71,  // Resonance
                        channel: 1
                    )
                }

                Divider()

                // Encoder
                VStack(alignment: .leading, spacing: 8) {
                    Text("Encoder/Knob Controller")
                        .font(.headline)
                    Text("Rotary encoder - endless rotation with visual feedback")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ExperimentalEncoderController(
                        title: "Volume",
                        cc: 7,
                        channel: 1
                    )
                }

                Divider()

                // Ideas for more controllers
                VStack(alignment: .leading, spacing: 12) {
                    Text("Future Ideas")
                        .font(.headline)

                    Text("• Step Sequencer - 16 steps with toggles")
                    Text("• Drum Pad Grid - 4x4 velocity-sensitive pads")
                    Text("• Ribbon Controller - continuous horizontal strip")
                    Text("• Gesture Pad - recognizes swipe patterns")
                    Text("• EQ Controller - multi-band visual EQ")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - Grid-Sized Tile Versions
/// XY Pad sized for grid tiles (2x2 = 2 columns, 2 rows)
struct GridXYPadController: View {
    let title: String
    let ccX: Int
    let ccY: Int
    let channel: Int
    let cellSize: CGFloat

    @State private var position: CGPoint = CGPoint(x: 0.5, y: 0.5)
    @State private var isDragging: Bool = false

    var body: some View {
        let tileSize = cellSize * 2 - 8  // 2x2 grid minus spacing

        return VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.systemGray6))

                // Grid lines
                Path { path in
                    path.move(to: CGPoint(x: tileSize/2, y: 0))
                    path.addLine(to: CGPoint(x: tileSize/2, y: tileSize))
                    path.move(to: CGPoint(x: 0, y: tileSize/2))
                    path.addLine(to: CGPoint(x: tileSize, y: tileSize/2))
                }
                .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3]))

                // Touch indicator
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                    .position(
                        x: position.x * tileSize,
                        y: (1.0 - position.y) * tileSize
                    )

                RoundedRectangle(cornerRadius: 8)
                    .stroke(isDragging ? Color.accentColor : Color.gray.opacity(0.5), lineWidth: 1.5)
            }
            .frame(width: tileSize, height: tileSize)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let normalizedX = max(0, min(1, value.location.x / tileSize))
                        let normalizedY = max(0, min(1, 1.0 - (value.location.y / tileSize)))
                        position = CGPoint(x: normalizedX, y: normalizedY)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )

            Text("X:\(Int(position.x * 127)) Y:\(Int(position.y * 127))")
                .font(.system(size: 8))
                .foregroundColor(.secondary)
        }
    }
}

/// Encoder sized for grid tiles (1x1 = 1 column, 1 row)
struct GridEncoderController: View {
    let title: String
    let cc: Int
    let channel: Int
    let cellSize: CGFloat

    @State private var rotation: Double = 0.0
    @State private var lastAngle: Double = 0.0
    @State private var currentValue: Int = 64

    var body: some View {
        let tileSize = cellSize - 8  // 1x1 grid minus spacing
        let knobSize = tileSize * 0.6

        return VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                    .frame(width: knobSize, height: knobSize)

                Circle()
                    .trim(from: 0, to: CGFloat(currentValue) / 127.0)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: knobSize, height: knobSize)
                    .rotationEffect(.degrees(-90))

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(UIColor.systemGray5), Color(UIColor.systemGray3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: knobSize * 0.7, height: knobSize * 0.7)
                    .overlay(
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: 2, height: knobSize * 0.3)
                            .offset(y: -knobSize * 0.2)
                    )
                    .rotationEffect(.degrees(rotation))
            }
            .frame(width: tileSize, height: tileSize)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let center = tileSize / 2
                        let vector = CGSize(
                            width: value.location.x - center,
                            height: value.location.y - center
                        )
                        let angle = atan2(vector.height, vector.width) * 180 / .pi

                        var delta = angle - lastAngle
                        if delta > 180 { delta -= 360 }
                        if delta < -180 { delta += 360 }

                        rotation += delta
                        lastAngle = angle

                        let valueChange = Int(delta / 10)
                        currentValue = max(0, min(127, currentValue + valueChange))
                    }
                    .onEnded { _ in
                        lastAngle = 0
                    }
            )

            Text("\(currentValue)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Mock Grid Buttons
/// Mock button for grid preview (simulates existing Play, Stop, Record, etc.)
struct MockGridButton: View {
    let title: String
    let color: Color
    let cellSize: CGFloat
    let columns: Int
    let rows: Int

    var body: some View {
        let width = (cellSize * CGFloat(columns)) - 8
        let height = (cellSize * CGFloat(rows)) - 8

        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.2))

            RoundedRectangle(cornerRadius: 8)
                .stroke(color, lineWidth: 1.5)

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
        }
        .frame(width: width, height: height)
    }
}

/// Mock fader for grid preview
struct MockGridFader: View {
    let title: String
    let cellSize: CGFloat
    @State private var value: Double = 0.7

    var body: some View {
        let width = cellSize - 8
        let height = (cellSize * 3) - 8  // 1x3 grid

        return VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(UIColor.systemGray6))

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.accentColor)
                    .frame(height: (height - 20) * value)
            }
            .frame(width: width * 0.5, height: height - 20)

            Text("\(Int(value * 100))")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Grid Preview Environment
struct GridWithExperimentalControllersPreview: View {
    let columns = 8
    let spacing: CGFloat = 8

    // Calculate cell size based on common iPad width (landscape)
    var cellSize: CGFloat {
        let screenWidth: CGFloat = 1024 - 40  // iPad landscape minus padding
        return (screenWidth - (CGFloat(columns - 1) * spacing)) / CGFloat(columns)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Grid with Experimental Controllers")
                .font(.title2.weight(.bold))

            Text("8-column grid layout simulating the real control area")
                .font(.caption)
                .foregroundColor(.secondary)

            ZStack {
                // Grid dots overlay (like edit mode)
                Canvas { context, size in
                    let rows = 6
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
                    height: 6 * cellSize + 5 * spacing
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

                    // Row 2-3: Experimental XY Pad (2x2) + Faders
                    HStack(alignment: .top, spacing: spacing) {
                        GridXYPadController(
                            title: "Filter XY",
                            ccX: 74,
                            ccY: 71,
                            channel: 1,
                            cellSize: cellSize
                        )
                        .frame(width: cellSize * 2, height: cellSize * 2)

                        MockGridFader(title: "Vol 1", cellSize: cellSize)
                        MockGridFader(title: "Vol 2", cellSize: cellSize)
                        MockGridFader(title: "Vol 3", cellSize: cellSize)
                        MockGridFader(title: "Vol 4", cellSize: cellSize)

                        VStack(spacing: spacing) {
                            GridEncoderController(
                                title: "Filter",
                                cc: 74,
                                channel: 1,
                                cellSize: cellSize
                            )
                            GridEncoderController(
                                title: "Resonance",
                                cc: 71,
                                channel: 1,
                                cellSize: cellSize
                            )
                        }

                        VStack(spacing: spacing) {
                            GridEncoderController(
                                title: "Attack",
                                cc: 73,
                                channel: 1,
                                cellSize: cellSize
                            )
                            GridEncoderController(
                                title: "Release",
                                cc: 72,
                                channel: 1,
                                cellSize: cellSize
                            )
                        }
                    }

                    // Row 4: Additional faders
                    HStack(spacing: spacing) {
                        MockGridFader(title: "Pan 1", cellSize: cellSize)
                        MockGridFader(title: "Pan 2", cellSize: cellSize)
                        MockGridFader(title: "Pan 3", cellSize: cellSize)
                        MockGridFader(title: "Pan 4", cellSize: cellSize)

                        MockGridButton(title: "Mute 1", color: .yellow, cellSize: cellSize, columns: 1, rows: 1)
                        MockGridButton(title: "Mute 2", color: .yellow, cellSize: cellSize, columns: 1, rows: 1)
                        MockGridButton(title: "Mute 3", color: .yellow, cellSize: cellSize, columns: 1, rows: 1)
                        MockGridButton(title: "Mute 4", color: .yellow, cellSize: cellSize, columns: 1, rows: 1)
                    }

                    // Row 5: More buttons
                    HStack(spacing: spacing) {
                        MockGridButton(title: "Solo 1", color: .blue, cellSize: cellSize, columns: 1, rows: 1)
                        MockGridButton(title: "Solo 2", color: .blue, cellSize: cellSize, columns: 1, rows: 1)
                        MockGridButton(title: "Solo 3", color: .blue, cellSize: cellSize, columns: 1, rows: 1)
                        MockGridButton(title: "Solo 4", color: .blue, cellSize: cellSize, columns: 1, rows: 1)

                        MockGridButton(title: "Arm 1", color: .red, cellSize: cellSize, columns: 1, rows: 1)
                        MockGridButton(title: "Arm 2", color: .red, cellSize: cellSize, columns: 1, rows: 1)
                        MockGridButton(title: "Arm 3", color: .red, cellSize: cellSize, columns: 1, rows: 1)
                        MockGridButton(title: "Arm 4", color: .red, cellSize: cellSize, columns: 1, rows: 1)
                    }

                    // Row 6: Scene buttons
                    HStack(spacing: spacing) {
                        MockGridButton(title: "Scene 1", color: .purple, cellSize: cellSize, columns: 2, rows: 1)
                        MockGridButton(title: "Scene 2", color: .purple, cellSize: cellSize, columns: 2, rows: 1)
                        MockGridButton(title: "Scene 3", color: .purple, cellSize: cellSize, columns: 2, rows: 1)
                        MockGridButton(title: "Scene 4", color: .purple, cellSize: cellSize, columns: 2, rows: 1)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)

            // Legend
            VStack(alignment: .leading, spacing: 4) {
                Text("Legend:")
                    .font(.caption.weight(.semibold))
                Text("Green boxes = Mock existing buttons")
                Text("Blue XY Pad = Experimental 2D controller (2x2)")
                Text("Circular knobs = Experimental encoder controllers (1x1)")
                Text("Gray dots = Grid alignment overlay")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - SwiftUI Preview
#Preview("Experimental Controllers") {
    ExperimentalControllersPreview()
}

#Preview("XY Pad Only") {
    ExperimentalXYPadController(
        title: "Filter XY",
        ccX: 74,
        ccY: 71,
        channel: 1
    )
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}

#Preview("Encoder Only") {
    ExperimentalEncoderController(
        title: "Volume",
        cc: 7,
        channel: 1
    )
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}

#Preview("Grid with Experimental Controllers") {
    GridWithExperimentalControllersPreview()
}

#Preview("Grid Tiles Only") {
    VStack(spacing: 20) {
        Text("Grid-Sized Tile Versions")
            .font(.headline)

        HStack(spacing: 16) {
            GridXYPadController(
                title: "XY Pad",
                ccX: 74,
                ccY: 71,
                channel: 1,
                cellSize: 100
            )

            GridEncoderController(
                title: "Encoder",
                cc: 7,
                channel: 1,
                cellSize: 100
            )
        }
    }
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}
