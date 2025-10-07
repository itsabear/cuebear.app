//
//  KnobInteractionGallery.swift - Preview Only
//  Cue Bear
//
//  EXPERIMENTAL: Gallery of different knob interaction patterns
//  Test each option to find the best UX for adjusting values
//  Lives in Preview Content so it's excluded from production builds
//

import SwiftUI

// MARK: - Option 1: Tap to Lock, Drag to Adjust (Vertical)
struct Option1_TapLockDrag: View {
    let title: String = "Tap to Lock, Drag to Adjust"
    let cc: Int = 74
    let channel: Int = 1

    @State private var currentValue: Int = 80  // Start at 80 to test decreasing
    @State private var isDragging: Bool = false
    @State private var lockedValue: Int = 80
    @State private var dragStartY: CGFloat = 0

    var body: some View {
        VStack(spacing: 12) {
            // Info banner
            VStack(spacing: 4) {
                Text("Option 1: Tap to Lock, Drag to Adjust")
                    .font(.headline)
                Text("Tap knob → locks current value\nDrag up/down → adjust from locked value")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)

            // Value display
            Text("\(currentValue)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(isDragging ? .accentColor : .primary)
                .frame(height: 32)

            // Knob
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: normalizedValue)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

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
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: 3, height: 25)
                            .offset(y: -27.5)
                            .rotationEffect(.degrees(rotationAngle))
                    )
                    .shadow(color: isDragging ? .accentColor.opacity(0.3) : .black.opacity(0.2), radius: isDragging ? 8 : 4, x: 0, y: 2)

                if isDragging {
                    Circle()
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 12)
                        .frame(width: 130, height: 130)
                        .blur(radius: 6)
                }
            }
            .scaleEffect(isDragging ? 1.15 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDragging)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            lockedValue = currentValue  // Lock current value
                            dragStartY = value.startLocation.y
                        }

                        // Vertical drag: up = decrease, down = increase
                        let deltaY = value.location.y - dragStartY
                        let sensitivity: CGFloat = 2.0
                        let valueDelta = Int(deltaY / sensitivity)

                        currentValue = max(0, min(127, lockedValue + valueDelta))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )

            Text("\(channel)•\(cc)")
                .font(.caption2)
                .foregroundColor(.secondary)

            // Status
            Text(isDragging ? "Adjusting from \(lockedValue)" : "Tap to lock at \(currentValue)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 4)
    }

    private var normalizedValue: CGFloat {
        CGFloat(currentValue) / 127.0
    }

    private var rotationAngle: Double {
        let range = 270.0
        let startAngle = -135.0
        return startAngle + (Double(normalizedValue) * range)
    }
}

// MARK: - Option 2: Virtual Touch Area
struct Option2_VirtualTouchArea: View {
    let title: String = "Virtual Touch Area"
    let cc: Int = 74
    let channel: Int = 1

    @State private var currentValue: Int = 80
    @State private var isDragging: Bool = false
    @State private var knobCenter: CGPoint = .zero

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("Option 2: Virtual Touch Area")
                    .font(.headline)
                Text("Tap anywhere in area\nValue = distance from knob center")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)

            Text("\(currentValue)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(isDragging ? .accentColor : .primary)
                .frame(height: 32)

            // Large touch area with visible boundary
            ZStack {
                // Virtual touch area (200x200)
                Circle()
                    .stroke(Color.orange.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .frame(width: 200, height: 200)

                // Knob (120x120)
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                        .frame(width: 120, height: 120)

                    Circle()
                        .trim(from: 0, to: normalizedValue)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))

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
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(width: 3, height: 25)
                                .offset(y: -27.5)
                                .rotationEffect(.degrees(rotationAngle))
                        )
                        .shadow(color: isDragging ? .accentColor.opacity(0.3) : .black.opacity(0.2), radius: isDragging ? 8 : 4, x: 0, y: 2)

                    if isDragging {
                        Circle()
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 12)
                            .frame(width: 130, height: 130)
                            .blur(radius: 6)
                    }
                }
            }
            .frame(width: 200, height: 200)
            .scaleEffect(isDragging ? 1.08 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDragging)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            knobCenter = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        }
                }
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true

                        // Calculate distance from knob center
                        let dx = value.location.x - 100  // Center of 200x200 area
                        let dy = value.location.y - 100
                        let distance = sqrt(dx * dx + dy * dy)

                        // Map distance to value (0 at center, 127 at edge)
                        let maxDistance: CGFloat = 100  // Radius of touch area
                        let normalizedDistance = min(distance / maxDistance, 1.0)
                        currentValue = Int(normalizedDistance * 127)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )

            Text("\(channel)•\(cc)")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(isDragging ? "Distance: \(String(format: "%.0f", CGFloat(currentValue) / 127.0 * 100))%" : "Tap anywhere")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 4)
    }

    private var normalizedValue: CGFloat {
        CGFloat(currentValue) / 127.0
    }

    private var rotationAngle: Double {
        let range = 270.0
        let startAngle = -135.0
        return startAngle + (Double(normalizedValue) * range)
    }
}

// MARK: - Option 3: Vertical Drag Relative Mode
struct Option3_VerticalRelative: View {
    let title: String = "Vertical Drag Relative"
    let cc: Int = 74
    let channel: Int = 1

    @State private var currentValue: Int = 80
    @State private var isDragging: Bool = false
    @State private var startValue: Int = 80
    @State private var dragStartY: CGFloat = 0

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("Option 3: Vertical Drag Relative")
                    .font(.headline)
                Text("Drag up to decrease\nDrag down to increase\nRelative to current value")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(12)

            Text("\(currentValue)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(isDragging ? .accentColor : .primary)
                .frame(height: 32)

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: normalizedValue)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

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
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: 3, height: 25)
                            .offset(y: -27.5)
                            .rotationEffect(.degrees(rotationAngle))
                    )
                    .shadow(color: isDragging ? .accentColor.opacity(0.3) : .black.opacity(0.2), radius: isDragging ? 8 : 4, x: 0, y: 2)

                if isDragging {
                    Circle()
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 12)
                        .frame(width: 130, height: 130)
                        .blur(radius: 6)
                }
            }
            .scaleEffect(isDragging ? 1.15 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDragging)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            startValue = currentValue
                            dragStartY = value.startLocation.y
                        }

                        // Vertical drag only, relative to start value
                        let deltaY = value.location.y - dragStartY
                        let sensitivity: CGFloat = 1.5
                        let valueDelta = Int(deltaY / sensitivity)

                        currentValue = max(0, min(127, startValue + valueDelta))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )

            Text("\(channel)•\(cc)")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(isDragging ? "Δ\(currentValue - startValue) from \(startValue)" : "Drag to adjust")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 4)
    }

    private var normalizedValue: CGFloat {
        CGFloat(currentValue) / 127.0
    }

    private var rotationAngle: Double {
        let range = 270.0
        let startAngle = -135.0
        return startAngle + (Double(normalizedValue) * range)
    }
}

// MARK: - Option 4: Two-Phase Interaction
struct Option4_TwoPhase: View {
    let title: String = "Two-Phase Interaction"
    let cc: Int = 74
    let channel: Int = 1

    @State private var currentValue: Int = 80
    @State private var isDragging: Bool = false
    @State private var mode: InteractionMode = .none
    @State private var holdTimer: Timer? = nil
    @State private var dragStartPosition: CGPoint = .zero
    @State private var startValue: Int = 80
    @State private var smoothedValue: CGFloat = 80

    enum InteractionMode {
        case none
        case relative  // Quick tap-drag
        case absolute  // Hold then drag (distance-based, resets to 0)
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("Option 4: Two-Phase Interaction")
                    .font(.headline)
                Text("Quick drag = relative adjust\nHold 0.5s then drag = absolute (resets to 0)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)

            HStack(spacing: 8) {
                Text(mode == .relative ? "RELATIVE" : mode == .absolute ? "ABSOLUTE" : "READY")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(mode == .relative ? Color.purple : mode == .absolute ? Color.orange : Color.gray)
                    .cornerRadius(8)

                Text("\(currentValue)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(isDragging ? .accentColor : .primary)
            }
            .frame(height: 32)

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: normalizedValue)
                    .stroke(
                        mode == .absolute ? Color.orange : Color.accentColor,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

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
                        Rectangle()
                            .fill(mode == .absolute ? Color.orange : Color.accentColor)
                            .frame(width: 3, height: 25)
                            .offset(y: -27.5)
                            .rotationEffect(.degrees(rotationAngle))
                    )
                    .shadow(color: isDragging ? .accentColor.opacity(0.3) : .black.opacity(0.2), radius: isDragging ? 8 : 4, x: 0, y: 2)

                if isDragging {
                    Circle()
                        .stroke((mode == .absolute ? Color.orange : Color.accentColor).opacity(0.3), lineWidth: 12)
                        .frame(width: 130, height: 130)
                        .blur(radius: 6)
                }
            }
            .scaleEffect(isDragging ? 1.15 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDragging)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            dragStartPosition = value.startLocation
                            startValue = currentValue
                            smoothedValue = CGFloat(currentValue)

                            // Start hold timer for absolute mode
                            holdTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                                mode = .absolute
                                currentValue = 0
                                smoothedValue = 0
                            }
                        } else if mode == .none {
                            // User started dragging before timer fired = relative mode
                            holdTimer?.invalidate()
                            mode = .relative
                        }

                        // Apply interaction based on mode
                        if mode == .relative {
                            // Vertical relative adjustment
                            let deltaY = value.location.y - dragStartPosition.y
                            let sensitivity: CGFloat = 1.5
                            let valueDelta = Int(deltaY / sensitivity)
                            currentValue = max(0, min(127, startValue + valueDelta))
                        } else if mode == .absolute {
                            // Distance-based absolute (like original)
                            let dx = value.location.x - dragStartPosition.x
                            let dy = value.location.y - dragStartPosition.y
                            let distance = sqrt(dx * dx + dy * dy)

                            let rawValue = distance / 1.5
                            let smoothingFactor: CGFloat = 0.3
                            smoothedValue = smoothedValue + smoothingFactor * (rawValue - smoothedValue)
                            let newValue = max(0, min(127, Int(smoothedValue.rounded())))
                            currentValue = newValue
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        mode = .none
                        holdTimer?.invalidate()
                        holdTimer = nil
                    }
            )

            Text("\(channel)•\(cc)")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(mode == .relative ? "Quick drag - adjusting" : mode == .absolute ? "Hold mode - distance from tap" : "Tap quick or hold 0.5s")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 4)
    }

    private var normalizedValue: CGFloat {
        CGFloat(currentValue) / 127.0
    }

    private var rotationAngle: Double {
        let range = 270.0
        let startAngle = -135.0
        return startAngle + (Double(normalizedValue) * range)
    }
}

// MARK: - Gallery View
struct KnobInteractionGallery: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Text("Knob Interaction Gallery")
                    .font(.title.weight(.bold))
                    .padding(.top)

                Text("Test each option to find the best interaction pattern.\nEach knob starts at value 80 to test decreasing.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Option 1
                Option1_TapLockDrag()

                Divider()
                    .padding(.horizontal)

                // Option 2
                Option2_VirtualTouchArea()

                Divider()
                    .padding(.horizontal)

                // Option 3
                Option3_VerticalRelative()

                Divider()
                    .padding(.horizontal)

                // Option 4
                Option4_TwoPhase()

                // Summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("Which feels best?")
                        .font(.headline)

                    Text("Option 1: Most intuitive, like iOS sliders")
                    Text("Option 2: Keeps radial concept, but less precise")
                    Text("Option 3: Professional audio app standard")
                    Text("Option 4: Flexible, but more complex to learn")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)

                Spacer(minLength: 40)
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - SwiftUI Preview
#Preview("Knob Interaction Gallery") {
    KnobInteractionGallery()
}
