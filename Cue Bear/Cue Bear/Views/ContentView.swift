//
//  ContentView.swift — Cue Bear (v1.16c)
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Combine

// MARK: - PreferenceKeys for UI Element Positions

struct EditCapsuleBottomPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// New comprehensive collision detection system
struct CapsuleBoundsPreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct TutorialWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// PreferenceKey for tracking tutorial target button frames
struct TutorialButtonFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Swipeable Capsule Configuration
// Shared settings for nav pill and cue capsule collapsible behavior

struct SwipeableCapsuleConfig {
    // Expanded size
    let expandedWidth: CGFloat
    let expandedHeight: CGFloat

    // Collapsed size
    let collapsedWidth: CGFloat
    let collapsedHeight: CGFloat

    // Tutorial settings
    let tutorialText: String
    let tutorialUserDefaultsKey: String
    let tutorialSpacing: CGFloat // Space between tutorial and capsule

    // Animation settings
    let collapseAnimationDuration: Double
    let tutorialFloatDuration: Double
    let tutorialFloatDistance: CGFloat

    // Static configurations
    static let navPill = SwipeableCapsuleConfig(
        expandedWidth: 120,
        expandedHeight: 275,
        collapsedWidth: 36,
        collapsedHeight: 90,
        tutorialText: "Swipe right to hide",
        tutorialUserDefaultsKey: "hasSeenNavPillTutorial",
        tutorialSpacing: 16,
        collapseAnimationDuration: 0.15,
        tutorialFloatDuration: 0.525,
        tutorialFloatDistance: 8
    )

    static let cueCapsule = SwipeableCapsuleConfig(
        expandedWidth: 120,
        expandedHeight: 310,
        collapsedWidth: 36,
        collapsedHeight: 90,
        tutorialText: "Swipe right to collapse",
        tutorialUserDefaultsKey: "hasSeenCueCapsuleTutorial",
        tutorialSpacing: 16,
        collapseAnimationDuration: 0.15,
        tutorialFloatDuration: 0.525,
        tutorialFloatDistance: 8
    )
}

// MARK: - Reusable Tutorial View

struct SwipeableCapsuleTutorial: View {
    let text: String
    let width: CGFloat
    let position: CGPoint
    let floatOffset: CGFloat
    let onDismiss: () -> Void
    var onSkip: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            // Main tutorial bubble
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "hand.draw")
                        .font(.system(size: 20))
                        .foregroundColor(.white)

                    Text(text)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }

                if let onSkip = onSkip {
                    Button("Skip") { onSkip() }
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [Color.purple, Color.blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)

            // Arrow pointing to capsule
            Image(systemName: "arrowtriangle.right.fill")
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .offset(x: -2)
        }
        .fixedSize()
        .background(
            GeometryReader { contentGeo in
                Color.clear.preference(
                    key: TutorialWidthPreferenceKey.self,
                    value: contentGeo.size.width
                )
            }
        )
        .offset(y: floatOffset)
        .position(position)
        .animation(.easeInOut(duration: 0.525).repeatForever(autoreverses: true), value: floatOffset)
    }
}

// MARK: - Onboarding Tutorial Views

/// Tutorial bubble that points upward to a target element (for top-area UI elements)
struct UpwardTutorial: View {
    let message: String
    let targetFrame: CGRect
    let onDismiss: () -> Void
    var onSkip: (() -> Void)? = nil

    @State private var floatOffset: CGFloat = 4  // Start at bottom of float range
    @State private var hasStartedAnimation = false
    @State private var bubbleSize: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let screenWidth = geo.size.width
            let padding: CGFloat = 16
            let estimatedBubbleWidth = bubbleSize.width > 0 ? bubbleSize.width : 280

            // Target X where the arrow should point
            let targetX = targetFrame.midX

            // Clamp bubble center X so bubble stays within screen bounds
            let minBubbleX = padding + estimatedBubbleWidth / 2
            let maxBubbleX = screenWidth - padding - estimatedBubbleWidth / 2
            let clampedBubbleX = min(max(targetX, minBubbleX), maxBubbleX)

            // Arrow offset from bubble center to point at target
            let arrowOffset = targetX - clampedBubbleX

            let tooltipY = targetFrame.maxY + 8  // Position just below target (touching)

            VStack(spacing: 0) {
                // Arrow pointing up - offset horizontally to point at target
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .offset(x: arrowOffset, y: 2)

                // Main tutorial bubble
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.tap")
                            .font(.system(size: 18))
                            .foregroundColor(.white)

                        Text(message)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let onSkip = onSkip {
                        Button("Skip") { onSkip() }
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
                .background(
                    GeometryReader { bubbleGeo in
                        Color.clear.onAppear {
                            bubbleSize = bubbleGeo.size
                        }
                    }
                )
            }
            .fixedSize()
            .offset(y: floatOffset)
            .position(x: clampedBubbleX, y: tooltipY)
            .onAppear {
                guard !hasStartedAnimation else { return }
                hasStartedAnimation = true
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    floatOffset = -4
                }
            }
        }
        .allowsHitTesting(true)
    }
}

/// Tutorial bubble that points downward to a target element (for bottom-area UI elements like Controls capsule)
struct DownwardTutorial: View {
    let message: String
    let targetFrame: CGRect
    let onDismiss: () -> Void
    var onSkip: (() -> Void)? = nil

    @State private var floatOffset: CGFloat = 4  // Start at bottom of float range
    @State private var hasStartedAnimation = false
    @State private var bubbleSize: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let screenWidth = geo.size.width
            let padding: CGFloat = 16
            let estimatedBubbleWidth = bubbleSize.width > 0 ? bubbleSize.width : 280

            // Target X where the arrow should point
            let targetX = targetFrame.midX

            // Clamp bubble center X so bubble stays within screen bounds
            let minBubbleX = padding + estimatedBubbleWidth / 2
            let maxBubbleX = screenWidth - padding - estimatedBubbleWidth / 2
            let clampedBubbleX = min(max(targetX, minBubbleX), maxBubbleX)

            // Arrow offset from bubble center to point at target
            let arrowOffset = targetX - clampedBubbleX

            let tooltipY = targetFrame.minY - 70  // Position above target (further away)

            VStack(spacing: 0) {
                // Main tutorial bubble
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.tap")
                            .font(.system(size: 18))
                            .foregroundColor(.white)

                        Text(message)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let onSkip = onSkip {
                        Button("Skip") { onSkip() }
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
                .background(
                    GeometryReader { bubbleGeo in
                        Color.clear.onAppear {
                            bubbleSize = bubbleGeo.size
                        }
                    }
                )

                // Arrow pointing down - offset horizontally to point at target
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .offset(x: arrowOffset, y: -2)
            }
            .fixedSize()
            .offset(y: floatOffset)
            .position(x: clampedBubbleX, y: tooltipY)
            .onAppear {
                guard !hasStartedAnimation else { return }
                hasStartedAnimation = true
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    floatOffset = -4
                }
            }
        }
    }
}

// MARK: - Control Area Scrollbar (iPhone)

private struct ControlAreaScrollbar: View {
    let contentWidth: CGFloat
    let visibleWidth: CGFloat
    @Binding var scrollOffset: CGFloat

    private let trackInset: CGFloat = 20
    private let trackHeight: CGFloat = 6
    private let handleSize: CGFloat = 28

    var needsScrollbar: Bool {
        contentWidth > visibleWidth && visibleWidth > 0
    }

    private var trackWidth: CGFloat {
        max(0, visibleWidth - trackInset * 2)
    }

    private var maxScrollOffset: CGFloat {
        contentWidth - visibleWidth
    }

    private var scrollFraction: CGFloat {
        maxScrollOffset > 0 ? min(1, max(0, scrollOffset / maxScrollOffset)) : 0
    }

    private var handleCenterX: CGFloat {
        let halfHandle = handleSize / 2
        let usableTrack = trackWidth - handleSize
        return halfHandle + scrollFraction * usableTrack
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Track
            Capsule()
                .fill(Color.primary.opacity(0.08))
                .frame(width: trackWidth, height: trackHeight)

            // Round draggable handle
            Circle()
                .fill(Color.primary.opacity(0.3))
                .frame(width: handleSize, height: handleSize)
                .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                .offset(x: handleCenterX - handleSize / 2)
        }
        .frame(height: handleSize)
        .padding(.horizontal, trackInset)
        .padding(.bottom, 4)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let trackUsable = trackWidth - handleSize
                    guard trackUsable > 0 else { return }
                    // Map drag X position to scroll fraction
                    let localX = value.location.x - handleSize / 2
                    let fraction = min(1, max(0, localX / trackUsable))
                    scrollOffset = fraction * maxScrollOffset
                }
        )
        .opacity(needsScrollbar ? 1 : 0)
        .allowsHitTesting(needsScrollbar)
    }
}

// MARK: - Draft State Persistence
// v1.0.8: Preserve draft edits across sheet dismissals (when tapping outside)
// Only clear drafts when Cancel is clicked, not when tapping outside

class CueEditorDraft: ObservableObject {
    @Published var name: String = ""
    @Published var subtitle: String = ""
    @Published var kind: MIDIKind = .cc
    @Published var number: Int = 0
    @Published var channel: Int = 1
    @Published var velocity: Int = 127
    @Published var autoAssign: Bool = true

    func clear() {
        name = ""
        subtitle = ""
        kind = .cc
        number = 0
        channel = 1
        velocity = 127
        autoAssign = true
    }

    func loadFrom(song: Song) {
        name = song.name
        subtitle = song.subtitle ?? ""
        kind = song.kind
        channel = song.channel
        velocity = song.velocity
        if kind == .note {
            number = song.note ?? 0
        } else {
            number = song.cc
        }
        autoAssign = true
    }
}

class ControlEditorDraft: ObservableObject {
    @Published var title: String = ""
    @Published var symbol: String = "square.grid.2x2.fill"
    @Published var kind: MIDIKind = .cc
    @Published var number: Int = 0
    @Published var channel: Int = 1
    @Published var velocity: Int = 127
    @Published var autoAssign: Bool = true
    @Published var isToggle: Bool = false
    @Published var isSmall: Bool = false
    @Published var isFader: Bool = false
    @Published var faderOrientation: String = "vertical"
    @Published var faderDirection: String = "up"
    @Published var colorHex: String? = nil

    func clear() {
        title = ""
        symbol = "square.grid.2x2.fill"
        kind = .cc
        number = 0
        channel = 1
        velocity = 127
        autoAssign = true
        isToggle = false
        isSmall = false
        isFader = false
        faderOrientation = "vertical"
        faderDirection = "up"
        colorHex = nil
    }

    func loadFrom(control: ControlButton) {
        title = control.title
        symbol = control.symbol
        kind = control.kind
        number = control.number
        channel = control.channel
        velocity = control.velocity
        autoAssign = true
        isToggle = control.isToggle ?? false
        isSmall = control.isSmall ?? false
        isFader = control.isFader == true
        faderOrientation = control.faderOrientation ?? "vertical"
        faderDirection = control.faderDirection ?? "up"
        colorHex = control.colorHex
    }
}

// MARK: - Reusable Button Styles

struct PrimaryWideButton: View {
    let title: String
    let action: () -> Void
    let isDisabled: Bool

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(PrimaryWideButtonStyle(isDisabled: isDisabled))
        .disabled(isDisabled)
    }
}

struct PrimaryWideButtonStyle: ButtonStyle {
    let isDisabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isDisabled
                            ? Color.gray.opacity(0.4)
                            : (configuration.isPressed ? Color.white.opacity(0.7) : Color.white)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SecondaryWideButton: View {
    let title: String
    let action: () -> Void
    let isDisabled: Bool

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(
                    isDisabled
                        ? Color.gray.opacity(0.5)
                        : Color.white
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(SecondaryWideButtonStyle(isDisabled: isDisabled))
        .disabled(isDisabled)
    }
}

struct SecondaryWideButtonStyle: ButtonStyle {
    let isDisabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isDisabled
                            ? Color.gray.opacity(0.1)
                            : (configuration.isPressed ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isDisabled
                            ? Color.gray.opacity(0.3)
                            : Color.white.opacity(0.5),
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct DestructiveWideButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(DestructiveWideButtonStyle())
    }
}

struct DestructiveWideButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(configuration.isPressed ? Color.red.opacity(0.7) : Color.red)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Shared Wobble Animator (Time-Based Continuous Animation)
// Uses continuous sine-wave calculations instead of discrete state updates for smooth 60fps performance
@MainActor
class WobbleAnimator: ObservableObject {
    static let shared = WobbleAnimator()

    // Not @Published — coalesced via scheduleNotification() so N simultaneous updates = 1 re-render
    private(set) var wobbles: [UUID: WobbleConfig] = [:]
    private var notificationScheduled = false

    struct WobbleConfig: Equatable {
        let amplitude: Double
        let scaleDelta: Double
        let phaseOffset: Double
    }

    private init() {}

    private func scheduleNotification() {
        guard !notificationScheduled else { return }
        notificationScheduled = true
        // Defer to next run loop tick so all synchronous mutations in the same cycle are batched
        DispatchQueue.main.async { [weak self] in
            self?.notificationScheduled = false
            self?.objectWillChange.send()
        }
    }

    func startWobbling(for id: UUID, amplitude: Double, scaleDelta: Double) {
        wobbles[id] = WobbleConfig(amplitude: amplitude, scaleDelta: scaleDelta, phaseOffset: Double.random(in: 0...(2 * .pi)))
        scheduleNotification()
    }

    func stopWobbling(for id: UUID) {
        guard wobbles.removeValue(forKey: id) != nil else { return }
        scheduleNotification()
    }

    func resetWobble(for id: UUID) {
        stopWobbling(for: id)
    }

    func stopAll() {
        guard !wobbles.isEmpty else { return }
        wobbles.removeAll()
        scheduleNotification()
    }

    func calculateWobble(time: TimeInterval, config: WobbleConfig) -> (rotation: Double, scale: Double) {
        let frequency = 18.8  // 3 Hz × 2π
        let angle = time * frequency + config.phaseOffset
        let rotation = sin(angle) * config.amplitude
        let scale = 1.0 + sin(angle + .pi / 2) * config.scaleDelta

        return (rotation, scale)
    }
}

// MARK: - Time-Based Wobble View Modifier
// Applies continuous wobble animation using TimelineView for 60fps performance
struct TimeBasedWobbleModifier: ViewModifier {
    let wobbleID: UUID
    @ObservedObject var wobbleAnimator: WobbleAnimator

    func body(content: Content) -> some View {
        if let config = wobbleAnimator.wobbles[wobbleID] {
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let wobble = wobbleAnimator.calculateWobble(time: time, config: config)

                content
                    .rotationEffect(.degrees(wobble.rotation))
                    .scaleEffect(wobble.scale)
            }
        } else {
            content
                .rotationEffect(.degrees(0))
                .scaleEffect(1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: wobbleAnimator.wobbles[wobbleID])
        }
    }
}

// Conditional wobble modifier - only applies wobble on iPad
struct ConditionalWobbleModifier: ViewModifier {
    let isPhone: Bool
    let wobbleID: UUID
    @ObservedObject var wobbleAnimator: WobbleAnimator

    func body(content: Content) -> some View {
        if isPhone {
            // iPhone: No wobble
            content
        } else {
            // iPad: Apply wobble
            content.modifier(TimeBasedWobbleModifier(wobbleID: wobbleID, wobbleAnimator: wobbleAnimator))
        }
    }
}

// MARK: - Reserved CCs for legacy transport mapping (kept for compatibility)
private enum CBTransportCC { static let play = 100, stop = 101, prev = 102, next = 103 }

// MARK: - Grid Position Helper
private struct GridPosition: Equatable {
    let col: Int
    let row: Int
}

// MARK: - Control Button (UI-local model; persisted in ProjectPayload)
internal struct ControlButton: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var symbol: String        // SF Symbol
    var kind: MIDIKind        // .cc or .note
    var number: Int           // CC or Note number (0–127)
    var channel: Int          // 1–16
    var velocity: Int = 127   // for notes
    // Behavior: nil/false = momentary, true = toggle
    var isToggle: Bool? = nil
    // Toggle state: true = on, false = off (only used when isToggle == true)
    var toggleState: Bool = false
    // SNAKE: render as a fader instead of a button (CC only)
    var isFader: Bool? = nil
    // SNAKE: render as a small button (1x1)
    var isSmall: Bool? = nil
    // Optional explicit grid placement (column, row) for widget-like layout
    var gridCol: Int? = nil
    var gridRow: Int? = nil
    // Fader value: 0.0 to 1.0 (only used when isFader == true)
    var faderValue: Double? = nil
    // Fader orientation: "vertical" or "horizontal" (only used when isFader == true)
    // Defaults to "vertical" for backward compatibility with existing faders
    var faderOrientation: String? = nil
    // Fader direction: "up", "down", "left", "right" (only used when isFader == true)
    // Defaults to "up" for vertical, "right" for horizontal
    var faderDirection: String? = nil
    // Custom color (hex string, e.g. "#FF5733")
    var colorHex: String? = nil
    // Page index (0-3) for multi-page control area
    var page: Int = 0

    // Memberwise initializer
    init(title: String, symbol: String, kind: MIDIKind, number: Int, channel: Int, velocity: Int = 127, isToggle: Bool? = nil, toggleState: Bool = false, isFader: Bool? = nil, isSmall: Bool? = nil, gridCol: Int? = nil, gridRow: Int? = nil, faderValue: Double? = nil, faderOrientation: String? = nil, faderDirection: String? = nil, colorHex: String? = nil, page: Int = 0) {
        self.title = title
        self.symbol = symbol
        self.kind = kind
        self.number = number
        self.channel = channel
        self.velocity = velocity
        self.isToggle = isToggle
        self.toggleState = toggleState
        self.isFader = isFader
        self.isSmall = isSmall
        self.gridCol = gridCol
        self.gridRow = gridRow
        self.faderValue = faderValue
        self.faderOrientation = faderOrientation
        self.faderDirection = faderDirection
        self.colorHex = colorHex
        self.page = page
    }

    // Custom decoder to handle missing toggleState in older project files
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        symbol = try container.decode(String.self, forKey: .symbol)
        kind = try container.decode(MIDIKind.self, forKey: .kind)
        number = try container.decode(Int.self, forKey: .number)
        channel = try container.decode(Int.self, forKey: .channel)
        velocity = try container.decodeIfPresent(Int.self, forKey: .velocity) ?? 127
        isToggle = try container.decodeIfPresent(Bool.self, forKey: .isToggle)
        toggleState = try container.decodeIfPresent(Bool.self, forKey: .toggleState) ?? false
        isFader = try container.decodeIfPresent(Bool.self, forKey: .isFader)
        isSmall = try container.decodeIfPresent(Bool.self, forKey: .isSmall)
        gridCol = try container.decodeIfPresent(Int.self, forKey: .gridCol)
        gridRow = try container.decodeIfPresent(Int.self, forKey: .gridRow)
        faderValue = try container.decodeIfPresent(Double.self, forKey: .faderValue)
        // New fader properties - defaults for backward compatibility
        faderOrientation = try container.decodeIfPresent(String.self, forKey: .faderOrientation)
        faderDirection = try container.decodeIfPresent(String.self, forKey: .faderDirection)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)
        // Page property - defaults to 0 for backward compatibility
        page = try container.decodeIfPresent(Int.self, forKey: .page) ?? 0
    }

    // Computed properties for grid dimensions
    var gridWidth: Int {
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone

        if isFader == true {
            // iPhone: All faders are 1 wide, iPad: orientation-dependent
            if isPhone {
                return 1
            } else {
                let orientation = faderOrientation ?? "vertical"
                return orientation == "horizontal" ? 2 : 1
            }
        } else if isSmall == true {
            return 1  // Small button: 1x1
        } else {
            // iPhone: Regular buttons are 2x1, iPad: 2x1
            return 2
        }
    }

    var gridHeight: Int {
        if isFader == true {
            // iPhone: All faders are 2 high, iPad: orientation-dependent
            if UIDevice.current.userInterfaceIdiom == .phone {
                return 2
            } else {
                let orientation = faderOrientation ?? "vertical"
                return orientation == "horizontal" ? 1 : 2
            }
        } else {
            return 1  // All buttons: height 1
        }
    }
}

// MARK: - Local UI helpers / rows
    internal struct CBLibraryRow: Identifiable {
    let id: UUID
    let song: Song
    let isInSetlist: Bool
    let isSelected: Bool
}

internal enum LibrarySortMode: String, CaseIterable, Identifiable {
    case nameAZ, nameZA, newest, oldest
    var id: String { rawValue }
    var label: String {
        switch self {
        case .nameAZ: return "A–Z"
        case .nameZA: return "Z–A"
        case .newest: return "Newest"
        case .oldest: return "Oldest"
        }
    }
}

// MARK: - Stepper + TextField MIDI Number Picker
struct MIDINumberPicker: View {
    let kind: MIDIKind
    @Binding var number: Int
    let disabled: Bool
    let channel: Int
    var currentOwnerName: ((MIDIKey) -> String?)?
    var editingControl: ControlButton?
    var editingSong: Song?
    @AppStorage("midiFiltersEnabled") private var midiFiltersEnabled: Bool = true
    var midiFilter: Set<Int> = []
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Text(kind == .cc ? "CC Number" : "Note Number")
                    .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))

                Spacer()

                // Note name (for MIDI notes only)
                if kind == .note {
                    Text(number.midiNoteName)
                        .font(.system(size: 14))
                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                }

                // Minus button
                Button(action: {
                    if number > 0 {
                        number -= 1
                    }
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(number > 0 && !disabled ? selectedTheme.primaryTextColor(for: colorScheme) : selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3))
                        .frame(width: 28, height: 28)
                        .background(selectedTheme.titleBarColor(for: colorScheme))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(disabled || number <= 0)

                // Text field
                TextField("", text: $textValue)
                    .focused($isFocused)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .frame(width: 50)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(selectedTheme.backgroundColor(for: colorScheme))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isFocused ? selectedTheme.accentColor(for: colorScheme) : selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3), lineWidth: 1)
                    )
                    .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                    .disabled(disabled)
                    .keyboardType(.numberPad)
                    .onAppear {
                        textValue = "\(number)"
                    }
                    .onChange(of: number) { _, newValue in
                        if !isFocused {
                            textValue = "\(newValue)"
                        }
                    }
                    .onSubmit {
                        validateAndUpdate()
                    }
                    .onChange(of: textValue) { _, newText in
                        if let value = Int(newText), value >= 0, value <= 127 {
                            number = value
                        }
                    }
                    .onChange(of: isFocused) { _, focused in
                        if !focused {
                            validateAndUpdate()
                        }
                    }
                    .onTapGesture {
                        isFocused = true
                    }

                // Plus button
                Button(action: {
                    if number < 127 {
                        number += 1
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(number < 127 && !disabled ? selectedTheme.primaryTextColor(for: colorScheme) : selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3))
                        .frame(width: 28, height: 28)
                        .background(selectedTheme.titleBarColor(for: colorScheme))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(disabled || number >= 127)
            }

            // Show "MIDI taken by" warning if number is taken
            if let owner = ownerFor(kind: kind, number: number, channel: channel) {
                Text("⚠️ MIDI taken by: \(owner)")
                    .font(.caption)
                    .foregroundColor(selectedTheme.warningColor(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Show filtered MIDI warning only when filters are active
            if midiFiltersEnabled && !midiFilter.isEmpty && kind == .cc && midiFilter.contains(number) {
                Text("⚠️ This CC is filtered. Turn off filter to use it.")
                    .font(.caption)
                    .foregroundColor(selectedTheme.warningColor(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func validateAndUpdate() {
        if let value = Int(textValue), value >= 0, value <= 127 {
            number = value
        } else {
            textValue = "\(number)"
        }
    }

    private func ownerFor(kind: MIDIKind, number: Int, channel: Int) -> String? {
        guard let currentOwnerName = currentOwnerName else { return nil }

        // If we're editing a control and checking its current MIDI assignment, don't show as taken
        if let edit = editingControl {
            if edit.kind == kind && edit.channel == channel && edit.number == number {
                return nil
            }
        }

        // If we're editing a song and checking its current MIDI assignment, don't show as taken
        if let edit = editingSong {
            let editNumber = (edit.kind == .note) ? (edit.note ?? 60) : edit.cc
            if edit.kind == kind && edit.channel == channel && editNumber == number {
                return nil
            }
        }

        let key = MIDIKey(kind: kind, channel: channel, number: number)
        guard let ownersString = currentOwnerName(key) else { return nil }

        // Filter out the editing song's name from the conflict list
        if let edit = editingSong {
            if ownersString.contains("|||") {
                // Multiple owners - filter out editing song
                let owners = ownersString.split(separator: "|||")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { $0 != edit.name }
                guard !owners.isEmpty else { return nil }
                if owners.count == 1 {
                    return owners[0]
                } else if owners.count == 2 {
                    return "\(owners[0]) and \(owners[1])"
                } else {
                    return owners.dropLast().joined(separator: ", ") + ", and " + owners.last!
                }
            } else if ownersString.trimmingCharacters(in: .whitespacesAndNewlines) == edit.name {
                // Single owner and it's the editing song
                return nil
            }
        }

        // Filter out the current control's name from the conflict list
        if let edit = editingControl {
            let editDisplayName: String
            if edit.isFader == true {
                editDisplayName = edit.title.isEmpty ? "Fader" : "Fader: \(edit.title)"
            } else {
                editDisplayName = edit.title.isEmpty ? "Button" : "Button: \(edit.title)"
            }
            // Check if the owners string contains the separator (multiple owners)
            if ownersString.contains("|||") {
                // Multiple owners - need to filter
                let owners = ownersString.split(separator: "|||").map(String.init).filter { $0 != editDisplayName }
                guard !owners.isEmpty else { return nil }
                if owners.count == 1 {
                    return owners[0]
                } else if owners.count == 2 {
                    return "\(owners[0]) and \(owners[1])"
                } else {
                    return owners.dropLast().joined(separator: ", ") + ", and " + owners.last!
                }
            } else if ownersString == editDisplayName {
                // Single owner and it's us
                return nil
            }
        }

        return ownersString
    }
}

// MARK: - Grid-Based Icon Picker
struct IconPicker: View {
    @Binding var symbol: String
    let icons: [String]
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @State private var showingPopover = false

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        Button(action: { showingPopover = true }) {
            HStack {
                Text("Icon")
                    .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                Spacer()
                if symbol.isEmpty {
                    Text("Text only")
                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                } else {
                    Image(systemName: symbol)
                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                }
            }
        }
        .popover(isPresented: $showingPopover) {
            IconGridView(symbol: $symbol, icons: icons, showingPopover: $showingPopover)
                .presentationCompactAdaptation(.popover)
                .presentationBackground(selectedTheme.sheetBackgroundColor(for: colorScheme))
        }
    }
}

// MARK: - Icon Grid View (Popover Content)
struct IconGridView: View {
    @Binding var symbol: String
    let icons: [String]
    @Binding var showingPopover: Bool
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Icon")
                    .font(.headline)
                    .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                Spacer()
                Button(action: { showingPopover = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                }
            }
            .padding()
            .background(selectedTheme.titleBarColor(for: colorScheme))

            Divider()

            // Grid
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                        // Text only option
                        Button(action: {
                            symbol = ""
                            showingPopover = false
                        }) {
                            VStack(spacing: 4) {
                                Text("Aa")
                                    .font(.system(size: 20, weight: .medium))
                                Text("Text only")
                                    .font(.system(size: 10))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(
                                symbol.isEmpty
                                    ? selectedTheme.accentColor(for: colorScheme)
                                    : selectedTheme.titleBarColor(for: colorScheme)
                            )
                            .foregroundColor(
                                symbol.isEmpty ? .white : selectedTheme.primaryTextColor(for: colorScheme)
                            )
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        symbol.isEmpty ? selectedTheme.accentColor(for: colorScheme) : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                        }
                        .id("text-only")

                        // Icon options
                        ForEach(icons, id: \.self) { icon in
                            let isSelected = icon == symbol

                            Button(action: {
                                symbol = icon
                                showingPopover = false
                            }) {
                                Image(systemName: icon)
                                    .font(.system(size: 24))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 60)
                                    .background(
                                        isSelected
                                            ? selectedTheme.accentColor(for: colorScheme)
                                            : selectedTheme.titleBarColor(for: colorScheme)
                                    )
                                    .foregroundColor(
                                        isSelected ? .white : selectedTheme.primaryTextColor(for: colorScheme)
                                    )
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                isSelected ? selectedTheme.accentColor(for: colorScheme) : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                            }
                            .id(icon)
                        }
                    }
                    .padding()
                }
                .onAppear {
                    if !symbol.isEmpty {
                        proxy.scrollTo(symbol, anchor: .center)
                    } else {
                        proxy.scrollTo("text-only", anchor: .top)
                    }
                }
            }
        }
        .frame(width: 450, height: 500)
        .background(selectedTheme.backgroundColor(for: colorScheme))
    }
}

extension IconPicker: Equatable {
    static func == (lhs: IconPicker, rhs: IconPicker) -> Bool {
        lhs.symbol == rhs.symbol && lhs.icons == rhs.icons
    }
}

// MARK: - Stepper + TextField Velocity Picker
struct VelocityPicker: View {
    @Binding var velocity: Int
    let disabled: Bool
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("Velocity")
                .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))

            Spacer()

            // Minus button
            Button(action: {
                if velocity > 0 {
                    velocity -= 1
                }
            }) {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(velocity > 0 && !disabled ? selectedTheme.primaryTextColor(for: colorScheme) : selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3))
                    .frame(width: 28, height: 28)
                    .background(selectedTheme.titleBarColor(for: colorScheme))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(disabled || velocity <= 0)

            // Text field
            TextField("", text: $textValue)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .frame(width: 50)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(selectedTheme.backgroundColor(for: colorScheme))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isFocused ? selectedTheme.accentColor(for: colorScheme) : selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3), lineWidth: 1)
                )
                .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                .disabled(disabled)
                .keyboardType(.numberPad)
                .onAppear {
                    textValue = "\(velocity)"
                }
                .onChange(of: velocity) { _, newValue in
                    if !isFocused {
                        textValue = "\(newValue)"
                    }
                }
                .onSubmit {
                    validateAndUpdate()
                }
                .onChange(of: textValue) { _, newText in
                    if let value = Int(newText), value >= 0, value <= 127 {
                        velocity = value
                    }
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        validateAndUpdate()
                    }
                }
                .onTapGesture {
                    isFocused = true
                }

            // Plus button
            Button(action: {
                if velocity < 127 {
                    velocity += 1
                }
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(velocity < 127 && !disabled ? selectedTheme.primaryTextColor(for: colorScheme) : selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3))
                    .frame(width: 28, height: 28)
                    .background(selectedTheme.titleBarColor(for: colorScheme))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(disabled || velocity >= 127)
        }
    }

    private func validateAndUpdate() {
        if let value = Int(textValue), value >= 0, value <= 127 {
            velocity = value
        } else {
            textValue = "\(velocity)"
        }
    }
}

// MARK: - Channel Picker (Stepper + TextField)
struct ChannelPicker: View {
    let title: String
    @Binding var channel: Int
    let disabled: Bool
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))

            Spacer()

            // Minus button
            Button(action: {
                if channel > 1 {
                    channel -= 1
                }
            }) {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(channel > 1 && !disabled ? selectedTheme.primaryTextColor(for: colorScheme) : selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3))
                    .frame(width: 28, height: 28)
                    .background(selectedTheme.titleBarColor(for: colorScheme))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(disabled || channel <= 1)

            // Text field
            TextField("", text: $textValue)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .frame(width: 50)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(selectedTheme.backgroundColor(for: colorScheme))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isFocused ? selectedTheme.accentColor(for: colorScheme) : selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3), lineWidth: 1)
                )
                .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                .disabled(disabled)
                .keyboardType(.numberPad)
                .onAppear {
                    textValue = "\(channel)"
                }
                .onChange(of: channel) { _, newValue in
                    if !isFocused {
                        textValue = "\(newValue)"
                    }
                }
                .onSubmit {
                    validateAndUpdate()
                }
                .onChange(of: textValue) { _, newText in
                    if let value = Int(newText), value >= 1, value <= 16 {
                        channel = value
                    }
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        validateAndUpdate()
                    }
                }
                .onTapGesture {
                    isFocused = true
                }

            // Plus button
            Button(action: {
                if channel < 16 {
                    channel += 1
                }
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(channel < 16 && !disabled ? selectedTheme.primaryTextColor(for: colorScheme) : selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3))
                    .frame(width: 28, height: 28)
                    .background(selectedTheme.titleBarColor(for: colorScheme))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(disabled || channel >= 16)
        }
    }

    private func validateAndUpdate() {
        if let value = Int(textValue), value >= 1, value <= 16 {
            channel = value
        } else {
            textValue = "\(channel)"
        }
    }
}

// MARK: - CC Number Picker (Stepper + TextField)
struct CCNumberPicker: View {
    let title: String
    @Binding var ccNumber: Int
    let disabled: Bool
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))

            Spacer()

            // Minus button
            Button(action: {
                if ccNumber > 0 {
                    ccNumber -= 1
                }
            }) {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ccNumber > 0 && !disabled ? selectedTheme.primaryTextColor(for: colorScheme) : selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3))
                    .frame(width: 28, height: 28)
                    .background(selectedTheme.titleBarColor(for: colorScheme))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(disabled || ccNumber <= 0)

            // Text field
            TextField("", text: $textValue)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .frame(width: 50)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(selectedTheme.backgroundColor(for: colorScheme))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isFocused ? selectedTheme.accentColor(for: colorScheme) : selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3), lineWidth: 1)
                )
                .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                .disabled(disabled)
                .keyboardType(.numberPad)
                .onAppear {
                    textValue = "\(ccNumber)"
                }
                .onChange(of: ccNumber) { _, newValue in
                    if !isFocused {
                        textValue = "\(newValue)"
                    }
                }
                .onSubmit {
                    validateAndUpdate()
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        validateAndUpdate()
                    }
                }
                .onTapGesture {
                    isFocused = true
                }

            // Plus button
            Button(action: {
                if ccNumber < 127 {
                    ccNumber += 1
                }
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ccNumber < 127 && !disabled ? selectedTheme.primaryTextColor(for: colorScheme) : selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3))
                    .frame(width: 28, height: 28)
                    .background(selectedTheme.titleBarColor(for: colorScheme))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(disabled || ccNumber >= 127)
        }
    }

    private func validateAndUpdate() {
        if let value = Int(textValue), value >= 0, value <= 127 {
            ccNumber = value
        } else {
            textValue = "\(ccNumber)"
        }
    }
}

// MARK: - Control Button Editor (moved outside ContentView for scope)
struct CBControlEditorSheet: View {
    @Binding var editing: ControlButton?
    let conflictFor: [MIDIKey: String]
    var currentOwnerName: (MIDIKey) -> String?
    @Binding var pendingIsFader: Bool?
    let isGlobalChannel: Bool
    let globalChannel: Int
    @AppStorage("midiFiltersEnabled") private var midiFiltersEnabled: Bool = true
    let midiFilter: Set<Int>
    var onSave: (ControlButton, Bool) -> Void  // Added Bool parameter for andAddAnother
    var onCancel: () -> Void
    var onDelete: ((ControlButton) -> Void)? = nil
    var allButtons: [ControlButton] = []  // All control buttons for space validation
    var columns: Int = 8  // Grid column count
    let icons: [String]
    var isEditMode: Bool = false  // Explicit flag: true for editing existing control, false for adding new
    @Binding var canAddMore: Bool  // Whether grid has room for more controls
    @Binding var flashNewForm: Bool  // Visual feedback for "Save & Add Another"

    // v1.0.8: Use ObservedObject draft to preserve edits across sheet dismissals
    @ObservedObject var draft: ControlEditorDraft

    // Color picker inline state
    @State private var showColorPicker = false
    @State private var showPreview = false

    @State private var showDeleteAlert: Bool = false
    @State private var showGlobalModeMaxReachedAlert: Bool = false
    private enum ControlType: String, CaseIterable, Identifiable { case button, fader; var id: String { rawValue } }
    private enum ButtonType: String, CaseIterable, Identifiable { case regular, small; var id: String { rawValue } }
    // UI-only state (not persisted in draft)
    @State private var controlType: ControlType = .button
    @State private var buttonType: ButtonType = .regular
    @State private var showSpaceWarning: Bool = false
    @State private var isOutOfRoom: Bool = false

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""
    @AppStorage("autoAssignMIDI") private var savedAutoAssign: Bool = true

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    // MARK: - Space Validation Helpers

    // Local GridRect helper for space validation
    private struct GridRectHelper {
        let col: Int
        let row: Int
        let width: Int
        let height: Int
    }

    /// Validates if the control with new dimensions can fit in the grid
    /// Returns true if it fits, false if no space is available
    private func validateSpaceForOrientation() -> Bool {
        guard let editingButton = editing else { return true }

        // Calculate what the new dimensions would be based on control type
        let newWidth: Int
        let newHeight: Int

        if editingButton.isFader == true {
            // Fader dimensions depend on orientation (use draft state)
            newWidth = (draft.faderOrientation == "horizontal") ? 2 : 1
            newHeight = (draft.faderOrientation == "horizontal") ? 1 : 2
        } else {
            // Button dimensions depend on button type (use UI state)
            newWidth = (buttonType == .small) ? 1 : 2
            newHeight = 1
        }

        // If dimensions haven't changed, no validation needed
        if newWidth == editingButton.gridWidth && newHeight == editingButton.gridHeight {
            return true
        }

        // Check if the current position still works with new dimensions
        if let col = editingButton.gridCol, let row = editingButton.gridRow {
            if col + newWidth <= columns && canFitAtPosition(col: col, row: row, width: newWidth, height: newHeight, excluding: editingButton.id) {
                return true  // Current position still works (grow right)
            }

            // For buttons growing wider (small → regular): only allow same-row expansion
            if editingButton.isFader != true && newWidth > editingButton.gridWidth {
                // Try growing left: shift col-1
                if col - 1 >= 0 && canFitAtPosition(col: col - 1, row: row, width: newWidth, height: newHeight, excluding: editingButton.id) {
                    return true
                }
                return false  // Can't grow on this row — don't search elsewhere
            }
        }

        // Fader orientation changes can search the full grid
        return findAvailablePosition(width: newWidth, height: newHeight, excluding: editingButton.id) != nil
    }

    /// Checks if a control can fit at a specific position
    private func canFitAtPosition(col: Int, row: Int, width: Int, height: Int, excluding excludeId: UUID) -> Bool {
        // Check bounds
        if col < 0 || row < 0 || col + width > columns {
            return false
        }

        // Check for overlaps with other buttons
        let testRect = GridRectHelper(col: col, row: row, width: width, height: height)

        for button in allButtons where button.id != excludeId {
            guard let bCol = button.gridCol, let bRow = button.gridRow else { continue }
            let buttonRect = GridRectHelper(col: bCol, row: bRow, width: button.gridWidth, height: button.gridHeight)
            if rectsOverlap(testRect, buttonRect) {
                return false
            }
        }

        return true
    }

    /// Finds an available position for the given dimensions
    private func findAvailablePosition(width: Int, height: Int, excluding excludeId: UUID) -> (col: Int, row: Int)? {
        let maxSearchRows = 4  // Match the display limit of 4 rows

        for row in 0..<maxSearchRows {
            for col in 0...(columns - width) {
                if canFitAtPosition(col: col, row: row, width: width, height: height, excluding: excludeId) {
                    return (col, row)
                }
            }
        }

        return nil
    }

    /// Checks if two grid rectangles overlap
    private func rectsOverlap(_ r1: GridRectHelper, _ r2: GridRectHelper) -> Bool {
        let r1Right = r1.col + r1.width
        let r1Bottom = r1.row + r1.height
        let r2Right = r2.col + r2.width
        let r2Bottom = r2.row + r2.height

        return !(r1Right <= r2.col || r2Right <= r1.col || r1Bottom <= r2.row || r2Bottom <= r1.row)
    }

    /// Validates if there's space available for adding a new control
    /// Returns true if space is available, false if grid is full
    private func validateSpaceForAddMode() -> Bool {
        // Only validate when adding new controls (title is empty)
        guard let editingButton = editing else { return true }
        guard editingButton.title.isEmpty else { return true }  // Edit mode - already has space

        // Calculate dimensions based on control type and orientation
        let width: Int
        let height: Int

        if controlType == .fader {
            // Use draft state for fader orientation
            width = (draft.faderOrientation == "horizontal") ? 2 : 1
            height = (draft.faderOrientation == "horizontal") ? 1 : 2
        } else {
            // Button - check button type (UI state)
            if buttonType == .small {
                width = 1
                height = 1
            } else {
                // Regular button
                width = 2
                height = 1
            }
        }

        // Try to find any available position with these dimensions
        // Use UUID.zero as the excludeId since this is a new control
        return findAvailablePosition(width: width, height: height, excluding: UUID()) != nil
    }

    // FIX #8: Combined validation function to reduce overhead
    private func validateSpaceForOrientationAndAddMode() -> (orientationValid: Bool, addModeValid: Bool) {
        return (validateSpaceForOrientation(), validateSpaceForAddMode())
    }

    /// Returns the appropriate out-of-room message based on control type
    private func outOfRoomMessage() -> String {
        let controlName: String
        if controlType == .fader {
            controlName = "Fader"
        } else {
            controlName = buttonType == .small ? "Small Button" : "Button"
        }
        return "Out of room! Remove a controller first to add this \(controlName) to your control area."
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom header — bypasses iOS 18+/26 toolbar chrome and gesture caching
                ZStack {
                    Text(titleForSheet())
                        .font(.custom("Sora-Bold", size: 17))
                        .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))

                    HStack(spacing: 8) {
                        CBSheetButton(title: "Cancel") {
                            draft.clear()
                            onCancel()
                        }
                        Spacer()
                        let isDisabled = isOutOfRoom || (midiFiltersEnabled && conflictOwner() != nil) || (midiFiltersEnabled && isFilteredMIDI())
                        CBSheetIconMenu(systemName: "ellipsis") {
                            if !isEditMode {
                                Button {
                                    saveControl(andAddAnother: true)
                                } label: {
                                    Label("Save & Add Another", systemImage: "plus")
                                }
                                .disabled(isDisabled)
                            } else {
                                if onDelete != nil {
                                    Button(role: .destructive) {
                                        showDeleteAlert = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        CBSheetIconButton(systemName: "checkmark", disabled: isDisabled) {
                            saveControl(andAddAnother: false)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

                Form {
                    // Out of room warning - shown at top for maximum visibility
                    if isOutOfRoom {
                        Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(selectedTheme.errorColor(for: colorScheme))
                            Text(outOfRoomMessage())
                                .font(.caption)
                                .foregroundColor(selectedTheme.errorColor(for: colorScheme))
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                    }
                }

                Section(header: Text("Appearance")) {
                    // Control type is preselected by the add buttons; hide the picker
                    HStack {
                        TextField("Control Name", text: $draft.title, prompt: Text("Control Name").foregroundColor(.secondary))
                        if !draft.title.isEmpty {
                            Button(action: { draft.title = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))

                    // Button Type picker - only show for buttons (not faders)
                    if !draft.isFader {
                        Picker("Button Type", selection: Binding(
                            get: { draft.isSmall ? ButtonType.small : ButtonType.regular },
                            set: { draft.isSmall = ($0 == .small) }
                        )) {
                            Text("Button").tag(ButtonType.regular)
                            Text("Small Button").tag(ButtonType.small)
                        }
                        .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                        .tint(selectedTheme.secondaryTextColor(for: colorScheme))
                        .foregroundStyle(selectedTheme.primaryTextColor(for: colorScheme))

                        // Show space warning if button type change won't fit
                        if showSpaceWarning {
                            Text("You're out of room! Try removing other controllers to change button size")
                                .font(.caption)
                                .foregroundColor(selectedTheme.errorColor(for: colorScheme))
                                .padding(.top, 4)
                                .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                        }
                    }

                    if !draft.isFader {
                        IconPicker(symbol: $draft.symbol, icons: icons)
                            .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                        Picker("Behavior", selection: $draft.isToggle) {
                            Text("Momentary").tag(false)
                            Text("Toggle").tag(true)
                        }
                        .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                        .tint(selectedTheme.secondaryTextColor(for: colorScheme))
                        .foregroundStyle(selectedTheme.primaryTextColor(for: colorScheme))
                    }

                    // Fader orientation and direction (only for faders)
                    if draft.isFader {
                        Picker("Fader Orientation", selection: $draft.faderOrientation) {
                            Text("Vertical").tag("vertical")
                            Text("Horizontal").tag("horizontal")
                        }
                        .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                        .tint(selectedTheme.secondaryTextColor(for: colorScheme))
                        .foregroundStyle(selectedTheme.primaryTextColor(for: colorScheme))

                        Picker("Fader Direction", selection: $draft.faderDirection) {
                            // Vertical faders: only up/down
                            if draft.faderOrientation == "vertical" {
                                Text("Up").tag("up")
                                Text("Down").tag("down")
                            }
                            // Horizontal faders: only left/right
                            else if draft.faderOrientation == "horizontal" {
                                Text("Left").tag("left")
                                Text("Right").tag("right")
                            }
                        }
                        .id("fader-direction-picker")
                        .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                        .tint(selectedTheme.secondaryTextColor(for: colorScheme))
                        .foregroundStyle(selectedTheme.primaryTextColor(for: colorScheme))

                        // Show space warning if orientation change won't fit
                        if showSpaceWarning {
                            Text("You're out of room! Try removing other controllers to add this one")
                                .font(.caption)
                                .foregroundColor(selectedTheme.errorColor(for: colorScheme))
                                .padding(.top, 4)
                                .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                        }
                    }

                    // Color Picker - Inline Disclosure
                    DisclosureGroup(
                        isExpanded: $showColorPicker,
                        content: {
                            // Inline color picker
                            CBColorPickerInline(selectedColorHex: $draft.colorHex)
                                .padding(.vertical, 8)
                        },
                        label: {
                            HStack {
                                Text("Color")
                                Spacer()
                                if let hex = draft.colorHex {
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
                // Live Preview - Collapsible
                Section {
                    DisclosureGroup(
                        isExpanded: $showPreview,
                        content: {
                            HStack {
                                Spacer(minLength: 0)
                                if draft.isFader {
                                    ControlFaderPreview(title: draft.title, cc: draft.number, channel: draft.channel, orientation: draft.faderOrientation, direction: draft.faderDirection, colorHex: draft.colorHex)
                                        .id("fader-\(draft.faderOrientation)-\(draft.faderDirection)")
                                } else {
                                    ControlButtonPreview(title: draft.title, symbol: draft.symbol, kind: draft.kind, number: draft.number, channel: draft.channel, velocity: draft.velocity, isSmall: draft.isSmall, colorHex: draft.colorHex)
                                        .id("button-\(draft.isSmall)")
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 6)
                        },
                        label: {
                            Text("Preview")
                        }
                    )
                    .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                }
                Section(header: Text("MIDI")) {
                    if midiFiltersEnabled && !midiFilter.isEmpty {
                        Text("Some MIDI values are unavailable because MIDI filters are enabled. Go to MIDI Settings to change this.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                    }
                    Toggle(isOn: Binding(
                        get: { draft.autoAssign },
                        set: { newValue in savedAutoAssign = newValue; draft.autoAssign = newValue }
                    )) {
                        Text("Assign MIDI automatically")
                    }
                    .toggleStyle(SwitchToggleStyle(tint: selectedTheme.successColor(for: colorScheme)))
                    .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                    if !draft.isFader {
                        Picker("Type", selection: $draft.kind) {
                            Text("Control Change").tag(MIDIKind.cc)
                            Text("Note").tag(MIDIKind.note)
                        }
                        .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                        .tint(selectedTheme.secondaryTextColor(for: colorScheme))
                        .foregroundStyle(selectedTheme.primaryTextColor(for: colorScheme))
                    }
                    if isGlobalChannel {
                        HStack {
                            Text("Channel")
                            Spacer()
                            Text("\(globalChannel) (Global Channel)")
                                .foregroundColor(.secondary)
                        }
                        .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                    } else {
                        ChannelPicker(title: "Channel", channel: $draft.channel, disabled: false)
                            .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                    }
                    MIDINumberPicker(
                        kind: draft.kind,
                        number: $draft.number,
                        disabled: draft.autoAssign,
                        channel: isGlobalChannel ? globalChannel : draft.channel,
                        currentOwnerName: currentOwnerName,
                        editingControl: editing,
                        midiFilter: midiFilter
                    )
                    .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                    if !draft.isFader && draft.kind == .note {
                        VelocityPicker(velocity: $draft.velocity, disabled: false)
                            .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                    }
                }

            }
            .scrollContentBackground(.hidden)
            .background(selectedTheme.backgroundColor(for: colorScheme))
            }
            .background(selectedTheme.backgroundColor(for: colorScheme))
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .tint(selectedTheme.accentColor(for: colorScheme))
            .cbDialog("Delete Control", isPresented: $showDeleteAlert, themeFont: selectedTheme.font,
                message: "Are you sure you want to delete this \(controlType == .fader ? "fader" : (buttonType == .small ? "small button" : "button"))? This action cannot be undone.",
                buttons: [
                    .init("Delete", role: .destructive) {
                        if let control = editing {
                            onDelete?(control)
                        }
                    },
                    .init("Cancel", role: .cancel) { }
                ]
            )
            .cbDialog("Maximum Controls Reached", isPresented: $showGlobalModeMaxReachedAlert, themeFont: selectedTheme.font,
                message: "You've reached the maximum of 127 controls in Global MIDI Channel mode. Turn off Global MIDI Channel mode to continue auto-assigning on additional channels.",
                buttons: [
                    .init("OK", role: .primary) { }
                ]
            )
            .onAppear {
                preset()
                // Validate space for add mode on sheet open
                isOutOfRoom = !validateSpaceForAddMode()
            }
            .onChange(of: editing) { oldValue, newValue in
                // When editing changes (especially when set to nil for "Add Another"),
                // re-run preset to ensure form is properly initialized
                if oldValue != nil && newValue == nil {
                    preset()
                    isOutOfRoom = !validateSpaceForAddMode()
                }
            }
            .onChange(of: draft.autoAssign) { _, newValue in
                if newValue {
                    let result = autoAssignMIDI(for: draft.kind, startChannel: draft.channel, startNumber: 0)
                    if result.reachedLimit {
                        showGlobalModeMaxReachedAlert = true
                        draft.autoAssign = false  // Turn off auto-assign since we hit the limit
                    } else {
                        draft.channel = result.channel
                        draft.number = result.number
                    }
                }
            }
            .onChange(of: draft.kind) { _, newValue in
                if draft.autoAssign {
                    let result = autoAssignMIDI(for: newValue, startChannel: draft.channel, startNumber: 0)
                    if result.reachedLimit {
                        showGlobalModeMaxReachedAlert = true
                        draft.autoAssign = false
                    } else {
                        draft.channel = result.channel
                        draft.number = result.number
                    }
                }
            }
            .onChange(of: draft.channel) { _, newValue in
                if draft.autoAssign {
                    let result = autoAssignMIDI(for: draft.kind, startChannel: newValue, startNumber: 0)
                    if result.reachedLimit {
                        showGlobalModeMaxReachedAlert = true
                        draft.autoAssign = false
                    } else {
                        draft.channel = result.channel
                        draft.number = result.number
                    }
                }
            }
            .onChange(of: controlType) { _, newType in
                if newType == .fader { draft.kind = .cc }
                pendingIsFader = (newType == .fader)
                // Re-validate space when control type changes
                isOutOfRoom = !validateSpaceForAddMode()
            }
            .onChange(of: draft.faderOrientation) { _, newOrientation in
                // Auto-set appropriate direction when orientation changes
                if newOrientation == "vertical" && (draft.faderDirection == "left" || draft.faderDirection == "right") {
                    draft.faderDirection = "up"
                } else if newOrientation == "horizontal" && (draft.faderDirection == "up" || draft.faderDirection == "down") {
                    draft.faderDirection = "right"
                }

                // FIX #8: Combine validation calls to reduce overhead
                let validationResults = validateSpaceForOrientationAndAddMode()
                showSpaceWarning = !validationResults.orientationValid
                isOutOfRoom = !validationResults.addModeValid
            }
            .onChange(of: buttonType) { _, newType in
                // Validate space when button type changes (regular <-> small)
                let validationResults = validateSpaceForOrientationAndAddMode()
                showSpaceWarning = !validationResults.orientationValid
                isOutOfRoom = !validationResults.addModeValid
            }
        }
        .preferredColorScheme(selectedTheme.preferredColorScheme(for: colorScheme))
    }

    private func preset() {
        debugPrint("📋 [CONTROL] preset() called, editing: \(editing != nil ? "exists" : "nil"), isEditMode: \(isEditMode)")
        if let b = editing {
            // v1.0.8: Check if draft has been modified from the original control
            // If draft matches original, load from control (first open or after cancel)
            // If draft differs from original, preserve draft (user made changes and tapped outside)
            let draftMatchesOriginal = (
                draft.title == b.title &&
                draft.symbol == b.symbol &&
                draft.kind == b.kind &&
                draft.number == b.number &&
                draft.channel == b.channel
            )

            if draftMatchesOriginal || draft.title.isEmpty {
                // Draft is empty or matches original - safe to load from editing button
                debugPrint("  📝 [CONTROL] Loading from editing button (isEditMode=\(isEditMode), draftMatchesOriginal=\(draftMatchesOriginal))")
                draft.loadFrom(control: b)
            } else {
                // Draft has user modifications - preserve them
                debugPrint("  💾 [CONTROL] Preserving modified draft content, NOT loading from editing button")
            }

            // Determine control type from button properties (for UI-only state)
            if b.isFader == true {
                controlType = .fader
            } else {
                controlType = .button
                buttonType = (b.isSmall == true) ? .small : .regular
            }

            if isEditMode {
                draft.autoAssign = false  // editing existing control — preserve its MIDI, don't auto-assign
            } else {
                // ADD mode: auto-assign only if draft was just loaded from template
                if draftMatchesOriginal || draft.title.isEmpty {
                    draft.autoAssign = savedAutoAssign
                    if savedAutoAssign {
                        let nextChannel = isGlobalChannel ? globalChannel : draft.channel
                        let result = autoAssignMIDI(for: draft.kind, startChannel: nextChannel, startNumber: 0)
                        if result.reachedLimit {
                            showGlobalModeMaxReachedAlert = true
                            draft.autoAssign = false
                        } else {
                            draft.channel = result.channel
                            draft.number = result.number
                            debugPrint("  ✅ [CONTROL] ADD mode - set autoAssign=\(savedAutoAssign), channel=\(result.channel), number=\(result.number)")
                        }
                    }
                } else {
                    debugPrint("  ✅ [CONTROL] ADD mode - preserving draft autoAssign=\(draft.autoAssign)")
                }
            }
        } else {
            // v1.0.8: Clear draft for new control
            // Check if this is "Add Another" by seeing if number is already set to a valid value
            if draft.number > 0 {
                // "Add Another" already set the correct number - DON'T recalculate!
                debugPrint("  🎯 [CONTROL] Number already set by 'Add Another': \(draft.number), skipping recalculation")
                return
            }

            // This is a fresh "Add Control" (not "Add Another")
            draft.clear()
            draft.autoAssign = savedAutoAssign
            // FIX: Use global channel if enabled, otherwise default to 1
            let nextChannel = isGlobalChannel ? globalChannel : 1
            debugPrint("  🆕 [CONTROL] No editing state, finding free number for \(draft.kind) ch\(nextChannel)")
            if savedAutoAssign {
                let result = autoAssignMIDI(for: draft.kind, startChannel: nextChannel, startNumber: 0)
                if result.reachedLimit {
                    showGlobalModeMaxReachedAlert = true
                    draft.autoAssign = false
                } else {
                    draft.channel = result.channel
                    draft.number = result.number
                    debugPrint("  ✅ [CONTROL] preset() set channel=\(result.channel), number=\(result.number)")
                }
            } else {
                draft.channel = nextChannel
            }
        }
    }

    private func titleForSheet() -> String {
        // Check if we're adding a new control or editing existing (use explicit mode flag)
        let isAddingNew = !isEditMode

        if isAddingNew {
            // Adding new control - show specific type
            if controlType == .fader {
                return "Add Fader"
            } else {
                return buttonType == .small ? "Add Small Button" : "Add Button"
            }
        } else {
            // Editing existing control - show specific type
            if controlType == .fader {
                return "Edit Fader"
            } else {
                return buttonType == .small ? "Edit Small Button" : "Edit Button"
            }
        }
    }

    private func conflictOwner() -> String? {
        // If we're editing an existing control and the MIDI assignment hasn't changed, no conflict
        if let edit = editing, edit.kind == draft.kind, edit.channel == draft.channel, edit.number == draft.number {
            return nil
        }
        let key = MIDIKey(kind: draft.kind, channel: draft.channel, number: draft.number)
        guard let ownersString = currentOwnerName(key) else { return nil }

        // Filter out the current control's name if editing
        if let edit = editing {
            let editDisplayName: String
            if edit.isFader == true {
                editDisplayName = edit.title.isEmpty ? "Fader" : "Fader: \(edit.title)"
            } else {
                editDisplayName = edit.title.isEmpty ? "Button" : "Button: \(edit.title)"
            }
            return filterOwnerName(ownersString, excluding: editDisplayName)
        }

        return ownersString
    }

    private func ownerFor(kind: MIDIKind, number: Int, channel: Int) -> String? {
        // If we're editing an existing control and checking its current MIDI assignment, no conflict
        if let edit = editing, edit.kind == kind, edit.channel == channel, edit.number == number {
            return nil
        }
        let key = MIDIKey(kind: kind, channel: channel, number: number)
        guard let ownersString = currentOwnerName(key) else { return nil }

        // Filter out the current control's name if editing
        if let edit = editing {
            let editDisplayName: String
            if edit.isFader == true {
                editDisplayName = edit.title.isEmpty ? "Fader" : "Fader: \(edit.title)"
            } else {
                editDisplayName = edit.title.isEmpty ? "Button" : "Button: \(edit.title)"
            }
            return filterOwnerName(ownersString, excluding: editDisplayName)
        }

        return ownersString
    }

    private func filterOwnerName(_ ownersString: String, excluding excludeName: String) -> String? {
        // Check if the owners string contains the separator (multiple owners)
        if ownersString.contains("|||") {
            // Multiple owners - need to filter
            let owners = ownersString.split(separator: "|||").map(String.init).filter { $0 != excludeName }
            guard !owners.isEmpty else { return nil }
            if owners.count == 1 {
                return owners[0]
            } else if owners.count == 2 {
                return "\(owners[0]) and \(owners[1])"
            } else {
                return owners.dropLast().joined(separator: ", ") + ", and " + owners.last!
            }
        } else if ownersString == excludeName {
            // Single owner and it's us
            return nil
        }
        return ownersString
    }

    private func isFilteredMIDI() -> Bool {
        return midiFiltersEnabled && !midiFilter.isEmpty && draft.kind == .cc && midiFilter.contains(draft.number)
    }

    private func assignFreeNumber() {
        draft.number = firstFreeNumber(for: draft.kind, channel: draft.channel)
    }

    // Result type for auto-assign with channel increment support
    private struct AutoAssignResult {
        let channel: Int
        let number: Int
        let reachedLimit: Bool  // true if hit 127 in global mode
    }

    // New auto-assign function that can increment channel when reaching 127
    private func autoAssignMIDI(for kind: MIDIKind, startChannel: Int, startNumber: Int = 0) -> AutoAssignResult {
        debugPrint("🔍 [CONTROL] Auto-assigning \(kind) starting from channel \(startChannel), number \(startNumber)")

        // In global mode, we can't increment channel
        if isGlobalChannel {
            // Search only on the global channel
            for n in startNumber...127 {
                // Skip filtered CC numbers only when filters are enabled
                if midiFiltersEnabled && kind == .cc && midiFilter.contains(n) {
                    debugPrint("  🚫 [CONTROL] CC \(n) is filtered, skipping")
                    continue
                }

                let key = MIDIKey(kind: kind, channel: globalChannel, number: n)
                let owner = currentOwnerName(key)
                if owner != nil {
                    // Skip if occupied by a different control
                    if let edit = editing, edit.kind == kind, edit.channel == globalChannel, edit.number == n {
                        debugPrint("  ✓ [CONTROL] \(n) is taken by editing control, available")
                        debugPrint("  ✅ [CONTROL] Assigned: channel \(globalChannel), number \(n)")
                        return AutoAssignResult(channel: globalChannel, number: n, reachedLimit: false)
                    } else {
                        debugPrint("  ✗ [CONTROL] \(n) is taken by '\(owner!)', skipping")
                        continue
                    }
                }
                debugPrint("  ✅ [CONTROL] Assigned: channel \(globalChannel), number \(n)")
                return AutoAssignResult(channel: globalChannel, number: n, reachedLimit: false)
            }
            // Reached limit in global mode
            debugPrint("  ⚠️ [CONTROL] Reached limit of 127 in global mode")
            return AutoAssignResult(channel: globalChannel, number: 0, reachedLimit: true)
        }

        // Non-global mode: can increment channel when reaching 127
        var currentChannel = startChannel
        var currentNumber = startNumber

        // Try up to 16 channels
        for _ in 0..<16 {
            // Search from currentNumber to 127 on current channel
            for n in currentNumber...127 {
                // Skip filtered CC numbers only when filters are enabled
                if midiFiltersEnabled && kind == .cc && midiFilter.contains(n) {
                    debugPrint("  🚫 [CONTROL] CC \(n) is filtered, skipping")
                    continue
                }

                let key = MIDIKey(kind: kind, channel: currentChannel, number: n)
                let owner = currentOwnerName(key)
                if owner != nil {
                    // Skip if occupied by a different control
                    if let edit = editing, edit.kind == kind, edit.channel == currentChannel, edit.number == n {
                        debugPrint("  ✓ [CONTROL] \(n) is taken by editing control, available")
                        debugPrint("  ✅ [CONTROL] Assigned: channel \(currentChannel), number \(n)")
                        return AutoAssignResult(channel: currentChannel, number: n, reachedLimit: false)
                    } else {
                        debugPrint("  ✗ [CONTROL] \(n) is taken by '\(owner!)', skipping")
                        continue
                    }
                }
                debugPrint("  ✅ [CONTROL] Assigned: channel \(currentChannel), number \(n)")
                return AutoAssignResult(channel: currentChannel, number: n, reachedLimit: false)
            }

            // Reached end of current channel, increment and start from 0
            debugPrint("  🔄 [CONTROL] Channel \(currentChannel) full, moving to channel \(currentChannel + 1)")
            currentChannel += 1
            if currentChannel > 16 {
                currentChannel = 1  // Wrap around
            }
            currentNumber = 0  // Reset to start of new channel
        }

        // Exhausted all channels (unlikely but handle it)
        debugPrint("  ⚠️ [CONTROL] No free slots found across all channels")
        return AutoAssignResult(channel: startChannel, number: 0, reachedLimit: false)
    }

    // Legacy function for compatibility - uses new auto-assign logic
    private func firstFreeNumber(for kind: MIDIKind, channel: Int) -> Int {
        let result = autoAssignMIDI(for: kind, startChannel: channel, startNumber: 0)
        return result.number
    }

    private func firstFreeNumberStartingFrom(_ start: Int, for kind: MIDIKind, channel: Int) -> Int {
        let result = autoAssignMIDI(for: kind, startChannel: channel, startNumber: start)
        return result.number
    }

    private func saveControl(andAddAnother: Bool) {
        var b = editing ?? ControlButton(title: "", symbol: "square.grid.2x2.fill", kind: .cc, number: 0, channel: 1, velocity: 127, isToggle: nil)
        b.title = draft.title
        b.symbol = draft.symbol
        b.kind = (controlType == .fader) ? .cc : draft.kind
        b.number = draft.number
        // Use global channel if enabled, otherwise use the selected channel
        b.channel = isGlobalChannel ? globalChannel : draft.channel
        b.velocity = draft.velocity
        b.isToggle = draft.isToggle
        b.isFader = (controlType == .fader)
        b.colorHex = draft.colorHex

        // Auto-name only for NEW buttons (not when editing existing ones)
        // This allows users to explicitly set empty titles for icon-only buttons
        if b.title.trimmingCharacters(in: .whitespaces).isEmpty && editing == nil {
            if controlType == .fader {
                // Count existing faders
                let faderCount = allButtons.filter { $0.isFader == true && $0.id != b.id }.count
                b.title = "Fader \(faderCount + 1)"
            } else {
                // Count existing buttons
                let buttonCount = allButtons.filter { $0.isFader != true && $0.id != b.id }.count
                b.title = "Button \(buttonCount + 1)"
            }
        }

        debugPrint("💾 Saving control '\(b.title)' with colorHex: \(draft.colorHex ?? "nil")")
        // v1.0.9: Set isSmall from draft (picker updates draft.isSmall directly)
        if controlType != .fader {
            b.isSmall = draft.isSmall
        }

        // Save fader orientation and direction (only for faders)
        if controlType == .fader {
            b.faderOrientation = draft.faderOrientation
            b.faderDirection = draft.faderDirection

            // Check if we need to reposition due to orientation change
            if let originalButton = editing, originalButton.isFader == true {
                let oldWidth = originalButton.gridWidth
                let oldHeight = originalButton.gridHeight
                let newWidth = b.gridWidth
                let newHeight = b.gridHeight

                // If dimensions changed, check if we need to reposition
                if oldWidth != newWidth || oldHeight != newHeight {
                    if let col = b.gridCol, let row = b.gridRow {
                        // Check if current position still works
                        if !canFitAtPosition(col: col, row: row, width: newWidth, height: newHeight, excluding: b.id) {
                            // Need to find a new position
                            if let newPos = findAvailablePosition(width: newWidth, height: newHeight, excluding: b.id) {
                                b.gridCol = newPos.col
                                b.gridRow = newPos.row
                                debugPrint("🔄 Repositioned fader from (\(col), \(row)) to (\(newPos.col), \(newPos.row)) due to orientation change")
                            } else {
                                // This shouldn't happen if validation is working correctly
                                debugPrint("⚠️ No position found for fader - this shouldn't happen!")
                            }
                        }
                    }
                }
            }
        } else {
            // Check if we need to reposition due to button type change (regular <-> small)
            if let originalButton = editing, originalButton.isFader != true {
                let oldWidth = originalButton.gridWidth
                let newWidth = b.gridWidth
                let newHeight = b.gridHeight

                // If growing wider (small → regular), use same-row right-first, left-second logic
                if newWidth > oldWidth {
                    if let col = b.gridCol, let row = b.gridRow {
                        if canFitAtPosition(col: col, row: row, width: newWidth, height: newHeight, excluding: b.id) {
                            // Grow right — position stays the same
                            debugPrint("🔄 Button growing right at (\(col), \(row))")
                        } else if col - 1 >= 0 && canFitAtPosition(col: col - 1, row: row, width: newWidth, height: newHeight, excluding: b.id) {
                            // Grow left — shift col by -1
                            b.gridCol = col - 1
                            debugPrint("🔄 Button growing left from (\(col), \(row)) to (\(col - 1), \(row))")
                        } else {
                            debugPrint("⚠️ No room to grow button - validation should have prevented this")
                        }
                    }
                }
                // Shrinking (regular → small): keep current position, no reposition needed
            }
        }

        onSave(b, andAddAnother)

        if andAddAnother {
            debugPrint("➕ [CONTROL] Save & Add Another clicked")

            // v1.0.8: Reset draft for next control

            // Calculate next channel and number BEFORE resetting draft
            debugPrint("  🔢 [CONTROL] Calculating next free number BEFORE resetting draft")
            let nextChannel = isGlobalChannel ? globalChannel : 1
            let savedNumber = b.number
            let savedKind = b.kind

            // Clear draft to defaults
            draft.clear()

            // v1.0.8: Preserve MIDI kind (CC vs Note) for "Add Another"
            // This ensures next control uses same MIDI type as the one just saved
            draft.kind = savedKind

            // Preserve fader state if we're adding faders
            if controlType == .fader {
                draft.isFader = true
                // Fader orientation and direction are preserved from previous draft values
                draft.faderOrientation = b.faderOrientation ?? "vertical"
                draft.faderDirection = b.faderDirection ?? "up"
            } else {
                // Preserve button size if we're adding buttons
                draft.isSmall = b.isSmall ?? false
                draft.isToggle = b.isToggle ?? false
            }

            // Set channel and find next free number (with channel increment if needed)
            draft.autoAssign = savedAutoAssign
            if savedAutoAssign {
                // FIX: After saving, find next free number starting from the one we just saved + 1
                let result = autoAssignMIDI(for: savedKind, startChannel: nextChannel, startNumber: savedNumber + 1)
                if result.reachedLimit {
                    showGlobalModeMaxReachedAlert = true
                    draft.autoAssign = false
                    draft.channel = nextChannel
                    draft.number = 0
                } else {
                    draft.channel = result.channel
                    draft.number = result.number
                    debugPrint("  ✅ [CONTROL] Set kind=\(savedKind), channel=\(result.channel), number=\(result.number)")
                }
            } else {
                draft.channel = nextChannel
                draft.number = 0
            }

            // NOW set editing to nil (triggers .onChange which calls preset())
            debugPrint("  🔄 [CONTROL] Setting editing=nil (will trigger .onChange)")
            editing = nil

            // Recalculate space validation after reset
            isOutOfRoom = !validateSpaceForAddMode()
        } else {
            // Why: shared draft persists across sheet presentations. Without clearing,
            // a subsequent edit of a different control sees a non-empty, non-matching
            // draft and preset() chooses to preserve it — so button B opens showing
            // button A's title/MIDI. The next save then writes A's data into B's slot.
            draft.clear()
        }
    }

    // Recompute when auto-assign is enabled or MIDI type/channel changes
}

// MARK: - MIDI Note Helper
extension Int {
    var midiNoteName: String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (self / 12) - 2
        let noteIndex = self % 12
        return "\(noteNames[noteIndex])\(octave)"
    }
}

// MARK: - Edit Control Sheet (separate from Add Control)
struct CBEditControlSheet: View {
    @Binding var editing: ControlButton?
    let conflictFor: [MIDIKey: String]
    var currentOwnerName: (MIDIKey) -> String?
    var onSave: (ControlButton) -> Void
    var onCancel: () -> Void
    var onDelete: ((ControlButton) -> Void)? = nil
    let icons: [String]
    @AppStorage("midiFiltersEnabled") private var midiFiltersEnabled: Bool = true
    let midiFilter: Set<Int>

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""
    @AppStorage("autoAssignMIDI") private var savedAutoAssign: Bool = true

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    @State private var title: String = ""
    @State private var symbol: String = "square.grid.2x2.fill"
    @State private var kind: MIDIKind = .cc
    @State private var number: Int = 0
    @State private var channel: Int = 1
    @State private var velocity: Int = 127
    @State private var autoAssign: Bool = true
    @State private var isToggle: Bool = false
    @State private var isFaderUI: Bool = false
    @State private var isSmall: Bool = false  // Track small button state for preview
    @State private var showDeleteAlert: Bool = false
    // Fader orientation and direction
    @State private var faderOrientation: String = "vertical"
    @State private var faderDirection: String = "up"
    @State private var colorHex: String? = nil  // Custom color for button/fader
    @State private var showColorPicker: Bool = false
    @State private var showPreview: Bool = false
    @State private var userDismissedExplicitly: Bool = false  // v1.0.8: Track Save/Cancel clicks

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Appearance")) {
                    // Control type is not editable - just show what it is
                    HStack {
                        Text("Control Type")
                        Spacer()
                        Text(isFaderUI ? "Fader" : "Button")
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                    if !isFaderUI {
                        Toggle("Small Button", isOn: $isSmall)
                            .toggleStyle(SwitchToggleStyle(tint: selectedTheme.successColor(for: colorScheme)))
                            .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                    }
                    HStack {
                        TextField("Control Name", text: $title, prompt: Text("Control Name").foregroundColor(.secondary))
                        if !title.isEmpty {
                            Button(action: { title = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                    if !isFaderUI {
                        IconPicker(symbol: $symbol, icons: icons)
                            .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                        Picker("Behavior", selection: $isToggle) {
                            Text("Momentary").tag(false)
                            Text("Toggle").tag(true)
                        }
                        .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                        .tint(selectedTheme.secondaryTextColor(for: colorScheme))
                        .foregroundStyle(selectedTheme.primaryTextColor(for: colorScheme))
                    }

                    // Fader orientation and direction (only for faders)
                    if isFaderUI {
                        Picker("Fader Orientation", selection: $faderOrientation) {
                            Text("Vertical").tag("vertical")
                            Text("Horizontal").tag("horizontal")
                        }
                        .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                        .tint(selectedTheme.secondaryTextColor(for: colorScheme))
                        .foregroundStyle(selectedTheme.primaryTextColor(for: colorScheme))

                        Picker("Fader Direction", selection: $faderDirection) {
                            // Vertical faders: only up/down
                            if faderOrientation == "vertical" {
                                Text("Up").tag("up")
                                Text("Down").tag("down")
                            }
                            // Horizontal faders: only left/right
                            else if faderOrientation == "horizontal" {
                                Text("Left").tag("left")
                                Text("Right").tag("right")
                            }
                        }
                        .id("fader-direction-picker-edit")
                        .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                        .tint(selectedTheme.secondaryTextColor(for: colorScheme))
                        .foregroundStyle(selectedTheme.primaryTextColor(for: colorScheme))
                    }

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
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    )
                    .tint(.secondary)
                    .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                }
                // Live Preview - Collapsible
                Section {
                    DisclosureGroup(
                        isExpanded: $showPreview,
                        content: {
                            HStack {
                                Spacer(minLength: 0)
                                if isFaderUI {
                                    ControlFaderPreview(title: title, cc: number, channel: channel, orientation: faderOrientation, direction: faderDirection, colorHex: colorHex)
                                } else {
                                    ControlButtonPreview(title: title, symbol: symbol, kind: kind, number: number, channel: channel, velocity: velocity, isSmall: isSmall, colorHex: colorHex)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 6)
                        },
                        label: {
                            Text("Preview")
                        }
                    )
                    .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                }
                Section(header: Text("MIDI")) {
                    if midiFiltersEnabled && !midiFilter.isEmpty {
                        Text("Some MIDI values are unavailable because MIDI filters are enabled. Go to MIDI Settings to change this.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                    }
                    Toggle(isOn: Binding(
                        get: { autoAssign },
                        set: { newValue in savedAutoAssign = newValue; autoAssign = newValue }
                    )) {
                        Text("Assign MIDI automatically")
                    }
                    .toggleStyle(SwitchToggleStyle(tint: selectedTheme.successColor(for: colorScheme)))
                    .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                    if !isFaderUI {
                        Picker("Type", selection: $kind) {
                            Text("Control Change").tag(MIDIKind.cc)
                            Text("Note").tag(MIDIKind.note)
                        }
                        .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                        .tint(selectedTheme.secondaryTextColor(for: colorScheme))
                        .foregroundStyle(selectedTheme.primaryTextColor(for: colorScheme))
                    }
                    ChannelPicker(title: "Channel", channel: $channel, disabled: false)
                        .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                    MIDINumberPicker(
                        kind: kind,
                        number: $number,
                        disabled: autoAssign,
                        channel: channel,
                        currentOwnerName: currentOwnerName,
                        editingControl: editing,
                        midiFilter: midiFilter
                    )
                    .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                    if !isFaderUI && kind == .note {
                        VelocityPicker(velocity: $velocity, disabled: false)
                            .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                    }
                }

                // Delete section - always show when editing existing control
                if onDelete != nil {
                    Section {
                        DestructiveWideButton(
                            title: isFaderUI ? "Delete Fader" : "Delete Button",
                            action: { showDeleteAlert = true }
                        )
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }
            }
            .navigationTitle(isFaderUI ? "Edit Fader" : "Edit Button")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .scrollContentBackground(.hidden)
            .background(selectedTheme.backgroundColor(for: colorScheme))
            .tint(selectedTheme.accentColor(for: colorScheme))
            .cbDialog("Delete Control", isPresented: $showDeleteAlert, themeFont: selectedTheme.font,
                message: "Are you sure you want to delete this \(isFaderUI ? "fader" : "button")? This action cannot be undone.",
                buttons: [
                    .init("Delete", role: .destructive) {
                        if let control = editing {
                            onDelete?(control)
                        }
                    },
                    .init("Cancel", role: .cancel) { }
                ]
            )
            .navigationBarItems(
                leading: Button("Cancel") {
                    userDismissedExplicitly = true  // v1.0.8: Mark as explicit dismissal
                    onCancel()
                },
                trailing: saveButton
            )
            .onAppear {
                userDismissedExplicitly = false  // v1.0.8: Reset on appear
                preset()
            }
            .onDisappear {
                // v1.0.8: Auto-save if dismissed by tapping outside (not Cancel/Save)
                if !userDismissedExplicitly && !title.isEmpty && conflictOwner() == nil && !isFilteredMIDI() {
                    debugPrint("📝 [SHEET] Edit control dismissed by outside-tap - auto-saving")
                    saveEdit()
                }
            }
            .onChange(of: autoAssign) { _, newValue in
                if newValue {
                    number = firstFreeNumber(for: kind, channel: channel)
                }
            }
            .onChange(of: kind) { _, newValue in
                if autoAssign {
                    number = firstFreeNumber(for: newValue, channel: channel)
                }
            }
            .onChange(of: channel) { _, newValue in
                if autoAssign {
                    number = firstFreeNumber(for: kind, channel: newValue)
                }
            }
            .onChange(of: faderOrientation) { _, newOrientation in
                // Auto-set appropriate direction when orientation changes
                if newOrientation == "vertical" && (faderDirection == "left" || faderDirection == "right") {
                    faderDirection = "up"
                } else if newOrientation == "horizontal" && (faderDirection == "up" || faderDirection == "down") {
                    faderDirection = "right"
                }
            }
        }
        .preferredColorScheme(selectedTheme.preferredColorScheme(for: colorScheme))
    }

    private var saveButton: some View {
        let isDisabled = title.isEmpty || conflictOwner() != nil || isFilteredMIDI()
        return Button("Save") {
            userDismissedExplicitly = true  // v1.0.8: Mark as explicit dismissal
            saveEdit()
        }
        .foregroundColor(isDisabled ? Color.gray.opacity(0.5) : selectedTheme.accentColor(for: colorScheme))
        .disabled(isDisabled)
    }

    // v1.0.8: Extract save logic to function for reuse in onDisappear
    private func saveEdit() {
        if var b = editing {
            b.title = title
            b.symbol = symbol
            b.kind = isFaderUI ? .cc : kind
            b.number = number
            b.channel = channel
            b.velocity = velocity
            b.isToggle = isToggle
            b.isFader = isFaderUI
            if !isFaderUI { b.isSmall = isSmall } else { b.isSmall = false }
            b.colorHex = colorHex  // Save color

            // Save fader orientation and direction (only for faders)
            if isFaderUI {
                b.faderOrientation = faderOrientation
                b.faderDirection = faderDirection
            }

            onSave(b)
        }
    }

    private func preset() {
        guard let b = editing else {
            autoAssign = savedAutoAssign
            return
        }
        title = b.title
        symbol = b.symbol
        kind = b.kind
        number = b.number
        channel = b.channel
        velocity = b.velocity
        autoAssign = savedAutoAssign
        isToggle = b.isToggle ?? false
        isFaderUI = b.isFader ?? false
        isSmall = b.isSmall ?? false  // Load small button state for preview
        colorHex = b.colorHex  // Load color

        // Load fader orientation and direction with defaults
        if b.isFader == true {
            faderOrientation = b.faderOrientation ?? "vertical"
            faderDirection = b.faderDirection ?? (faderOrientation == "vertical" ? "up" : "right")
        }
    }

    private func conflictOwner() -> String? {
        // If we're editing an existing control and the MIDI assignment hasn't changed, no conflict
        if let edit = editing, edit.kind == kind, edit.channel == channel, edit.number == number {
            return nil
        }
        let key = MIDIKey(kind: kind, channel: channel, number: number)
        return currentOwnerName(key)
    }

    private func isFilteredMIDI() -> Bool {
        return midiFiltersEnabled && !midiFilter.isEmpty && kind == .cc && midiFilter.contains(number)
    }

    private func ownerFor(kind: MIDIKind, number: Int, channel: Int) -> String? {
        // If we're editing an existing control and checking its current MIDI assignment, no conflict
        if let edit = editing, edit.kind == kind, edit.channel == channel, edit.number == number {
            return nil
        }
        let key = MIDIKey(kind: kind, channel: channel, number: number)
        guard let ownersString = currentOwnerName(key) else { return nil }

        // Filter out the current control's name if editing
        if let edit = editing {
            let editDisplayName: String
            if edit.isFader == true {
                editDisplayName = edit.title.isEmpty ? "Fader" : "Fader: \(edit.title)"
            } else {
                editDisplayName = edit.title.isEmpty ? "Button" : "Button: \(edit.title)"
            }

            // Check if the owners string contains the separator (multiple owners)
            if ownersString.contains("|||") {
                // Multiple owners - need to filter
                let owners = ownersString.split(separator: "|||").map(String.init).filter { $0 != editDisplayName }
                guard !owners.isEmpty else { return nil }
                if owners.count == 1 {
                    return owners[0]
                } else if owners.count == 2 {
                    return "\(owners[0]) and \(owners[1])"
                } else {
                    return owners.dropLast().joined(separator: ", ") + ", and " + owners.last!
                }
            } else if ownersString == editDisplayName {
                // Single owner and it's us
                return nil
            }
        }

        return ownersString
    }

    private func firstFreeNumber(for kind: MIDIKind, channel: Int) -> Int {
        for n in 0...127 {
            // Skip filtered CC numbers when filters are enabled
            if kind == .cc && midiFiltersEnabled && midiFilter.contains(n) {
                continue
            }
            let key = MIDIKey(kind: kind, channel: channel, number: n)
            if currentOwnerName(key) != nil {
                // Skip if occupied by a different control
                if let edit = editing, edit.kind == kind, edit.channel == channel, edit.number == n {
                    // This is the control we're editing, so this number is available
                } else {
                    continue
                }
            }
            return n
        }
        return 0
    }
}

// MARK: - Control Button Preview (used in editor)
struct ControlButtonPreview: View {
    let title: String
    let symbol: String
    let kind: MIDIKind
    let number: Int
    let channel: Int
    let velocity: Int
    var isSmall: Bool = false
    var colorHex: String? = nil

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    private var midiLabel: String {
        kind == .cc ? "\(channel)•\(number)" : "\(channel)•\(number)•\(velocity)"
    }

    private var buttonColor: Color {
        if let hex = colorHex, !hex.isEmpty {
            return Color(hex: hex)
        }
        // Use custom accent color if set, otherwise theme default
        if !customDefaultCueColorStorage.isEmpty {
            return Color(hex: customDefaultCueColorStorage)
        }
        return selectedTheme.defaultCueColor(for: colorScheme)
    }

    var body: some View {
        // Match real button dimensions: regular is 2 cells wide (2*cellSize + 12 spacing), small is 1 cell (cellSize x cellSize)
        // Using preview cellSize of 72 to match the aspect ratio of real buttons in the grid
        let previewCellSize: CGFloat = 72
        let columnSpacing: CGFloat = 12
        let frameWidth: CGFloat = isSmall ? previewCellSize : (2 * previewCellSize + columnSpacing)
        let frameHeight: CGFloat = previewCellSize
        let corner: CGFloat = 8

        let textColor: Color = buttonColor.needsDarkText() ? .black : .white

        return VStack(spacing: 4) {
            Spacer(minLength: 0)
            if symbol.isEmpty {
                // Text only
                Text(title.isEmpty ? "Custom" : title)
                    .font(.custom("Sora-Bold", size: 14))
                    .foregroundColor(textColor)
                Text(midiLabel)
                    .font(.custom("Sora-Regular", size: 9))
                    .foregroundColor(textColor.opacity(0.5))
            } else if title.isEmpty {
                // Icon only
                Image(systemName: symbol)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(textColor)
                Text(midiLabel)
                    .font(.custom("Sora-Regular", size: 9))
                    .foregroundColor(textColor.opacity(0.5))
            } else {
                // Icon + text
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(textColor)
                Text(title)
                    .font(.custom("Sora-Bold", size: 12))
                    .foregroundColor(textColor)
                Text(midiLabel)
                    .font(.custom("Sora-Regular", size: 9))
                    .foregroundColor(textColor.opacity(0.5))
            }
            Spacer(minLength: 0)
        }
        .frame(width: frameWidth, height: frameHeight)
        .background(
            RoundedRectangle(cornerRadius: corner)
                .fill(buttonColor.opacity(0.9))
        )
    }
}

// Preview for fader in the editor — matches in-grid FaderTileContent visuals
struct ControlFaderPreview: View {
    let title: String
    let cc: Int
    let channel: Int
    var orientation: String = "vertical"
    var direction: String = "up"
    var colorHex: String? = nil

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    private var faderColor: Color {
        if let hex = colorHex, !hex.isEmpty {
            return Color(hex: hex)
        }
        // Use custom accent color if set, otherwise theme default
        if !customDefaultCueColorStorage.isEmpty {
            return Color(hex: customDefaultCueColorStorage)
        }
        return selectedTheme.defaultCueColor(for: colorScheme)
    }

    private var textColor: Color {
        faderColor.needsDarkText() ? .black : .white
    }

    var body: some View {
        let isHorizontal = (orientation == "horizontal")
        let previewValue: Double = 0.66  // Preview at 66% position

        if isHorizontal {
            // HORIZONTAL FADER PREVIEW — filled style with 8pt corners
            let fillAlignment: Alignment = (direction == "right") ? .leading : .trailing

            ZStack(alignment: fillAlignment) {
                // Track background
                RoundedRectangle(cornerRadius: 8)
                    .fill(faderColor.opacity(0.2))

                // Fill level
                GeometryReader { geo in
                    HStack {
                        if direction != "right" { Spacer() }
                        RoundedRectangle(cornerRadius: 8)
                            .fill(faderColor.opacity(0.85))
                            .frame(width: geo.size.width * previewValue)
                        if direction == "right" { Spacer() }
                    }
                }

                // Labels overlay
                HStack {
                    Text(title.isEmpty ? "Fader" : title)
                        .font(.custom("Sora-Bold", size: 11))
                        .foregroundColor(textColor)
                        .padding(.leading, 8)
                    Spacer()
                    Text("\(channel)•\(cc)")
                        .font(.custom("Sora-Regular", size: 9))
                        .foregroundColor(textColor.opacity(0.5))
                        .padding(.trailing, 8)
                }
            }
            .frame(width: 156, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            // VERTICAL FADER PREVIEW — filled style with 8pt corners
            ZStack(alignment: .bottom) {
                // Track background
                RoundedRectangle(cornerRadius: 8)
                    .fill(faderColor.opacity(0.2))

                // Fill level
                GeometryReader { geo in
                    VStack {
                        if direction == "up" { Spacer() }
                        RoundedRectangle(cornerRadius: 8)
                            .fill(faderColor.opacity(0.85))
                            .frame(height: geo.size.height * previewValue)
                        if direction != "up" { Spacer() }
                    }
                }

                // Labels overlay
                VStack(spacing: 2) {
                    Text(title.isEmpty ? "Fader" : title)
                        .font(.custom("Sora-Bold", size: 11))
                        .foregroundColor(textColor)
                    Text("\(channel)•\(cc)")
                        .font(.custom("Sora-Regular", size: 9))
                        .foregroundColor(textColor.opacity(0.5))
                }
                .padding(.bottom, 8)
            }
            .frame(width: 72, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Project Data Structure (moved to ProjectPayload.swift)
// MARK: - ProjectIO (moved to ProjectIO.swift)

// MARK: - MIDI conflict key
internal struct MIDIKey: Hashable {
    let kind: MIDIKind
    let channel: Int
    let number: Int
}

// MARK: - ContentView
internal struct ContentView: View {
    // Icon library for control buttons
    let icons = [
        // Transport & Control
        "backward.end.fill", "backward.frame.fill",
        "forward.end.fill", "forward.frame.fill",
        "pause.circle.fill", "pause.fill",
        "play.circle.fill", "play.fill", "play.square.fill",
        "record.circle.fill",
        "stop.circle.fill", "stop.fill",

        // Music & Performance - Strings & Keys
        "pianokeys", "pianokeys.inverse",

        // Music & Performance - Vocals & Microphones
        "mic.fill",

        // Music & Performance - Notes & Notation
        "music.note", "music.note.list", "music.quarternote.3",

        // Music & Performance - Audio Equipment
        "radio", "radio.fill",
        "hifispeaker", "hifispeaker.fill",
        "hifispeaker.2", "hifispeaker.2.fill",
        "homepod", "homepod.fill",
        "homepod.2", "homepod.2.fill",
        "headphones", "headphones.circle.fill",

        // Audio & Mixing
        "dial.max",
        "ear.fill",
        "slider.horizontal.3",
        "speaker.slash.fill",
        "speaker.wave.2.fill", "speaker.wave.3.fill",
        "waveform",
        "waveform.circle", "waveform.circle.fill",
        "waveform.path",
        "waveform.path.badge.minus",
        "waveform.path.ecg", "waveform.path.ecg.rectangle",

        // Effects & Processing
        "arrow.down.circle.fill", "arrow.up.circle.fill",
        "arrow.up.right.circle.fill",
        "bolt.circle.fill", "bolt.fill",
        "building.columns.fill",
        "burst.fill",
        "cloud.bolt.fill",
        "dot.radiowaves.left.and.right",
        "repeat.1.circle.fill", "repeat.circle.fill",
        "sparkles",
        "wave.3.right.circle.fill",

        // Song Structure
        "b.circle.fill", "b.square.fill",
        "c.circle.fill", "c.square.fill",
        "flag.checkered",
        "i.circle.fill",
        "o.circle.fill",
        "v.circle.fill", "v.square.fill",

        // Numbers & Markers
        "1.circle", "1.square.fill",
        "2.circle", "2.square.fill",
        "3.circle", "3.square.fill",
        "4.circle", "4.circle.fill",
        "5.circle",
        "6.circle",
        "8.circle.fill",

        // People & Groups
        "person.2.fill", "person.3.fill",

        // Lighting & Theater
        "arrow.down.square.fill", "arrow.up.square.fill",
        "hands.clap.fill",
        "light.beacon.max.fill",
        "light.max", "light.min",

        // Utility
        "circle.hexagongrid.fill",
        "memories",
        "minus.circle.fill",
        "plus.circle.fill",
        "square.grid.2x2.fill"
    ]

    @EnvironmentObject var store: SetlistStore
    @Environment(\.scenePhase) private var scenePhase

    // Simple connection systems - USB server + WiFi client
    @EnvironmentObject var usbServer: ConnectionManager
    @EnvironmentObject var wifiClient: BridgeOutput
    @EnvironmentObject var connectionCoordinator: ConnectionCoordinator

    // UI state
    @State private var showConnections = false
    @State private var showAddEdit = false
    @State private var editingSong: Song? = nil
    @State private var isEditing = false
    @State private var modeBeforeEditing: AppMode? = nil  // Remember mode before entering edit mode
    @State private var editModeTab: Int = 1  // iPhone only: 0 = Library, 1 = Cue List
    @State private var showEditModeViewPicker = false  // iPhone only: Show sheet to choose view
    @State private var reorderMode = false  // v1.0.9: Reorder mode for cue list
    @State private var setlistBatchMode = false  // Batch select mode for cue list
    @State private var setlistSelected: Set<UUID> = []  // Selected cues in batch mode
    @State private var showLibraryPopover = false  // Show song library popover
    @State private var showCueListChooser = false  // Show cue list chooser popover

    // Library state
    @State private var songLibrary: [Song] = []
    @State private var libBatchMode = false
    @State private var libSelected: Set<UUID> = []
    @State private var sortMode: LibrarySortMode = .nameAZ
    @State private var libAddedAt: [UUID: Date] = [:]
    @State private var libraryQuery: String = ""
    @State private var libraryQueryDebounced: String = ""
    @State private var setlistQuery: String = ""
    @State private var setlistQueryDebounced: String = ""
    @FocusState private var isSetlistSearchFocused: Bool

    // Splash Screen - v1.0.8: Use AppStorage to persist across view recreations
    @AppStorage("hasCompletedInitialLaunch") private var hasCompletedInitialLaunch = false
    @State private var showSplash = true
    @State private var hasInitialized = false

    // v1.0.8: Draft managers to preserve edits across sheet dismissals
    @StateObject private var cueEditorDraft = CueEditorDraft()
    @StateObject private var controlEditorDraft = ControlEditorDraft()

    // Onboarding Tutorial State
    // Flow: Onboarding → T1 (Edit btn) → T2 (+ btn) → T2b (Library btn) → exit edit → T2c (cue list name) → T3 (Controls)
    @AppStorage("hasSeenTutorial1") private var hasSeenTutorial1 = false  // Tutorial 1: Edit button
    @AppStorage("hasSeenTutorial2") private var hasSeenTutorial2 = false  // Tutorial 2: + button
    @AppStorage("hasSeenTutorial2b") private var hasSeenTutorial2b = false  // Tutorial 2b: Library button
    @AppStorage("hasSeenTutorial2c") private var hasSeenTutorial2c = false  // Tutorial 2c: Cue list name
    @AppStorage("hasSeenTutorial3") private var hasSeenTutorial3 = false  // Tutorial 3: Controls capsule
    // Tutorial 4 removed (two-finger scroll no longer exists)
    @State private var showTutorial1 = false  // Tutorial 1: Edit button (after onboarding)
    @State private var showTutorial2 = false  // Tutorial 2: + button (after clicking Edit)
    @State private var showTutorial2b = false  // Tutorial 2b: Library button
    @State private var showTutorial2c = false  // Tutorial 2c: Cue list name button (after exiting edit)
    @State private var showTutorial3 = false  // Tutorial 3: Controls capsule
    // showTutorial4 removed (two-finger scroll no longer exists)
    @State private var interruptedTutorial: Int? = nil  // Track which tutorial was interrupted by nav/cue capsule tutorial (1, 2, 2 for 2b, 3 for 2c, 4 for 3)
    @State private var pendingTutorial: Int? = nil  // Tutorial waiting to be shown (queued because another is active)

    /// Check if any tutorial is currently showing
    private var isAnyTutorialShowing: Bool {
        showTutorial1 || showTutorial2 || showTutorial2b || showTutorial2c || showTutorial3
    }

    /// Request to show a tutorial - will queue if another is active
    /// Tutorial IDs: 1=Edit, 2=AddCue, 2b=Library, 2c=CueListName, 3=Controls
    private func requestTutorial(_ tutorialId: Int) {
        if isAnyTutorialShowing {
            // Queue this tutorial to show after current one is dismissed
            pendingTutorial = tutorialId
            debugPrint("📖 [Tutorial] Tutorial \(tutorialId) queued - another tutorial is active")
        } else {
            // Show immediately
            showTutorialById(tutorialId)
        }
    }

    /// Show a tutorial by its ID
    private func showTutorialById(_ tutorialId: Int) {
        switch tutorialId {
        case 1: showTutorial1 = true
        case 2: showTutorial2 = true
        case 21: showTutorial2b = true  // Using 21 for 2b
        case 22: showTutorial2c = true  // Using 22 for 2c
        case 3: showTutorial3 = true
        default: break
        }
        debugPrint("📖 [Tutorial] Showing tutorial \(tutorialId)")
    }

    /// Called when a tutorial is dismissed - shows pending tutorial if any
    private func onTutorialDismissed() {
        if let pending = pendingTutorial {
            pendingTutorial = nil
            // Small delay before showing next tutorial for smooth transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if !self.isAnyTutorialShowing {
                    self.showTutorialById(pending)
                }
            }
        }
    }

    // Tutorial frame tracking (for positioning tutorials)
    @State private var editButtonFrame: CGRect = .zero  // Edit button in top right capsule
    @State private var addCueButtonFrame: CGRect = .zero  // + button in edit mode
    @State private var libraryButtonFrame: CGRect = .zero  // Library button (book icon)
    @State private var cueListNameButtonFrame: CGRect = .zero  // Cue list name button (top left)
    @State private var controlsCapsuleFrame: CGRect = .zero  // Controls capsule (bottom right)
    // controlAreaFrame removed (tutorial 4 no longer exists)

    // Projects
    @State private var showProjects = false
    @State private var showOnboarding = false
    @State private var showShowMode = false  // v1.3: the stage screen (Now, Next, GO)
    @State private var songForDetails: Song? = nil  // v1.3: Notes & Extras sheet
    @Binding var crashAlertActive: Bool  // Prevents onboarding from showing while crash alert is active
    @AppStorage("lastProjectName") private var projectName: String = "Untitled"
    @State private var projectsList: [String] = []
    @State private var isDirty: Bool = false
    @State private var showNamePrompt: Bool = false
    @State private var tempName: String = ""
    @State private var showSaveChangesAlert: Bool = false
    @State private var pendingAction: (() -> Void)? = nil
    @State private var shouldSaveAfterNaming: Bool = false  // Track if we should save after user names the project

    // Cue list renaming
    @State private var showCueListRenamePrompt: Bool = false
    @State private var cueListToRename: UUID? = nil
    @State private var tempCueListName: String = ""
    @State private var showDuplicateRenameAlert: Bool = false
    @State private var duplicateRenameNewName: String = ""

    // Cue list creation
    @State private var showNewCueListPrompt: Bool = false
    @State private var newCueListName: String = ""
    @State private var showDuplicateCueListAlert: Bool = false
    @State private var duplicateCueListName: String = ""

    // Duplicate cue name detection
    @State private var showDuplicateCueNameAlert: Bool = false
    @State private var duplicateCueName: String = ""
    @State private var duplicateCueSuggestedName: String = ""
    @State private var pendingDuplicateCue: Song? = nil
    @State private var pendingDuplicateCueAddAnother: Bool = false

    // Navigation capsule (Regular + Remote mode)
    @State private var lastTriggeredSongIndex: Int = 0

    // Last played cue (for play icon indicator)
    @State private var lastPlayedCueID: UUID? = nil

    // Selected/chosen cue (for expanded width in cue list)
    @State private var selectedCue: UUID? = nil

    // Song deletion confirmation
    @State private var showDeleteConfirmation: Bool = false
    @State private var songToDelete: Song? = nil

    // Document loading error alert
    @State private var showDocumentLoadError: Bool = false
    @State private var documentLoadErrorMessage: String = ""

    // Control Area (formerly transport)
    @State private var controlButtons: [ControlButton] = []
    @State private var controlEditMode = false
    @State private var controlAreaCollapsed: Bool = false  // Track if control area is collapsed
    @State private var currentControlPage: Int = 0  // Current page (0-3) for multi-page control area
    @State private var controlsPerRow: Int = 4
    @State private var controlAreaHeight: CGFloat = 0
    @State private var showCollapsedCapsule: Bool = false  // Control visibility for sequential animation
    @State private var showExpandedArea: Bool = false  // Control visibility for sequential animation
    @State private var isAnimatingControlArea: Bool = false  // Track if control area is animating
    @State private var controlSectionReady: Bool = false  // PERFORMANCE: Delay CBControlSection creation until after initial layout
    @State private var titleBarBottom: CGFloat = 88  // Bottom edge of title bar (default: safe area + title height)
    @State private var editCapsuleBottom: CGFloat = 0  // Bottom edge of edit/search capsules when visible
    @State private var capsuleBounds: [String: CGRect] = [:]  // Track all UI capsule bounds for collision detection
    @State private var canAddMoreControlsToGrid: Bool = true  // Track if grid has space for new controls
    @State private var controlEditModeTimer: Timer? = nil  // Auto-exit timer for edit mode
    @State private var showControlEditor: Bool = false
    @State private var editingControl: ControlButton? = nil
    @State private var showEditControlSheet: Bool = false
    @State private var editingControlForEdit: ControlButton? = nil
    @State private var showMidiTable: Bool = false
    @State private var flashNewFormControl: Bool = false  // Visual feedback for "Save & Add Another" in control editor

    // Notification subscriptions (to prevent memory leaks)
    @State private var notificationCancellables: Set<AnyCancellable> = []

    // Global MIDI Channel
    @State private var isGlobalChannel: Bool = false
    @State private var globalChannel: Int = 1
    // Backup of original channels before enabling global mode
    @State private var savedSongChannels: [UUID: Int] = [:]
    @State private var savedControlChannels: [UUID: Int] = [:]
    // Flag to prevent backup/restore during project loading
    @State private var isLoadingProject: Bool = false

    // MIDI Filter - persisted globally via UserDefaults (not per-project)
    @AppStorage("midiFiltersEnabled") private var midiFiltersEnabled: Bool = true
    @State private var midiFilter: Set<Int> = [1, 7, 10, 11, 64, 120, 121, 122, 123, 124, 125, 126, 127]
    @State private var customMidiFilters: [(Int, String)] = []

    // Undo/Redo
    @State private var setlistUndoStack: [[Song]] = []
    @State private var setlistRedoStack: [[Song]] = []
    @State private var libraryUndoStack: [[Song]] = []
    @State private var libraryRedoStack: [[Song]] = []
    @State private var controlUndoStack: [[ControlButton]] = []
    @State private var controlRedoStack: [[ControlButton]] = []

    // Misc
    @State private var autosaveTask: Task<Void, Never>? = nil
    // FIX #4: Replace task-based autosave with DispatchWorkItem
    @State private var autosaveWorkItem: DispatchWorkItem? = nil
    @State private var showAddEditMIDIOnly = false
    @State private var pendingAddIsFader: Bool? = nil
    @State private var isTyping: Bool = false
    @State private var flashingCueID: UUID? = nil  // Tracks which cue should flash

    // Side Menu
    @State private var showSideMenu = false
    @State private var modeChangeWorkItem: DispatchWorkItem?
    @State private var showAboutSheet = false
    @State private var showAppearanceSheet = false
    @State private var showAppearanceSettingsSheet = false
    @State private var showDesignPreview = false  // Design preview for cue appearance testing
    #if DEBUG
    @State private var showAdminPanel = false
    @State private var adminPanelPressTimer: Timer? = nil
    @State private var adminPanelPressCount = 0
    #endif

    // Theme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var currentTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    // Effective default cue color (custom overrides theme default)
    private var effectiveDefaultCueColorHex: String {
        customDefaultCueColorStorage.isEmpty ? currentTheme.defaultCueColorHexValue(for: colorScheme) : customDefaultCueColorStorage
    }

    // Appearance Settings
    @AppStorage("showMIDIData") private var showMIDIData: Bool = true
    @AppStorage("cueHeight") private var cueHeight: Double = 110
    @AppStorage("navigationPillSize") private var navigationPillSize: Double = 0.85
    @AppStorage("cueCapsuleSize") private var cueCapsuleSize: Double = 0.85
    @AppStorage("fontSize") private var fontSize: Double = 1.0
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""
    @AppStorage("autoAssignCueColors") private var autoAssignCueColors: Bool = true
    @AppStorage("autoAssignControlColors") private var autoAssignControlColors: Bool = true

    // Performance caches
    @State private var cachedConflictLookup: [MIDIKey: String] = [:]
    @State private var cacheVersion: Int = 0
    @State private var cachedUsedCCs: Set<Int> = []
    // FIX #5: Conflict cache throttling
    @State private var conflictCacheUpdateScheduled = false

    // Control Area constraints
    private let maxControlRows: Int = 5

    

    // Visuals
    private var connectionTint: Color { connectionCoordinator.activeConnection != .none ? .green : .red }
    // activeIsUSB removed - now handled by ConnectionCoordinator

    // Break up body for compiler
    private var topBarView: some View {
            CBTopBar(
                mode: $store.mode,
                showSideMenu: $showSideMenu,
                isEditing: $isEditing,
                isGlobalChannel: $isGlobalChannel,
                globalChannel: $globalChannel,
                showLibraryPopover: $showLibraryPopover,
                songLibrary: $songLibrary,
                activeCueListSongs: Binding(
                    get: { store.activeSongs },
                    set: { _ in }
                ),
                editingSong: $editingSong,
                showAddEdit: $showAddEdit,
                cueLists: $store.cueLists,
                activeCueListID: $store.activeCueListID,
                showCueListChooser: $showCueListChooser,
                libAddedAt: libAddedAt,
                selectedThemeID: selectedThemeID,
                projectTitle: projectName,
                connectionTint: connectionTint,
                connectionCoordinator: connectionCoordinator,
                titleBarColor: currentTheme.titleBarColor(for: colorScheme),
                buttonColor: .white,
                textColor: .white,
                lightButtonBackgroundColor: currentTheme.lightButtonBackgroundColor(for: colorScheme),
                themeFont: { size, weight in .custom("Sora-Regular", size: size) },
                // Core actions
                onConnections: {
                    if isEditing { isEditing = false }
                    showConnections = true
                },
                onEditToggle: {
                    withAnimation(.easeInOut) {
                        isEditing.toggle()

                        // Reset selection when entering edit mode
                        if isEditing {
                            store.cuedSong = nil
                            if store.mode == .cue {
                                store.mode = .regular
                            }
                        }
                    }
                },
                onAdd: {
                    // Don't exit edit mode when adding a new cue
                    editingSong = nil
                    showAddEdit = true

                    // Tutorial 2: Dismiss when clicking + button
                    if showTutorial2 {
                        showTutorial2 = false
                        hasSeenTutorial2 = true
                        onTutorialDismissed()
                    }
                    // Will trigger tutorial 2b after the add sheet closes
                },
                onUndo: { performUndo() },
                onRedo: { performRedo() },
                canUndo: !setlistUndoStack.isEmpty || !libraryUndoStack.isEmpty,
                canRedo: !setlistRedoStack.isEmpty || !libraryRedoStack.isEmpty,
                onMenuToggle: {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                        showSideMenu.toggle()
                        // Exit edit mode when opening side menu
                        if showSideMenu {
                            isEditing = false
                        }
                    }
                },
                onAddToSetlist: { song in
                    addToSetlist(song)
                },
                onDeleteFromLibrary: { song in
                    deleteFromLibrary(song)
                },
                // Menu actions
                onRenameProject: {
                    if isEditing { isEditing = false }
                    tempName = projectName
                    showNamePrompt = true
                },
                onNewProject: {
                    if isEditing { isEditing = false }
                    newProjectFlow()
                },
                onSave: {
                    if isEditing { isEditing = false }
                    saveCurrentProject(overwrite: true)
                },
                onSaveAs: {
                    if isEditing { isEditing = false }
                    saveCurrentProject(overwrite: false)
                },
                onOpenProject: {
                    if isEditing { isEditing = false }
                    openProjectFlow()
                },
                onImport: {
                    if isEditing { isEditing = false }
                    openDocumentPicker()
                },
                onExport: {
                    if isEditing { isEditing = false }
                    exportCurrentProject()
                },
                onShowMidiSettings: {
                    if isEditing { isEditing = false }
                    showMidiTable = true
                },
                onShowAppearance: {
                    if isEditing { isEditing = false }
                    showAppearanceSheet = true
                },
                onShowOnboarding: {
                    if isEditing { isEditing = false }
                    // Only show onboarding if crash alert is not active
                    if !crashAlertActive {
                        showOnboarding = true
                    }
                },
                onShowAbout: {
                    if isEditing { isEditing = false }
                    showAboutSheet = true
                },
                // Cue list actions
                onSwitchCueList: { cueListID in
                    store.switchToCueList(cueListID)
                    isDirty = true
                    saveCurrentProject(overwrite: true)
                },
                onDuplicateCueList: { cueListID in
                    if let newID = store.duplicateCueList(cueListID) {
                        store.switchToCueList(newID)
                        isDirty = true
                        saveCurrentProject(overwrite: true)
                    }
                },
                onRenameCueList: { cueListID in
                    // Pre-fill with current cue list name
                    if let cueList = store.cueLists.first(where: { $0.id == cueListID }) {
                        cueListToRename = cueListID
                        tempCueListName = cueList.name
                        showCueListRenamePrompt = true
                    }
                },
                onDeleteCueList: { cueListID in
                    store.deleteCueList(cueListID)
                    isDirty = true
                },
                onCreateCueList: {
                    newCueListName = "New Cue List"
                    showNewCueListPrompt = true
                },
                onShowMode: {
                    if isEditing { isEditing = false }
                    showShowMode = true
                }
            )
    }

    // Filter active songs based on search query
    private var filteredActiveSongs: [Song] {
        if setlistQuery.isEmpty {
            return store.activeSongs
        }
        return store.activeSongs.filter { song in
            song.name.localizedCaseInsensitiveContains(setlistQuery)
        }
    }

    @ViewBuilder private func buildMiddleSectionView() -> some View {
        ZStack {
                // Background - same in all modes

                VStack(spacing: 0) {
                    CBPerformanceList(
                        songs: filteredActiveSongs,
                    songLibrary: songLibrary,  // Pass full song library for alias resolution
                    isCueMode: store.mode == .cue,
                    cuedID: store.mode == .cue ? store.cuedSong?.id : (store.mode == .regularPlusRemote && !store.activeSongs.isEmpty ? store.activeSongs[currentSongIndex()].id : nil),
                    isEditing: isEditing,
                    reorderMode: reorderMode,  // Pass reorder mode for drag handles
                    batchSelectMode: setlistBatchMode,  // Pass batch select mode
                    selectedSongs: setlistSelected,  // Pass selected song IDs
                    flashingCueID: flashingCueID,  // Pass flash trigger down to rows
                    lastPlayedID: lastPlayedCueID,  // Pass last played cue ID for play icon
                    accentColor: currentTheme.accentColor(for: colorScheme),  // Pass theme accent color
                    defaultCueColor: Color(hex: effectiveDefaultCueColorHex),  // Pass theme default cue color (custom or theme default)
                    themeFont: currentTheme.font,  // Pass theme font function
                    selectionStrokeColor: { cueColorHex in currentTheme.selectionStrokeColor(for: cueColorHex, colorScheme: colorScheme) },  // Compute contrasting selection stroke color
                    backgroundColorHex: currentTheme.backgroundColorHexValue(for: colorScheme),  // Pass background color hex
                    defaultCueColorHex: effectiveDefaultCueColorHex,  // Pass default cue color hex (custom or theme default)
                    showMIDIData: showMIDIData,  // Pass MIDI data visibility setting
                    cueHeight: cueHeight,  // Pass customizable cue height
                    fontSize: fontSize,  // Pass font size multiplier
                    controlAreaCollapsed: controlAreaCollapsed || (controlButtons.isEmpty && !controlEditMode),  // Pass effective collapsed state
                    controlAreaHeight: controlAreaHeight,  // Pass control area height for dynamic bottom padding
                    onTapSong: { song in
                        if store.mode == .regular || store.mode == .regularPlusRemote {
                            // In Navigator mode, update the index to match the tapped song
                            if store.mode == .regularPlusRemote {
                                if let index = store.activeSongs.firstIndex(where: { $0.id == song.id }) {
                                    lastTriggeredSongIndex = index
                                }
                            }
                            trigger(song)
                        } else {
                            store.cuedSong = song
                            UISelectionFeedbackGenerator().selectionChanged()
                        }
                    },
                    onLongPressChangeMIDI: { song in
                        editingSong = song
                        showAddEditMIDIOnly = true
                    },
                    onRename: { s in editingSong = s; showAddEdit = true },
                    onDelete: { s in removeFromSetlist(s) },
                    onDuplicate: { s in duplicateSong(s) },
                    onMove: { indices, newOffset in
                        pushSetlistUndo()
                        store.updateActiveSongs { songs in
                            songs.move(fromOffsets: indices, toOffset: newOffset)
                        }
                        isDirty = true
                    },
                    onToggleSelection: { song in
                        if setlistSelected.contains(song.id) {
                            setlistSelected.remove(song.id)
                        } else {
                            setlistSelected.insert(song.id)
                        }
                    },
                    conflictFor: conflictLookup()
                )
                .onAppear { /* Start with blank data for shipping */ }
                .overlay(alignment: .center) {
                    // Show draggable transport dock in cue mode
                    if store.mode == .cue || (isEditing && modeBeforeEditing == .cue) {
                        let songs = store.activeSongs
                        let cued = store.cuedSong
                        let cuedIndex = cued.flatMap { s in songs.firstIndex(where: { $0.id == s.id }) }
                        let canPrev = (cuedIndex ?? 0) > 0
                        let canNext = cuedIndex.map { $0 < songs.count - 1 } ?? false

                        SimpleDraggableTransportDock(
                            cuedName: cued?.name,
                            canPrev: canPrev,
                            canNext: canNext,
                            isGoEnabled: cued != nil,
                            onPrev: { selectPreviousCued() },
                            onGo: { cueGo() },
                            onNext: { selectNextCued() },
                            onClear: { store.cuedSong = nil },
                            controlAreaHeight: $controlAreaHeight,
                            isEditing: isEditing,
                            titleBarBottom: titleBarBottom,
                            editCapsuleBottom: editCapsuleBottom,
                            sizeMultiplier: navigationPillSize,  // Use same size as nav pill
                            isControlAreaCollapsed: effectivelyCollapsedForOverlay,
                            capsuleBounds: capsuleBounds,
                            hasControlButtons: !controlButtons.isEmpty,
                            themeColor: currentTheme.titleBarColor(for: colorScheme),
                            onTutorialDismiss: { resumeInterruptedTutorial() }
                        )
                        .offset(x: isEditing ? globalCachedPortraitWidth : 0)
                        .animation(.easeInOut(duration: 0.3), value: isEditing)
                        .zIndex(100)
                    }

                    // Show draggable navigation capsule in regularPlusRemote mode
                    if store.mode == .regularPlusRemote || (isEditing && modeBeforeEditing == .regularPlusRemote) {
                        let songs = store.activeSongs
                        let currentIndex = currentSongIndex()
                        let canPrev = currentIndex > 0
                        let canNext = currentIndex < songs.count - 1

                        DraggableNavigationCapsule(
                            canPrev: canPrev,
                            canNext: canNext,
                            onPrev: { triggerPrevious() },
                            onNext: { triggerNext() },
                            controlAreaHeight: $controlAreaHeight,
                            isEditing: isEditing,
                            titleBarBottom: titleBarBottom,
                            editCapsuleBottom: editCapsuleBottom,
                            sizeMultiplier: navigationPillSize,
                            isControlAreaCollapsed: effectivelyCollapsedForOverlay,
                            capsuleBounds: capsuleBounds,
                            hasControlButtons: !controlButtons.isEmpty,
                            themeColor: currentTheme.titleBarColor(for: colorScheme),
                            onTutorialDismiss: { resumeInterruptedTutorial() }
                        )
                        .offset(x: isEditing ? globalCachedPortraitWidth : 0)
                        .animation(.easeInOut(duration: 0.3), value: isEditing)
                        .zIndex(100)
                    }
                }
                // No background needed - cues and capsules live on same plane
                // Animation removed to prevent interference with draggable capsule position updates
                .overlay(alignment: .top) {
                    // Gradient from top of screen (solid background) to below title/search bar (fades to transparent) - improves scrolled cue visibility
                    let gradientHeight: CGFloat = isEditing ? 118 : 120  // Taller in edit mode (title + search), extends below title bar capsule in normal mode
                    let bgColor = currentTheme.backgroundColor(for: colorScheme)

                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: bgColor, location: 0.0),                  // Solid background at top
                            .init(color: bgColor.opacity(0.7), location: 0.25),   // More visible
                            .init(color: bgColor.opacity(0.3), location: 0.5),    // Slight fade
                            .init(color: bgColor.opacity(0.0), location: 1.0)     // Transparent at bottom
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(maxWidth: .infinity, maxHeight: gradientHeight)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
                    .animation(.spring(response: 0.25, dampingFraction: 0.85), value: isEditing)
                }
                .overlay(alignment: .top) {
                    // Search and action capsules overlay (only in edit mode) - cues scroll underneath
                    if isEditing {
                        HStack(spacing: 8) {
                            // Search bar — always present, animates between full width and circular icon
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: setlistBatchMode ? 18 : 16))
                                    .foregroundColor(.white)

                                if !setlistBatchMode {
                                    TextField("Search cues...", text: $setlistQuery)
                                        .font(.system(size: 15))
                                        .foregroundColor(currentTheme.primaryTextColor(for: colorScheme))
                                        .focused($isSetlistSearchFocused)

                                    if !setlistQuery.isEmpty {
                                        Button(action: { setlistQuery = "" }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 16))
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.horizontal, setlistBatchMode ? 0 : 14)
                            .frame(width: setlistBatchMode ? 44 : nil, height: 44)
                            .frame(maxWidth: setlistBatchMode ? nil : .infinity)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
                            .onTapGesture {
                                if setlistBatchMode {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                        setlistBatchMode = false
                                        setlistSelected.removeAll()
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                        isSetlistSearchFocused = true
                                    }
                                } else {
                                    isSetlistSearchFocused = true
                                }
                            }
                            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: setlistBatchMode)

                            if setlistBatchMode {
                                Spacer()
                            }

                            // Reorder button - separate capsule (hidden in batch mode)
                            if !setlistBatchMode {
                                Button(action: {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                        reorderMode.toggle()
                                    }
                                }) {
                                    Image(systemName: reorderMode ? "checkmark" : "list.bullet")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.black.opacity(0.5))
                                                .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
                                        )
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(IOSPressButtonStyle())
                            }

                            // Select capsule — grows into batch actions
                            HStack(spacing: 0) {
                                if setlistBatchMode {
                                    Button(action: {
                                        setlistSelected = Set(filteredActiveSongs.map { $0.id })
                                    }) {
                                        Text("All")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 10)
                                            .frame(height: 44)
                                    }
                                    .buttonStyle(IOSPressButtonStyle())

                                    Button(action: {
                                        setlistSelected.removeAll()
                                    }) {
                                        Text("Clear")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 10)
                                            .frame(height: 44)
                                    }
                                    .buttonStyle(IOSPressButtonStyle())

                                    Button(action: {
                                        pushSetlistUndo()
                                        store.updateActiveSongs { songs in
                                            songs.removeAll(where: { setlistSelected.contains($0.id) })
                                        }
                                        setlistSelected.removeAll()
                                        isDirty = true
                                    }) {
                                        Text("Remove")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(setlistSelected.isEmpty ? currentTheme.primaryTextColor(for: colorScheme).opacity(0.3) : .red)
                                            .padding(.horizontal, 10)
                                            .frame(height: 44)
                                    }
                                    .buttonStyle(IOSPressButtonStyle())
                                    .disabled(setlistSelected.isEmpty)

                                    Rectangle()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(width: 1, height: 24)
                                        .padding(.horizontal, 2)

                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                            setlistBatchMode = false
                                            setlistSelected.removeAll()
                                        }
                                    }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white)
                                            .frame(width: 36, height: 44)
                                    }
                                    .buttonStyle(IOSPressButtonStyle())
                                } else {
                                    // Collapsed: just the checklist icon
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                            setlistBatchMode = true
                                            reorderMode = false
                                        }
                                    }) {
                                        Image(systemName: "checklist")
                                            .font(.system(size: 18))
                                            .foregroundColor(.white)
                                            .frame(width: 44, height: 44)
                                    }
                                    .buttonStyle(IOSPressButtonStyle())
                                }
                            }
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
                            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: setlistBatchMode)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 68)  // Position below the top bar
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(key: EditCapsuleBottomPreferenceKey.self, value: geo.frame(in: .global).maxY)
                            }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: isEditing)
                    }
                }
                    }
                }
    }

    private var effectivelyCollapsedForOverlay: Bool {
        return controlAreaCollapsed || (controlButtons.isEmpty && !controlEditMode)
    }

    // State for controls capsule press animation (can't use ButtonStyle due to GeometryReader conflicts)
    @State private var controlsCapsulePressed: Bool = false

    private var collapsedControlCapsule: some View {
        // Floating action button with rounded rectangle to match app button style
        Image(systemName: "slider.horizontal.3")
            .font(.system(size: 24, weight: .medium))
            .foregroundColor(.white)
            .frame(width: 56, height: 56)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.8)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.2), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
            .opacity(controlsCapsulePressed ? 0.5 : 1.0)
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !controlsCapsulePressed {
                            controlsCapsulePressed = true
                        }
                    }
                    .onEnded { _ in
                        controlsCapsulePressed = false
                        // User found the controls on their own — skip tutorial 3
                        hasSeenTutorial3 = true
                        if showTutorial3 {
                            showTutorial3 = false
                            onTutorialDismissed()
                        }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            controlAreaCollapsed = false
                            // If empty, also enter edit mode
                            if controlButtons.isEmpty {
                                controlEditMode = true
                            }
                        }
                    }
            )
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: TutorialButtonFramePreferenceKey.self,
                        value: ["controlsCapsule": geo.frame(in: .global)]
                    )
                }
            )
            .padding(.trailing, 16)
            .padding(.bottom, 0)  // No internal bottom padding - applied externally at frame level
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: CapsuleBoundsPreferenceKey.self,
                        value: ["controlArea.main": geo.frame(in: .global)]
                    )
                }
            )
    }

    private var controlSectionView: some View {
        CBControlSection(
            buttons: $controlButtons,
            isEditing: $controlEditMode,
            perRow: $controlsPerRow,
            pendingAddIsFader: $pendingAddIsFader,
            reportedHeight: $controlAreaHeight,
            canAddMoreControls: $canAddMoreControlsToGrid,
            isCollapsed: $controlAreaCollapsed,
            selectedCue: $selectedCue,
            currentPage: $currentControlPage,
            conflictFor: conflictLookup(),
            midiFilter: midiFilter,
            showMIDIData: showMIDIData,
            onTap: { btn in triggerControl(btn) },
            onEditButton: { btn in
                editingControlForEdit = btn
                showEditControlSheet = true
                resetControlEditModeTimer()
            },
            onAddButton: { if canAddMoreControlsToGrid { beginAddControlOfType(.button) }; resetControlEditModeTimer() },
            onAddFader: { if canAddMoreControlsToGrid { beginAddControlOfType(.fader) }; resetControlEditModeTimer() },
            onUndo: { undoControls(); resetControlEditModeTimer() },
            onRedo: { redoControls(); resetControlEditModeTimer() },
            canUndo: !controlUndoStack.isEmpty,
            canRedo: !controlRedoStack.isEmpty,
            onDelete: { btn in deleteControl(btn); resetControlEditModeTimer() },
            onMove: { from, to in pushControlUndo(); controlButtons.move(fromOffsets: from, toOffset: to); markDirty(); resetControlEditModeTimer() },
            onCancelTimer: cancelControlEditModeTimer,
            onResetTimer: resetControlEditModeTimer,
            usbServer: usbServer,
            wifiClient: wifiClient,
            connectionCoordinator: connectionCoordinator,
            controlAreaColor: currentTheme.titleBarColor(for: colorScheme),
            buttonBackgroundColor: currentTheme.buttonBackgroundColor(for: colorScheme, customAccentHex: customDefaultCueColorStorage),
            lightButtonBackgroundColor: currentTheme.lightButtonBackgroundColor(for: colorScheme),
            defaultCueColor: Color(hex: effectiveDefaultCueColorHex),
            standardButtonColor: currentTheme.accentColor(for: colorScheme),
            textColor: currentTheme.primaryTextColor(for: colorScheme),
            markDirty: markDirty,
            cueListEditMode: isEditing
        )
            .onChange(of: controlEditMode) { _, newValue in
                if newValue {
                    // Entering edit mode - start timer
                    startControlEditModeTimer()

                    // Tutorial 4 dismiss removed (no longer exists)
                } else {
                    // Exiting edit mode - cancel timer
                    cancelControlEditModeTimer()

                    // Tutorial 4 (two-finger scroll) removed — no longer needed
                }
            }
            .onChange(of: showControlEditor) { _, isShowing in
                if isShowing {
                    // Sheet opened - pause timer
                    cancelControlEditModeTimer()
                } else {
                    // Sheet dismissed - restart timer if still in edit mode
                    if controlEditMode {
                        startControlEditModeTimer()
                    }
                }
            }
            .onChange(of: showEditControlSheet) { _, isShowing in
                if isShowing {
                    // Sheet opened - pause timer
                    cancelControlEditModeTimer()
                } else {
                    // Sheet dismissed - restart timer if still in edit mode
                    if controlEditMode {
                        startControlEditModeTimer()
                    }
                }
            }
    }

    // FIX #1: Setup NotificationCenter subscriptions using Combine to prevent memory leaks
    private func setupNotificationSubscriptions() {
        // Clear any existing subscriptions
        notificationCancellables.removeAll()

        // Subscription 1: cbFaderChanged
        NotificationCenter.default.publisher(for: Notification.Name("cbFaderChanged"))
            .sink { [self] notif in
                guard let info = notif.userInfo as? [String: Any],
                      let channel = info["channel"] as? Int,
                      let cc = info["cc"] as? Int,
                      let value = info["value"] as? Int,
                      let id = info["id"] as? UUID,
                      let title = info["title"] as? String else { return }

                // Store the fader value in the ControlButton model for persistence
                if let index = controlButtons.firstIndex(where: { $0.id == id }) {
                    let faderValue = Double(value) / 127.0
                    controlButtons[index].faderValue = faderValue
                    markDirty() // Mark project as dirty to save the fader value
                    debugPrint("🎚️ cbFaderChanged: Stored fader value \(faderValue) for \"\(title)\"")
                }

                // Use global channel if enabled, otherwise use fader's channel
                let channelToUse = isGlobalChannel ? globalChannel : channel

                let connectionType = connectionCoordinator.activeConnection == .usb ? "USB" : "WiFi"
                debugPrint("🎚️ MIDI OUT [\(connectionType)]: Fader CC #\(cc) = \(value) • Ch \(channelToUse) • \"\(title)\"")

                // Use ConnectionCoordinator to send MIDI through the active connection
                connectionCoordinator.sendMIDI(type: .cc, channel: channelToUse, number: cc, value: value, label: title, buttonID: id.uuidString)
            }
            .store(in: &notificationCancellables)

        // v1.3: open "Notes & Extras" for a song (from the cue row's menu)
        NotificationCenter.default.publisher(for: Notification.Name("cbOpenSongDetails"))
            .sink { [self] notif in
                guard let id = notif.userInfo?["songID"] as? UUID else { return }
                if let song = store.activeSongs.first(where: { $0.id == id })
                    ?? songLibrary.first(where: { $0.id == id }) {
                    songForDetails = song
                }
            }
            .store(in: &notificationCancellables)

        // Subscription 2: cbMIDIInputFromDAW
        NotificationCenter.default.publisher(for: Notification.Name("cbMIDIInputFromDAW"))
            .sink { [self] notif in
                debugPrint("🎚️ Received cbMIDIInputFromDAW notification: \(notif.userInfo ?? [:])")

                guard let info = notif.userInfo as? [String: Any],
                      let type = info["type"] as? String else {
                    debugPrint("🎚️ ❌ Invalid notification data")
                    return
                }

                if type == "cc",
                   let channel = info["channel"] as? Int,
                   let cc = info["cc"] as? Int,
                   let value = info["value"] as? Int {

                    debugPrint("🎚️ MIDI IN [DAW]: CC #\(cc) = \(value) • Ch \(channel)")

                    // Find matching fader and update its value
                    updateFaderFromDAW(channel: channel, cc: cc, value: value)
                } else {
                    debugPrint("🎚️ ❌ Invalid MIDI CC data: type=\(type), channel=\(info["channel"] ?? "nil"), cc=\(info["cc"] ?? "nil"), value=\(info["value"] ?? "nil")")
                }
            }
            .store(in: &notificationCancellables)
    }

    // MARK: - Side Menu
    private var sideMenuView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Spacer for floating top bar (transparent)
            Spacer().frame(height: 80)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Section 0: Mode Selection
                    sideMenuSection(title: "Performance") {
                        // Regular Mode (no pill)
                        Button(action: {
                            modeChangeWorkItem?.cancel()
                            let workItem = DispatchWorkItem {
                                store.mode = .regular
                            }
                            modeChangeWorkItem = workItem
                            DispatchQueue.main.async(execute: workItem)
                        }) {
                            HStack {
                                if store.mode == .regular {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(currentTheme.accentColor(for: colorScheme))
                                        .frame(width: 20)
                                } else {
                                    Color.clear.frame(width: 20)
                                }
                                Text("Regular")
                                    .font(currentTheme.font(size: 15, weight: .regular))
                                    .foregroundColor(currentTheme.primaryTextColor(for: colorScheme))
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(IOSPressButtonStyle())

                        // Regular + Remote (navigation capsule)
                        Button(action: {
                            modeChangeWorkItem?.cancel()
                            let workItem = DispatchWorkItem {
                                store.mode = .regularPlusRemote
                            }
                            modeChangeWorkItem = workItem
                            DispatchQueue.main.async(execute: workItem)
                        }) {
                            HStack {
                                if store.mode == .regularPlusRemote {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(currentTheme.accentColor(for: colorScheme))
                                        .frame(width: 20)
                                } else {
                                    Color.clear.frame(width: 20)
                                }
                                Text("Navigator")
                                    .font(currentTheme.font(size: 15, weight: .regular))
                                    .foregroundColor(currentTheme.primaryTextColor(for: colorScheme))
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(IOSPressButtonStyle())

                        // Cue Mode (GO capsule)
                        Button(action: {
                            modeChangeWorkItem?.cancel()
                            let workItem = DispatchWorkItem {
                                store.mode = .cue
                            }
                            modeChangeWorkItem = workItem
                            DispatchQueue.main.async(execute: workItem)
                        }) {
                            HStack {
                                if store.mode == .cue {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(currentTheme.accentColor(for: colorScheme))
                                        .frame(width: 20)
                                } else {
                                    Color.clear.frame(width: 20)
                                }
                                Text("Cue Mode")
                                    .font(currentTheme.font(size: 15, weight: .regular))
                                    .foregroundColor(currentTheme.primaryTextColor(for: colorScheme))
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(IOSPressButtonStyle())
                    }

                    Divider()
                        .padding(.horizontal, 24)

                    // Section 1: File Operations
                    sideMenuSection(title: "Project") {
                        sideMenuButton("New Project", icon: "doc.badge.plus", action: {
                            if isEditing { isEditing = false }
                            newProjectFlow()
                            closeMenu()
                        })
                        sideMenuButton("Save", icon: "square.and.arrow.down", action: {
                            if isEditing { isEditing = false }
                            saveCurrentProject(overwrite: true)
                            closeMenu()
                        })
                        sideMenuButton("Save As...", icon: "square.and.arrow.down.on.square", action: {
                            if isEditing { isEditing = false }
                            saveCurrentProject(overwrite: false)
                            closeMenu()
                        })
                        sideMenuButton("Open...", icon: "folder", action: {
                            if isEditing { isEditing = false }
                            projectsList = ProjectIO.list()
                            showProjects = true
                            closeMenu()
                        })
                        sideMenuButton("Import...", icon: "arrow.down.doc", action: {
                            if isEditing { isEditing = false }
                            openDocumentPicker()
                            closeMenu()
                        })
                        sideMenuButton("Export...", icon: "square.and.arrow.up", action: {
                            if isEditing { isEditing = false }
                            exportCurrentProject()
                            closeMenu()
                        })
                    }

                    Divider()
                        .padding(.horizontal, 24)

                    // Section 2: Settings
                    sideMenuSection(title: "Settings") {
                        sideMenuButton("MIDI Settings...", icon: "slider.horizontal.3", action: {
                            if isEditing { isEditing = false }
                            showMidiTable = true
                            closeMenu()
                        })
                        sideMenuButton("Appearance...", icon: "paintbrush", action: {
                            if isEditing { isEditing = false }
                            showAppearanceSettingsSheet = true
                            closeMenu()
                        })
                    }

                    Divider()
                        .padding(.horizontal, 24)

                    // Section 3: Help
                    sideMenuSection(title: "Help") {
                        sideMenuButton("Getting Started", icon: "questionmark.circle", action: {
                            if isEditing { isEditing = false }
                            // Only show onboarding if crash alert is not active
                            if !crashAlertActive {
                                showOnboarding = true
                            }
                            closeMenu()
                        })
                        #if DEBUG
                        // About button with long press for admin panel
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle")
                                .frame(width: 24)
                                .foregroundColor(currentTheme.accentColor(for: colorScheme))
                            Text("About Cue Bear")
                                .font(currentTheme.font(size: 15, weight: .regular))
                                .foregroundColor(currentTheme.primaryTextColor(for: colorScheme))
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isEditing { isEditing = false }
                            showAboutSheet = true
                            closeMenu()
                        }
                        .onLongPressGesture(minimumDuration: 3.0) {
                            showAdminPanel = true
                            closeMenu()
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        }
                        #else
                        sideMenuButton("About Cue Bear", icon: "info.circle", action: {
                            if isEditing { isEditing = false }
                            showAboutSheet = true
                            closeMenu()
                        })
                        #endif

                        // Reset Tutorials button (in Help section)
                        sideMenuButton("Reset Tutorials", icon: "arrow.counterclockwise", action: {
                            // Reset all tutorial flags
                            hasSeenTutorial1 = false
                            hasSeenTutorial2 = false
                            hasSeenTutorial2b = false
                            hasSeenTutorial2c = false
                            hasSeenTutorial3 = false
                            // Also reset nav pill and cue capsule tutorials
                            UserDefaults.standard.removeObject(forKey: "hasSeenNavPillTutorial")
                            UserDefaults.standard.removeObject(forKey: "hasSeenCueCapsuleTutorial")
                            // Reset onboarding so it shows again
                            UserDefaults.standard.removeObject(forKey: "hasSeenOnboarding")
                            closeMenu()
                            // Show onboarding immediately after menu closes
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                showOnboarding = true
                            }
                        })
                    }

                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
        .frame(maxHeight: .infinity)
        .background(currentTheme.titleBarColor(for: colorScheme))
        .shadow(color: .black.opacity(0.2), radius: 10, x: 2, y: 0)
    }

    private func sideMenuSection<Content: View>(title: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = title {
                Text(title)
                    .font(currentTheme.font(size: 11, weight: .semibold))
                    .foregroundColor(currentTheme.primaryTextColor(for: colorScheme))
                    .textCase(.uppercase)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 4)
            }
            content()
        }
    }

    private func sideMenuButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 24)
                    .foregroundColor(currentTheme.accentColor(for: colorScheme))
                Text(title)
                    .font(currentTheme.font(size: 15, weight: .regular))
                    .foregroundColor(currentTheme.primaryTextColor(for: colorScheme))
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(IOSPressButtonStyle())
    }

    private func closeMenu() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showSideMenu = false
        }
    }

    private func mainStack() -> AnyView {
        AnyView(
            ZStack(alignment: .leading) {
                // Theme background color - extends to all edges including safe areas
                currentTheme.backgroundColor(for: colorScheme)
                    .ignoresSafeArea(edges: .all)

                // Main content (without top bar - it will overlay)
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        buildMiddleSectionView()
                    }
                    .disabled(showSideMenu)
                    .blur(radius: showSideMenu ? 3 : 0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.85), value: showSideMenu)
                    .ignoresSafeArea(edges: .bottom) // Allow cues to extend into bottom safe area behind home indicator

                    // Floating control area capsules - NOT clipped so they can slide off-screen
                    ZStack {
                        if !isEditing && effectivelyCollapsedForOverlay && showCollapsedCapsule {
                            // Show small collapsed capsule with sequential animation
                            // Match expanded control area positioning
                            let bottomPadding: CGFloat = 21
                            AnyView(collapsedControlCapsule)
                                .padding(.bottom, bottomPadding)  // Match expanded control area bottom padding
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                                .ignoresSafeArea(edges: .bottom)  // Match expanded control area safe area handling
                                .zIndex(0)
                                .id("collapsed")
                                .transition(.move(edge: .bottom))
                        }

                        // PERFORMANCE: Only create CBControlSection when controlSectionReady is true
                        // This delays heavy view initialization until after initial app layout
                        // NOTE: Removed GeometryReader background - it caused UI freeze due to layout loop
                        if !isEditing && !effectivelyCollapsedForOverlay && showExpandedArea && controlSectionReady {
                            let isLandscape = verticalSizeClass == .compact
                            // Bottom padding: X + 2Y where X = home indicator height (~5pt), Y = its distance from bottom (8pt)
                            let bottomPadding: CGFloat = 21

                            AnyView(controlSectionView)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isLandscape ? .bottomTrailing : .bottom)
                                .padding(.trailing, isLandscape ? 16 : 0)
                                .padding(.bottom, bottomPadding)
                                .ignoresSafeArea(edges: .bottom)
                                .transition(.move(edge: .bottom))
                                .zIndex(1)
                                .id("expandedNonEdit")
                        }
                    }
                    // NOTE: No blanket .animation() here — using explicit withAnimation in onChange
                    // to prevent parent spring from infecting child view properties (e.g. chevron opacity)
                    .onChange(of: effectivelyCollapsedForOverlay) { _, isCollapsed in
                        // Mark as animating - prevents GeometryReader from updating height during animation
                        isAnimatingControlArea = true

                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            if isCollapsed {
                                // Collapsing: hide expanded area and show collapsed capsule simultaneously
                                showExpandedArea = false
                                showCollapsedCapsule = true
                            } else {
                                // Expanding: hide collapsed capsule and show expanded area simultaneously
                                showCollapsedCapsule = false
                                showExpandedArea = true
                            }
                        }

                        if isCollapsed {
                            // Set collapsed height immediately
                            controlAreaHeight = 56
                        } else {
                            // Set expanded height immediately from bounds or use fixed estimate
                            // IMPORTANT: Do NOT access UIScreen.main.bounds here - causes freeze
                            if let actualHeight = capsuleBounds["controlArea.main"]?.height, actualHeight > 56 {
                                controlAreaHeight = actualHeight
                            } else {
                                // Use fixed estimate - actual height will be set by CBControlSection
                                controlAreaHeight = 200
                            }
                        }

                        // Clear animating flag after animation completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            isAnimatingControlArea = false
                        }
                    }
                    .onAppear {
                        // Initialize visibility based on initial state
                        showCollapsedCapsule = effectivelyCollapsedForOverlay
                        showExpandedArea = !effectivelyCollapsedForOverlay

                        // Initialize control area height based on initial state
                        if effectivelyCollapsedForOverlay {
                            controlAreaHeight = 56  // Collapsed capsule height
                        } else {
                            // For expanded state, try to get actual height from bounds or use estimate
                            if let actualHeight = capsuleBounds["controlArea.main"]?.height {
                                controlAreaHeight = actualHeight
                            } else {
                                // Use fixed estimate - UIScreen.main.bounds access during layout causes freeze
                                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                                let maxHeight = isPhone ? globalCachedPortraitWidth * 0.8 : 200
                                controlAreaHeight = maxHeight
                            }
                        }

                        // PERFORMANCE: Delay CBControlSection creation until after initial layout
                        // This prevents the heavy view from blocking app startup
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            controlSectionReady = true
                        }
                    }
                }

                // Floating top bar overlay
                VStack {
                    AnyView(topBarView)
                        .padding(.top, UIDevice.current.userInterfaceIdiom == .phone && verticalSizeClass == .compact ? 8 : 0)
                    Spacer()
                }
                .background(Color.clear)
                .zIndex(10)

                // Side menu with overlay
                // Overlay - fades independently
                if showSideMenu {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                                showSideMenu = false
                            }
                        }
                        .zIndex(1)
                }

                // Menu - slides independently
                if showSideMenu {
                    sideMenuView
                        .frame(width: 320)
                        .transition(.move(edge: .leading))
                        .zIndex(2)
                }
            }
        )
    }

    // Control area is now always shown as overlay (see mainStack overlay)
    // No longer need bottomSectionView

    // MARK: - Control functions
    private func controlRowCount() -> Int {
        // Grid triples columns; normal buttons occupy 3, faders 2 (2 grid squares wide).
        let slotsPerRow = max(3, controlsPerRow * 3)
        let totalSlots = controlButtons.reduce(0) { acc, b in acc + (b.isFader == true ? 2 : 3) }
        return Int(ceil(Double(totalSlots) / Double(slotsPerRow)))
    }
    
    // Update fader value from DAW MIDI input
    private func updateFaderFromDAW(channel: Int, cc: Int, value: Int) {
        debugPrint("🎚️ updateFaderFromDAW: Looking for fader with channel=\(channel), cc=\(cc), value=\(value)")
        debugPrint("🎚️ Available faders:")
        for (index, button) in controlButtons.enumerated() {
            if button.isFader == true {
                debugPrint("🎚️   Fader \(index): \"\(button.title)\" - channel=\(button.channel), cc=\(button.number)")
            }
        }
        
        // Find the fader that matches this MIDI channel and CC
        if let index = controlButtons.firstIndex(where: { button in
            button.isFader == true && button.channel == channel && button.number == cc
        }) {
            // Convert MIDI value (0-127) to fader value (0.0-1.0)
            let faderValue = Double(value) / 127.0
            
            debugPrint("🎚️ ✅ Found matching fader \"\(controlButtons[index].title)\" at index \(index)")
            debugPrint("🎚️ Updated fader \"\(controlButtons[index].title)\" to \(faderValue) from DAW MIDI")
            
            // Store the fader value in the ControlButton model for persistence
            controlButtons[index].faderValue = faderValue
            markDirty() // Mark project as dirty to save the fader value
            
            // Post notification for the fader tile to update its visual value
            NotificationCenter.default.post(
                name: Notification.Name("cbUpdateFaderFromDAW"),
                object: nil,
                userInfo: [
                    "buttonID": controlButtons[index].id.uuidString,
                    "value": faderValue
                ]
            )
        } else {
            debugPrint("🎚️ ❌ No matching fader found for channel=\(channel), cc=\(cc)")
        }
    }

    private func canAddMoreControls() -> Bool {
        return controlRowCount() < maxControlRows
    }
    private func addControl() {
        // Legacy helper kept if needed elsewhere: directly append a default control
        let ch = isGlobalChannel ? globalChannel : 1
        let freeCC = (0...127).first { n in
            !(midiFiltersEnabled && midiFilter.contains(n)) &&
            ownerName(for: MIDIKey(kind: .cc, channel: ch, number: n)) == nil
        } ?? 0
        var new = ControlButton(title: "Custom", symbol: "square.grid.2x2.fill", kind: .cc, number: freeCC, channel: 1, velocity: 127)
        if autoAssignControlColors {
            let usedColors = Set(controlButtons.compactMap { $0.colorHex })
            let available = curatedColorPalette.filter { !usedColors.contains($0) }
            new.colorHex = available.randomElement() ?? curatedColorPalette.randomElement()
        }
        controlButtons.append(new)
        invalidateConflictCache()
        markDirty()
    }

    private func beginAddControl() {
        // Prepare a default control for editing (do not append yet)
        let ch = isGlobalChannel ? globalChannel : 1
        let freeCC = (0...127).first { n in
            !(midiFiltersEnabled && midiFilter.contains(n)) &&
            ownerName(for: MIDIKey(kind: .cc, channel: ch, number: n)) == nil
        } ?? 0
        let draft = ControlButton(title: "", symbol: "square.grid.2x2.fill", kind: .cc, number: freeCC, channel: 1, velocity: 127, isToggle: nil)
        editingControl = draft
        pendingAddIsFader = false
        showControlEditor = true
    }

    private enum AddKind { case button, fader }
    private func beginAddControlOfType(_ kind: AddKind) {
        debugPrint("🎹 [ADD CONTROL] beginAddControlOfType called with kind: \(kind)")
        // FIX: Skip filtered CC numbers and MIDI already taken by cues or controls
        let ch = isGlobalChannel ? globalChannel : 1
        let freeCC = (0...127).first { n in
            !(midiFiltersEnabled && midiFilter.contains(n)) &&
            ownerName(for: MIDIKey(kind: .cc, channel: ch, number: n)) == nil
        } ?? 0
        debugPrint("🎹 beginAddControlOfType: Found free CC = \(freeCC)")
        var draft = ControlButton(title: "", symbol: "square.grid.2x2.fill", kind: .cc, number: freeCC, channel: 1, velocity: 127, isToggle: nil, page: currentControlPage)
        switch kind {
        case .button:
            draft.isFader = false
            draft.isSmall = false
            draft.title = nextDefaultControlName("Button")
            debugPrint("🎹 [ADD CONTROL] Creating button draft on page \(currentControlPage)")
        case .fader:
            draft.isFader = true
            draft.isSmall = false
            draft.symbol = "" // no icon for fader
            draft.title = nextDefaultControlName("Fader")
            debugPrint("🎹 [ADD CONTROL] Creating fader draft on page \(currentControlPage)")
        }
        editingControl = draft
        // Hint the editor about fader mode
        pendingAddIsFader = (kind == .fader)
        debugPrint("🎹 [ADD CONTROL] Setting showControlEditor = true")
        showControlEditor = true
        debugPrint("🎹 [ADD CONTROL] showControlEditor is now: \(showControlEditor)")
    }

    private func deleteControl(_ btn: ControlButton) {
        pushControlUndo()
        controlButtons.removeAll { $0.id == btn.id }
        invalidateConflictCache()
        markDirty()
    }

    @ViewBuilder
    private var contentView: some View {
        ZStack {
            mainStack()
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .focusable()  // Required to receive keyboard input from Bluetooth pedals
                .focusEffectDisabled()  // Hide the blue focus indicator lines
                // Bluetooth pedal support (Airturn BT500 and similar devices)
                .onKeyPress(.upArrow) {
                    debugPrint("🎹 Up Arrow pressed")
                    handlePedalPrevious()
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    debugPrint("🎹 Down Arrow pressed")
                    handlePedalNext()
                    return .handled
                }
                .onKeyPress(.pageUp) {
                    debugPrint("🎹 Page Up pressed")
                    handlePedalPrevious()
                    return .handled
                }
                .onKeyPress(.pageDown) {
                    debugPrint("🎹 Page Down pressed")
                    handlePedalNext()
                    return .handled
                }
                // MARK: - Tutorial Overlays
                .overlay {
                    ZStack {
                        // Tutorial 1: Edit button (after onboarding)
                        if showTutorial1 && editButtonFrame != .zero {
                            UpwardTutorial(
                                message: "Open edit mode to add your first cue",
                                targetFrame: editButtonFrame,
                                onDismiss: {
                                    showTutorial1 = false
                                    hasSeenTutorial1 = true
                                    onTutorialDismissed()
                                },
                                onSkip: {
                                    showTutorial1 = false
                                    hasSeenTutorial1 = true
                                    onTutorialDismissed()
                                }
                            )
                        }

                        // Tutorial 2: + button (after clicking Edit)
                        if showTutorial2 && addCueButtonFrame != .zero {
                            UpwardTutorial(
                                message: "Tap + to add your first cue",
                                targetFrame: addCueButtonFrame,
                                onDismiss: {
                                    showTutorial2 = false
                                    hasSeenTutorial2 = true
                                    onTutorialDismissed()
                                },
                                onSkip: {
                                    showTutorial2 = false
                                    hasSeenTutorial2 = true
                                    if !hasSeenTutorial2b {
                                        pendingTutorial = 21  // 21 = tutorial 2b
                                    }
                                    onTutorialDismissed()
                                }
                            )
                        }

                        // Tutorial 2b: Library button (after tutorial 2 or adding cue)
                        if showTutorial2b && libraryButtonFrame != .zero {
                            UpwardTutorial(
                                message: "All your cues live in the cue library.",
                                targetFrame: libraryButtonFrame,
                                onDismiss: {
                                    showTutorial2b = false
                                    hasSeenTutorial2b = true
                                    onTutorialDismissed()
                                },
                                onSkip: {
                                    showTutorial2b = false
                                    hasSeenTutorial2b = true
                                    onTutorialDismissed()
                                }
                            )
                        }

                        // Tutorial 2c: Cue list name button
                        if showTutorial2c && cueListNameButtonFrame != .zero {
                            UpwardTutorial(
                                message: "Create as many cue lists as you want",
                                targetFrame: cueListNameButtonFrame,
                                onDismiss: {
                                    showTutorial2c = false
                                    hasSeenTutorial2c = true
                                    if !hasSeenTutorial3 {
                                        pendingTutorial = 3
                                    }
                                    onTutorialDismissed()
                                },
                                onSkip: {
                                    showTutorial2c = false
                                    hasSeenTutorial2c = true
                                    if !hasSeenTutorial3 {
                                        pendingTutorial = 3
                                    }
                                    onTutorialDismissed()
                                }
                            )
                        }

                        // Tutorial 3: Controls capsule (contextual: 3+ cues in active list)
                        if showTutorial3 && controlsCapsuleFrame != .zero {
                            DownwardTutorial(
                                message: "Add buttons and faders for extra MIDI control",
                                targetFrame: controlsCapsuleFrame,
                                onDismiss: {
                                    showTutorial3 = false
                                    hasSeenTutorial3 = true
                                    onTutorialDismissed()
                                },
                                onSkip: {
                                    showTutorial3 = false
                                    hasSeenTutorial3 = true
                                    onTutorialDismissed()
                                }
                            )
                        }

                        // Tutorial 4 (two-finger scroll) removed
                    }
                    .animation(.easeInOut(duration: 0.3), value: showTutorial1)
                    .animation(.easeInOut(duration: 0.3), value: showTutorial2)
                    .animation(.easeInOut(duration: 0.3), value: showTutorial2b)
                    .animation(.easeInOut(duration: 0.3), value: showTutorial2c)
                    .animation(.easeInOut(duration: 0.3), value: showTutorial3)
                    .onChange(of: showTutorial1) { _, newValue in
                        debugPrint("📖 [Tutorial] showTutorial1 changed to \(newValue), editButtonFrame=\(editButtonFrame), frame != .zero: \(editButtonFrame != .zero)")
                    }
                    .onChange(of: showTutorial2) { _, newValue in
                        debugPrint("📖 [Tutorial] showTutorial2 changed to \(newValue), addCueButtonFrame=\(addCueButtonFrame)")
                    }
                    .onChange(of: showTutorial2b) { _, newValue in
                        debugPrint("📖 [Tutorial] showTutorial2b changed to \(newValue), libraryButtonFrame=\(libraryButtonFrame)")
                    }
                    .onChange(of: showTutorial2c) { _, newValue in
                        debugPrint("📖 [Tutorial] showTutorial2c changed to \(newValue), cueListNameButtonFrame=\(cueListNameButtonFrame)")
                    }
                    .onChange(of: showTutorial3) { _, newValue in
                        debugPrint("📖 [Tutorial] showTutorial3 changed to \(newValue), controlsCapsuleFrame=\(controlsCapsuleFrame)")
                    }
                    // Tutorial 4 onChange removed
                    .onChange(of: showCueListChooser) { _, isShowing in
                        if isShowing && showTutorial2c {
                            // Dismiss tutorial 2c when user opens cue list chooser
                            showTutorial2c = false
                            hasSeenTutorial2c = true
                        }
                        if !isShowing && hasSeenTutorial2c && !hasSeenTutorial3 {
                            // Skip tutorial 3 if control area is already open
                            if !effectivelyCollapsedForOverlay {
                                hasSeenTutorial3 = true
                            } else {
                                // Queue Tutorial 3 after cue list chooser closes
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    self.requestTutorial(3)
                                }
                            }
                        }
                    }
                    .onChange(of: showLibraryPopover) { _, isShowing in
                        // Dismiss tutorial 2b when user opens song library
                        if isShowing && showTutorial2b {
                            showTutorial2b = false
                            hasSeenTutorial2b = true
                            onTutorialDismissed()
                        }
                    }
                }

            if showSplash {
                SplashScreen()
                    .transition(.opacity)
                    .ignoresSafeArea()
                    .zIndex(1)
            }
        }
    }

    var body: some View {
        applyObservers(applyLifecycle(
            applyAlerts(
                applySheets(
                    contentView
                        .onPreferenceChange(EditCapsuleBottomPreferenceKey.self) { value in
                            editCapsuleBottom = isEditing ? value : 0  // Only track when visible
                        }
                        .onPreferenceChange(CapsuleBoundsPreferenceKey.self) { value in
                            // PERFORMANCE: Guard against redundant updates to prevent layout loops
                            // Use a larger threshold (5 points) to filter out animation micro-updates
                            let hasSignificantChange = value.contains { key, newRect in
                                guard let oldRect = capsuleBounds[key] else { return true }
                                return abs(newRect.origin.x - oldRect.origin.x) > 5 ||
                                       abs(newRect.origin.y - oldRect.origin.y) > 5 ||
                                       abs(newRect.width - oldRect.width) > 5 ||
                                       abs(newRect.height - oldRect.height) > 5
                            }

                            guard hasSignificantChange || value.count != capsuleBounds.count else { return }

                            capsuleBounds = value
                            // Tutorial 4 controlAreaFrame tracking removed
                        }
                        .onPreferenceChange(TutorialButtonFramePreferenceKey.self) { value in
                            // PERFORMANCE: Only process tutorial frames when tutorials might be shown
                            // This prevents expensive frame comparisons on every layout pass
                            let anyTutorialVisible = showTutorial1 || showTutorial2 || showTutorial2b || showTutorial2c || showTutorial3
                            let anyTutorialPending = !hasSeenTutorial1 || !hasSeenTutorial2 || !hasSeenTutorial2b || !hasSeenTutorial2c || !hasSeenTutorial3

                            guard anyTutorialVisible || anyTutorialPending else { return }

                            // Helper to check if frames differ significantly (more than 5 points to filter animation frames)
                            func framesDiffer(_ a: CGRect, _ b: CGRect) -> Bool {
                                return abs(a.origin.x - b.origin.x) > 5 ||
                                       abs(a.origin.y - b.origin.y) > 5 ||
                                       abs(a.width - b.width) > 5 ||
                                       abs(a.height - b.height) > 5
                            }

                            // Silently update frames without logging - logging caused major performance issues
                            if let frame = value["editButton"], framesDiffer(frame, editButtonFrame) {
                                editButtonFrame = frame
                            }
                            if let frame = value["addCueButton"], framesDiffer(frame, addCueButtonFrame) {
                                addCueButtonFrame = frame
                            }
                            if let frame = value["libraryButton"], framesDiffer(frame, libraryButtonFrame) {
                                libraryButtonFrame = frame
                            }
                            if let frame = value["cueListNameButton"], framesDiffer(frame, cueListNameButtonFrame) {
                                cueListNameButtonFrame = frame
                            }
                            if let frame = value["controlsCapsule"], framesDiffer(frame, controlsCapsuleFrame) {
                                controlsCapsuleFrame = frame
                            }
                        }
                        .onChange(of: isEditing) { oldValue, newValue in
                            if newValue {
                                // Entering edit mode - save current mode
                                modeBeforeEditing = store.mode

                                // Tutorial 2: Show + button tutorial after clicking Edit
                                if showTutorial1 {
                                    // Dismiss Tutorial 1 first
                                    showTutorial1 = false
                                    hasSeenTutorial1 = true
                                    onTutorialDismissed()
                                }
                                if !hasSeenTutorial2 {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        self.requestTutorial(2)
                                    }
                                }
                            } else {
                                // Exiting edit mode - restore previous mode if it was cue or regularPlusRemote
                                if let previousMode = modeBeforeEditing,
                                   (previousMode == .cue || previousMode == .regularPlusRemote) {
                                    store.mode = previousMode
                                }
                                modeBeforeEditing = nil

                                // Dismiss tutorial 2 or 2b if still showing when exiting edit mode
                                if showTutorial2 {
                                    showTutorial2 = false
                                    hasSeenTutorial2 = true
                                    onTutorialDismissed()
                                }
                                if showTutorial2b {
                                    showTutorial2b = false
                                    hasSeenTutorial2b = true
                                    onTutorialDismissed()
                                }

                                // Tutorial 2c: Show cue list name tutorial after exiting edit mode
                                if !hasSeenTutorial2c {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        self.requestTutorial(22)  // 22 = tutorial 2c
                                    }
                                }
                                // Tutorial 3: Show controls tutorial after exiting edit mode (if 2c already seen)
                                else if !hasSeenTutorial3 {
                                    // Skip if control area is already open
                                    if !effectivelyCollapsedForOverlay {
                                        hasSeenTutorial3 = true
                                    } else {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            self.requestTutorial(3)
                                        }
                                    }
                                }
                            }
                        }
                        .onChange(of: scenePhase) { _, phase in
                            // Ensure connections are properly managed when app becomes active
                            if phase == .active {
                                debugPrint("📱 App became active, managing connections...")

                                // Restart USB tunnel
                                // usb.stop() // Removed to prevent restart loop

                                // Small delay to ensure clean restart
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    // Simple connection management - USB server is already running
                                    debugPrint("📱 App became active, USB server should be running")
                                    if !wifiClient.isConnected {
                                        wifiClient.restartDiscovery()
                                    }
                                }
                            } else if phase == .background {
                                // Save project when app goes to background
                                if isDirty && !isUntitledProject(projectName) {
                                    debugPrint("💾 App going to background, saving project: \(projectName)")
                                    snapshotAndSave(as: projectName, overwrite: true)
                                }
                            }
                        }
                        .onChange(of: store.mode) { _, newMode in
                            if !isUntitledProject(projectName) && !isLoadingProject {
                                debugPrint("🔄 Mode changed to \(newMode), saving project: \(projectName)")
                                snapshotAndSave(as: projectName, overwrite: true)
                            }

                            // Tutorial interruption: When switching to Navigator or Cue mode, pause current tutorial
                            // so the nav pill or cue capsule tutorial can show first
                            if newMode == .regularPlusRemote || newMode == .cue {
                                // Check if any tutorial is currently showing and save it
                                if showTutorial1 {
                                    interruptedTutorial = 1
                                    showTutorial1 = false
                                } else if showTutorial2 {
                                    interruptedTutorial = 2
                                    showTutorial2 = false
                                } else if showTutorial2b {
                                    interruptedTutorial = 3  // Using 3 for 2b
                                    showTutorial2b = false
                                } else if showTutorial2c {
                                    interruptedTutorial = 4  // Using 4 for 2c
                                    showTutorial2c = false
                                } else if showTutorial3 {
                                    interruptedTutorial = 5  // Using 5 for 3
                                    showTutorial3 = false
                                }
                            }
                        }
                )
            )
        ))
        .preferredColorScheme(currentTheme.preferredColorScheme(for: colorScheme))
    }

    // MARK: - View Modifiers (extracted to fix compiler type-checking timeout)

    @ViewBuilder
    /// v1.3 (Cue Bear Next): Show mode and Notes & Extras, kept out of the long sheet chain below
    /// so the compiler can type-check each part quickly.
    private func applyNextFeatures<V: View>(_ view: V) -> some View {
        view
        // v1.3 (Cue Bear Next): the stage screen
        .fullScreenCover(isPresented: $showShowMode) {
            ShowModeView(
                store: store,
                coordinator: connectionCoordinator,
                wifiClient: wifiClient,
                usbServer: usbServer,
                rigs: BackupRigManager.shared,
                controlButtons: $controlButtons,
                projectName: isUntitledProject(projectName) ? "Untitled show" : projectName,
                accent: currentTheme.accentColor(for: colorScheme),
                isGlobalChannel: isGlobalChannel,
                globalChannel: globalChannel,
                startAfterSongID: lastPlayedCueID,
                onFire: { song in trigger(song) },
                onSharedControl: { button in triggerControl(button) },
                onExit: { showShowMode = false }
            )
        }
        // v1.3 (Cue Bear Next): Notes & Extras for one song
        .sheet(item: $songForDetails) { song in
            SongDetailsSheet(
                originalSong: song,
                sharedFaders: controlButtons.filter { $0.isFader == true },
                otherSongs: store.activeSongs.filter { $0.id != song.id },
                accent: currentTheme.accentColor(for: colorScheme),
                onSave: { updated in
                    saveSong(updated)
                    saveIfNamed()
                    songForDetails = nil
                },
                onCopyExtras: { ids, extras in
                    copyExtras(extras, toSongIDs: ids)
                },
                onCancel: { songForDetails = nil }
            )
            .presentationCornerRadius(20)
        }
    }

    private func applySheets<V: View>(_ view: V) -> some View {
        applyNextFeatures(view)
        // MARK: Sheets
        .sheet(isPresented: $showConnections) {
            CBConnectionsSheet(
                usbServer: usbServer,
                wifiClient: wifiClient,
                connectionCoordinator: connectionCoordinator,
                onDisconnectWifi: { connectionCoordinator.disconnectWiFi() },
                onConnectWifiItem: { item in
                    connectionCoordinator.connectToWiFi(bridge: item)
                }
            )
            .presentationBackground(currentTheme.sheetBackgroundColor(for: colorScheme))
            .presentationCornerRadius(20)
        }
        .sheet(isPresented: $showMidiTable) {
            MidiTableSheet(
                setlist: store.activeSongs,
                controlButtons: $controlButtons,
                isGlobalChannel: $isGlobalChannel,
                globalChannel: $globalChannel,
                midiFiltersEnabled: $midiFiltersEnabled,
                midiFilter: $midiFilter,
                customMidiFilters: $customMidiFilters,
                onDismiss: { showMidiTable = false },
                onApply: { items in
                    debugPrint("🎛️ [MIDI] Applying MIDI assignments: \(items.count) items")

                    // Write changes back to setlist and controls by id
                    store.updateActiveSongs { songs in
                        for i in 0..<songs.count {
                            if let edited = items.first(where: { $0.id == songs[i].id }) {
                                debugPrint("🎛️ [MIDI] Updating song '\(songs[i].name)': \(edited.midiType) Ch\(edited.channel) #\(edited.value)")
                                songs[i].kind = edited.midiType
                                songs[i].channel = edited.channel
                                if edited.midiType == .note { songs[i].note = edited.value } else { songs[i].cc = edited.value }
                            }
                        }
                    }

                    var controls = controlButtons
                    var updatedCount = 0
                    for i in 0..<controls.count {
                        if let edited = items.first(where: { $0.id == controls[i].id }) {
                            debugPrint("🎛️ [MIDI] Updating control '\(controls[i].title)' (was \(controls[i].kind) Ch\(controls[i].channel) #\(controls[i].number)) -> (now \(edited.midiType) Ch\(edited.channel) #\(edited.value))")
                            controls[i].kind = edited.midiType
                            controls[i].channel = edited.channel
                            controls[i].number = edited.value
                            updatedCount += 1
                        }
                    }
                    debugPrint("🎛️ [MIDI] Updated \(updatedCount) controls out of \(controls.count) total")
                    controlButtons = controls
                    markDirty()
                }
            )
            .presentationBackground(currentTheme.sheetBackgroundColor(for: colorScheme))
            .presentationCornerRadius(20)
        }
        .sheet(isPresented: $showAddEdit, onDismiss: {
            // Tutorial 2b: Show Library tutorial after adding a cue
            if hasSeenTutorial2 && !hasSeenTutorial2b && isEditing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.requestTutorial(21)  // 21 = tutorial 2b
                }
            }
        }) {
            CBAddEditCueSheet(
                editingSong: $editingSong,
                conflictFor: conflictLookup(),
                currentOwnerName: { key in ownerName(for: key) },
                defaultName: nextDefaultCueName(),
                onSave: { song, andAddAnother in
                    saveCueWithDuplicateCheck(song, andAddAnother: andAddAnother) {
                        if andAddAnother {
                            // Close with linear animation (no slowdown) and reopen
                            withAnimation(.linear(duration: 0.15)) {
                                showAddEdit = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                showAddEdit = true
                            }
                        } else {
                            // Normal close
                            showAddEdit = false
                        }
                    }
                },
                onCancel: {
                    // v1.0.8: Don't clear draft - it persists across dismissals
                    // Only close sheet
                    showAddEdit = false
                },
                onDelete: { song in
                    // Remove from cue list only (when in cue list context)
                    // Or delete from library (when in library context)
                    if isEditing {
                        removeFromSetlist(song)
                    } else {
                        deleteFromLibrary(song)
                    }
                    showAddEdit = false
                },
                onDeleteFromLibrary: { song in
                    // Delete from library (and all cue lists)
                    deleteFromLibrary(song)
                    showAddEdit = false
                },
                onDuplicate: { song in
                    // Create an alias cue
                    var aliasCue = song
                    aliasCue.id = UUID()  // New ID for the alias
                    aliasCue.aliasedCueID = song.id  // Reference to original cue

                    // Add to setlist
                    store.updateActiveSongs { $0.append(aliasCue) }
                    showAddEdit = false
                },
                editContext: isEditing ? .cueList : .library,
                isGlobalChannel: isGlobalChannel,
                globalChannel: globalChannel,
                midiFilter: midiFilter
            )
            .presentationBackground(currentTheme.sheetBackgroundColor(for: colorScheme))
            .presentationCornerRadius(20)
        }
        .sheet(isPresented: $showAddEditMIDIOnly) {
            CBMIDIPickerSheet(
                title: "Change MIDI",
                kind: editingSong?.kind ?? .cc,
                number: (editingSong?.kind == .note) ? (editingSong?.note ?? 60) : (editingSong?.cc ?? 0),
                channel: editingSong?.channel ?? 1,
                velocity: editingSong?.velocity ?? 127,
                conflictFor: conflictLookup(),
                currentOwnerName: { key in ownerName(for: key) },
                onSave: { kind, number, channel, velocity in
                    guard var s = editingSong else { return }
                    s.kind = kind
                    if kind == .note { s.note = number } else { s.cc = number }
                    s.channel = channel
                    s.velocity = velocity
                    saveSong(s)
                    showAddEditMIDIOnly = false
                },
                onCancel: { showAddEditMIDIOnly = false },
                editingSongName: editingSong?.name
            )
            .presentationBackground(currentTheme.sheetBackgroundColor(for: colorScheme))
            .presentationCornerRadius(20)
        }
        .sheet(isPresented: $showControlEditor) {
            CBControlEditorSheet(
                editing: $editingControl,
                conflictFor: conflictLookup(),
                currentOwnerName: { key in ownerName(for: key) },
                pendingIsFader: $pendingAddIsFader,
                isGlobalChannel: isGlobalChannel,
                globalChannel: globalChannel,
                midiFilter: midiFilter,
                onSave: { updated, andAddAnother in
                    if let idx = controlButtons.firstIndex(where: { $0.id == updated.id }) {
                        // Editing existing control
                        pushControlUndo()
                        // Force SwiftUI to detect the change by creating a new array
                        var updatedButtons = controlButtons
                        updatedButtons[idx] = updated
                        controlButtons = updatedButtons
                    } else {
                        // Adding new control
                        pushControlUndo()
                        // Assign grid position immediately when adding new control
                        var newControl = updated
                        if newControl.gridCol == nil || newControl.gridRow == nil {
                            // Find first available position based on control type
                            let buttonWidth = newControl.gridWidth
                            let buttonHeight = newControl.gridHeight

                            // Only check buttons on the same page for overlap
                            let pageButtons = controlButtons.filter { $0.page == newControl.page }

                            // Simple position finder - scan grid for first available spot
                            var foundPosition = false
                            for row in 0..<4 { // Scan up to 4 rows (matching display limit)
                                for col in 0..<(8 - buttonWidth + 1) { // 8 columns max, account for width
                                    var canPlace = true
                                    // Check if this position is free
                                    for existingButton in pageButtons {
                                        if let existingCol = existingButton.gridCol, let existingRow = existingButton.gridRow {
                                            let existingWidth = existingButton.gridWidth
                                            let existingHeight = existingButton.gridHeight

                                            // Check for overlap
                                            if !(col + buttonWidth <= existingCol ||
                                                existingCol + existingWidth <= col ||
                                                row + buttonHeight <= existingRow ||
                                                existingRow + existingHeight <= row) {
                                                canPlace = false
                                                break
                                            }
                                        }
                                    }
                                    if canPlace {
                                        newControl.gridCol = col
                                        newControl.gridRow = row
                                        foundPosition = true
                                        debugPrint("🔧 Assigned new control to position (\(col), \(row)) on page \(newControl.page)")
                                        break
                                    }
                                }
                                if foundPosition { break }
                            }

                            if !foundPosition {
                                // Fallback to 0,0 if no space found
                                newControl.gridCol = 0
                                newControl.gridRow = 0
                                debugPrint("🔧 No space found, placing new control at (0, 0) on page \(newControl.page)")
                            }
                        }
                        // Auto-assign random color for new controls if enabled and no color set
                        if autoAssignControlColors && newControl.colorHex == nil {
                            let usedColors = Set(controlButtons.compactMap { $0.colorHex })
                            let available = curatedColorPalette.filter { !usedColors.contains($0) }
                            if let random = available.randomElement() {
                                newControl.colorHex = random
                            } else {
                                newControl.colorHex = curatedColorPalette.randomElement()
                            }
                        }
                        controlButtons.append(newControl)
                    }
                    invalidateConflictCache()
                    markDirty()

                    if andAddAnother {
                        // Close with linear animation (no slowdown) and reopen
                        withAnimation(.linear(duration: 0.15)) {
                            showControlEditor = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            showControlEditor = true
                        }
                    } else {
                        // Normal close
                        showControlEditor = false
                        pendingAddIsFader = nil
                    }
                },
                    onCancel: { showControlEditor = false; pendingAddIsFader = nil },
                onDelete: { control in
                    deleteControl(control)
                    showControlEditor = false
                    pendingAddIsFader = nil
                },
                allButtons: controlButtons,
                columns: 8,
                icons: icons,
                isEditMode: false,
                canAddMore: $canAddMoreControlsToGrid,
                flashNewForm: $flashNewFormControl,
                draft: controlEditorDraft  // v1.0.8: Pass draft manager
            )
            .presentationBackground(currentTheme.sheetBackgroundColor(for: colorScheme))
            .presentationCornerRadius(20)
        }
        .sheet(isPresented: $showEditControlSheet) {
            CBControlEditorSheet(
                editing: $editingControlForEdit,
                conflictFor: conflictLookup(),
                currentOwnerName: { key in ownerName(for: key) },
                pendingIsFader: $pendingAddIsFader,
                isGlobalChannel: isGlobalChannel,
                globalChannel: globalChannel,
                midiFilter: midiFilter,
                onSave: { updated, andAddAnother in
                    if let idx = controlButtons.firstIndex(where: { $0.id == updated.id }) {
                        // Editing existing control
                        pushControlUndo()
                        // Force SwiftUI to detect the change by creating a new array
                        var updatedButtons = controlButtons
                        updatedButtons[idx] = updated
                        controlButtons = updatedButtons
                    }
                    invalidateConflictCache()
                    markDirty()
                    // Edit sheet always closes (andAddAnother only for add sheet)
                    showEditControlSheet = false
                    editingControlForEdit = nil
                    pendingAddIsFader = nil
                },
                onCancel: {
                    showEditControlSheet = false
                    editingControlForEdit = nil
                    pendingAddIsFader = nil
                },
                onDelete: { control in
                    deleteControl(control)
                    showEditControlSheet = false
                    editingControlForEdit = nil
                    pendingAddIsFader = nil
                },
                allButtons: controlButtons,
                columns: 8,
                icons: icons,
                isEditMode: true,
                canAddMore: $canAddMoreControlsToGrid,
                flashNewForm: .constant(false),  // Edit mode doesn't use "Save & Add Another"
                draft: controlEditorDraft  // v1.0.8: Pass draft manager
            )
            .presentationBackground(currentTheme.sheetBackgroundColor(for: colorScheme))
            .presentationCornerRadius(20)
        }
        .sheet(isPresented: $showProjects) {
            CBProjectsSheet(
                projectName: $projectName,
                projects: projectsList,
                isDirty: $isDirty,
                onTapTitleWhenUnsaved: { tempName = projectName; showNamePrompt = true },
                onLoad: { name in checkUnsavedChangesBeforeAction { loadProject(named: name) } },
                onDelete: { name in
                    debugPrint("🗑️ Delete button tapped for project: \(name)")

                    // If deleting the current project, switch to Untitled
                    if name == projectName {
                        debugPrint("🗑️ Deleting current project, switching to Untitled")
                        projectName = "Untitled"
                        isDirty = false
                    }

                    ProjectIO.delete(name: name)
                    projectsList = ProjectIO.list()
                    debugPrint("🗑️ Projects list after deletion: \(projectsList)")
                }
            )
            .presentationBackground(currentTheme.sheetBackgroundColor(for: colorScheme))
            .presentationCornerRadius(20)
        }
        .sheet(isPresented: $showOnboarding, onDismiss: {
            // v1.3 (Cue Bear Next): the step-by-step tutorials are retired; the demo show
            // and the connect checklist replace them.
            UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
            hasSeenTutorial1 = true
            hasSeenTutorial2 = true
            hasSeenTutorial2b = true
            hasSeenTutorial2c = true
            hasSeenTutorial3 = true
        }) {
            FirstRunView(
                usbServer: usbServer,
                wifiClient: wifiClient,
                coordinator: connectionCoordinator,
                accent: currentTheme.accentColor(for: colorScheme),
                onSendTest: { sendFirstRunTest() },
                onConnectWiFi: { item in connectionCoordinator.connectToWiFi(bridge: item) },
                onTryShowMode: {
                    showOnboarding = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showShowMode = true }
                },
                onDone: { showOnboarding = false }
            )
            .presentationBackground(currentTheme.sheetBackgroundColor(for: colorScheme))
            .presentationCornerRadius(20)
            .interactiveDismissDisabled(false)
        }

        .sheet(isPresented: $showAboutSheet) {
            AboutSheet()
                .presentationBackground(currentTheme.sheetBackgroundColor(for: colorScheme))
                .presentationCornerRadius(20)
        }
        .sheet(isPresented: $showAppearanceSheet) {
            AppearanceSheet()
                .presentationBackground(currentTheme.sheetBackgroundColor(for: colorScheme))
                .presentationCornerRadius(20)
        }
        .sheet(isPresented: $showAppearanceSettingsSheet) {
            AppearanceSettingsSheet()
                .presentationBackground(currentTheme.sheetBackgroundColor(for: colorScheme))
                .presentationCornerRadius(20)
        }
        .sheet(isPresented: $showDesignPreview) {
            DesignPreviewSheet()
                .presentationBackground(currentTheme.sheetBackgroundColor(for: colorScheme))
                .presentationCornerRadius(20)
        }
        #if DEBUG
        .sheet(isPresented: $showAdminPanel) {
            ThemeAdminPanel()
                .presentationBackground(currentTheme.sheetBackgroundColor(for: colorScheme))
                .presentationCornerRadius(20)
        }
        #endif
        // Force default theme on every app launch
        .task {
            selectedThemeID = "default"
        }
        // TODO: Integrate tutorial overlay when ready
        // .overlay {
        //     TutorialOverlay(coordinator: tutorialCoordinator)
        // }
    }

    @ViewBuilder
    private func applyAlerts<V: View>(_ view: V) -> some View {
        view
        .cbDialog("Project Name", isPresented: $showNamePrompt, themeFont: currentTheme.font,
            message: "Enter a name for your project.",
            textField: $tempName, textFieldPlaceholder: "Name",
            buttons: [
                .init("OK", role: .primary) {
                    let final = tempName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !final.isEmpty else { return }
                    projectName = final
                    if shouldSaveAfterNaming {
                        snapshotAndSave(as: final, overwrite: false)
                        shouldSaveAfterNaming = false
                    }
                    showProjects = false
                },
                .init("Cancel", role: .cancel) {
                    shouldSaveAfterNaming = false
                }
            ]
        )
        .cbDialog("Rename Cue List", isPresented: $showCueListRenamePrompt, themeFont: currentTheme.font,
            message: "Enter a new name for this cue list.",
            textField: $tempCueListName, textFieldPlaceholder: "Name",
            buttons: [
                .init("Save", role: .primary) {
                    let final = tempCueListName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !final.isEmpty, let cueListID = cueListToRename else { return }
                    if store.cueListNameExists(final, excluding: cueListID) {
                        duplicateRenameNewName = final
                        showDuplicateRenameAlert = true
                    } else {
                        store.renameCueList(cueListID, to: final)
                        isDirty = true
                        cueListToRename = nil
                    }
                },
                .init("Cancel", role: .cancel) {
                    cueListToRename = nil
                }
            ]
        )
        .cbDialog("Duplicate Name", isPresented: $showDuplicateRenameAlert, themeFont: currentTheme.font,
            message: "A cue list named \"\(duplicateRenameNewName)\" already exists. Do you want to use this name anyway?",
            buttons: [
                .init("Use Anyway", role: .primary) {
                    guard let cueListID = cueListToRename else { return }
                    store.renameCueList(cueListID, to: duplicateRenameNewName)
                    isDirty = true
                    cueListToRename = nil
                },
                .init("Cancel", role: .cancel) { }
            ]
        )
        .cbDialog("New Cue List", isPresented: $showNewCueListPrompt, themeFont: currentTheme.font,
            message: "Enter a name for the new cue list.",
            textField: $newCueListName, textFieldPlaceholder: "Name",
            buttons: [
                .init("Create", role: .primary) {
                    let final = newCueListName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !final.isEmpty else { return }
                    if store.cueListNameExists(final) {
                        duplicateCueListName = final
                        showDuplicateCueListAlert = true
                    } else {
                        let newID = store.createCueList(name: final)
                        store.switchToCueList(newID)
                        isDirty = true
                    }
                },
                .init("Cancel", role: .cancel) { }
            ]
        )
        .cbDialog("Duplicate Name", isPresented: $showDuplicateCueListAlert, themeFont: currentTheme.font,
            message: "A cue list named \"\(duplicateCueListName)\" already exists in your song library.",
            buttons: [
                .init("Create A Copy", role: .primary) {
                    let newID = store.createCueList(name: duplicateCueListName, forceNumbered: true)
                    store.switchToCueList(newID)
                    isDirty = true
                },
                .init("Cancel", role: .cancel) { }
            ]
        )
        .cbDialog("Duplicate Name", isPresented: $showDuplicateCueNameAlert, themeFont: currentTheme.font,
            message: "A cue named \"\(duplicateCueName)\" already exists in your library.",
            buttons: [
                .init("Rename to \"\(duplicateCueSuggestedName)\"", role: .primary) {
                    if var cue = pendingDuplicateCue {
                        let addAnother = pendingDuplicateCueAddAnother
                        cue.name = duplicateCueSuggestedName
                        saveSong(cue)
                        pendingDuplicateCue = nil
                        if addAnother {
                            withAnimation(.linear(duration: 0.15)) {
                                showAddEdit = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                showAddEdit = true
                            }
                        } else {
                            showAddEdit = false
                        }
                    }
                },
                .init("Cancel", role: .cancel) {
                    pendingDuplicateCue = nil
                }
            ]
        )
        .cbDialog("Save Changes", isPresented: $showSaveChangesAlert, themeFont: currentTheme.font,
            message: "You have unsaved changes. Do you want to save them before continuing?",
            buttons: [
                .init("Save", role: .primary) {
                    saveCurrentProject(overwrite: true)
                    pendingAction?()
                    pendingAction = nil
                },
                .init("Don't Save", role: .destructive) {
                    pendingAction?()
                    pendingAction = nil
                },
                .init("Cancel", role: .cancel) {
                    pendingAction = nil
                }
            ]
        )
        .cbDialog("Error Loading Project", isPresented: $showDocumentLoadError, themeFont: currentTheme.font,
            message: documentLoadErrorMessage,
            buttons: [
                .init("OK", role: .primary) {
                    documentLoadErrorMessage = ""
                }
            ]
        )
        .cbDialog("Delete Song", isPresented: $showDeleteConfirmation, themeFont: currentTheme.font,
            message: "Remove \"\(songToDelete?.name ?? "")\" from song library and cue list?",
            buttons: [
                .init("Delete from Both", role: .destructive) {
                    if let song = songToDelete {
                        performDeleteFromLibrary(song)
                    }
                    songToDelete = nil
                },
                .init("Cancel", role: .cancel) {
                    songToDelete = nil
                }
            ]
        )
    }

    @ViewBuilder
    private func applyLifecycle<V: View>(_ view: V) -> some View {
        view
        // MARK: Lifecycle
        // FIX #1: Setup notification subscriptions on appear
        .onAppear {
            setupNotificationSubscriptions()
            cachedConflictLookup = computeConflictLookup()
            loadMidiFiltersFromUserDefaults()
        }
        .task {
            let loadStart = Date()
            debugPrint("🚀 App launch: hasCompletedInitialLaunch=\(hasCompletedInitialLaunch)")

            // Build initial conflict cache
            cachedConflictLookup = computeConflictLookup()

            // On very first ever launch, clear any stale state
            if !hasInitialized && !hasCompletedInitialLaunch {
                debugPrint("🔄 First launch — clearing all data")
                store.updateActiveSongs { $0.removeAll() }
                songLibrary.removeAll()
                controlButtons.removeAll()
                libAddedAt.removeAll()
                hasInitialized = true
            }

            // Load project list from disk
            projectsList = await Task.detached(priority: .userInitiated) { ProjectIO.list() }.value
            debugPrint("📁 Found \(projectsList.count) projects")

            // Load project data into memory if needed
            if songLibrary.isEmpty && !isUntitledProject(projectName) && !projectName.isEmpty {
                debugPrint("🔄 Loading project: \(projectName)")
                await autoOpenLastProject()
            } else if songLibrary.isEmpty && isUntitledProject(projectName) {
                if let saved = await Task.detached(priority: .userInitiated, operation: { ProjectIO.loadLibraryAutosave() }).value {
                    songLibrary = saved
                    debugPrint("📂 Restored \(saved.count) songs from autosave")
                }
            }

            // Rebuild cache after data load
            cachedConflictLookup = computeConflictLookup()
            debugPrint("🔄 Conflict cache: \(cachedConflictLookup.count) entries")

            // Splash shows for minimum 1.5s (first launch: 2.5s) — loading runs concurrently
            let minDuration: Double = hasCompletedInitialLaunch ? 1.5 : 2.5
            let elapsed = Date().timeIntervalSince(loadStart)
            let remaining = max(0.0, minDuration - elapsed)
            if remaining > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }

            withAnimation(.easeInOut(duration: 0.5)) {
                debugPrint("🎬 Hiding splash screen")
                showSplash = false
            }

            hasCompletedInitialLaunch = true

            // v1.3 (Cue Bear Next): a brand-new user starts inside a real demo show
            if !UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
                && songLibrary.isEmpty
                && ProjectIO.list().contains(DemoShows.firstShowName) {
                loadProject(named: DemoShows.firstShowName)
            }

            // Show onboarding if not yet seen
            let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
            debugPrint("📖 Onboarding: hasSeenOnboarding=\(hasSeenOnboarding), crashAlertActive=\(crashAlertActive)")
            if !hasSeenOnboarding && !crashAlertActive {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showOnboarding = true
                }
            }

            debugPrint("✅ App initialization complete")
        }
        .onDisappear {
            // FIX #1: Clean up notification subscriptions to prevent memory leaks
            notificationCancellables.removeAll()
            // Don't stop connections completely - just pause them for background
            // This allows automatic reconnection when the app is reopened
            debugPrint("📱 App going to background - pausing connections")
            // Connections are managed by ConnectionCoordinator
        }
        // Connection monitoring now handled by ConnectionCoordinator
        .task(id: wifiClient.discovered.count) {
            debugPrint("🔍 Discovery changed: \(wifiClient.discovered.count) bridges found")
            debugPrint("🔌 USB connected: \(usbServer.isConnected), WiFi connected: \(wifiClient.isConnected)")
            
            // Simple status reporting - ConnectionCoordinator handles the logic
            if wifiClient.discovered.count > 0 {
                debugPrint("🔌 Bridge discovered - USB server running, WiFi available for manual connection")
            } else if wifiClient.discovered.count == 0 {
                debugPrint("⏸️ No bridges discovered - waiting for bridge to appear")
            } else if wifiClient.isConnected {
                debugPrint("✅ Already connected to bridge")
            } else {
                debugPrint("⏸️ Waiting for user to choose connection method")
            }
        }
        .task(id: store.mode) {
            if store.mode == .regular || store.mode == .regularPlusRemote { store.cuedSong = nil }
            updateConflictCache()
        }
        .task(id: store.activeSongs.map(\.id)) {
            updateConflictCache()
            if !isLoadingProject {
                markDirty()
            }
        }
        .task(id: songLibrary) {
            updateConflictCache()
            if !isLoadingProject {
                markDirty()
            }
        }
        .onChange(of: isGlobalChannel) { oldValue, newValue in
            handleGlobalChannelToggle(wasEnabled: oldValue, isEnabled: newValue)
        }
        .onChange(of: globalChannel) { oldValue, newValue in
            // When global channel number changes while global mode is enabled, reapply
            if isGlobalChannel && !isLoadingProject {
                debugPrint("🌍 Global channel changed from \(oldValue) to \(newValue) - reapplying to all items")
                applyGlobalChannel()
                invalidateConflictCache()
                markDirty()
            }
        }
        .onChange(of: midiFiltersEnabled) { _, _ in
            if !isLoadingProject { markDirty() }
        }
        .onChange(of: midiFilter) { _, newValue in
            if !isLoadingProject {
                markDirty()
                UserDefaults.standard.set(Array(newValue), forKey: "midiFilterCCs")
            }
        }
        .onChange(of: customMidiFilters.count) { _, _ in
            if !isLoadingProject {
                markDirty()
                saveMidiCustomFiltersToUserDefaults()
            }
        }
        .task(id: controlButtons) {
            updateConflictCache()
            if !isLoadingProject {
                markDirty()
            }
        }
    }

    @ViewBuilder private func applyObservers<V: View>(_ view: V) -> some View {
        view
            .onChange(of: isDirty) { _, newValue in
                guard newValue, !isUntitledProject(projectName) else { return }
                autosaveWorkItem?.cancel()
                let currentProjectName = projectName
                let workItem = DispatchWorkItem {
                    snapshotAndSave(as: currentProjectName, overwrite: true)
                }
                autosaveWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: workItem)
            }
            .onChange(of: songLibrary) { _, newLibrary in
                DispatchQueue.global(qos: .utility).async {
                    ProjectIO.saveLibraryAutosave(newLibrary)
                }
            }
            .onChange(of: isEditing) { _, newValue in
                if !newValue {
                    libBatchMode = false
                    libSelected.removeAll()
                    setlistBatchMode = false
                    setlistSelected.removeAll()
                    reorderMode = false
                    WobbleAnimator.shared.stopAll()
                }
            }
            .onChange(of: libraryQuery) { _, newQuery in
                isTyping = !newQuery.isEmpty
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if libraryQuery == newQuery {
                        libraryQueryDebounced = newQuery
                        isTyping = false
                    }
                }
            }
            .onChange(of: setlistQuery) { _, newQuery in
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if setlistQuery == newQuery {
                        setlistQueryDebounced = newQuery
                    }
                }
            }
    }

    // MARK: - Conflict map (always use cached version to prevent main thread blocking)
    private func conflictLookup() -> [MIDIKey: String] {
        // FIX: NEVER compute synchronously during rendering - this was causing app freeze
        // Always return cached value (even if empty). The cache will be populated
        // asynchronously by .task modifiers within ~500ms
        // Empty cache temporarily shows no conflicts, which is acceptable vs freezing the app
        return cachedConflictLookup
    }

    private func computeConflictLookup() -> [MIDIKey: String] {
        var multiMap: [MIDIKey: [String]] = [:]

        // Songs in setlist + library (deduplicate by ID to avoid counting same song twice)
        var seenSongIDs = Set<UUID>()
        for s in (store.activeSongs + songLibrary) {
            // Skip if we've already processed this song ID
            guard !seenSongIDs.contains(s.id) else { continue }
            seenSongIDs.insert(s.id)

            let key = (s.kind == .note)
                ? MIDIKey(kind: .note, channel: s.channel, number: s.note ?? 0)
                : MIDIKey(kind: .cc,   channel: s.channel, number: s.cc)
            multiMap[key, default: []].append(s.name)
        }

        // Control buttons - add type prefix for clarity
        for b in controlButtons {
            let typePrefix: String
            if b.isFader == true {
                typePrefix = "Fader"
            } else {
                typePrefix = "Button"
            }
            let displayName = b.title.isEmpty ? typePrefix : "\(typePrefix): \(b.title)"
            multiMap[MIDIKey(kind: b.kind, channel: b.channel, number: b.number), default: []].append(displayName)
        }

        // Convert to single string per key, joining multiple owners (deduplicate names)
        // NOTE: Duplicate cues (same name) intentionally share MIDI - don't count as conflict
        var map: [MIDIKey: String] = [:]
        for (key, owners) in multiMap {
            // Deduplicate owner names - this means cues with the same name
            // (duplicates/copies) won't be counted as separate conflicts
            let uniqueOwners = Array(Set(owners)).sorted()

            // Only store if there are 2+ UNIQUE owners (actual conflicts)
            // Single owner or multiple cues with same name = no conflict
            if uniqueOwners.count >= 2 {
                // Format list with separator
                map[key] = uniqueOwners.joined(separator: "|||")
            }
            // Don't store single owners - no conflict to display
        }

        return map
    }

    // Helper function to format conflict owners, excluding a specific name
    private func formatConflictOwners(_ ownersString: String, excluding excludeName: String? = nil) -> String? {
        // Split by our separator
        let owners = ownersString.split(separator: "|||").map(String.init)

        // Filter out excluded name if provided
        let filteredOwners = excludeName != nil ? owners.filter { $0 != excludeName } : owners

        guard !filteredOwners.isEmpty else { return nil }

        if filteredOwners.count == 1 {
            return filteredOwners[0]
        } else if filteredOwners.count == 2 {
            return "\(filteredOwners[0]) and \(filteredOwners[1])"
        } else if filteredOwners.count <= 4 {
            return filteredOwners.dropLast().joined(separator: ", ") + ", and " + filteredOwners.last!
        } else {
            let shown = filteredOwners.prefix(3).joined(separator: ", ")
            return "\(shown), and \(filteredOwners.count - 3) more"
        }
    }

    private func invalidateConflictCache() {
        // FIX: Immediately rebuild cache instead of clearing it
        // Clearing causes "Save & Add Another" to see empty cache and assign CC#0
        cachedConflictLookup = computeConflictLookup()
        cachedUsedCCs = []
        cacheVersion += 1
        debugPrint("🔄 Conflict cache rebuilt immediately with \(cachedConflictLookup.count) entries")
    }

    // FIX #5: Throttled conflict cache update (500ms throttle)
    private func scheduleConflictCacheUpdate() {
        guard !conflictCacheUpdateScheduled else { return }
        conflictCacheUpdateScheduled = true

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms throttle
            cachedConflictLookup = computeConflictLookup()
            conflictCacheUpdateScheduled = false
        }
    }

    private func updateConflictCache() {
        // FIX #5: Use throttled version instead of immediate update
        scheduleConflictCacheUpdate()
    }
    
    /// Returns the owner name for a MIDI key (for auto-assign conflict detection)
    /// This checks ALL owners, not just conflicts (unlike conflictLookup which only stores 2+ owners)
    private func ownerName(for key: MIDIKey) -> String? {
        // Check songs in setlist
        for s in store.activeSongs {
            let songKey = (s.kind == .note)
                ? MIDIKey(kind: .note, channel: s.channel, number: s.note ?? 0)
                : MIDIKey(kind: .cc, channel: s.channel, number: s.cc)
            if songKey == key {
                return s.name
            }
        }

        // Check songs in library (not in setlist)
        for s in songLibrary {
            // Skip if already in setlist (avoid double-counting)
            if store.activeSongs.contains(where: { $0.id == s.id }) { continue }
            let songKey = (s.kind == .note)
                ? MIDIKey(kind: .note, channel: s.channel, number: s.note ?? 0)
                : MIDIKey(kind: .cc, channel: s.channel, number: s.cc)
            if songKey == key {
                return s.name
            }
        }

        // Check control buttons
        for b in controlButtons {
            let buttonKey = MIDIKey(kind: b.kind, channel: b.channel, number: b.number)
            if buttonKey == key {
                let typePrefix = b.isFader == true ? "Fader" : "Button"
                return b.title.isEmpty ? typePrefix : "\(typePrefix): \(b.title)"
            }
        }

        return nil
    }

    // MARK: - Global Channel Management
    private func handleGlobalChannelToggle(wasEnabled: Bool, isEnabled: Bool) {
        guard wasEnabled != isEnabled else { return }

        // Don't backup/restore during project loading
        guard !isLoadingProject else {
            debugPrint("🔄 Skipping global channel toggle handling during project load")
            return
        }

        if isEnabled {
            // Enabling global mode: Save current channels and apply global channel
            debugPrint("🌍 Enabling global MIDI channel mode - saving current channels")

            // Save song channels
            savedSongChannels.removeAll()
            for song in store.activeSongs {
                savedSongChannels[song.id] = song.channel
            }
            for song in songLibrary {
                savedSongChannels[song.id] = song.channel
            }

            // Save control channels
            savedControlChannels.removeAll()
            for button in controlButtons {
                savedControlChannels[button.id] = button.channel
            }

            debugPrint("💾 Saved channels for \(savedSongChannels.count) songs and \(savedControlChannels.count) controls")

            // Apply global channel to all items
            applyGlobalChannel()
        } else {
            // Disabling global mode: Restore original channels
            debugPrint("🌍 Disabling global MIDI channel mode - restoring original channels")

            // Restore song channels
            store.updateActiveSongs { songs in
                for i in 0..<songs.count {
                    if let savedChannel = savedSongChannels[songs[i].id] {
                        songs[i].channel = savedChannel
                    }
                }
            }
            for i in 0..<songLibrary.count {
                if let savedChannel = savedSongChannels[songLibrary[i].id] {
                    songLibrary[i].channel = savedChannel
                }
            }

            // Restore control channels
            for i in 0..<controlButtons.count {
                if let savedChannel = savedControlChannels[controlButtons[i].id] {
                    controlButtons[i].channel = savedChannel
                }
            }

            debugPrint("♻️ Restored channels for \(savedSongChannels.count) songs and \(savedControlChannels.count) controls")

            // Clear the saved channels
            savedSongChannels.removeAll()
            savedControlChannels.removeAll()
        }

        // Invalidate cache and mark as dirty
        invalidateConflictCache()
        markDirty()
    }

    private func applyGlobalChannel() {
        debugPrint("🌍 Applying global channel \(globalChannel) to all items")

        // Apply to songs in setlist
        store.updateActiveSongs { songs in
            for i in 0..<songs.count {
                songs[i].channel = globalChannel
            }
        }

        // Apply to songs in library
        for i in 0..<songLibrary.count {
            songLibrary[i].channel = globalChannel
        }

        // Apply to control buttons
        for i in 0..<controlButtons.count {
            controlButtons[i].channel = globalChannel
        }

        debugPrint("✅ Applied global channel to \(store.activeSongs.count + songLibrary.count) songs and \(controlButtons.count) controls")
    }

    // MARK: - Actions
    private func trigger(_ song: Song) {
        let id = song.id.uuidString

        // Use ConnectionCoordinator to send MIDI through the active connection
        connectionCoordinator.sendMIDI(type: song.kind, channel: song.channel, number: song.kind == .cc ? song.cc : (song.note ?? 60), value: song.kind == .cc ? 127 : song.velocity, label: song.name, buttonID: id)

        // Trigger flash animation on the cue row
        flashingCueID = song.id
        // Clear the flash trigger after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            flashingCueID = nil
        }

        // Update last played cue for play icon indicator
        lastPlayedCueID = song.id

        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func triggerControl(_ b: ControlButton) {
        var value: Int
        var updatedButton = b

        if b.isToggle == true {
            // Toggle behavior: flip state and send appropriate value
            updatedButton.toggleState.toggle()
            value = updatedButton.toggleState ? (b.kind == .cc ? 127 : b.velocity) : 0
        } else {
            // Momentary behavior: send fixed value
            value = b.kind == .cc ? 127 : b.velocity
        }

        // Use global channel if enabled, otherwise use button's channel
        let channelToUse = isGlobalChannel ? globalChannel : b.channel

        // Use ConnectionCoordinator to send MIDI through the active connection
        connectionCoordinator.sendMIDI(type: b.kind, channel: channelToUse, number: b.number, value: value, label: b.title, buttonID: b.id.uuidString)
        
        // Update the button state in the controlButtons array if it's a toggle
        if b.isToggle == true {
            if let index = controlButtons.firstIndex(where: { $0.id == b.id }) {
                controlButtons[index] = updatedButton
            }
        }
        
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func sendFaderMIDI(channel: Int, cc: Int, value: Int, title: String, buttonID: UUID) {
        // Use ConnectionCoordinator to send MIDI through the active connection
        connectionCoordinator.sendMIDI(type: .cc, channel: channel, number: cc, value: value, label: title, buttonID: buttonID.uuidString)
    }

    // MARK: - v1.3 (Cue Bear Next) helpers

    /// First-run checklist: sends a recognisable test message so the user can see it arrive in the DAW.
    private func sendFirstRunTest() {
        let channelToUse = isGlobalChannel ? globalChannel : 1
        connectionCoordinator.sendMIDI(type: .note, channel: channelToUse, number: 60, value: 100,
                                       label: "Cue Bear test", buttonID: "cuebear-first-run-test")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            connectionCoordinator.sendMIDI(type: .note, channel: channelToUse, number: 60, value: 0,
                                           label: "Cue Bear test", buttonID: "cuebear-first-run-test")
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// "Copy extras to other songs": each target song gets its own copies (new IDs).
    private func copyExtras(_ extras: [SongExtra], toSongIDs ids: [UUID]) {
        guard !extras.isEmpty, !ids.isEmpty else { return }
        for id in ids {
            guard var target = store.activeSongs.first(where: { $0.id == id })
                    ?? songLibrary.first(where: { $0.id == id }) else { continue }
            var merged = target.extras ?? []
            for e in extras where !merged.contains(where: { $0.title == e.title && $0.number == e.number }) {
                var copy = e
                copy.id = UUID()
                merged.append(copy)
            }
            target.extras = merged
            saveSong(target)
        }
        saveIfNamed()
    }

    /// Saves straight away when the show already has a name; otherwise just marks it changed
    /// (no name prompt popping up over a sheet).
    private func saveIfNamed() {
        let trimmed = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || isUntitledProject(trimmed) {
            isDirty = true
        } else {
            saveCurrentProject(overwrite: true)
        }
    }

    private func cueGo() {
        guard let s = store.cuedSong else { return }
        trigger(s)
        if let i = store.activeSongs.firstIndex(where: { $0.id == s.id }),
           i + 1 < store.activeSongs.count {
            store.cuedSong = store.activeSongs[i + 1]
        }
        // If on last song, stay on it (don't set to nil)
    }

    private func selectPreviousCued() {
        guard let cued = store.cuedSong,
              let i = store.activeSongs.firstIndex(where: { $0.id == cued.id }),
              i > 0 else { return }
        store.cuedSong = store.activeSongs[i - 1]
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func selectNextCued() {
        if let cued = store.cuedSong, let i = store.activeSongs.firstIndex(where: { $0.id == cued.id }) {
            guard i + 1 < store.activeSongs.count else { return }
            store.cuedSong = store.activeSongs[i + 1]
        } else if !store.activeSongs.isEmpty {
            // If nothing cued yet, select first
            store.cuedSong = store.activeSongs.first
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    // MARK: - Tutorial Resume
    /// Resumes a tutorial that was interrupted by nav pill or cue capsule tutorial
    private func resumeInterruptedTutorial() {
        guard let interrupted = interruptedTutorial else { return }
        interruptedTutorial = nil

        // Small delay to let the capsule tutorial fully dismiss, then use queue system
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            switch interrupted {
            case 1: self.requestTutorial(1)
            case 2: self.requestTutorial(2)
            case 3: self.requestTutorial(21)  // 21 = tutorial 2b
            case 4: self.requestTutorial(22)  // 22 = tutorial 2c
            case 5:
                // Skip if control area already open (user found it themselves)
                if !self.effectivelyCollapsedForOverlay {
                    self.hasSeenTutorial3 = true
                } else {
                    self.requestTutorial(3)
                }
            default: break
            }
        }
    }

    // MARK: - Regular Mode Navigation (for Navigation Capsule)
    private func currentSongIndex() -> Int {
        return max(0, min(lastTriggeredSongIndex, store.activeSongs.count - 1))
    }

    private func triggerNext() {
        guard !store.activeSongs.isEmpty else { return }
        // Prevent going past the last song
        guard lastTriggeredSongIndex < store.activeSongs.count - 1 else { return }
        let nextIndex = lastTriggeredSongIndex + 1
        lastTriggeredSongIndex = nextIndex
        let song = store.activeSongs[nextIndex]
        trigger(song)
    }

    private func triggerPrevious() {
        guard !store.activeSongs.isEmpty else { return }
        // Prevent going before the first song
        guard lastTriggeredSongIndex > 0 else { return }
        let prevIndex = lastTriggeredSongIndex - 1
        lastTriggeredSongIndex = prevIndex
        let song = store.activeSongs[prevIndex]
        trigger(song)
    }

    // MARK: - Bluetooth Pedal Handlers
    // These functions handle pedal input intelligently based on the current mode

    private func handlePedalNext() {
        if store.mode == .cue {
            // In Cue mode: move the chosen cue down the list
            selectNextCued()
        } else {
            // In Regular/Navigator mode: trigger next song
            triggerNext()
        }
    }

    private func handlePedalPrevious() {
        if store.mode == .cue {
            // In Cue mode: move the chosen cue up the list
            selectPreviousCued()
        } else {
            // In Regular/Navigator mode: trigger previous song
            triggerPrevious()
        }
    }

    // MARK: - Library helpers
    private func usedCCNumbers() -> Set<Int> {
        // Always compute fresh to avoid state modification during view updates
        var taken: Set<Int> = [CBTransportCC.play, CBTransportCC.stop, CBTransportCC.prev, CBTransportCC.next]
        taken.formUnion(store.activeSongs.filter{ $0.kind == .cc }.map { $0.cc })
        taken.formUnion(songLibrary.filter{ $0.kind == .cc }.map { $0.cc })
        taken.formUnion(controlButtons.filter{ $0.kind == .cc }.map { $0.number })

        return taken
    }

    private func nextDefaultCueName() -> String {
        let prefix = "Cue "
        var maxN = 0
        // Check all songs in the library (not just active cue list) for unique naming
        for s in songLibrary {
            if s.name.hasPrefix(prefix) {
                let rest = s.name.dropFirst(prefix.count)
                if let n = Int(rest) { maxN = max(maxN, n) }
            }
        }
        return "Cue \(maxN + 1)"
    }

    private func nextDefaultControlName(_ prefix: String) -> String {
        var maxN = 0
        for b in controlButtons {
            if b.title.hasPrefix(prefix + " ") {
                let rest = b.title.dropFirst(prefix.count + 1)
                if let n = Int(rest) { maxN = max(maxN, n) }
            }
        }
        return "\(prefix) \(maxN + 1)"
    }

    private func cueNameExists(_ name: String, excluding id: UUID? = nil) -> Bool {
        songLibrary.contains { $0.id != id && $0.name.lowercased() == name.lowercased() }
    }

    private func uniqueCueName(baseName: String, excluding id: UUID? = nil) -> String {
        let names = Set(songLibrary.filter { $0.id != id }.map { $0.name.lowercased() })
        if !names.contains(baseName.lowercased()) { return baseName }
        var n = 2
        while names.contains("\(baseName) (\(n))".lowercased()) { n += 1 }
        return "\(baseName) (\(n))"
    }

    /// Handles saving a cue with duplicate name check. Shows alert if name exists, otherwise saves directly.
    private func saveCueWithDuplicateCheck(_ song: Song, andAddAnother: Bool, dismissSheet: @escaping () -> Void) {
        // Skip duplicate check for aliased (duplicated) cues — duplicate names are their purpose
        if song.aliasedCueID != nil {
            saveSong(song)
            dismissSheet()
            return
        }

        // If editing an existing cue whose name is unchanged, skip the check entirely.
        // Check both library and setlist since a cue might be in the setlist but not the library.
        let existingCue = songLibrary.first(where: { $0.id == song.id })
                       ?? store.activeSongs.first(where: { $0.id == song.id })
        if let existingCue, existingCue.name.lowercased() == song.name.lowercased() {
            saveSong(song)
            dismissSheet()
            return
        }

        // For existing cues being renamed, exclude their own ID from the check.
        // Also check setlist in case a cue exists there but not yet in the library.
        let isKnownCue = songLibrary.contains(where: { $0.id == song.id })
                      || store.activeSongs.contains(where: { $0.id == song.id })
        let excludeID: UUID? = isKnownCue ? song.id : nil

        if cueNameExists(song.name, excluding: excludeID) {
            pendingDuplicateCue = song
            pendingDuplicateCueAddAnother = andAddAnother
            duplicateCueName = song.name
            duplicateCueSuggestedName = uniqueCueName(baseName: song.name, excluding: excludeID)
            // Dismiss the edit sheet first, then show the alert — prevents alert appearing behind the open sheet
            dismissSheet()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                showDuplicateCueNameAlert = true
            }
        } else {
            saveSong(song)
            dismissSheet()
        }
    }

    private func sortedLibrary() -> [Song] {
        switch sortMode {
        case .nameAZ:
            return songLibrary.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameZA:
            return songLibrary.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .newest:
            return songLibrary.sorted { (libAddedAt[$0.id] ?? .distantPast) > (libAddedAt[$1.id] ?? .distantPast) }
        case .oldest:
            return songLibrary.sorted { (libAddedAt[$0.id] ?? .distantPast) < (libAddedAt[$1.id] ?? .distantPast) }
        }
    }

    private func libraryDecorated() -> [CBLibraryRow] {
        let setIDs = Set(store.activeSongs.map { $0.id })
        return sortedLibrary().map { s in
            CBLibraryRow(id: s.id, song: s, isInSetlist: setIDs.contains(s.id), isSelected: libSelected.contains(s.id))
        }
    }

    private func filteredLibraryRows() -> [CBLibraryRow] {
        let rows = libraryDecorated()
        // FIX #9: Use debounced query and localizedCaseInsensitiveContains for better performance
        let q = libraryQueryDebounced.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return rows }
        return rows.filter { row in
            row.song.name.localizedCaseInsensitiveContains(q) ||
            (row.song.subtitle ?? "").localizedCaseInsensitiveContains(q)
        }
    }

    private func filteredSetlistSongs() -> [Song] {
        let songs = store.activeSongs
        let q = setlistQueryDebounced.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return songs }
        return songs.filter { song in
            song.name.localizedCaseInsensitiveContains(q) ||
            (song.subtitle ?? "").localizedCaseInsensitiveContains(q)
        }
    }

    private func toggleLibSelection(_ id: UUID) {
        let songName = songLibrary.first(where: { $0.id == id })?.name ?? "Unknown"
        let wasSelected = libSelected.contains(id)
        debugPrint("🔵 toggleLibSelection called for: \(songName) (ID: \(id)), wasSelected: \(wasSelected)")
        if libSelected.contains(id) { libSelected.remove(id) } else { libSelected.insert(id) }
        let nowSelected = libSelected.contains(id)
        debugPrint("🔵 toggleLibSelection completed for: \(songName), nowSelected: \(nowSelected)")
    }

    private func selectAllLibrary() {
        // Select ALL items in the library, including those already in the cue list
        let candidates = filteredLibraryRows()
        libSelected = Set(candidates.map { $0.id })
    }

    private func addSelectedToSetlist() {
        guard !libSelected.isEmpty else { return }
        let toAdd = songLibrary.filter { libSelected.contains($0.id) }
        toAdd.forEach(addToSetlist(_:))
        libSelected.removeAll()
        UIImpactFeedbackGenerator().impactOccurred(intensity: 0.7)
    }

    private func deleteSelectedFromLibrary() {
        guard !libSelected.isEmpty else { return }
        pushSetlistUndo()
        pushLibraryUndo()

        // Remove from both library and cue list
        songLibrary.removeAll { libSelected.contains($0.id) }
        store.updateActiveSongs { $0.removeAll { libSelected.contains($0.id) } }

        // Clean up metadata for deleted songs
        libSelected.forEach { libAddedAt[$0] = nil }
        invalidateConflictCache()
        isDirty = true

        libSelected.removeAll()
        UIImpactFeedbackGenerator().impactOccurred(intensity: 0.7)
    }

    // MARK: - Setlist Batch Operations

    private func toggleSetlistSelection(_ id: UUID) {
        let songName = store.activeSongs.first(where: { $0.id == id })?.name ?? "Unknown"
        let wasSelected = setlistSelected.contains(id)
        debugPrint("🔵 toggleSetlistSelection called for: \(songName) (ID: \(id)), wasSelected: \(wasSelected)")
        if setlistSelected.contains(id) { setlistSelected.remove(id) } else { setlistSelected.insert(id) }
        let nowSelected = setlistSelected.contains(id)
        debugPrint("🔵 toggleSetlistSelection completed for: \(songName), nowSelected: \(nowSelected)")
    }

    private func selectAllSetlist() {
        let candidates = filteredSetlistSongs()
        setlistSelected = Set(candidates.map { $0.id })
    }

    private func removeSelectedFromSetlist() {
        guard !setlistSelected.isEmpty else { return }
        pushSetlistUndo()

        // Remove from cue list only
        store.updateActiveSongs { $0.removeAll { setlistSelected.contains($0.id) } }

        invalidateConflictCache()
        isDirty = true

        setlistSelected.removeAll()
        UIImpactFeedbackGenerator().impactOccurred(intensity: 0.7)
    }

    private func addToSetlist(_ s: Song) {
        debugPrint("➕ addToSetlist called for: \(s.name) (ID: \(s.id))")
        pushSetlistUndo()
        let alreadyInSetlist = store.activeSongs.contains(where: { $0.id == s.id })
        debugPrint("➕ Already in setlist: \(alreadyInSetlist)")
        guard !alreadyInSetlist else {
            debugPrint("➕ Skipping add - song already in setlist")
            return
        }

        // Auto-assign MIDI message if not already assigned
        var songToAdd = s
        if songToAdd.channel == 0 || songToAdd.cc == 0 {
            // Find first available CC message
            let freeCC = firstFreeCC()
            if freeCC >= 0 {
                songToAdd.kind = .cc
                songToAdd.channel = 1
                songToAdd.cc = freeCC
                songToAdd.velocity = 127
            }
        }

        debugPrint("➕ Appending \(s.name) to setlist")
        store.updateActiveSongs { $0.append(songToAdd) }
        invalidateConflictCache()
        isDirty = true
        debugPrint("➕ addToSetlist completed for: \(s.name), setlist now has \(store.activeSongs.count) songs")
    }

    private func firstFreeCC() -> Int {
        for cc in 0...127 {
            let key = MIDIKey(kind: .cc, channel: 1, number: cc)
            if conflictLookup()[key] == nil {
                return cc
            }
        }
        return -1 // No free CC found
    }

    private func removeFromSetlist(_ s: Song) {
        debugPrint("🔴 removeFromSetlist called for: \(s.name) (ID: \(s.id))")
        let countBefore = store.activeSongs.count
        debugPrint("🔴 Setlist size before removal: \(countBefore)")
        pushSetlistUndo()
        store.updateActiveSongs { $0.removeAll { $0.id == s.id } }
        let countAfter = store.activeSongs.count
        debugPrint("🔴 Setlist size after removal: \(countAfter)")
        isDirty = true
        debugPrint("🔴 removeFromSetlist completed for: \(s.name), removed: \(countBefore - countAfter) song(s)")
    }

    private func deleteFromLibrary(_ s: Song) {
        // Dismiss library popover so it doesn't cover the confirmation dialog
        showLibraryPopover = false

        // Check if song is in ANY cue list
        let isInAnyCueList = store.cueLists.contains { cueList in
            cueList.songs.contains(where: { $0.id == s.id })
        }

        if isInAnyCueList {
            // Show confirmation popup
            songToDelete = s
            showDeleteConfirmation = true
        } else {
            // Safe to delete from library only
            performDeleteFromLibrary(s)
        }
    }
    
    private func performDeleteFromLibrary(_ s: Song) {
        pushSetlistUndo()
        pushLibraryUndo()

        // Convert any alias cues pointing to this song into regular cues AND remove song from ALL cue lists
        for i in 0..<store.cueLists.count {
            var updated = false
            for j in 0..<store.cueLists[i].songs.count {
                // Convert aliases to regular cues
                if store.cueLists[i].songs[j].aliasedCueID == s.id {
                    store.cueLists[i].songs[j].aliasedCueID = nil
                    debugPrint("🔄 Converted alias cue '\(store.cueLists[i].songs[j].name)' to regular cue (original deleted)")
                    updated = true
                }
            }
            // Remove the song from this cue list
            let beforeCount = store.cueLists[i].songs.count
            store.cueLists[i].songs.removeAll { $0.id == s.id }
            let afterCount = store.cueLists[i].songs.count
            if beforeCount != afterCount {
                updated = true
                debugPrint("🗑️ Removed song '\(s.name)' from cue list '\(store.cueLists[i].name)'")
            }
            // Update timestamp if modified
            if updated {
                store.cueLists[i].touch()
            }
        }

        // Remove from library
        songLibrary.removeAll { $0.id == s.id }
        libAddedAt[s.id] = nil
        invalidateConflictCache()
        isDirty = true

        UIImpactFeedbackGenerator().impactOccurred(intensity: 0.7)
    }

    private func duplicateSong(_ s: Song) {
        pushSetlistUndo()
        pushLibraryUndo()

        // If this is an alias cue, duplicate the original cue instead
        let sourceSong: Song
        if let aliasedID = s.aliasedCueID,
           let originalCue = songLibrary.first(where: { $0.id == aliasedID }) {
            sourceSong = originalCue
        } else {
            sourceSong = s
        }

        // Create copy with same name but "copy of [name]" as subtitle
        var copy = Song(name: sourceSong.name, subtitle: "copy of \(sourceSong.name)", cc: sourceSong.cc, channel: sourceSong.channel)
        copy.kind = sourceSong.kind
        copy.note = sourceSong.note
        copy.velocity = sourceSong.velocity
        copy.colorHex = sourceSong.colorHex
        copy.midiEnabled = sourceSong.midiEnabled
        // Don't copy aliasedCueID - this is a real duplicate, not an alias
        songLibrary.append(copy)
        libAddedAt[copy.id] = Date()

        // Add the copy to the cue list right after the original song
        store.updateActiveSongs { songs in
            if let index = songs.firstIndex(where: { $0.id == s.id }) {
                songs.insert(copy, at: index + 1)
            }
        }

        UIImpactFeedbackGenerator().impactOccurred(intensity: 0.5)
        isDirty = true
        saveCurrentProject(overwrite: true)
    }

    private func saveSong(_ song: Song) {
        pushSetlistUndo()
        pushLibraryUndo()

        var song = song

        let isNewSong = !songLibrary.contains(where: { $0.id == song.id })

        // Auto-assign random color for new cues if enabled and no color set
        if isNewSong && autoAssignCueColors && song.colorHex == nil {
            let usedColors = Set(songLibrary.compactMap { $0.colorHex })
            let available = curatedColorPalette.filter { !usedColors.contains($0) }
            if let random = available.randomElement() {
                song.colorHex = random
            } else {
                song.colorHex = curatedColorPalette.randomElement()
            }
        }

        // Update existing song in setlist if it's there
        store.updateActiveSongs { songs in
            if let i = songs.firstIndex(where: { $0.id == song.id }) {
                songs[i] = song
            }
        }

        // Add or update in library
        if let j = songLibrary.firstIndex(where: { $0.id == song.id }) {
            songLibrary[j] = song
        } else {
            songLibrary.append(song)
            libAddedAt[song.id] = Date()

            // For new songs, also add directly to cue list for better UX
            if isNewSong && !store.activeSongs.contains(where: { $0.id == song.id }) {
                store.updateActiveSongs { $0.append(song) }
        }
        }

        // Invalidate conflict cache since MIDI assignments may have changed
        invalidateConflictCache()
        isDirty = true
    }

    private func markDirty() {
        isDirty = true
    }

    private func loadMidiFiltersFromUserDefaults() {
        if let saved = UserDefaults.standard.array(forKey: "midiFilterCCs") as? [Int] {
            midiFilter = Set(saved)
        }
        let ccs = UserDefaults.standard.array(forKey: "midiCustomFilterCCs") as? [Int] ?? []
        let names = UserDefaults.standard.array(forKey: "midiCustomFilterNames") as? [String] ?? []
        if ccs.count == names.count && !ccs.isEmpty {
            customMidiFilters = zip(ccs, names).map { ($0, $1) }
        }
    }

    private func saveMidiCustomFiltersToUserDefaults() {
        UserDefaults.standard.set(customMidiFilters.map { $0.0 }, forKey: "midiCustomFilterCCs")
        UserDefaults.standard.set(customMidiFilters.map { $0.1 }, forKey: "midiCustomFilterNames")
    }

    private func snapshotAndSave(as name: String, overwrite: Bool) {
        let cueLists = store.cueLists
        let activeCueListID = store.activeCueListID
        let library = songLibrary
        let controls = controlButtons
        let isGlobalCh = isGlobalChannel
        let globalCh = globalChannel
        let theme = selectedThemeID
        let appMode = store.mode
        let filtersEnabled = midiFiltersEnabled
        let filter = midiFilter
        let customFilters = customMidiFilters
        DispatchQueue.global(qos: .utility).async {
            do {
                try ProjectIO.save(name: name, cueLists: cueLists, activeCueListID: activeCueListID, library: library, controls: controls, isGlobalChannel: isGlobalCh, globalChannel: globalCh, theme: theme, appMode: appMode, midiFiltersEnabled: filtersEnabled, midiFilter: filter, customMidiFilters: customFilters)
                let projects = ProjectIO.list()
                DispatchQueue.main.async {
                    projectName = name
                    isDirty = false
                    projectsList = projects
                }
            } catch { debugPrint("Save failed: \(error)") }
        }
    }

    /// Generate a unique project name by appending (1), (2), etc. if name already exists
    private func uniqueProjectName(baseName: String) -> String {
        let existingProjects = projectsList

        // If name doesn't exist, return as-is
        if !existingProjects.contains(baseName) {
            return baseName
        }

        // Find the next available number
        var counter = 1
        while existingProjects.contains("\(baseName) (\(counter))") {
            counter += 1
        }

        return "\(baseName) (\(counter))"
    }

    // MARK: - Undo/Redo helpers
    private func pushSetlistUndo() {
        setlistUndoStack.append(store.activeSongs)
        if setlistUndoStack.count > 30 { setlistUndoStack.removeFirst() }
        setlistRedoStack.removeAll()
    }
    private func undoSetlist() {
        guard let last = setlistUndoStack.popLast() else { return }
        setlistRedoStack.append(store.activeSongs)
        store.updateActiveSongs { $0 = last }
        isDirty = true
    }
    private func redoSetlist() {
        guard let next = setlistRedoStack.popLast() else { return }
        setlistUndoStack.append(store.activeSongs)
        store.updateActiveSongs { $0 = next }
        isDirty = true
    }
    
    private func pushLibraryUndo() {
        libraryUndoStack.append(songLibrary)
        if libraryUndoStack.count > 30 { libraryUndoStack.removeFirst() }
        libraryRedoStack.removeAll()
    }
    private func undoLibrary() {
        guard let last = libraryUndoStack.popLast() else { return }
        libraryRedoStack.append(songLibrary)
        songLibrary = last
        isDirty = true
    }
    private func redoLibrary() {
        guard let next = libraryRedoStack.popLast() else { return }
        libraryUndoStack.append(songLibrary)
        songLibrary = next
        isDirty = true
    }
    
    // Combined undo/redo that handles both setlist and library
    private func performUndo() {
        // Prioritize setlist undo if available, otherwise library undo
        if !setlistUndoStack.isEmpty {
            undoSetlist()
        } else if !libraryUndoStack.isEmpty {
            undoLibrary()
        }
    }
    
    private func performRedo() {
        // Prioritize setlist redo if available, otherwise library redo
        if !setlistRedoStack.isEmpty {
            redoSetlist()
        } else if !libraryRedoStack.isEmpty {
            redoLibrary()
        }
    }

    private func pushControlUndo() {
        controlUndoStack.append(controlButtons)
        controlRedoStack.removeAll()
    }
    private func undoControls() {
        guard let last = controlUndoStack.popLast() else { return }
        controlRedoStack.append(controlButtons)
        controlButtons = last
        invalidateConflictCache()
        markDirty()
    }
    private func redoControls() {
        guard let next = controlRedoStack.popLast() else { return }
        controlUndoStack.append(controlButtons)
        controlButtons = next
        invalidateConflictCache()
        markDirty()
    }

    // Control edit mode auto-exit timer
    private func startControlEditModeTimer() {
        // Cancel existing timer
        controlEditModeTimer?.invalidate()

        // Start new 5-second timer
        controlEditModeTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            withAnimation(.easeInOut) {
                controlEditMode = false
            }
        }
    }

    private func cancelControlEditModeTimer() {
        controlEditModeTimer?.invalidate()
        controlEditModeTimer = nil
    }

    private func resetControlEditModeTimer() {
        if controlEditMode {
            startControlEditModeTimer()
        }
    }

    private func saveCurrentProject(overwrite: Bool) {
        let trimmed = projectName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Show name prompt for "Save As" OR when saving an untitled project for the first time
        if !overwrite || trimmed.isEmpty || isUntitledProject(trimmed) {
            // Pre-fill with current name for "Save As", or suggest active cue list name for new projects
            tempName = trimmed.isEmpty || isUntitledProject(trimmed) ? (store.activeCueList?.name ?? "My Show") : trimmed
            shouldSaveAfterNaming = true  // Mark that we should save after user enters name
            showNamePrompt = true
            return
        }

        // For projects with a name, save directly
        snapshotAndSave(as: trimmed, overwrite: overwrite)
    }

    private func loadProject(named: String) {
        do {
            debugPrint("🔄 Loading project: \(named)")
            let payload = try ProjectIO.load(name: named)
            debugPrint("📦 Project payload loaded - cueLists: \(payload.cueLists?.count ?? 0), library: \(payload.library.count) songs, controls: \(payload.controls.count) buttons")

            // Set loading flag to prevent global channel toggle from triggering backup/restore
            isLoadingProject = true

            projectName = payload.name

            // Migrate legacy format: convert setlist to "Main" cue list
            if payload.isLegacyFormat, let legacySetlist = payload.setlist {
                debugPrint("🔄 Migrating legacy project format to v1.2.0")
                let mainList = CueList(name: "Main", songs: legacySetlist)
                store.cueLists = [mainList]
                store.activeCueListID = mainList.id
                debugPrint("✅ Migrated \(legacySetlist.count) songs to 'Main' cue list")
            } else {
                // Modern format or empty legacy
                store.cueLists = payload.cueLists ?? [CueList.defaultMain]
                store.activeCueListID = payload.activeCueListID ?? store.cueLists.first?.id
            }
            songLibrary = payload.library
            controlButtons = payload.controls
            isGlobalChannel = payload.isGlobalChannel ?? false
            globalChannel = payload.globalChannel ?? 1

            // Restore app mode preference if saved
            if let savedMode = payload.appMode {
                store.mode = savedMode
                debugPrint("✅ Restored app mode: \(savedMode)")
            }

            // MIDI filter settings are global preferences (UserDefaults), not per-project.
            // Do not restore from project file — loadMidiFiltersFromUserDefaults() on onAppear handles this.

            // Reset loading flag after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isLoadingProject = false
            }

            // Migrate controls that are beyond the 4-row limit (rows 0-3)
            migrateOutOfBoundsControls()

            debugPrint("✅ Project data assigned - cueLists: \(store.cueLists.count), activeSongs: \(store.activeSongs.count) songs, library: \(songLibrary.count) songs, controls: \(controlButtons.count) buttons")
            
            let now = Date()
            for s in songLibrary where libAddedAt[s.id] == nil { libAddedAt[s.id] = now }
            isDirty = false

            // Clear autosave when loading a named project
            ProjectIO.clearLibraryAutosave()

            debugPrint("✅ Project loaded successfully: \(named)")

            // v1.0.8: Auto-recover empty library from setlist
            recoverEmptyLibrary()
        } catch {
            debugPrint("❌ Load failed for project \(named): \(error)")
        }
    }

    /// v1.0.8: Auto-recovery for corrupted projects where library is empty but setlist has songs
    /// This copies all songs from setlist to library and marks project as dirty for save
    private func recoverEmptyLibrary() {
        // Only recover if library is empty AND setlist has songs
        guard songLibrary.isEmpty && !store.activeSongs.isEmpty else {
            return
        }

        debugPrint("🔧 RECOVERY: Detected empty library with \(store.activeSongs.count) songs in setlist")
        debugPrint("🔧 RECOVERY: Auto-populating library from setlist...")

        // Copy all songs from setlist to library
        songLibrary = store.activeSongs

        // Set timestamps for all recovered songs
        let now = Date()
        for song in songLibrary {
            libAddedAt[song.id] = now
        }

        // Mark project as dirty so it gets saved
        isDirty = true

        debugPrint("✅ RECOVERY: Added \(songLibrary.count) songs to library")
        debugPrint("✅ RECOVERY: Project marked as dirty - save to keep changes")
    }

    /// Migrates controls that are positioned beyond the 4-row limit (rows 0-3) or 8-column limit (cols 0-7)
    /// This fixes projects created when the row limit was higher or controls positioned incorrectly
    private func migrateOutOfBoundsControls() {
        // FIX #10: Early exit check using .contains for performance
        let hasOutOfBounds = controlButtons.contains { button in
            let width = button.gridWidth
            let height = button.gridHeight

            if let row = button.gridRow, row >= 4 { return true }
            if let col = button.gridCol, col >= 8 { return true }
            if let col = button.gridCol, col + width > 8 { return true }
            if let row = button.gridRow, row + height > 4 { return true }
            return false
        }

        guard hasOutOfBounds else {
            debugPrint("✅ No out-of-bounds controls found")
            return
        }

        var migratedCount = 0

        debugPrint("⚠️ Found controls out of bounds (beyond row 3 or col 7), starting migration...")

        // Second pass: reposition out-of-bounds controls
        for i in 0..<controlButtons.count {
            let button = controlButtons[i]
            let width = button.gridWidth
            let height = button.gridHeight
            var needsRepositioning = false

            // Check all out-of-bounds conditions
            if let row = button.gridRow, row >= 4 {
                needsRepositioning = true
            }
            if let col = button.gridCol, col >= 8 {
                needsRepositioning = true
            }
            if let col = button.gridCol, col + width > 8 {
                needsRepositioning = true
            }
            if let row = button.gridRow, row + height > 4 {
                needsRepositioning = true
            }

            if needsRepositioning {
                let currentCol = button.gridCol ?? -1
                let currentRow = button.gridRow ?? -1
                debugPrint("🔧 Control '\(button.title)' at (\(currentCol), \(currentRow)) size \(width)×\(height) needs repositioning")

                // Try to find an available position within the 4-row, 8-column limit

                var foundPosition = false
                for newRow in 0..<4 {
                    for newCol in 0..<(8 - width + 1) {
                        var canPlace = true

                        // Check if this position is free
                        for j in 0..<controlButtons.count where i != j {
                            if let existingCol = controlButtons[j].gridCol,
                               let existingRow = controlButtons[j].gridRow {
                                let existingWidth = controlButtons[j].gridWidth
                                let existingHeight = controlButtons[j].gridHeight

                                // Check for overlap
                                if !(newCol + width <= existingCol ||
                                    existingCol + existingWidth <= newCol ||
                                    newRow + height <= existingRow ||
                                    existingRow + existingHeight <= newRow) {
                                    canPlace = false
                                    break
                                }
                            }
                        }

                        if canPlace {
                            controlButtons[i].gridCol = newCol
                            controlButtons[i].gridRow = newRow
                            foundPosition = true
                            migratedCount += 1
                            debugPrint("✅ Repositioned '\(button.title)' to (\(newCol), \(newRow))")
                            break
                        }
                    }
                    if foundPosition { break }
                }

                if !foundPosition {
                    // No space found - clear position to let auto-assign handle it
                    controlButtons[i].gridCol = nil
                    controlButtons[i].gridRow = nil
                    debugPrint("⚠️ No space found for '\(button.title)', cleared position for auto-assign")
                }
            }
        }

        if migratedCount > 0 {
            debugPrint("✅ Migration complete: repositioned \(migratedCount) control(s)")
            // Mark as dirty so the migration is saved
            markDirty()
        }
    }

    // MARK: - Automatic Save/Open Functions
    
    /// Start automatic saving with debouncing
    private func startAutosave() {
        // Cancel existing autosave task
        autosaveTask?.cancel()

        // Only autosave if project has a name (not "Untitled Project")
        guard !isUntitledProject(projectName) && !projectName.isEmpty else { return }

        autosaveTask = Task {
            // Wait 2 seconds before saving to debounce rapid changes
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            // Check if task was cancelled
            guard !Task.isCancelled else { return }

            await MainActor.run {
                if isDirty && !isUntitledProject(projectName) {
                    debugPrint("💾 Auto-saving project: \(projectName)")
                    do {
                        try ProjectIO.save(name: projectName, cueLists: store.cueLists, activeCueListID: store.activeCueListID, library: songLibrary, controls: controlButtons, isGlobalChannel: isGlobalChannel, globalChannel: globalChannel, theme: selectedThemeID, appMode: store.mode, midiFiltersEnabled: midiFiltersEnabled, midiFilter: midiFilter, customMidiFilters: customMidiFilters)
                        isDirty = false
                        debugPrint("✅ Auto-save completed: \(projectName)")
                    } catch {
                        debugPrint("❌ Auto-save failed: \(error)")
                    }
                }
            }
        }
    }
    
    /// Automatically open the last project on app launch
    @MainActor private func autoOpenLastProject() async {
        debugPrint("🔍 Auto-open check - projectName: '\(projectName)'")
        debugPrint("🔍 UserDefaults lastProjectName: '\(UserDefaults.standard.string(forKey: "lastProjectName") ?? "nil")'")
        debugPrint("🔍 hasCompletedInitialLaunch: \(hasCompletedInitialLaunch)")

        // First launch - new users start with an empty project
        if !hasCompletedInitialLaunch {
            debugPrint("🎵 First launch detected - starting with empty project")
            hasCompletedInitialLaunch = true
            return
        }

        // For subsequent launches, load the last opened project
        guard !isUntitledProject(projectName) && !projectName.isEmpty else {
            debugPrint("⏭️ Skipping auto-open - projectName is 'Untitled Project' or empty")
            // For "Untitled Project" projects, try to restore library from autosave
            if let saved = await Task.detached(priority: .userInitiated, operation: { ProjectIO.loadLibraryAutosave() }).value {
                songLibrary = saved
                debugPrint("📂 Restored library from autosave for Untitled project (\(saved.count) songs)")
            }
            return
        }

        // Check if the project file exists
        do {
            let name = projectName
            let payload = try await Task.detached(priority: .userInitiated) { try ProjectIO.load(name: name) }.value
            debugPrint("🔄 Auto-opening last project: \(projectName)")
            debugPrint("📦 Auto-open payload - cueLists: \(payload.cueLists?.count ?? 0), library: \(payload.library.count) songs, controls: \(payload.controls.count) buttons")

            // Set loading flag to prevent global channel toggle from triggering backup/restore
            isLoadingProject = true

            // Load the project data - migrate legacy format if needed
            if payload.isLegacyFormat, let legacySetlist = payload.setlist {
                debugPrint("🔄 Migrating legacy auto-open project to v1.2.0")
                let mainList = CueList(name: "Main", songs: legacySetlist)
                store.cueLists = [mainList]
                store.activeCueListID = mainList.id
                debugPrint("✅ Migrated \(legacySetlist.count) songs to 'Main' cue list")
            } else {
                store.cueLists = payload.cueLists ?? [CueList.defaultMain]
                store.activeCueListID = payload.activeCueListID ?? store.cueLists.first?.id
            }
            songLibrary = payload.library
            controlButtons = payload.controls
            isGlobalChannel = payload.isGlobalChannel ?? false
            globalChannel = payload.globalChannel ?? 1

            // Restore MIDI filter settings if saved
            // MIDI filter settings are global preferences (UserDefaults), not per-project.
            // Do not restore from project file — loadMidiFiltersFromUserDefaults() on onAppear handles this.

            // Reset loading flag after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isLoadingProject = false
            }
            let now = Date()
            for s in songLibrary where libAddedAt[s.id] == nil {
                libAddedAt[s.id] = now
            }
            isDirty = false

            // Clear autosave when loading a named project
            ProjectIO.clearLibraryAutosave()

            debugPrint("✅ Successfully auto-opened: \(projectName)")
        } catch {
            debugPrint("❌ Failed to auto-open '\(projectName)': \(error)")
            debugPrint("💡 Project may have been deleted or corrupted")
            // Reset to untitled if project doesn't exist
            projectName = "Untitled"
        }
    }
    
    // MARK: - Document-Based Project Functions
    
    /// Open document picker to load projects from Files/iCloud Drive
    private func openDocumentPicker() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            debugPrint("❌ Could not find root view controller for document picker")
            return
        }
        
        debugPrint("📁 ContentView: Presenting document picker from root view controller")

        DocumentProjectIO.presentDocumentPicker(from: rootViewController) { url in
            debugPrint("📁 ContentView: Document picker completion called with URL: \(url?.absoluteString ?? "nil")")

            guard let url = url else {
                debugPrint("📁 ContentView: No URL received (user cancelled)")
                return
            }

            debugPrint("📁 ContentView: Calling openProject with URL: \(url.path)")

            DocumentProjectIO.openProject(from: url) { payload in
                DispatchQueue.main.async {
                    if let payload = payload {
                        debugPrint("✅ ContentView: Project payload received: \(payload.name)")

                        // Generate unique name if project with same name already exists
                        let uniqueName = self.uniqueProjectName(baseName: payload.name)
                        if uniqueName != payload.name {
                            debugPrint("📝 ContentView: Project renamed from '\(payload.name)' to '\(uniqueName)' to avoid overwrite")
                        }

                        // Set loading flag to prevent global channel toggle from triggering backup/restore
                        self.isLoadingProject = true

                        self.projectName = uniqueName

                        // Migrate legacy format if needed
                        if payload.isLegacyFormat, let legacySetlist = payload.setlist {
                            debugPrint("🔄 Migrating imported legacy project to v1.2.0")
                            let mainList = CueList(name: "Main", songs: legacySetlist)
                            self.store.cueLists = [mainList]
                            self.store.activeCueListID = mainList.id
                            debugPrint("✅ Migrated \(legacySetlist.count) songs to 'Main' cue list")
                        } else {
                            self.store.cueLists = payload.cueLists ?? [CueList.defaultMain]
                            self.store.activeCueListID = payload.activeCueListID ?? self.store.cueLists.first?.id
                        }
                        self.songLibrary = payload.library
                        self.controlButtons = payload.controls
                        self.isGlobalChannel = payload.isGlobalChannel ?? false
                        self.globalChannel = payload.globalChannel ?? 1

                        // Reset loading flag after a brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.isLoadingProject = false
                        }
                        let now = Date()
                        for s in self.songLibrary where self.libAddedAt[s.id] == nil {
                            self.libAddedAt[s.id] = now
                        }
                        self.isDirty = true  // Mark as dirty so user needs to save the imported project
                        debugPrint("✅ ContentView: Project loaded successfully as: \(uniqueName)")
                    } else {
                        debugPrint("❌ ContentView: Failed to load project - showing error alert")
                        self.documentLoadErrorMessage = "Could not open the selected project file. The file may be corrupted or in an unsupported format."
                        self.showDocumentLoadError = true
                    }
                }
            }
        }
    }

    /// Export current project to share sheet (save to Files, AirDrop, etc.)
    private func exportCurrentProject() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            debugPrint("❌ Could not find root view controller for export")
            return
        }

        debugPrint("📤 ContentView: Exporting project: \(projectName)")

        // Create payload from current state
        let payload = ProjectPayload(
            name: projectName,
            cueLists: store.cueLists,
            activeCueListID: store.activeCueListID,
            library: songLibrary,
            controls: controlButtons,
            isGlobalChannel: isGlobalChannel,
            globalChannel: globalChannel,
            theme: selectedThemeID,
            appMode: store.mode
        )

        // Present share sheet
        DocumentProjectIO.exportProject(
            name: projectName,
            data: payload,
            from: rootViewController
        )
    }

    private func newProjectFlow() {
        if isDirty {
            showSaveChangesAlert = true
            pendingAction = { [self] in
                createNewProject()
            }
        } else {
            createNewProject()
        }
    }

    private func openProjectFlow() {
        if isDirty {
            showSaveChangesAlert = true
            pendingAction = { [self] in
                projectsList = ProjectIO.list()
                showProjects = true
            }
        } else {
            projectsList = ProjectIO.list()
            showProjects = true
        }
    }

    private func createNewProject() {
        projectName = "Untitled Project"
        store.reset()  // Reset to single "Untitled Cue List"
        songLibrary.removeAll()
        controlButtons.removeAll()
        libAddedAt.removeAll()
        isDirty = false
        // No seeding for shipping - start blank

        // v1.0.8: Dismiss project sheet after creating new project
        showProjects = false
    }
    
    private func checkUnsavedChangesBeforeAction(_ action: @escaping () -> Void) {
        // v1.0.8: Only show save prompt for projects that have been saved before (not "Untitled Project")
        // Matches autosave behavior pattern used throughout the app
        if isDirty && !isUntitledProject(projectName) {
            showSaveChangesAlert = true
            pendingAction = action
        } else {
            action()
        }
    }

    // Helper function to check if project name is untitled
    private func isUntitledProject(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "Untitled" || trimmed == "Untitled Project"
    }

    // MARK: - Ready for Shipping
    // App starts with completely blank data - no placeholder content
}

// MARK: - Conditional Drawing Group
// Applies drawingGroup only when enabled (skip on iPhone to avoid rendering issues)
private struct ConditionalDrawingGroup: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.drawingGroup(opaque: false, colorMode: .nonLinear)
        } else {
            content
        }
    }
}

// MARK: - Press Gesture Modifier
// Applies press feedback gesture for visual touch feedback on both iPhone and iPad
// (Previously disabled on iPhone to allow ScrollView scrolling, but ScrollView was removed)
private struct PressGestureModifier: ViewModifier {
    let isPhone: Bool
    @Binding var isTouching: Bool
    @Binding var isPressed: Bool
    var onTouchDown: (() -> Void)? = nil

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isTouching {
                                isTouching = true
                                isPressed = true
                                onTouchDown?()
                            }
                        }
                        .onEnded { _ in
                            isTouching = false
                            withAnimation(.easeInOut(duration: 0.08)) {
                                isPressed = false
                            }
                        }
                )
    }
}

// MARK: - Splash Screen
private struct SplashScreen: View {
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.15),
                    Color(red: 0.05, green: 0.05, blue: 0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Bear paw icon
                Image("BearPawIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .scaleEffect(1.2)
                
                // App name
                Text("Cue Bear")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Subtle loading indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                    .padding(.top, 20)
            }
        }
    }
}

// MARK: - Shipping Ready
// All placeholder data removed - app starts completely blank


// MARK: - Top Bar (v1.1.0 Extreme Simplification)
private struct CBTopBar: View {
    @Binding var mode: AppMode
    @Binding var showSideMenu: Bool
    @Binding var isEditing: Bool
    @Binding var isGlobalChannel: Bool
    @Binding var globalChannel: Int
    @Binding var showLibraryPopover: Bool  // Control library popover visibility
    @Binding var songLibrary: [Song]  // Song library for popover
    @Binding var activeCueListSongs: [Song]  // Active cue list songs
    @Binding var editingSong: Song?  // Currently editing song
    @Binding var showAddEdit: Bool  // Show add/edit sheet
    @Binding var cueLists: [CueList]  // All cue lists
    @Binding var activeCueListID: UUID?  // Active cue list ID
    @Binding var showCueListChooser: Bool  // Show cue list chooser popover
    let libAddedAt: [UUID: Date]  // Timestamps for library songs
    let selectedThemeID: String  // Theme ID for popover
    let projectTitle: String
    let connectionTint: Color
    let connectionCoordinator: ConnectionCoordinator
    let titleBarColor: Color  // Theme title bar color
    let buttonColor: Color  // Theme button color for icons/text
    let textColor: Color  // Theme text color for title
    let lightButtonBackgroundColor: Color  // Slightly lighter version of title bar for button backgrounds
    let themeFont: (CGFloat, Font.Weight) -> Font  // Theme font function

    // Core actions
    var onConnections: () -> Void
    var onEditToggle: () -> Void
    var onAdd: () -> Void
    var onUndo: () -> Void
    var onRedo: () -> Void
    var canUndo: Bool = false
    var canRedo: Bool = false
    var onMenuToggle: () -> Void
    var onAddToSetlist: (Song) -> Void  // Add song to setlist callback
    var onDeleteFromLibrary: (Song) -> Void  // Delete from library callback

    // Menu actions
    var onRenameProject: () -> Void
    var onNewProject: () -> Void
    var onSave: () -> Void
    var onSaveAs: () -> Void
    var onOpenProject: () -> Void
    var onImport: () -> Void
    var onExport: () -> Void
    var onShowMidiSettings: () -> Void
    var onShowAppearance: () -> Void = {}
    var onShowOnboarding: () -> Void = {}
    var onShowAbout: () -> Void = {}

    // Cue list actions
    var onSwitchCueList: (UUID) -> Void = { _ in }
    var onDuplicateCueList: (UUID) -> Void = { _ in }
    var onRenameCueList: (UUID) -> Void = { _ in }
    var onDeleteCueList: (UUID) -> Void = { _ in }
    var onCreateCueList: () -> Void = {}

    // v1.3: open Show mode
    var onShowMode: () -> Void = {}

    @Environment(\.colorScheme) private var colorScheme

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone

        HStack(spacing: 0) {
            // LEFT CAPSULE: Menu button + Project Name
            // iPhone: Hide when in edit mode
            if !(isPhone && isEditing) {
                HStack(spacing: 8) {
                    // Hamburger menu capsule
                    mainMenuButton
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)

                    // Cue list name capsule
                    projectNameButton
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: TutorialButtonFramePreferenceKey.self,
                                    value: ["cueListNameButton": geo.frame(in: .global)]
                                )
                            }
                        )
                }
                .padding(.leading, 16)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: CapsuleBoundsPreferenceKey.self,
                            value: ["topBar.left": geo.frame(in: .global)]
                        )
                    }
                )
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            Spacer()

            // RIGHT CAPSULES: Separate capsules for connections and edit
            HStack(spacing: 8) {
                // v1.3: Show mode capsule (hide when editing)
                if !isEditing {
                    Button(action: onShowMode) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Show")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .contentShape(RoundedRectangle(cornerRadius: 10))
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
                    }
                    .buttonStyle(IOSPressButtonStyle())
                    .accessibilityLabel("Show mode")
                    .accessibilityHint("Opens the stage screen with Now, Next and GO")
                    .transition(.opacity.combined(with: .scale))
                }

                // Connections capsule (hide when editing)
                if !isEditing {
                    Button(action: onConnections) {
                        // All visual styling inside label so ButtonStyle animates the whole capsule
                        HStack(spacing: 6) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 18))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(connectionTint)

                            // Show connection type chip when connected
                            if connectionCoordinator.activeConnection == .usb {
                                Text("USB")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.green)
                                    .clipShape(Capsule())
                            } else if connectionCoordinator.activeConnection == .wifi {
                                Text("WiFi")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.blue)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .contentShape(RoundedRectangle(cornerRadius: 10))
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
                    }
                    .buttonStyle(IOSPressButtonStyle())
                    .transition(.opacity.combined(with: .scale))
                }

                // Edit controls capsule
                rightCapsuleControls
                .padding(.horizontal, isEditing ? 4 : 0)
                .frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .contentShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: TutorialButtonFramePreferenceKey.self,
                            value: ["editButton": geo.frame(in: .global)]
                        )
                    }
                )
            }
            .padding(.trailing, 16)
            .padding(.leading, isPhone && isEditing ? 16 : 0)  // iPhone edit mode: expand to left edge
            .offset(x: showSideMenu ? 300 : 0)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: CapsuleBoundsPreferenceKey.self,
                        value: ["topBar.right": geo.frame(in: .global)]
                    )
                }
            )
            .animation(.spring(response: 0.2, dampingFraction: 0.85), value: showSideMenu)
        }
    }

    // MARK: - Subviews

    private var projectNameButton: some View {
        Button(action: { showCueListChooser.toggle() }) {
            HStack(spacing: 6) {
                Text(activeCueList?.name ?? "Untitled")
                    .font(themeFont(17, .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Image(systemName: showCueListChooser ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(IOSPressButtonStyle())
        .popover(isPresented: $showCueListChooser, arrowEdge: .top) {
            CueListChooserPopover(
                cueLists: $cueLists,
                activeCueListID: $activeCueListID,
                selectedThemeID: selectedThemeID,
                projectName: projectTitle,
                onSwitchCueList: { id in
                    // If clicking the already-active cue list, just close chooser
                    if id != activeCueListID {
                        onSwitchCueList(id)
                    }
                    showCueListChooser = false
                },
                onDuplicate: onDuplicateCueList,
                onRename: onRenameCueList,
                onDelete: onDeleteCueList,
                onCreateNew: onCreateCueList,
                onRenameProject: onRenameProject
            )
            .presentationCompactAdaptation(.popover)
            .presentationBackground(selectedTheme.sheetBackgroundColor(for: colorScheme))
            .tint(.white)
        }
    }

    private var activeCueList: CueList? {
        guard let id = activeCueListID else { return cueLists.first }
        return cueLists.first(where: { $0.id == id })
    }

    private var mainMenuButton: some View {
        Button(action: onMenuToggle) {
            Image(systemName: showSideMenu ? "xmark" : "line.3.horizontal")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .rotationEffect(.degrees(showSideMenu ? 90 : 0))
                .contentTransition(.symbolEffect(.replace))
                .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(IOSPressButtonStyle())
    }

    // Unified right capsule that morphs between performance and edit modes
    private var rightCapsuleControls: some View {
        HStack(spacing: 4) {
            // Edit mode controls (show when editing)
            if isEditing {
                // Library button - opens song library popover
                Button(action: {
                    showLibraryPopover = true
                }) {
                    Image(systemName: "book")
                        .imageScale(.large)
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(IOSPressButtonStyle())
                .transition(.opacity.combined(with: .scale))
                .id("libraryButton")
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: TutorialButtonFramePreferenceKey.self,
                            value: ["libraryButton": geo.frame(in: .global)]
                        )
                    }
                )
                .popover(isPresented: $showLibraryPopover, arrowEdge: .top) {
                    SongLibraryPopover(
                        library: $songLibrary,
                        activeCueListSongs: $activeCueListSongs,
                        libAddedAt: libAddedAt,
                        selectedThemeID: selectedThemeID,
                        onAddToCueList: onAddToSetlist,
                        onRemoveFromCueList: { song in
                            // Remove song from active cue list
                            if let activeCueList = cueLists.first(where: { $0.id == activeCueListID }) {
                                var updatedList = activeCueList
                                updatedList.songs.removeAll(where: { $0.id == song.id })
                                if let index = cueLists.firstIndex(where: { $0.id == activeCueListID }) {
                                    cueLists[index] = updatedList
                                }
                            }
                        },
                        onDelete: onDeleteFromLibrary,
                        onEdit: { song in
                            editingSong = song
                            showAddEdit = true
                        }
                    )
                    .presentationCompactAdaptation(.popover)
                    .presentationBackground(selectedTheme.sheetBackgroundColor(for: colorScheme))
                    .tint(.white)
                }

                Button(action: onUndo) {
                    Image(systemName: "arrow.uturn.backward")
                        .imageScale(.large)
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(IOSPressButtonStyle())
                .disabled(!canUndo)
                .opacity(canUndo ? 1.0 : 0.4)
                .transition(.opacity.combined(with: .scale))

                Button(action: onRedo) {
                    Image(systemName: "arrow.uturn.forward")
                        .imageScale(.large)
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(IOSPressButtonStyle())
                .disabled(!canRedo)
                .opacity(canRedo ? 1.0 : 0.4)
                .transition(.opacity.combined(with: .scale))

                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .imageScale(.large)
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(IOSPressButtonStyle())
                .transition(.opacity.combined(with: .scale))
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: TutorialButtonFramePreferenceKey.self,
                            value: ["addCueButton": geo.frame(in: .global)]
                        )
                    }
                )
            }

            // Edit/Done button (morphs between states) - pencil/checkmark icon like CueRowDesignPreview
            Button(action: onEditToggle) {
                Image(systemName: isEditing ? "checkmark" : "pencil")
                    .imageScale(.large)
                    .foregroundColor(buttonColor)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(IOSPressButtonStyle())
            .transition(.opacity.combined(with: .scale))
            .id(isEditing ? "doneButton" : "editButton")
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(minHeight: 32)
    }

    private var performanceModeControls: some View {
        HStack(spacing: 12) {
            // Connections button
            Button(action: onConnections) {
                HStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .imageScale(.large)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(connectionTint)
                        .scaleEffect(connectionCoordinator.activeConnection == .none ? 1.0 : 1.0)
                        .animation(
                            connectionCoordinator.activeConnection == .none
                                ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                                : .default,
                            value: connectionCoordinator.activeConnection
                        )

                    // Show connection type chip when connected
                    if connectionCoordinator.activeConnection == .usb {
                        Text("USB")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green)
                            .clipShape(Capsule())
                    } else if connectionCoordinator.activeConnection == .wifi {
                        Text("WiFi")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue)
                            .clipShape(Capsule())
                    }
                }
            }
            .buttonStyle(ThemedCapsuleButtonStyle(backgroundColor: lightButtonBackgroundColor, strokeColor: connectionTint))

            // Edit button - pencil icon
            Button(action: onEditToggle) {
                Image(systemName: "pencil")
                    .imageScale(.large)
                    .foregroundColor(buttonColor)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(IOSPressButtonStyle())
        }
    }

    // iPhone only: Combined controls for edit mode (connections + edit actions)
    private var combinedEditModeControls: some View {
        HStack(spacing: 12) {
            // Connections button
            Button(action: onConnections) {
                HStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .imageScale(.large)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(connectionTint)
                        .scaleEffect(connectionCoordinator.activeConnection == .none ? 1.0 : 1.0)
                        .animation(
                            connectionCoordinator.activeConnection == .none
                                ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                                : .default,
                            value: connectionCoordinator.activeConnection
                        )

                    // Show connection type chip when connected
                    if connectionCoordinator.activeConnection == .usb {
                        Text("USB")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green)
                            .clipShape(Capsule())
                    } else if connectionCoordinator.activeConnection == .wifi {
                        Text("WiFi")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue)
                            .clipShape(Capsule())
                    }
                }
            }
            .buttonStyle(ThemedCapsuleButtonStyle(backgroundColor: lightButtonBackgroundColor, strokeColor: connectionTint))

            Button(action: onUndo) {
                Image(systemName: "arrow.uturn.backward")
                    .imageScale(.large)
            }
            .buttonStyle(ThemedCapsuleButtonStyle(backgroundColor: lightButtonBackgroundColor, strokeColor: buttonColor))
            .disabled(!canUndo)

            Button(action: onRedo) {
                Image(systemName: "arrow.uturn.forward")
                    .imageScale(.large)
            }
            .buttonStyle(ThemedCapsuleButtonStyle(backgroundColor: lightButtonBackgroundColor, strokeColor: buttonColor))
            .disabled(!canRedo)

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .imageScale(.large)
            }
            .buttonStyle(ThemedCapsuleButtonStyle(backgroundColor: lightButtonBackgroundColor, strokeColor: buttonColor))

            Button("Done", action: onEditToggle)
                .buttonStyle(ThemedCapsuleButtonStyle(backgroundColor: lightButtonBackgroundColor, strokeColor: buttonColor))
        }
    }

    private var editModeControls: some View {
        HStack(spacing: 12) {
            Button(action: onUndo) {
                Image(systemName: "arrow.uturn.backward")
                    .imageScale(.large)
            }
            .buttonStyle(ThemedCapsuleButtonStyle(backgroundColor: lightButtonBackgroundColor, strokeColor: buttonColor))
            .disabled(!canUndo)

            Button(action: onRedo) {
                Image(systemName: "arrow.uturn.forward")
                    .imageScale(.large)
            }
            .buttonStyle(ThemedCapsuleButtonStyle(backgroundColor: lightButtonBackgroundColor, strokeColor: buttonColor))
            .disabled(!canRedo)

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .imageScale(.large)
            }
            .buttonStyle(ThemedCapsuleButtonStyle(backgroundColor: lightButtonBackgroundColor, strokeColor: buttonColor))

            Button("Done", action: onEditToggle)
                .buttonStyle(ThemedCapsuleButtonStyle(backgroundColor: lightButtonBackgroundColor, strokeColor: buttonColor))
        }
    }
}

// MARK: - Control Area

    // Widget-like packed grid layout types (visible to CBControlSection)
    struct GridSpan { let columns: Int; let rows: Int }
    struct GridSpanKey: LayoutValueKey { static let defaultValue = GridSpan(columns: 1, rows: 1) }
    struct GridOrigin { let col: Int; let row: Int; let isSet: Bool }
    struct GridOriginKey: LayoutValueKey { static let defaultValue = GridOrigin(col: -1, row: -1, isSet: false) }
    struct PackedGridLayout: Layout {
        let columns: Int
        let columnSpacing: CGFloat
        let rowSpacing: CGFloat

        // FIX #6: Make Placement accessible for cache
        struct Placement { let originRow: Int; let originCol: Int; let span: GridSpan }

        // FIX #6: Implement cache structure to avoid recomputation
        struct LayoutCache {
            var width: CGFloat = 0
            var placements: [Placement] = []
            var rows: Int = 0
            var cellSize: CGSize = .zero
        }
        typealias Cache = LayoutCache

        // FIX #6: Implement makeCache to initialize cache
        func makeCache(subviews: Subviews) -> LayoutCache {
            return LayoutCache()
        }

        private func computePlacements(_ subviews: Subviews, width: CGFloat) -> (placements: [Placement], rows: Int, cellSize: CGSize) {
            let totalColSpacing = columnSpacing * CGFloat(max(0, columns - 1))
            let cellWidth = (width - totalColSpacing) / CGFloat(columns)
            let cellHeight = cellWidth
            var occupancy: [[Bool]] = Array(repeating: Array(repeating: false, count: columns), count: 1)

            func fits(_ r: Int, _ c: Int, _ w: Int, _ h: Int) -> Bool {
                if c + w > columns { return false }
                let rowsNeeded = r + h
                if rowsNeeded > occupancy.count {
                    occupancy.append(contentsOf: Array(repeating: Array(repeating: false, count: columns), count: rowsNeeded - occupancy.count))
                }
                for rr in r..<(r+h) { for cc in c..<(c+w) { if occupancy[rr][cc] { return false } } }
                return true
            }
            func mark(_ r: Int, _ c: Int, _ w: Int, _ h: Int) {
                for rr in r..<(r+h) { for cc in c..<(c+w) { occupancy[rr][cc] = true } }
            }

            var placements: [Placement] = []
            var placedIndex = Set<Int>()
            // First: honor explicit origins when possible
            for idx in subviews.indices {
                let span = subviews[idx][GridSpanKey.self]
                let origin = subviews[idx][GridOriginKey.self]
                if origin.isSet {
                    if origin.col >= 0, origin.row >= 0, fits(origin.row, origin.col, span.columns, span.rows) {
                        placements.append(Placement(originRow: origin.row, originCol: origin.col, span: span))
                        mark(origin.row, origin.col, span.columns, span.rows)
                        placedIndex.insert(idx)
                    }
                }
            }
            // Then: place remaining by first-fit
            for idx in subviews.indices where !placedIndex.contains(idx) {
                let span = subviews[idx][GridSpanKey.self]
                var placed = false
                var r = 0
                while !placed {
                    var c = 0
                    while c < columns {
                        if fits(r, c, span.columns, span.rows) { placements.append(Placement(originRow: r, originCol: c, span: span)); mark(r, c, span.columns, span.rows); placed = true; break }
                        c += 1
                    }
                    if !placed { r += 1 }
                }
            }

            var lastUsed = 0
            for (i, row) in occupancy.enumerated() { if row.contains(true) { lastUsed = i + 1 } }
            return (placements, max(1, lastUsed), CGSize(width: cellWidth, height: cellHeight))
        }

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
            guard let width = proposal.width else { return .zero }
            // FIX #6: Use cached result if width hasn't changed
            if cache.width != width {
                let result = computePlacements(subviews, width: width)
                cache.width = width
                cache.placements = result.placements
                cache.rows = result.rows
                cache.cellSize = result.cellSize
            }
            let totalHeight = CGFloat(cache.rows) * cache.cellSize.height + rowSpacing * CGFloat(max(0, cache.rows - 1))
            return CGSize(width: width, height: totalHeight)
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
            let width = bounds.width
            // FIX #6: Use cached result if width hasn't changed
            if cache.width != width {
                let result = computePlacements(subviews, width: width)
                cache.width = width
                cache.placements = result.placements
                cache.rows = result.rows
                cache.cellSize = result.cellSize
            }
            for (idx, placement) in cache.placements.enumerated() {
                let x = CGFloat(placement.originCol) * (cache.cellSize.width + columnSpacing)
                let y = CGFloat(placement.originRow) * (cache.cellSize.height + rowSpacing)
                let w = CGFloat(placement.span.columns) * cache.cellSize.width + CGFloat(max(0, placement.span.columns - 1)) * columnSpacing
                let h = CGFloat(placement.span.rows) * cache.cellSize.height + CGFloat(max(0, placement.span.rows - 1)) * rowSpacing
                let rect = CGRect(x: bounds.minX + x, y: bounds.minY + y, width: w, height: h)
                subviews[idx].place(at: rect.origin, anchor: .topLeading, proposal: ProposedViewSize(rect.size))
            }
        }
    }
// Global cached portrait width to prevent repeated UIScreen access during SwiftUI layout
// This MUST be outside the struct to avoid recreation on each view instantiation
private let globalCachedPortraitWidth: CGFloat = {
    let screenBounds = UIScreen.main.bounds
    return min(screenBounds.width, screenBounds.height)
}()

private struct CBControlSection: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Binding var buttons: [ControlButton]
    @Binding var isEditing: Bool
    @Binding var perRow: Int
    @Binding var pendingAddIsFader: Bool?
    @Binding var reportedHeight: CGFloat
    @Binding var canAddMoreControls: Bool
    @Binding var isCollapsed: Bool  // Changed from @State to @Binding so ContentView can access it
    @Binding var selectedCue: UUID?  // Chosen cue to clear when entering edit mode
    @Binding var currentPage: Int  // Current page (0-3) for multi-page control area
    let conflictFor: [MIDIKey: String]
    @AppStorage("midiFiltersEnabled") private var midiFiltersEnabled: Bool = true
    let midiFilter: Set<Int>
    let showMIDIData: Bool  // Toggle for showing MIDI data
    var onTap: (ControlButton) -> Void
    var onEditButton: (ControlButton) -> Void
    var onAddButton: () -> Void
    var onAddFader: () -> Void
    var onUndo: () -> Void
    var onRedo: () -> Void
    var canUndo: Bool = false
    var canRedo: Bool = false
    var onDelete: (ControlButton) -> Void
    var onMove: (IndexSet, Int) -> Void
    var onCancelTimer: () -> Void  // Called to cancel edit mode timer
    var onResetTimer: () -> Void  // Called to reset edit mode timer
    var usbServer: ConnectionManager
    var wifiClient: BridgeOutput
    var connectionCoordinator: ConnectionCoordinator
    let controlAreaColor: Color  // Theme control area color
    let buttonBackgroundColor: Color  // Theme button background color
    let lightButtonBackgroundColor: Color  // Slightly lighter version of title bar for button backgrounds
    let defaultCueColor: Color  // Theme default cue color for buttons/faders (includes custom accent)
    let standardButtonColor: Color  // Standard button color for UI controls (no custom accent)
    let textColor: Color  // Theme text color
    var markDirty: () -> Void
    var cueListEditMode: Bool = false  // When true, force collapse

    // Mac editor architecture adapted for iPad
    @State private var dragging: ControlButton? = nil
    @State private var previewLocation: GridPosition? = nil
    @State private var dropSurfaceElevated: Bool = false
    @State private   var editSessionNonce: Int = 0
    @State private var isDragOperation: Bool = false
    @State private var lastDropTime: Date = Date.distantPast
    @State private var isAutoAssigning: Bool = false

    // Smooth drag system inspired by cue capsule success
    @State private var dragTranslation: CGSize = .zero
    @State private var dragStartLocation: CGPoint = .zero
    @State private var shadowOffset: CGSize = .zero // For smooth shadow tracking

    // Track actual width for proper orientation handling
    // IMPORTANT: Initialize to 0, will be set by GeometryReader on first layout
    // Using UIScreen.main.bounds.width here causes freeze issues
    @State private var actualWidth: CGFloat = 0

    // Track portrait width for consistent grid sizing in both orientations
    // Uses global cached value to prevent infinite layout loops
    private var portraitWidth: CGFloat {
        return globalCachedPortraitWidth
    }

    // Track calculated height to avoid infinite render loops
    @State private var cachedHeight: CGFloat = 0

    // iPhone horizontal scroll tracking for custom scrollbar
    @State private var controlScrollOffset: CGFloat = 0
    @State private var controlVisibleWidth: CGFloat = 0

    // Cross-page drag state
    @State private var edgeDragTimer: Timer? = nil
    @State private var edgeDragDirection: Int = 0  // -1 = left edge, +1 = right edge, 0 = not at edge
    private let edgeDragDelay: TimeInterval = 0.5  // Delay before switching pages
    private let edgeThreshold: CGFloat = 40  // Pixels from edge to trigger

    // PERFORMANCE FIX: Cache displacement calculations to prevent O(n²) recomputation during drag
    @State private var displacementCache: [UUID: (col: Int, row: Int)] = [:]
    @State private var displacementCacheKey: String = ""
    @State private var hasInvalidDisplacement: Bool = false

    // iPhone 3-dot menu for adding controls
    @State private var showControlAddMenu: Bool = false

    // Pixel snapping to prevent jitter (from cue capsule success)
    private func snap(_ value: CGFloat) -> CGFloat {
        #if canImport(UIKit)
        let scale = UIScreen.main.scale
        #else
        let scale: CGFloat = 2.0
        #endif
        return (value * scale).rounded() / scale
    }
    
    // Centralized drag state management
    private func clearDragState(reason: String) {
        dragging = nil
        previewLocation = nil
        displacementCache.removeAll()
        displacementCacheKey = ""
        hasInvalidDisplacement = false
        dropSurfaceElevated = false
        isDragOperation = false
        dragTranslation = .zero
        dragStartLocation = .zero
        shadowOffset = .zero
        // Cancel any pending cross-page drag timer
        cancelEdgeDragTimer()
    }

    // Update displacement cache (called from onChange to avoid state modification during view update)
    private func updateDisplacementCache() {
        guard let dragging = dragging, let preview = previewLocation else {
            // No active drag - clear cache
            displacementCache.removeAll()
            displacementCacheKey = ""
            hasInvalidDisplacement = false
            return
        }

        // Generate cache key for current drag state
        let cacheKey = "\(dragging.id)_\(preview.col)_\(preview.row)"

        // Only rebuild if cache key changed
        if displacementCacheKey != cacheKey {
            displacementCacheKey = cacheKey
            let result = computeAllDisplacements(draggedButton: dragging, targetPosition: preview, columns: columns)
            displacementCache = result.displacements
            hasInvalidDisplacement = result.hasInvalidDisplacement
        }
    }

    // Grid configuration (same as Mac editor)
    private let columns = 8
    private var columnSpacing: CGFloat {
        UIDevice.current.userInterfaceIdiom == .phone ? 10 : 12
    }
    private var rowSpacing: CGFloat {
        UIDevice.current.userInterfaceIdiom == .phone ? 10 : 10
    }
    private var gridPadding: CGFloat {
        UIDevice.current.userInterfaceIdiom == .phone ? 8 : 20
    }
    
    private var canAddMoreControlsGlobal: Bool {
        // Check if there's space for either a button (2x1) or fader (1x2)
        let testButton = ControlButton(title: "Test", symbol: "square", kind: .cc, number: 0, channel: 1, isFader: false)
        let testFader = ControlButton(title: "Test", symbol: "square", kind: .cc, number: 0, channel: 1, isFader: true)

        // Return true if we can fit either a button OR a fader
        return findFirstAvailablePosition(for: testButton) != nil ||
               findFirstAvailablePosition(for: testFader) != nil
    }

    private var canAddFader: Bool {
        // Check if there's space for EITHER a horizontal (2x1) OR vertical (1x2) fader
        // Horizontal fader
        let horizontalFader = ControlButton(
            title: "Test",
            symbol: "square",
            kind: .cc,
            number: 0,
            channel: 1,
            isFader: true,
            faderOrientation: "horizontal"
        )

        // Vertical fader
        let verticalFader = ControlButton(
            title: "Test",
            symbol: "square",
            kind: .cc,
            number: 0,
            channel: 1,
            isFader: true,
            faderOrientation: "vertical"
        )

        // Return true if we can fit EITHER orientation
        return findFirstAvailablePosition(for: horizontalFader) != nil ||
               findFirstAvailablePosition(for: verticalFader) != nil
    }

    // MARK: - Page Navigation

    private let totalPages = 10  // Fixed number of pages (0-9)

    /// Returns buttons on the current page only
    private var currentPageButtons: [ControlButton] {
        buttons.filter { $0.page == currentPage }
    }

    /// Returns pages that have at least one control (for non-edit mode navigation)
    private var pagesWithControls: [Int] {
        let usedPages = Set(buttons.map { $0.page })
        return (0..<totalPages).filter { usedPages.contains($0) }.sorted()
    }

    /// In edit mode: show all pages. Otherwise: only pages with controls
    private var availablePages: [Int] {
        if isEditing {
            return Array(0..<totalPages)
        } else {
            let pages = pagesWithControls
            // If no controls at all, still show page 0
            return pages.isEmpty ? [0] : pages
        }
    }

    /// Previous available page (skipping empty pages in non-edit mode)
    private var previousPage: Int? {
        let pages = availablePages
        guard let currentIndex = pages.firstIndex(of: currentPage), currentIndex > 0 else {
            return nil
        }
        return pages[currentIndex - 1]
    }

    /// Next available page (skipping empty pages in non-edit mode)
    private var nextPage: Int? {
        let pages = availablePages
        guard let currentIndex = pages.firstIndex(of: currentPage), currentIndex < pages.count - 1 else {
            return nil
        }
        return pages[currentIndex + 1]
    }

    /// Display string for page indicator (e.g., "1/4" in edit mode, "1/2" if only 2 pages have controls)
    private var pageIndicatorText: String {
        let pages = availablePages
        let displayPage = (pages.firstIndex(of: currentPage) ?? 0) + 1
        return "\(displayPage)/\(pages.count)"
    }

    // MARK: - Cross-Page Drag Handling

    /// Check if drag position is at the edge and start/stop timer accordingly
    private func checkEdgeDrag(dragX: CGFloat, gridWidth: CGFloat) {
        let leftEdge = dragX < edgeThreshold
        let rightEdge = dragX > gridWidth - edgeThreshold

        if leftEdge && currentPage > 0 {
            // At left edge - can go to previous page
            if edgeDragDirection != -1 {
                startEdgeDragTimer(direction: -1)
            }
        } else if rightEdge && currentPage < totalPages - 1 {
            // At right edge - can go to next page
            if edgeDragDirection != 1 {
                startEdgeDragTimer(direction: 1)
            }
        } else {
            // Not at edge - cancel timer
            cancelEdgeDragTimer()
        }
    }

    private func startEdgeDragTimer(direction: Int) {
        cancelEdgeDragTimer()
        edgeDragDirection = direction
        edgeDragTimer = Timer.scheduledTimer(withTimeInterval: edgeDragDelay, repeats: false) { [self] _ in
            // Move control to adjacent page
            if let draggedButton = dragging {
                moveControlToPage(draggedButton, newPage: currentPage + direction)
            }
        }
    }

    private func cancelEdgeDragTimer() {
        edgeDragTimer?.invalidate()
        edgeDragTimer = nil
        edgeDragDirection = 0
    }

    /// Move a control to a different page and switch to that page
    private func moveControlToPage(_ control: ControlButton, newPage: Int) {
        guard newPage >= 0 && newPage < totalPages else { return }

        // Update the control's page
        if let index = buttons.firstIndex(where: { $0.id == control.id }) {
            buttons[index].page = newPage
            // Reset grid position to find a new spot on the new page
            buttons[index].gridCol = nil
            buttons[index].gridRow = nil
        }

        // Switch to the new page
        withAnimation(.easeInOut(duration: 0.2)) {
            currentPage = newPage
        }

        // Reset drag state
        clearDragState(reason: "moved control to page \(newPage)")
        cancelEdgeDragTimer()

        // Trigger re-layout
        editSessionNonce &+= 1
    }

    private func controlRowCount() -> Int {
        let slotsPerRow = max(3, perRow * 3)
        let totalSlots = buttons.reduce(0) { acc, b in acc + (b.isFader == true ? 2 : 3) }
        return Int(ceil(Double(max(1, totalSlots)) / Double(slotsPerRow)))
    }

    private var collapsedView: some View {
        Group {
            if buttons.isEmpty && !isEditing {
                // Show floating Edit button capsule when no controls exist
                Color.clear
                    .frame(height: 0)
                    .overlay(alignment: .bottomTrailing) {
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                isEditing = true
                                isCollapsed = false
                                editSessionNonce &+= 1
                            }
                        }) {
                            Text("Edit")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(standardButtonColor)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
                        .padding(.trailing, 16)
                        .padding(.bottom, 8)
                    }
                    .transition(.move(edge: .bottom))
            } else {
                // Show small collapsed capsule on right when collapsed
                Color.clear
                    .frame(height: 0)
                    .overlay(alignment: .bottomTrailing) {
                        HStack(spacing: 0) {
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    if isEditing {
                                        isEditing = false
                                        clearDragState(reason: "done button in collapsed capsule")
                                    } else {
                                        isEditing = true
                                        isCollapsed = false
                                        editSessionNonce &+= 1
                                    }
                                }
                            }) {
                                Text(isEditing ? "Done" : "Edit")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .frame(height: 44)
                            }
                            .buttonStyle(IOSPressButtonStyle())

                            if !buttons.isEmpty {
                                Button(action: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                        isCollapsed = false
                                    }
                                }) {
                                    Image(systemName: "chevron.up")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(IOSPressButtonStyle())
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
                        .padding(.trailing, 16)
                        .padding(.bottom, 8)
                    }
                    .transition(.move(edge: .bottom))
            }
        }
        .onChange(of: isEditing) { _, editing in
            clearDragState(reason: "edit mode toggle")
        }
        .onAppear {
            canAddMoreControls = canAddMoreControlsGlobal
        }
        .onChange(of: buttons.count) { _, _ in
            canAddMoreControls = canAddMoreControlsGlobal
        }
    }

    private var headerView: some View {
        VStack(spacing: 0) {
            mainHeader
        }
    }
    
    private var collapseHandle: some View {
        Button(action: {
            // Only allow toggle if there are buttons in the control area
            if !buttons.isEmpty {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isCollapsed.toggle()
                }
            }
        }) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.secondary.opacity(buttons.isEmpty ? 0.15 : 0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 4)
                .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .disabled(buttons.isEmpty)
    }
    
    private var mainHeader: some View {
        HStack(spacing: 8) {
            // Page navigation capsule (left side) - show if:
            // 1. More than 1 page has controls, OR
            // 2. In edit mode with multiple pages available, OR
            // 3. There are any buttons (show page indicator even if all on one page)
            if pagesWithControls.count > 1 || (isEditing && availablePages.count > 1) || !buttons.isEmpty {
                HStack(spacing: 0) {
                    // Previous page button
                    Button(action: {
                        if let prev = previousPage {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentPage = prev
                            }
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(previousPage != nil ? .white : .white.opacity(0.3))
                            .frame(width: 36, height: 44)
                    }
                    .disabled(previousPage == nil)

                    // Page indicator
                    Text(pageIndicatorText)
                        .font(.custom("Sora-Regular", size: 14))
                        .foregroundColor(.white)
                        .frame(minWidth: 32)

                    // Next page button
                    Button(action: {
                        if let next = nextPage {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentPage = next
                            }
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(nextPage != nil ? .white : .white.opacity(0.3))
                            .frame(width: 36, height: 44)
                    }
                    .disabled(nextPage == nil)
                }
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
                .contentShape(RoundedRectangle(cornerRadius: 10))
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            let horizontalAmount = value.translation.width
                            // Swipe left = next page, swipe right = previous page
                            if horizontalAmount < -30, let next = nextPage {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    currentPage = next
                                }
                            } else if horizontalAmount > 30, let prev = previousPage {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    currentPage = prev
                                }
                            }
                        }
                )
                .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            // Edit mode: 3 separate capsules (undo/redo | + | done)
            // Non-edit mode: single "Edit" capsule
            if isEditing && !isCollapsed {
                // Capsule 3 (leftmost): Undo/Redo
                HStack(spacing: 0) {
                    Button(action: onUndo) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(canUndo ? .white : .white.opacity(0.3))
                            .frame(width: 44, height: 44)
                    }
                    .disabled(!canUndo)

                    Button(action: onRedo) {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(canRedo ? .white : .white.opacity(0.3))
                            .frame(width: 44, height: 44)
                    }
                    .disabled(!canRedo)
                }
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
                .transition(.scale.combined(with: .opacity))

                // Capsule 2 (middle): Add (+)
                Menu {
                    Button(action: onAddButton) {
                        Label("Button", systemImage: "button.horizontal")
                    }
                    .disabled(!canAddMoreControls)

                    Button(action: onAddFader) {
                        Label("Fader", systemImage: "slider.vertical.3")
                    }
                    .disabled(!canAddFader)
                } label: {
                    Color.clear
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor((canAddMoreControls || canAddFader) ? .white : .white.opacity(0.3))
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canAddMoreControls && !canAddFader)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
                .transition(.scale.combined(with: .opacity))
            }

            // Rightmost capsule: always present, no conditional insertion
            // Non-edit mode with buttons: [Edit | ▼] combined capsule
            // Non-edit mode no buttons: [Edit] single button
            // Edit mode: [✓] done button
            HStack(spacing: 0) {
                if isEditing && !isCollapsed {
                    // Done button (checkmark or collapse chevron if empty)
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            if buttons.isEmpty {
                                isCollapsed = true
                                isEditing = false
                                clearDragState(reason: "main edit button - collapsing empty control area")
                            } else {
                                isEditing = false
                                clearDragState(reason: "main edit button - exiting edit mode")
                            }
                        }
                    }) {
                        Image(systemName: buttons.isEmpty ? "chevron.down" : "checkmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Edit button
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            isEditing = true
                            isCollapsed = false
                            selectedCue = nil
                            editSessionNonce &+= 1
                            clearDragState(reason: "main edit button - entering edit mode")
                        }
                    }) {
                        Text("Edit")
                            .font(.custom("Sora-Regular", size: 15))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                    }
                    .buttonStyle(.plain)

                    // Collapse chevron — always here when Edit is shown + buttons exist
                    // No conditional insertion = no transition animation issues
                    if !buttons.isEmpty {
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 1, height: 24)

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isCollapsed.toggle()
                            }
                        }) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 44)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(height: 68)
    }


    var body: some View {
        // Early return for collapsed/empty states - skip grid creation entirely
        if effectivelyCollapsed {
            return AnyView(collapsedView)
        }

        let gridArea = Group {
            // Only render the grid area when not collapsed
            if !effectivelyCollapsed {
                GeometryReader { outerProxy in
                    buildControlGrid(proxy: outerProxy, isCtrlEditing: isEditing, sessionNonce: editSessionNonce, usbServer: usbServer, wifiClient: wifiClient, connectionCoordinator: connectionCoordinator)
                    .onAppear {
                        // Update actual width when view appears
                        actualWidth = outerProxy.size.width
                    }
                    .onChange(of: outerProxy.size.width) { oldWidth, newWidth in
                        // Update actual width when orientation changes
                        // Guard against tiny changes that could cause layout loops
                        guard abs(newWidth - oldWidth) > 1 else { return }
                        actualWidth = newWidth
                    }
                }
                .id("ctrl-geo-\(isEditing)-sess-\(editSessionNonce)")
                // No maxWidth constraint - let the capsule width calculation determine the size
                // Use cachedHeight instead of calculateDynamicHeight() to prevent infinite layout loop
                .frame(height: cachedHeight > 0 ? cachedHeight : 200, alignment: .top)  // Align content to top
                .background(Color.clear)  // Ensure no white background
                // Skip drawingGroup on iPhone - can cause rendering issues with GeometryReader
                .modifier(ConditionalDrawingGroup(enabled: UIDevice.current.userInterfaceIdiom != .phone))
                .onAppear {
                    // Calculate initial height on appear
                    let height = calculateDynamicHeight()
                    cachedHeight = height
                    // Debounce reportedHeight update to avoid infinite loop
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        if abs(reportedHeight - height) > 5 {
                            reportedHeight = height
                        }
                    }
                }
                .onChange(of: actualWidth) { _, _ in
                    // Recalculate height when width changes (orientation change)
                    let height = calculateDynamicHeight()
                    cachedHeight = height
                    // Debounce reportedHeight update to avoid infinite loop
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if abs(reportedHeight - height) > 5 {
                            reportedHeight = height
                        }
                    }
                }
            }
        }

        let styledGridArea = gridArea
            .opacity(effectivelyCollapsed ? 0 : 1)  // Hide grid completely when collapsed
            .onChange(of: isEditing) { _, newValue in
                if !newValue {
                    // fully reset drag/drop when leaving edit
                    clearDragState(reason: "onChange - leaving edit mode")
                }
            }
            .onChange(of: cueListEditMode) { _, newValue in
                // Collapse control area when cue list enters edit mode
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    if newValue {
                        isCollapsed = true
                    } else {
                        isCollapsed = false
                        // Auto-enter edit mode when expanding empty control area
                        if buttons.isEmpty {
                            isEditing = true
                        }
                    }
                }
            }
            .onChange(of: buttons.count) { _, _ in
                let height = calculateDynamicHeight()
                cachedHeight = height
                // Debounce reportedHeight update to avoid infinite loop
                // The delay breaks the synchronous layout cycle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if abs(reportedHeight - height) > 5 {
                        reportedHeight = height
                    }
                }
            }
            .onChange(of: buttons.map { "\($0.gridRow ?? -1)" }.joined()) { _, _ in
                // Recalculate when button positions change (not just count)
                let height = calculateDynamicHeight()
                cachedHeight = height
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if abs(reportedHeight - height) > 5 {
                        reportedHeight = height
                    }
                }
            }
            .onChange(of: isCollapsed) { _, _ in
                let height = calculateDynamicHeight()
                cachedHeight = height
                // Debounce reportedHeight update to avoid infinite loop
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if abs(reportedHeight - height) > 5 {
                        reportedHeight = height
                    }
                }
            }
            .onChange(of: isEditing) { _, _ in
                // Recalculate when entering/exiting edit mode (edit mode shows full 4 rows)
                let height = calculateDynamicHeight()
                cachedHeight = height
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if abs(reportedHeight - height) > 5 {
                        reportedHeight = height
                    }
                }
            }
        
        let gridWithLifecycle = styledGridArea
                .onAppear {
                // Auto-assign positions on first load - call immediately since onAppear is safe
                    autoAssignGridPositions()
                }
            .onChange(of: buttons.count) { _, newCount in
                debugPrint("🔄 buttons.count changed to \(newCount) - dragging: \(dragging?.title ?? "none"), isDragOperation: \(isDragOperation)")

                // Auto-unfold and enter edit mode when control area becomes empty
                if newCount == 0 && isCollapsed {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        isCollapsed = false
                        isEditing = true  // Always edit mode when empty
                    }
                }

                // Only auto-assign when buttons are actually added/removed, not during drag operations
                // Also avoid auto-assign shortly after a drop to prevent position interference
                let timeSinceLastDrop = Date().timeIntervalSince(lastDropTime)
                if dragging == nil && !isDragOperation && timeSinceLastDrop > 0.5 && !isAutoAssigning {
                    // Auto-assign positions when buttons are added/removed (deferred to avoid state modification warnings)
                    DispatchQueue.main.async {
                        debugPrint("🔧 Auto-assigning positions due to button count change (new count: \(newCount))")
                        self.isAutoAssigning = true
                        autoAssignGridPositions()
                        self.isAutoAssigning = false
                    }
                } else {
                    let reason = dragging != nil ? "dragging in progress" :
                                isDragOperation ? "drag operation flag set" :
                                isAutoAssigning ? "auto-assign already in progress" :
                                "recent drop (time since: \(String(format: "%.2f", timeSinceLastDrop))s)"
                    debugPrint("⏭️ Skipping auto-assign: \(reason)")
                }
            }
            .onChange(of: dragging) { _, newValue in
                    debugPrint("🔄 dragging state changed → \(newValue?.title ?? "nil")")

                    if newValue != nil {
                        // Dragging started - cancel timer to keep edit mode active
                        onCancelTimer()
                    } else {
                        // Dragging ended - reset timer
                        onResetTimer()
                    }

                    // If dragging ended without going through performDrop, clean up state
                    if newValue == nil {
                        isDragOperation = false
                        // Use a small delay to allow performDrop to complete first
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            if dragging == nil && previewLocation != nil {
                                debugPrint("🧹 Fallback cleanup - clearing lingering preview")
                                previewLocation = nil
                                dropSurfaceElevated = false
                            }
                        }
                    }
                }
                .onChange(of: previewLocation) { _, newValue in
                    debugPrint("🔄 Preview location changed: \(newValue?.col ?? -1),\(newValue?.row ?? -1)")
                }
                .onChange(of: dragging?.id) { _, _ in
                    // Update displacement cache when drag state changes
                    updateDisplacementCache()
                }
                .onChange(of: previewLocation) { _, _ in
                    // Update displacement cache when preview location changes
                    updateDisplacementCache()
                }

        // Expanded view - only reached when not collapsed
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        let isLandscape = verticalSizeClass == .compact

        // Calculate grid width (fixed, based on screen size only)
        let gridWidthWithPadding: CGFloat? = {
            // iPhone: Only apply in landscape, use full width in portrait
            if isPhone && !isLandscape {
                return nil
            }

            // iPad landscape: Calculate width based on full columns
            if !isPhone && isLandscape {
                // Use same cell size calculation as portrait for consistency
                let totalSpacing = CGFloat(columns - 1) * columnSpacing
                let actualHorizontalPadding = 16 + columnSpacing
                let availableWidth = portraitWidth - (2 * actualHorizontalPadding) - totalSpacing
                var cellSize = floor(availableWidth / CGFloat(columns))

                // Apply same height constraint logic - use cached value to avoid freeze
                let landscapeHeight = globalCachedPortraitWidth
                let maxHeight = isPhone ? landscapeHeight * 0.8 : landscapeHeight * 0.7
                let actualVerticalPadding: CGFloat = 18 + (isPhone ? 0 : 8)  // top + bottom
                let extraPadding: CGFloat = 0
                let availableGridHeight = maxHeight - actualVerticalPadding - extraPadding
                // Always use 4 rows for consistent sizing regardless of edit mode
                let displayRows = 4
                let verticalGaps = max(0, displayRows - 1)
                let maxCellSize = (availableGridHeight - CGFloat(verticalGaps) * rowSpacing) / CGFloat(displayRows)
                cellSize = min(cellSize, floor(maxCellSize))

                // Use full columns for fixed width
                let gridWidth = CGFloat(columns) * cellSize + CGFloat(max(0, columns - 1)) * columnSpacing
                // Capsule padding: 16pt left + 16pt right (added at line 7381)
                let capsulePadding: CGFloat = 32
                let finalWidth = gridWidth + (columnSpacing * 2) + capsulePadding
                return finalWidth
            }

            // iPhone landscape: Also use full width
            let totalSpacing = CGFloat(columns - 1) * columnSpacing
            let actualHorizontalPadding = 16 + columnSpacing
            let availableWidth = portraitWidth - (2 * actualHorizontalPadding) - totalSpacing
            var cellSize = floor(availableWidth / CGFloat(columns))

            // Apply height constraint - use 80% of landscape height (cached to avoid freeze)
            let landscapeHeight = globalCachedPortraitWidth
            let maxHeight = landscapeHeight * 0.8
            let actualVerticalPadding: CGFloat = 18
            let availableGridHeight = maxHeight - actualVerticalPadding
            let displayRows = 4
            let verticalGaps = max(0, displayRows - 1)
            let maxCellSize = (availableGridHeight - CGFloat(verticalGaps) * rowSpacing) / CGFloat(displayRows)
            cellSize = min(cellSize, floor(maxCellSize))

            // Use full columns for fixed width
            let gridWidth = CGFloat(columns) * cellSize + CGFloat(max(0, columns - 1)) * columnSpacing
            let capsulePadding: CGFloat = 32
            let finalWidth = gridWidth + (columnSpacing * 2) + capsulePadding
            return finalWidth
        }()

        let baseView = Group {
            VStack(spacing: 0) {
                headerView
                    .zIndex(0)  // Header stays behind
                gridWithLifecycle
                    .zIndex(1)  // Grid (with X buttons) renders on top
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 4)
            )
        }

        let shapedView = baseView
        .padding(.horizontal, 16)  // Add padding to keep capsule content from edges
        .padding(.bottom, isPhone ? 0 : 8)
        // NOTE: Deliberately NOT reporting CapsuleBoundsPreferenceKey here
        // Reporting bounds causes an infinite loop:
        // 1. CBControlSection reports bounds via preference
        // 2. ContentView receives preference and updates capsuleBounds state
        // 3. ContentView re-renders
        // 4. controlSectionView computed property creates NEW CBControlSection with NEW closures
        // 5. SwiftUI sees new closures as "different" view and recreates CBControlSection
        // 6. Go to step 1 -> infinite loop / freeze
        //
        // Tutorial 4 removed (two-finger scroll no longer exists)

        let controlCapsule = shapedView
        .compositingGroup()
        .onChange(of: isEditing) { _, editing in
            clearDragState(reason: "edit mode toggle")
        }
        .onAppear {
            canAddMoreControls = canAddMoreControlsGlobal
        }
        .onChange(of: buttons.count) { _, _ in
            canAddMoreControls = canAddMoreControlsGlobal
        }

        // Apply width constraint (iPad: both orientations, iPhone: landscape only)
        if let width = gridWidthWithPadding {
            // Use fixed width in both orientations to allow outer frame alignment to work
            return AnyView(
                controlCapsule
                    .frame(width: width)  // Fixed width allows outer frame's .bottomTrailing to align correctly
            )
        } else {
            return AnyView(controlCapsule)
        }
    }
    
    // Treat empty as collapsed (when not editing)
    private var effectivelyCollapsed: Bool {
        return isCollapsed || (buttons.isEmpty && !isEditing)
    }

    // Calculate dynamic height without needing GeometryProxy
    private func calculateDynamicHeight() -> CGFloat {
        // Use tracked actual width instead of screen bounds for proper orientation handling
        let height = calculateControlAreaHeight(proxy: nil, screenWidth: actualWidth)
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        if isPhone {
            debugPrint("📱 [calculateDynamicHeight] height=\(height), actualWidth=\(actualWidth)")
        }
        return height
    }
    
    // Calculate the height needed for the control area
    private func calculateControlAreaHeight(proxy: GeometryProxy?, screenWidth: CGFloat? = nil) -> CGFloat {
        let isLandscape = verticalSizeClass == .compact
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone

        // iPhone: Dynamic height based on content, with larger cells
        // Always use 80% of landscape height (the shorter dimension) for consistency
        // NOTE: This returns GRID HEIGHT ONLY - header is added separately in VStack
        if isPhone {
            // IMPORTANT: Use globalCachedPortraitWidth instead of UIScreen.main.bounds
            // Accessing UIScreen.main.bounds during SwiftUI layout causes freeze
            let landscapeHeight = globalCachedPortraitWidth  // Already the shorter dimension
            let maxAvailableHeight = landscapeHeight * 0.8

            // Reserve space for header (68pt is added separately) and grid padding
            let headerHeight: CGFloat = 68
            let gridVerticalPadding: CGFloat = 52  // 8pt top + 12pt bottom + scrollbar (28pt handle + 4pt bottom padding)
            let maxGridAreaHeight = maxAvailableHeight - headerHeight - gridVerticalPadding

            // Calculate cell size based on 4 rows max - NO MINIMUM, let it shrink to fit
            let maxRows = 4
            let verticalGapsMax = max(0, maxRows - 1)
            let cellSize = floor((maxGridAreaHeight - CGFloat(verticalGapsMax) * rowSpacing) / CGFloat(maxRows))

            // Determine actual rows needed
            let rows: Int
            if isEditing {
                rows = 4  // Full grid in edit mode
            } else {
                let visualRows = calculateVisualRows()
                let pageButtons = buttons.filter { $0.page == currentPage }
                if visualRows == 0 && pageButtons.isEmpty {
                    return 44  // Header-only height when no buttons (this is total height)
                }
                rows = min(4, max(1, visualRows))
            }

            // Calculate GRID height only (header is in separate view in VStack)
            let verticalGaps = max(0, rows - 1)
            let gridHeight = CGFloat(rows) * cellSize + CGFloat(verticalGaps) * rowSpacing + gridVerticalPadding

            debugPrint("📱 [iPhone height] landscapeH=\(landscapeHeight), maxAvail=\(maxAvailableHeight), cellSize=\(cellSize), rows=\(rows), gridHeight=\(gridHeight)")

            return gridHeight
        }

        // iPad: Calculate based on grid dimensions
        let fixedWidthForGrid: CGFloat = portraitWidth

        let width: CGFloat = fixedWidthForGrid
        let totalSpacing = CGFloat(columns - 1) * columnSpacing
        let actualHorizontalPadding = gridPadding
        let availableWidth = width - (2 * actualHorizontalPadding) - totalSpacing
        let cellSize = floor(availableWidth / CGFloat(columns))

        // Ensure minimum cell size in landscape to prevent cutoff
        let minCellSize: CGFloat = isLandscape ? 80 : 60
        let adjustedCellSize = max(cellSize, minCellSize)

        // Determine rows based on mode and orientation
        let rows: Int

        if isEditing {
            // Edit mode: Always show full 4-row editing canvas
            rows = 4
        } else {
            // Non-edit mode: Dynamic based on occupied buttons on current page, capped at 4 rows
            let visualRows = calculateVisualRows()
            let pageButtons = buttons.filter { $0.page == currentPage }
            if visualRows == 0 && pageButtons.isEmpty {
                // Special case: no buttons on current page = header-only height (same as collapsed)
                return 44
            }
            rows = min(4, max(0, visualRows))
        }

        // Convert rows to pixels
        let verticalGaps = max(0, rows - 1)
        let gridHeight = CGFloat(rows) * adjustedCellSize + CGFloat(verticalGaps) * rowSpacing

        // Add extra padding in landscape to prevent cutoff and provide breathing room
        let extraPadding: CGFloat = isLandscape ? 30 : 0
        // iPad: top=8, bottom=gridPadding (same as sides)
        let actualVerticalPadding: CGFloat = 8 + gridPadding
        let finalHeight = gridHeight + actualVerticalPadding + extraPadding

        return finalHeight
    }
    
    // Calculate visual rows based on actual control positions and sizes (for current page only)
    private func calculateVisualRows() -> Int {
        // Only count buttons on the current page
        let pageButtons = buttons.filter { $0.page == currentPage }
        guard !pageButtons.isEmpty else {
            return 0  // Will be handled specially in height calculation
        }

        // Don't call autoAssignGridPositions during view updates to avoid state modification warnings
        // Instead, just calculate based on current positions, defaulting to row 0 if not set

        var maxEndRow = 0
        for button in pageButtons {
            let row = button.gridRow ?? 0  // Default to row 0 if not assigned yet
            // Use button.gridHeight to get the correct height based on orientation
            let height = button.gridHeight
            let endRow = row + height
            maxEndRow = max(maxEndRow, endRow)
        }

        let result = maxEndRow  // Allow 0 rows for minimal height when no buttons
        return result
    }
    
    // Legacy function kept for compatibility
    private func calculateOccupiedRows() -> Int {
        return calculateVisualRows()
    }
    
    // Auto-assign grid positions for controls that don't have them
    private func autoAssignGridPositions() {
        var needsUpdate = false
        var updates: [(Int, Int, Int)] = [] // (index, col, row)
        var occupiedPositions: Set<String> = [] // Track occupied positions as "col,row"

        // First, record all existing positions to avoid conflicts
        for button in buttons {
            if let col = button.gridCol, let row = button.gridRow {
                let width = button.gridWidth
                let height = button.gridHeight

                // Mark all cells occupied by this button
                for c in col..<(col + width) {
                    for r in row..<(row + height) {
                        occupiedPositions.insert("\(c),\(r)")
                    }
                }
            }
        }

        for i in 0..<buttons.count {
            // Only assign if not already set - don't override user-placed positions
            let needsPosition = buttons[i].gridCol == nil || buttons[i].gridRow == nil
            
            if needsPosition {
                if let position = findFirstAvailablePositionAvoidingOccupied(for: buttons[i], occupied: occupiedPositions) {
                    updates.append((i, position.col, position.row))
                    needsUpdate = true

                    // Update occupied positions for next iteration
                    let width = buttons[i].gridWidth
                    let height = buttons[i].gridHeight
                    for c in position.col..<(position.col + width) {
                        for r in position.row..<(position.row + height) {
                            occupiedPositions.insert("\(c),\(r)")
                        }
                    }
                } else {
                    // Fallback: place at bottom in first available column
                    let maxRow = buttons.compactMap { $0.gridRow }.max() ?? 0
                    let fallbackRow = maxRow + 2 // Give some space
                    updates.append((i, 0, fallbackRow))
                    needsUpdate = true
                }
            }
        }

        // Apply updates on next run loop to avoid "modifying state during view update"
        if needsUpdate {
            DispatchQueue.main.async {
                for (index, col, row) in updates {
                    if index < self.buttons.count {
                        self.buttons[index].gridCol = col
                        self.buttons[index].gridRow = row
                    }
                }
            }
        }
    }
    
    // Check if a button overlaps with any other buttons
    private func checkForOverlap(button: ControlButton, excluding excludeIds: [UUID]) -> Bool {
        guard let col = button.gridCol, let row = button.gridRow else { return false }

        let width = button.gridWidth
        let height = button.gridHeight
        let buttonRect = GridRect(col: col, row: row, width: width, height: height)
        
        let hasOverlap = hasOverlapExcluding(buttonRect, excluding: excludeIds)
        if hasOverlap {
            debugPrint("🔍 Overlap detected for \(button.title) at (\(col), \(row)) size \(width)x\(height)")
        }
        return hasOverlap
    }
    
    // Find first available position avoiding already occupied positions
    private func findFirstAvailablePositionAvoidingOccupied(for control: ControlButton, occupied: Set<String>) -> (col: Int, row: Int)? {
        let width = control.gridWidth
        let height = control.gridHeight
        let maxSearchRows = 4 // Reasonable limit

        // Search from top-left to bottom-right
        for row in 0..<maxSearchRows {
            // Skip this row if the control would extend beyond the bottom edge
            if row + height > maxSearchRows {
                continue
            }

            for col in 0...(columns - width) {
                var canPlace = true

                // Check if all required cells are free
                for c in col..<(col + width) {
                    for r in row..<(row + height) {
                        if occupied.contains("\(c),\(r)") {
                            canPlace = false
                            break
                        }
                    }
                    if !canPlace { break }
                }

                if canPlace {
                    return (col, row)
                }
            }
        }
        return nil
    }
    
    // Find the first available position for a control (top-left to bottom-right priority)
    private func findFirstAvailablePosition(for control: ControlButton) -> (col: Int, row: Int)? {
        let width = control.gridWidth
        let height = control.gridHeight
        let maxSearchRows = 4

        // Search from top-left to bottom-right
        for row in 0..<maxSearchRows {
            // Skip this row if the control would extend beyond the bottom edge
            if row + height > maxSearchRows {
                continue
            }

            for col in 0...(columns - width) {
                let testRect = GridRect(col: col, row: row, width: width, height: height)
                let hasOverlap = hasOverlapExcluding(testRect, excluding: [control.id])
                if !hasOverlap {
                    return (col, row)
                }
            }
        }
        return nil
    }

    // Compute effective position for live displacement preview during drag
    private func effectivePosition(
        for button: ControlButton,
        dragging: ControlButton?,
        preview: GridPosition?,
        columns: Int
    ) -> (col: Int, row: Int) {
        let baseCol = button.gridCol ?? 0
        let baseRow = button.gridRow ?? 0
        guard let dragging = dragging, let preview = preview else {
            return (baseCol, baseRow)
        }

        // If this IS the dragged button, keep it at its original position
        // The dragTranslation offset will handle the visual movement
        if dragging.id == button.id {
            return (baseCol, baseRow)
        }

        // PERFORMANCE FIX: Generate cache key for current drag state
        let cacheKey = "\(dragging.id)_\(preview.col)_\(preview.row)"

        // PERFORMANCE FIX: Check if we need to rebuild cache (but don't modify state here!)
        // If cache is stale, compute on-the-fly. Cache will be updated via onChange modifier.
        if displacementCacheKey != cacheKey {
            // Cache is stale - compute directly without modifying state
            let result = computeAllDisplacements(draggedButton: dragging, targetPosition: preview, columns: columns)
            return result.displacements[button.id] ?? (baseCol, baseRow)
        }

        // PERFORMANCE FIX: Use cached result (O(1) lookup instead of O(n) computation)
        if let cachedPos = displacementCache[button.id] {
            return cachedPos
        }

        return (baseCol, baseRow)
    }

    // PERFORMANCE FIX: Compute all displacement positions at once (called once per preview location change)
    private func computeAllDisplacements(draggedButton: ControlButton, targetPosition: GridPosition, columns: Int) -> (displacements: [UUID: (col: Int, row: Int)], hasInvalidDisplacement: Bool) {
        var result: [UUID: (col: Int, row: Int)] = [:]
        var hasInvalidDisplacement = false

        let draggedW = draggedButton.gridWidth
        let draggedH = draggedButton.gridHeight
        let draggedButtonShadow = GridRect(col: targetPosition.col, row: targetPosition.row, width: draggedW, height: draggedH)

        // Build occupancy map once for all buttons
        var occupiedPositions: Set<String> = []

        // Mark the dragged button's new position as occupied
        for c in targetPosition.col..<(targetPosition.col + draggedW) {
            for r in targetPosition.row..<(targetPosition.row + draggedH) {
                occupiedPositions.insert("\(c),\(r)")
            }
        }

        // Mark all existing button positions as occupied (excluding dragged button)
        for otherButton in buttons {
            if otherButton.id == draggedButton.id { continue }

            if let col = otherButton.gridCol, let row = otherButton.gridRow {
                let width = otherButton.gridWidth
                let height = otherButton.gridHeight
                for c in col..<(col + width) {
                    for r in row..<(row + height) {
                        occupiedPositions.insert("\(c),\(r)")
                    }
                }
            }
        }

        // Now compute displacement for each button that overlaps
        for button in buttons {
            if button.id == draggedButton.id { continue }

            let baseCol = button.gridCol ?? 0
            let baseRow = button.gridRow ?? 0
            let buttonRect = GridRect(col: baseCol, row: baseRow, width: button.gridWidth, height: button.gridHeight)

            if rectsOverlap(buttonRect, draggedButtonShadow) {
                // This button needs to move - calculate its new position
                let newPos = calculateDisplacementPosition(
                    for: button,
                    draggedButton: draggedButton,
                    targetPosition: targetPosition,
                    columns: columns,
                    occupiedPositions: occupiedPositions
                )

                if let validPos = newPos {
                    result[button.id] = validPos
                } else {
                    // No valid position found - keep button in original position and mark as invalid
                    hasInvalidDisplacement = true
                    result[button.id] = (baseCol, baseRow)
                }
            }
        }

        return (displacements: result, hasInvalidDisplacement: hasInvalidDisplacement)
    }
    
    // PERFORMANCE FIX: Calculate displacement position using pre-computed occupancy map
    private func calculateDisplacementPosition(
        for button: ControlButton,
        draggedButton: ControlButton,
        targetPosition: GridPosition,
        columns: Int,
        occupiedPositions: Set<String>
    ) -> (col: Int, row: Int)? {
        let buttonW = button.gridWidth
        let buttonH = button.gridHeight
        let draggedOriginalCol = draggedButton.gridCol ?? 0
        let draggedOriginalRow = draggedButton.gridRow ?? 0

        // Create a mutable copy to track positions occupied by other displaced buttons
        var mutableOccupied = occupiedPositions

        // Remove this button's current position from occupancy check
        if let col = button.gridCol, let row = button.gridRow {
            for c in col..<(col + buttonW) {
                for r in row..<(row + buttonH) {
                    mutableOccupied.remove("\(c),\(r)")
                }
            }
        }

        // iPhone-like smart positioning: try positions in order of preference
        // 1. Try swapping with dragged button's original position first (simple swap)

        if draggedOriginalCol + buttonW <= columns {
            var canSwap = true
            for c in draggedOriginalCol..<(draggedOriginalCol + buttonW) {
                for r in draggedOriginalRow..<(draggedOriginalRow + buttonH) {
                    if occupiedPositions.contains("\(c),\(r)") {
                        canSwap = false
                        break
                    }
                }
                if !canSwap { break }
            }

            if canSwap {
                return (draggedOriginalCol, draggedOriginalRow)
            }
        }

        // 2. Try moving right first (same row, next column) - iPhone behavior
        let originalCol = button.gridCol ?? 0
        let originalRow = button.gridRow ?? 0
        let rightCol = originalCol + 1

        if rightCol + buttonW <= columns {
            var canMoveRight = true
            for c in rightCol..<(rightCol + buttonW) {
                for r in originalRow..<(originalRow + buttonH) {
                    if occupiedPositions.contains("\(c),\(r)") {
                        canMoveRight = false
                        break
                    }
                }
                if !canMoveRight { break }
            }

            if canMoveRight {
                return (rightCol, originalRow)
            }
        }

        // 3. Try moving down and left (cascade to next row) - iPhone behavior
        let nextRow = originalRow + 1
        if nextRow + buttonH <= 4 { // max rows check
            for col in 0...(columns - buttonW) {
                var canPlace = true
                for c in col..<(col + buttonW) {
                    for r in nextRow..<(nextRow + buttonH) {
                        if occupiedPositions.contains("\(c),\(r)") {
                            canPlace = false
                            break
                        }
                    }
                    if !canPlace { break }
                }

                if canPlace {
                    return (col, nextRow)
                }
            }
        }

        // 4. Fallback: find the next available position (top-left to bottom-right)
        let maxRows = 4
        for row in 0..<maxRows {
            for col in 0...(columns - buttonW) {
                var canPlace = true
                for c in col..<(col + buttonW) {
                    for r in row..<(row + buttonH) {
                        if occupiedPositions.contains("\(c),\(r)") {
                            canPlace = false
                            break
                        }
                    }
                    if !canPlace { break }
                }

                if canPlace {
                    return (col, row)
                }
            }
        }

        // No valid position found - return nil to signal "no space available"
        return nil
    }
    
    // Commit positions for all buttons that were displaced during the drag
    private func commitDisplacedButtonPositions(draggedButton: ControlButton, targetPosition: GridPosition) {
        let draggedW = draggedButton.gridWidth
        let draggedH = draggedButton.gridHeight
        let draggedButtonShadow = GridRect(col: targetPosition.col, row: targetPosition.row, width: draggedW, height: draggedH)
        
        // Find all buttons that were displaced
        var displacedButtons: [(Int, ControlButton)] = []
        for i in 0..<buttons.count {
            let button = buttons[i]
            if button.id == draggedButton.id { continue } // Skip the dragged button
            
            let buttonRect = GridRect(
                col: button.gridCol ?? 0,
                row: button.gridRow ?? 0,
                width: button.gridWidth,
                height: button.gridHeight
            )
            
            // If this button was displaced (overlapped with the dragged button's shadow)
            if rectsOverlap(buttonRect, draggedButtonShadow) {
                displacedButtons.append((i, button))
            }
        }
        
        // Assign unique positions to displaced buttons
        var occupiedPositions: Set<String> = []
        
        // First, mark the dragged button's new position as occupied
        for c in targetPosition.col..<(targetPosition.col + draggedW) {
            for r in targetPosition.row..<(targetPosition.row + draggedH) {
                occupiedPositions.insert("\(c),\(r)")
            }
        }
        
        // Mark all existing button positions as occupied (excluding displaced buttons)
        for i in 0..<buttons.count {
            let button = buttons[i]
            if button.id == draggedButton.id { continue }
            if displacedButtons.contains(where: { $0.1.id == button.id }) { continue }
            
            if let col = button.gridCol, let row = button.gridRow {
                let width = button.gridWidth
                let height = button.gridHeight
                for c in col..<(col + width) {
                    for r in row..<(row + height) {
                        occupiedPositions.insert("\(c),\(r)")
                    }
                }
            }
        }
        
        // Assign unique positions to displaced buttons
        for (index, button) in displacedButtons {
            let buttonW = button.gridWidth
            let buttonH = button.gridHeight
            
            // Try swapping with dragged button's original position first
            let draggedOriginalCol = draggedButton.gridCol ?? 0
            let draggedOriginalRow = draggedButton.gridRow ?? 0
            
            var foundPosition = false
            if draggedOriginalCol + buttonW <= columns {
                var canSwap = true
                for c in draggedOriginalCol..<(draggedOriginalCol + buttonW) {
                    for r in draggedOriginalRow..<(draggedOriginalRow + buttonH) {
                        if occupiedPositions.contains("\(c),\(r)") {
                            canSwap = false
                            break
                        }
                    }
                    if !canSwap { break }
                }
                
                if canSwap {
                    buttons[index].gridCol = draggedOriginalCol
                    buttons[index].gridRow = draggedOriginalRow
                    foundPosition = true
                    debugPrint("🔄 Committed displaced button \(button.title) to swapped position (\(draggedOriginalCol), \(draggedOriginalRow))")
                    
                    // Mark this position as occupied
                    for c in draggedOriginalCol..<(draggedOriginalCol + buttonW) {
                        for r in draggedOriginalRow..<(draggedOriginalRow + buttonH) {
                            occupiedPositions.insert("\(c),\(r)")
                        }
                    }
                }
            }
            
            // If swap didn't work, find the next available position
            if !foundPosition {
                let maxRows = 4
                for row in 0..<maxRows {
                    for col in 0...(columns - buttonW) {
                        var canPlace = true
                        for c in col..<(col + buttonW) {
                            for r in row..<(row + buttonH) {
                                if occupiedPositions.contains("\(c),\(r)") {
                                    canPlace = false
                                    break
                                }
                            }
                            if !canPlace { break }
                        }
                        
                        if canPlace {
                            buttons[index].gridCol = col
                            buttons[index].gridRow = row
                            foundPosition = true
                            debugPrint("🔄 Committed displaced button \(button.title) to (\(col), \(row))")
                            
                            // Mark this position as occupied
                            for c in col..<(col + buttonW) {
                                for r in row..<(row + buttonH) {
                                    occupiedPositions.insert("\(c),\(r)")
                                }
                            }
                            break
                        }
                    }
                    if foundPosition { break }
                }
            }
            
            // Fallback if no position found
            if !foundPosition {
                let maxRow = buttons.compactMap { $0.gridRow }.max() ?? 0
                buttons[index].gridCol = 0
                buttons[index].gridRow = maxRow + 2
                debugPrint("🔄 Committed displaced button \(button.title) to fallback position (0, \(maxRow + 2))")
            }
        }
    }
    
    // Find displacement position for a button, ensuring no conflicts with other displaced buttons
    private func findDisplacementPosition(for button: ControlButton, draggedButton: ControlButton, columns: Int) -> (col: Int, row: Int) {
        let buttonW = button.gridWidth
        let buttonH = button.gridHeight
        
        // First try swapping with the dragged button's original position
        let draggedOriginalCol = draggedButton.gridCol ?? 0
        let draggedOriginalRow = draggedButton.gridRow ?? 0
        let draggedOriginalRect = GridRect(col: draggedOriginalCol, row: draggedOriginalRow, width: buttonW, height: buttonH)
        
        if draggedOriginalCol + buttonW <= columns && !hasOverlapExcluding(draggedOriginalRect, excluding: [draggedButton.id, button.id]) {
            return (draggedOriginalCol, draggedOriginalRow)
        }
        
        // Find a unique position by using the button's index as a seed
        let buttonIndex = buttons.firstIndex(where: { $0.id == button.id }) ?? 0
        let maxRows = 4
        
        // Try positions in a deterministic order based on button index
        // Start the search from a different position based on button index to ensure uniqueness
        let startOffset = buttonIndex * 3 // Use button index to offset the search
        for offset in startOffset..<(maxRows * columns + startOffset) {
            let actualOffset = offset % (maxRows * columns)
            let row = actualOffset / columns
            let col = actualOffset % columns
            
            // Skip if this position would go out of bounds
            if col + buttonW > columns || row + buttonH > maxRows {
                continue
            }
            
            let testRect = GridRect(col: col, row: row, width: buttonW, height: buttonH)
            
            // Check if this position is available (excluding dragged button and this button)
            if !hasOverlapExcluding(testRect, excluding: [draggedButton.id, button.id]) {
                return (col, row)
            }
        }
        
        // Fallback: place at bottom
        let maxRow = buttons.compactMap { $0.gridRow }.max() ?? 0
        return (0, maxRow + 2)
    }

    // Visual-only overlap helpers for live displacement preview
    private func rectsOverlap(_ rect1: GridRect, _ rect2: GridRect) -> Bool {
        return !(rect1.col + rect1.width <= rect2.col ||
                 rect2.col + rect2.width <= rect1.col ||
                 rect1.row + rect1.height <= rect2.row ||
                 rect2.row + rect2.height <= rect1.row)
    }

    private func hasOverlap(_ rect: GridRect) -> Bool {
        for item in buttons {
            guard let col = item.gridCol, let row = item.gridRow else { continue }
            let itemRect = GridRect(
                col: col, row: row,
                width: item.gridWidth,
                height: item.gridHeight
            )
            if rectsOverlap(rect, itemRect) { return true }
        }
        return false
    }

    private func hasOverlapExcluding(_ rect: GridRect, excluding excludeIds: [UUID]) -> Bool {
        // Only check buttons on the current page
        let pageButtons = buttons.filter { $0.page == currentPage }
        for item in pageButtons {
            guard let col = item.gridCol, let row = item.gridRow, !excludeIds.contains(item.id) else { continue }
            let itemRect = GridRect(
                col: col, row: row,
                width: item.gridWidth,
                height: item.gridHeight
            )
            if rectsOverlap(rect, itemRect) { return true }
        }
        return false
    }

    private func findFreePositionVisual(for item: ControlButton, columns: Int, excluding excludeIds: [UUID] = []) -> (col: Int, row: Int)? {
        let width = item.gridWidth
        let height = item.gridHeight
        let maxSearchRows = 4 // Increased search area
        for row in 0..<maxSearchRows {
            // Skip this row if the control would extend beyond the bottom edge
            if row + height > maxSearchRows {
                continue
            }
            for col in 0...(columns - width) {
                let test = GridRect(col: col, row: row, width: width, height: height)
                if !hasOverlapExcluding(test, excluding: excludeIds) {
                    return (col, row)
                }
            }
        }
        return nil
    }

    // Find the nearest available position for a button to move to, avoiding the dragged button's shadow
    private func findNearestAvailablePosition(
        for button: ControlButton,
        avoiding draggedButtonShadow: GridRect,
        maxRows: Int,
        columns: Int
    ) -> GridPosition? {
        let buttonWidth = button.gridWidth
        let buttonHeight = button.gridHeight
        
        // Start with the current position
        let currentPos = GridPosition(col: button.gridCol ?? 0, row: button.gridRow ?? 0)
        
        // If current position doesn't overlap with shadow, keep it
        let currentRect = GridRect(col: currentPos.col, row: currentPos.row, width: buttonWidth, height: buttonHeight)
        if !rectsOverlap(currentRect, draggedButtonShadow) {
            return currentPos
        }
        
        // Search in expanding rings around the current position
        let maxSearchRadius = max(maxRows, columns)
        
        for radius in 1...maxSearchRadius {
            // Check positions at this radius
            for dx in -radius...radius {
                for dy in -radius...radius {
                    // Only check positions at the current radius (on the perimeter)
                    if abs(dx) != radius && abs(dy) != radius { continue }
                    
                    let newCol = currentPos.col + dx
                    let newRow = currentPos.row + dy
                    
                    // Check bounds
                    if newCol < 0 || newRow < 0 || 
                       newCol + buttonWidth > columns || 
                       newRow + buttonHeight > maxRows {
                        continue
                    }
                    
                    let candidateRect = GridRect(col: newCol, row: newRow, width: buttonWidth, height: buttonHeight)
                    
                    // Check if this position avoids the shadow and doesn't overlap with other buttons
                    if !rectsOverlap(candidateRect, draggedButtonShadow) && 
                       !hasOverlapExcluding(candidateRect, excluding: [button.id]) {
                        return GridPosition(col: newCol, row: newRow)
                    }
                }
            }
        }
        
        return nil // No available position found
    }

    // Check if a specific grid cell is occupied by any button (excluding currently dragged button)
    private func isCellOccupied(col: Int, row: Int) -> Bool {
        // Only check buttons on the current page
        let pageButtons = buttons.filter { $0.page == currentPage }
        for button in pageButtons {
            // Skip the button that's currently being dragged
            if let draggedButton = dragging, draggedButton.id == button.id {
                continue
            }

            guard let buttonCol = button.gridCol, let buttonRow = button.gridRow else { continue }

            // Get button dimensions
            let buttonWidth = button.gridWidth
            let buttonHeight = button.gridHeight
            
            // Check if the cell (col, row) is within the button's area
            if col >= buttonCol && col < buttonCol + buttonWidth &&
               row >= buttonRow && row < buttonRow + buttonHeight {
                return true
            }
        }
        return false
    }

    // Count rows using a dynamic packing heuristic matching layout
    private func occupiedRows(columns: Int) -> Int {
        // Only count rows for buttons on the current page
        let pageButtons = buttons.filter { $0.page == currentPage }
        guard !pageButtons.isEmpty else { return 1 }

        var occupancy: [[Bool]] = []
        func ensureRows(_ r: Int) {
            while occupancy.count <= r { occupancy.append(Array(repeating: false, count: columns)) }
        }

        func fits(_ r: Int, _ c: Int, _ w: Int, _ h: Int) -> Bool {
            ensureRows(r + h)
            if c + w > columns { return false }
            for rr in r..<(r+h) { for cc in c..<(c+w) { if occupancy[rr][cc] { return false } } }
            return true
        }

        func mark(_ r: Int, _ c: Int, _ w: Int, _ h: Int) {
            ensureRows(r + h)
            for rr in r..<(r+h) { for cc in c..<(c+w) { occupancy[rr][cc] = true } }
        }

        // First: place controls with explicit positions
        var explicitlyPlaced = Set<UUID>()
        for b in pageButtons {
            let w = b.gridWidth
            let h = b.gridHeight
            if let gridCol = b.gridCol, let gridRow = b.gridRow,
               gridCol >= 0, gridRow >= 0, fits(gridRow, gridCol, w, h) {
                mark(gridRow, gridCol, w, h)
                explicitlyPlaced.insert(b.id)
            }
        }
        
        // Then: place remaining controls with auto-packing
        for b in pageButtons where !explicitlyPlaced.contains(b.id) {
            let w = b.gridWidth
            let h = b.gridHeight
            var placed = false
            var r = 0
            while !placed {
                for c in 0..<columns {
                    if fits(r, c, w, h) {
                        mark(r, c, w, h)
                        placed = true
                        break
                    }
                }
                if !placed { r += 1 }
            }
        }
        
        var lastUsed = 0
        for (i, row) in occupancy.enumerated() { 
            if row.contains(true) { lastUsed = i + 1 } 
        }
        return max(1, lastUsed)
    }
    
    // Compute packed rows consistent with non-edit portrait packed layout
    private func packedVisualRows() -> Int {
        let positions = computePackedPositions(for: buttons)
        var maxRow = 0
        for b in buttons {
            let pos = positions[b.id]
            let row = pos?.row ?? (b.gridRow ?? 0)
            let height = b.gridHeight
            maxRow = max(maxRow, row + height)
        }
        return max(1, maxRow)
    }
    
    // Helper function to build individual control tile (extracted from ForEach for type-checking performance)
    @ViewBuilder
    private func buildControlTileView(button: ControlButton, cellSize: CGFloat, columnSpacing: CGFloat, rowSpacing: CGFloat, conflictFor: [MIDIKey: String], midiFilter: Set<Int>, isEditing: Bool, maxRows: Int, usbServer: ConnectionManager, wifiClient: BridgeOutput, connectionCoordinator: ConnectionCoordinator, controlButtons: Binding<[ControlButton]>, markDirty: @escaping () -> Void) -> some View {
        // Calculate button size
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        let totalWidth = CGFloat(button.gridWidth) * cellSize + CGFloat(max(0, button.gridWidth - 1)) * columnSpacing
        let totalHeight = CGFloat(button.gridHeight) * cellSize + CGFloat(max(0, button.gridHeight - 1)) * rowSpacing
        // iPhone: buttons fill the full grid space (spacing creates gaps)
        let width = totalWidth
        let height = totalHeight

        let pos: (col: Int, row: Int) = effectivePosition(for: button, dragging: dragging, preview: previewLocation, columns: columns)
                // iPhone: no offset needed since buttons fill the full space
                let xBase = CGFloat(pos.col) * (cellSize + columnSpacing)
                let yBase = CGFloat(pos.row) * (cellSize + rowSpacing)
                let x = xBase
                let y = yBase

        // DEBUG: Log tile positioning for iPhone
        let _ = isPhone ? debugPrint("📱 [Tile] '\(button.title)' cellSize=\(cellSize), pos=(\(pos.col),\(pos.row)), offset=(\(x),\(y)), size=(\(width)x\(height))") : ()

        let key = MIDIKey(kind: button.kind, channel: button.channel, number: button.number)
                let owner = conflictFor[key]

                // Filter out the current button from conflict list
                let typePrefix = (button.isFader == true) ? "Fader" : "Button"
                let buttonDisplayName = button.title.isEmpty ? typePrefix : "\(typePrefix): \(button.title)"
                let filteredOwner: String? = {
                    var warning: String? = nil

                    // Check for MIDI conflicts
                    if let ownerString = owner {
                        // If owner string contains multiple owners (separated by "|||")
                        if ownerString.contains("|||") {
                            let owners = ownerString.split(separator: "|||")
                                .map { $0.trimmingCharacters(in: .whitespaces) }
                                .filter { $0 != buttonDisplayName }
                            if !owners.isEmpty {
                                warning = owners.joined(separator: " and ")
                            }
                        } else {
                            // Single owner - check if it's this button
                            if ownerString.trimmingCharacters(in: .whitespaces) != buttonDisplayName {
                                warning = ownerString
                            }
                        }
                    }

                    // Check for filtered MIDI (only when filters are enabled)
                    if midiFiltersEnabled && !midiFilter.isEmpty && button.kind == .cc && midiFilter.contains(button.number) {
                        let filteredMsg = "Filtered CC"
                        if let existing = warning {
                            warning = "\(existing) • \(filteredMsg)"
                        } else {
                            warning = filteredMsg
                        }
                    }

                    return warning
                }()

                iPadControlTile(
                    button: button,
                    takenBy: filteredOwner,
                    isEditing: isEditing,
                    isDragging: dragging?.id == button.id,
                    defaultCueColor: defaultCueColor,
                    showMIDIData: showMIDIData,
                    onTap: { onTap(button) },
                    onEdit: {
                        // Look up the current button by ID to avoid stale closure captures after drag reorder
                        let current = controlButtons.wrappedValue.first(where: { $0.id == button.id }) ?? button
                        onEditButton(current)
                    },
                    onDelete: { onDelete(button) },
                    onDrag: {
                        // Keep the old system for compatibility, but we'll add smooth gesture on top
                        guard isEditing else { return NSItemProvider() }
                        return NSItemProvider(object: button.id.uuidString as NSString)
                    },
                    onFaderMIDI: { channel, cc, value, title, buttonID in
                        // Store the fader value in the ControlButton model for persistence
                        if let index = controlButtons.wrappedValue.firstIndex(where: { $0.id == buttonID }) {
                            let faderValue = Double(value) / 127.0
                            controlButtons.wrappedValue[index].faderValue = faderValue
                            markDirty() // Mark project as dirty to save the fader value
                            debugPrint("🎚️ onFaderMIDI: Stored fader value \(faderValue) for \"\(title)\"")
                        }

                        // Use ConnectionCoordinator to send MIDI through the active connection
                        connectionCoordinator.sendMIDI(type: .cc, channel: channel, number: cc, value: value, label: title, buttonID: buttonID.uuidString)
                    }
                )
                .id(button.id)
                .frame(width: width, height: height)
                .offset(
                    x: x + (dragging?.id == button.id ? dragTranslation.width : 0),
                    y: y + (dragging?.id == button.id ? dragTranslation.height : 0)
                )
                .scaleEffect((dragging?.id == button.id && !isPhone) ? 1.1 : 1.0) // iPad only: scale during drag
                // Enable smooth spring animations for buttons moving out of the way (iPhone-like)
                .animation(
                    dragging?.id == button.id ? nil : .spring(response: 0.35, dampingFraction: 0.75),
                    value: x
                )
                .animation(
                    dragging?.id == button.id ? nil : .spring(response: 0.35, dampingFraction: 0.75),
                    value: y
                )
                .animation(.easeInOut(duration: 0.15), value: dragging?.id == button.id) // Smooth scale animation
                .allowsHitTesting(true)
                .simultaneousGesture(
                    isEditing ?
                    DragGesture(minimumDistance: 10, coordinateSpace: .global)
                        .onChanged { value in
                            if dragging?.id != button.id {
                                // Start iOS-style drag
                                isDragOperation = true
                        dragging = button
                        dropSurfaceElevated = true
                                dragStartLocation = value.startLocation
                                previewLocation = nil
                            }
                            
                            if dragging?.id == button.id {
                                // Follow finger exactly - no constraints or modifications
                                let dx = value.translation.width
                                let dy = value.translation.height
                                
                                // Update dragged device position - this should follow finger exactly
                                var transaction = Transaction()
                                transaction.disablesAnimations = true
                                withTransaction(transaction) {
                                    dragTranslation = CGSize(width: dx, height: dy)
                                }
                                
                                // Calculate shadow position independently - this snaps to grid
                                let currentCol = button.gridCol ?? 0
                                let currentRow = button.gridRow ?? 0

                                let targetWidth = button.gridWidth
                                let targetHeight = button.gridHeight
                                
                                // Calculate target grid position based on drag distance
                                let cellsMovedX = Int((dx / (cellSize + columnSpacing)).rounded())
                                let cellsMovedY = Int((dy / (cellSize + rowSpacing)).rounded())
                                
                                // Calculate target position
                                let targetCol = currentCol + cellsMovedX
                                let targetRow = currentRow + cellsMovedY
                                
                                // Clamp to valid grid boundaries
                                let shadowCol = max(0, min(targetCol, columns - targetWidth))
                                let shadowRow = max(0, min(targetRow, maxRows - targetHeight))
                                
                                // Always update preview location for live displacement preview
                                // This allows other buttons to move out of the way in real-time
                                let newShadowPos = GridPosition(col: shadowCol, row: shadowRow)
                                if previewLocation?.col != shadowCol || previewLocation?.row != shadowRow {
                                    previewLocation = newShadowPos
                                }
                                
                                // Store shadow offset separately - this is for visual shadow positioning only
                                shadowOffset = CGSize(width: dx, height: dy)

                                // Check for edge drag to switch pages
                                let dragX = value.location.x
                                let gridWidth = actualWidth
                                checkEdgeDrag(dragX: dragX, gridWidth: gridWidth)
                            }
                        }
                        .onEnded { value in
                            guard dragging?.id == button.id else { return }

                            // Cancel any pending edge drag timer
                            cancelEdgeDragTimer()

                            // Snap to grid position like iOS home screen
                            if let preview = previewLocation {
                                // Commit the dragged button's position
                                if let buttonIndex = buttons.firstIndex(where: { $0.id == button.id }) {
                                    buttons[buttonIndex].gridCol = preview.col
                                    buttons[buttonIndex].gridRow = preview.row
                                    lastDropTime = Date()
                                    debugPrint("✅ Drop successful at (\(preview.col), \(preview.row))")
                                }
                                
                                // Commit positions for all displaced buttons
                                self.commitDisplacedButtonPositions(draggedButton: button, targetPosition: preview)
                            }
                            
                            // Clear drag state after drop is processed
                            clearDragState(reason: "iOS-style drag completed")
                        }
                    : nil
                )
                .zIndex(1)
            }

    // Helper function to compute packed positions (moved outside ViewBuilder)
    private func computePackedPositions(for buttons: [ControlButton]) -> [UUID: (col: Int, row: Int)] {
        let isPortraitLike = verticalSizeClass != .compact
        guard !isEditing && isPortraitLike else { return [:] }
        
        var occupancy: [[Bool]] = []
        var packedPositions: [UUID: (col: Int, row: Int)] = [:]
        
        func ensureRows(_ r: Int) {
            while occupancy.count <= r { occupancy.append(Array(repeating: false, count: columns)) }
        }
        func fits(_ r: Int, _ c: Int, _ w: Int, _ h: Int) -> Bool {
            ensureRows(r + h)
            if c + w > columns { return false }
            for rr in r..<(r+h) { for cc in c..<(c+w) { if occupancy[rr][cc] { return false } } }
            return true
        }
        func mark(_ r: Int, _ c: Int, _ w: Int, _ h: Int) { for rr in r..<(r+h) { for cc in c..<(c+w) { occupancy[rr][cc] = true } } }
        
        for b in buttons {
            let w = b.gridWidth
            let h = b.gridHeight
            var placed = false
            var r = 0
            while !placed {
                ensureRows(r + h)
                for c in 0...(columns - w) {
                    if fits(r, c, w, h) {
                        mark(r, c, w, h)
                        packedPositions[b.id] = (c, r)
                        placed = true
                        break
                    }
                }
                if !placed { r += 1 }
            }
        }
        
        return packedPositions
    }
    
    // Helper to calculate grid parameters
    private func calculateGridParameters(proxy: GeometryProxy) -> (cellSize: CGFloat, displayRows: Int, gridHeight: CGFloat, gridWidth: CGFloat) {
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone

        var cellSize: CGFloat
        let displayRows: Int

        if isPhone {
            // iPhone: Use fixed cell size based on available height
            // This creates larger, easier-to-use controls that scroll horizontally
            // Always use 80% of landscape height (the shorter dimension) for consistency
            // Use cached value to avoid freeze from UIScreen.main.bounds access during layout
            let landscapeHeight = globalCachedPortraitWidth  // Already the shorter dimension
            let availableHeight = landscapeHeight * 0.8
            // Reserve space for header and grid padding
            let headerHeight: CGFloat = 68
            let gridVerticalPadding: CGFloat = 52  // 8pt top + 12pt bottom + scrollbar (28pt handle + 4pt bottom padding)
            let gridAreaHeight = availableHeight - headerHeight - gridVerticalPadding

            // Calculate cell size based on 4 rows (max) - NO MINIMUM, let it shrink to fit 80% height
            let maxRows = 4
            let verticalGaps = max(0, maxRows - 1)
            cellSize = floor((gridAreaHeight - CGFloat(verticalGaps) * rowSpacing) / CGFloat(maxRows))

            // iPhone: Dynamic rows like iPad - shrink to fit content, expand in edit mode
            if isEditing {
                displayRows = 4  // Full grid in edit mode
            } else {
                let visualRows = calculateVisualRows()
                displayRows = min(4, max(1, visualRows))  // At least 1 row, max 4
            }
        } else {
            // iPad: Calculate based on available width (original behavior)
            let totalSpacing = CGFloat(columns - 1) * columnSpacing
            let actualHorizontalPadding = gridPadding
            let availableWidth = proxy.size.width - (2 * actualHorizontalPadding) - totalSpacing
            cellSize = floor(availableWidth / CGFloat(columns))

            if isEditing {
                displayRows = 4
            } else {
                let visualRows = calculateVisualRows()
                displayRows = min(4, max(0, visualRows))
            }
        }

        let verticalGaps = max(0, displayRows - 1)
        let gridHeight = CGFloat(displayRows) * cellSize + CGFloat(verticalGaps) * rowSpacing
        let gridWidth = CGFloat(columns) * cellSize + CGFloat(max(0, columns - 1)) * columnSpacing

        return (cellSize: cellSize, displayRows: displayRows, gridHeight: gridHeight, gridWidth: gridWidth)
    }
    
    private func buildControlGrid(proxy: GeometryProxy, isCtrlEditing: Bool, sessionNonce: Int, usbServer: ConnectionManager, wifiClient: BridgeOutput, connectionCoordinator: ConnectionCoordinator) -> AnyView {
        let params = calculateGridParameters(proxy: proxy)
        let cellSize = params.cellSize
        let displayRows = params.displayRows
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone // Moved up for debug
        // let dropTypes: [UTType] = isCtrlEditing ? [UTType.text] : [] // Unused in new iOS-style drag system

        let maxRows = displayRows // Capture for use in gesture closures
        let pageButtons = buttons.filter { $0.page == currentPage }

        let tilesCore = ForEach(pageButtons) { button in
            buildControlTileView(
                button: button,
                cellSize: cellSize,
                columnSpacing: columnSpacing,
                rowSpacing: rowSpacing,
                conflictFor: conflictFor,
                midiFilter: midiFilter,
                isEditing: isCtrlEditing,
                maxRows: maxRows,
                usbServer: usbServer,
                wifiClient: wifiClient,
                connectionCoordinator: connectionCoordinator,
                controlButtons: $buttons,
                markDirty: markDirty
            )
        }
        let tiles: AnyView = AnyView(
            Group { tilesCore }
                .id("tiles-\(isCtrlEditing)")
        )

        let editOverlay: AnyView = {
            guard isCtrlEditing else { return AnyView(EmptyView()) }
            let overlayCells: [(Int, Int)] = (0..<displayRows).flatMap { row in
                (0..<columns).compactMap { col in
                    isCellOccupied(col: col, row: row) ? nil : (row, col)
                }
            }
            let overlay = ForEach(overlayCells.indices, id: \.self) { idx in
                let (row, col) = overlayCells[idx]
                        let x = CGFloat(col) * (cellSize + columnSpacing)
                        let y = CGFloat(row) * (cellSize + rowSpacing)
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .frame(width: cellSize, height: cellSize)
                            .offset(x: x, y: y)
                }
                .zIndex(0.5)
                .allowsHitTesting(false)
            return AnyView(overlay)
        }()

        let dragPreview: AnyView = {
            // iOS-style shadow: shows at TARGET grid position, not following finger
            guard let dragging = dragging, let preview = previewLocation else { return AnyView(EmptyView()) }
            let width = CGFloat(dragging.gridWidth) * cellSize + CGFloat(max(0, dragging.gridWidth - 1)) * columnSpacing
            let height = CGFloat(dragging.gridHeight) * cellSize + CGFloat(max(0, dragging.gridHeight - 1)) * rowSpacing
            
            // Simple shadow positioning - align exactly with grid cells
            let shadowX = CGFloat(preview.col) * (cellSize + columnSpacing)
            let shadowY = CGFloat(preview.row) * (cellSize + rowSpacing)
            
            // Choose shadow color based on whether displacement is valid
            let shadowColor = hasInvalidDisplacement ? Color.red : Color.blue

            // iPhone uses 6px corner radius, iPad uses 12px
            let cornerRadius: CGFloat = UIDevice.current.userInterfaceIdiom == .phone ? 6 : 12

            let previewView = ZStack {
                // Shadow effect (blue if valid, red if no space available)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(shadowColor.opacity(0.2))
                    .blur(radius: 8)
                    .scaleEffect(1.1)

                // Main preview shape
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(shadowColor.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(shadowColor, lineWidth: 3)
                    )
            }
                    .frame(width: width, height: height)
            .offset(x: shadowX, y: shadowY)
            .zIndex(2000)
                    .allowsHitTesting(false)
            .animation(nil, value: preview.col) // No animations to prevent grid movement
            .animation(nil, value: preview.row) // No animations to prevent grid movement
            return AnyView(previewView)
        }()
        
        let _ = iPadDropDelegate( // Unused in new iOS-style drag system
            columns: columns,
            columnSpacing: columnSpacing,
            rowSpacing: rowSpacing,
            cellSize: cellSize,
            displayRows: displayRows,
            buttons: $buttons,
            dragging: $dragging,
            previewLocation: $previewLocation,
            dropSurfaceElevated: $dropSurfaceElevated,
            isDragOperation: $isDragOperation,
            lastDropTime: $lastDropTime,
            isActive: isCtrlEditing,
            clearDragState: clearDragState
        )

        let gridContent = ZStack(alignment: .topLeading) {
            // Controls positioned with simple offset (Mac editor approach)
            tiles
                .allowsHitTesting(true)

            // Dotted grid overlay in edit mode (Mac editor approach)
            editOverlay

            // Blue drag shadow preview
            dragPreview
        }
        .frame(
            width: params.gridWidth,
            height: params.gridHeight,
            alignment: .topLeading
        )

        // iPhone: Clipped grid with draggable scrollbar (no ScrollView to avoid gesture conflicts with faders)
        // iPad: No scroll needed, grid fits within screen
        let content: AnyView
        let totalContentWidth = params.gridWidth + 2 * columnSpacing
        if isPhone {
            content = AnyView(
                VStack(spacing: 0) {
                    // Clipped viewport — GeometryReader provides the clip bounds
                    GeometryReader { viewportGeo in
                        gridContent
                            .padding(.horizontal, columnSpacing)
                            .padding(.top, 8)
                            .padding(.bottom, 12)
                            .offset(x: -controlScrollOffset)
                            .onAppear {
                                controlVisibleWidth = viewportGeo.size.width
                            }
                            .onChange(of: viewportGeo.size.width) { _, newWidth in
                                controlVisibleWidth = newWidth
                            }
                    }
                    .clipped()

                    // Draggable scrollbar
                    ControlAreaScrollbar(
                        contentWidth: totalContentWidth,
                        visibleWidth: controlVisibleWidth,
                        scrollOffset: $controlScrollOffset
                    )
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .id("ctrl-container-\(isCtrlEditing)-sess-\(sessionNonce)-page-\(currentPage)-\(pageButtons.count)")
                .allowsHitTesting(true)
                .onChange(of: sessionNonce) { _, _ in
                    clearDragState(reason: "gesture cancelled")
                }
                .onChange(of: currentPage) { _, _ in
                    // Reset scroll when switching pages
                    controlScrollOffset = 0
                }
            )
        } else {
            content = AnyView(
                gridContent
                    .id("ctrl-container-\(isCtrlEditing)-sess-\(sessionNonce)-page-\(currentPage)-\(pageButtons.count)")
                    .padding(EdgeInsets(
                        top: isCtrlEditing ? 20 : 8,
                        leading: gridPadding,
                        bottom: gridPadding,
                        trailing: gridPadding
                    ))
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .animation(.easeInOut(duration: 0.3), value: displayRows)
                    .allowsHitTesting(true)
                    .onChange(of: sessionNonce) { _, _ in
                        clearDragState(reason: "gesture cancelled")
                    }
            )
        }

        return content
}

private struct ControlButtonTile: View {
    let button: ControlButton
    let takenBy: String?
    let isEditing: Bool
    var onTap: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var down = false
    @State private var wiggle = false

    // Wobble state - now uses shared animator
    @ObservedObject private var wobbleAnimator = WobbleAnimator.shared
    @State private var wobbleID = UUID()

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    // iPhone/compact mode detection
    private var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    var body: some View {
        let isToggle = button.isToggle ?? false

        // Determine if button should show as "on" (pressed/active)
        // iPad toggle buttons: only use toggleState (no flash on press)
        // Regular buttons or iPhone: use down state for press effect
        let isOn = (isToggle && !isPhone) ? button.toggleState : (isToggle ? button.toggleState : down)

        // Accent color (same for both modes)
        let accentColor: Color = {
            if let colorHex = button.colorHex {
                return Color(hex: colorHex)
            } else if !customDefaultCueColorStorage.isEmpty {
                return Color(hex: customDefaultCueColorStorage)
            } else {
                return selectedTheme.defaultCueColor(for: colorScheme)
            }
        }()

        // Filled tile background — always accent color
        let buttonColor: Color = isOn ? accentColor : accentColor.opacity(0.9)

        // Adaptive text color based on tile background brightness
        let textColor: Color = accentColor.needsDarkText() ? .black : .white

        ZStack {
            Button {
                    if isEditing { onEdit() } else { onTap() }
            } label: {
                VStack(spacing: 4) {
                        Spacer(minLength: 0)

                        if button.symbol.isEmpty {
                            // No icon: show title only
                            Text(button.title)
                                .font(.custom("Sora-Bold", size: isPhone ? 11 : 12))
                        } else if button.title.trimmingCharacters(in: .whitespaces).isEmpty {
                            // Icon-only mode: center the icon without title or MIDI label
                            Image(systemName: button.symbol)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(textColor)
                        } else {
                            // Icon + title mode: show all elements
                            Image(systemName: button.symbol)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(textColor)
                            Text(button.title)
                                .font(.custom("Sora-Bold", size: 12))
                                .lineLimit(1)
                            Text(midiLabel())
                                .font(.custom("Sora-Regular", size: 9))
                                .foregroundColor(textColor.opacity(0.5))
                        }

                        Spacer(minLength: 0)
                }
                .foregroundColor(textColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(buttonColor)
                )
                    .overlay(alignment: .topLeading) {
                    if isEditing {
                        Button(action: onDelete) {
                                ZStack {
                                    Circle()
                                        .fill(Color.gray.opacity(0.9))
                                        .frame(width: isPhone ? 20 : 30, height: isPhone ? 20 : 30)
                                    Image(systemName: "xmark")
                                        .font(.system(size: isPhone ? 10 : 13, weight: .bold))
                                        .foregroundColor(Color(uiColor: .systemBackground))
                                }
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .frame(width: isPhone ? 44 : 70, height: isPhone ? 44 : 70)
                            .offset(x: isPhone ? -10 : -32, y: isPhone ? -10 : -32)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(takenBy != nil && !isEditing)
            .opacity(1.0)
            .modifier(PressEffectWhenNotEditing(isEditing: isEditing, onChange: { down = true }, onEnd: { down = false }))
            .scaleEffect((down && !isEditing && !isPhone) ? 0.97 : 1.0)  // iPhone: no scale effect
            .animation(isPhone ? nil : .spring(response: 0.18, dampingFraction: 0.8), value: down)  // iPhone: no animation
            .modifier(TimeBasedWobbleModifier(wobbleID: wobbleID, wobbleAnimator: wobbleAnimator))
                .onChange(of: isEditing) { _, editing in
                    if editing { startWobble() } else { stopWobble(); down = false }
            }
            .onDisappear { stopWobble() }
        }
    }

    private func midiLabel() -> String {
        switch button.kind {
        case .cc:   return "\(button.channel)•\(button.number)"
        case .note: return "\(button.channel)•\(button.number)•\(button.velocity)"
        }
    }

    // MARK: - iPhone-style wobble implementation (using shared animator)
    private func startWobble() {
        guard isEditing else { return }

        var rng = SeededRandom(seed: button.id.uuidString.hashValue)
        let amplitude = 0.5 + Double(rng.nextNormalized()) * 0.3
        let scaleDelta = 0.001 + Double(rng.nextNormalized()) * 0.0005
        wobbleAnimator.startWobbling(for: wobbleID, amplitude: amplitude, scaleDelta: scaleDelta)
    }

    private func stopWobble() {
        wobbleAnimator.stopWobbling(for: wobbleID)
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
    
    // Edit grid overlay made of dotted squares the size of half a button
    private struct CBGridOverlay: View {
        let columns: Int
        let rows: Int
        let columnSpacing: CGFloat = 12
        let rowSpacing: CGFloat = 10
        
        var body: some View {
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let colCount = max(1, columns)
                let rowCount = max(1, rows)
                let totalColSpacing = columnSpacing * CGFloat(max(0, colCount - 1))
                // Base cells: each base cell is one column. Button spans 2 base cells (rectangular).
                let cellWidth = (totalWidth - totalColSpacing) / CGFloat(colCount)
                let cellHeight = cellWidth // squares
                let dashed = StrokeStyle(lineWidth: 1, dash: [4, 4])
                let color = Color.secondary.opacity(0.5)
                ZStack {
                    ForEach(0..<rowCount, id: \.self) { r in
                        ForEach(0..<colCount, id: \.self) { c in
                            let x = CGFloat(c) * (cellWidth + columnSpacing)
                            let y = CGFloat(r) * (cellHeight + rowSpacing)
                            let rect = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
                            RoundedRectangle(cornerRadius: 10)
                                .inset(by: 4)
                                .stroke(style: dashed)
                                .foregroundColor(color)
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                        }
                    }
                }
            }
        }
    }
    
    // (moved earlier above CBControlSection)

    // SNAKE: Fader control tile (two rows tall, half width)
    private struct ControlFaderTile: View {
        let button: ControlButton
        let takenBy: String?
        let isEditing: Bool
        var onTap: () -> Void
        var onEdit: () -> Void
        var onDelete: () -> Void

        // 0.0..1.0 mapped to CC 0..127, rest at 84
        @State private var value: Double = Double(84) / 127.0
        @State private var wiggle = false

        // Wobble state - now uses shared animator
        @ObservedObject private var wobbleAnimator = WobbleAnimator.shared
        @State private var wobbleID = UUID()

        @Environment(\.colorScheme) private var colorScheme
        @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
        @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""

        private var selectedTheme: AppTheme {
            AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
        }

        // iPhone/compact mode detection
        private var isPhone: Bool {
            UIDevice.current.userInterfaceIdiom == .phone
        }

        var body: some View {
            let isHorizontal = (button.faderOrientation == "horizontal")
            let direction = button.faderDirection ?? (isHorizontal ? "right" : "up")

            // Use custom color if button has colorHex, otherwise use custom accent color if set, otherwise use theme default
            let faderColor: Color = {
                if let colorHex = button.colorHex {
                    return Color(hex: colorHex)
                } else if !customDefaultCueColorStorage.isEmpty {
                    return Color(hex: customDefaultCueColorStorage)
                } else {
                    return selectedTheme.defaultCueColor(for: colorScheme)
                }
            }()
            ZStack(alignment: .topTrailing) {
                // Fill entire available space - 1x2 for vertical, 2x1 for horizontal
                GeometryReader { geo in
                    if isHorizontal {
                        // HORIZONTAL FADER
                        let headWidth: CGFloat = 20
                        let w = max(0, geo.size.width - headWidth)
                        // shouldReverse is only used for input mapping in gesture, not for visual rendering
                        let shouldReverse = (direction == "left")
                        // Fill alignment: "right" fills from left, "left" fills from right
                        // The alignment handles the directional flip, so we use the same value for both
                        let fillAlignment: Alignment = (direction == "right") ? .leading : .trailing

                        ZStack(alignment: fillAlignment) {
                            // Main fader track background - filled style with 8pt corners
                            RoundedRectangle(cornerRadius: 8)
                                .fill(faderColor.opacity(0.2))

                            // Fader fill (dynamic based on value) - alignment handles the direction
                            RoundedRectangle(cornerRadius: 8)
                                .fill(faderColor.opacity(0.85))
                                .frame(width: w * value)
                                .padding(3)

                            // Fader head (dynamic position) - conditional offset for direction
                            RoundedRectangle(cornerRadius: 6)
                                .fill(faderColor)
                                .frame(width: headWidth)
                                .offset(x: (direction == "right") ? (w * value) : -(w * value))
                                .padding(.vertical, 6)

                            // Text overlay inside fader at left
                            // Adaptive text color: switches based on whether fader fill covers the text
                            // Text is left-aligned, so for "right" direction fill covers it early, for "left" late
                            HStack(spacing: 2) {
                                let filledTextColor: Color = faderColor.needsDarkText() ? .black : .white
                                let emptyTextColor: Color = .white  // Dark mode background
                                let textOnFill = (direction == "right") ? value > 0.1 : value > 0.85
                                let faderTextColor = textOnFill ? filledTextColor : emptyTextColor
                                Text(button.title)
                                    .font(.custom("Sora-Bold", size: 11))
                                    .lineLimit(1)
                                    .foregroundColor(faderTextColor)
                                    .minimumScaleFactor(0.7)
                                Text("CC\(button.number)")
                                    .font(.custom("Sora-Regular", size: 9))
                                    .foregroundColor(faderTextColor.opacity(0.5))
                                Text("Ch\(button.channel)")
                                    .font(.custom("Sora-Regular", size: 9))
                                    .foregroundColor(faderTextColor.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .padding(.leading, 6)
                            .allowsHitTesting(false)

                            // Full-track gesture: tap/drag anywhere
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { g in
                                            guard !isEditing else { return }
                                            let localX = g.location.x
                                            let clamped = max(headWidth / 2, min(w - headWidth / 2, localX))
                                            var normalized = Double((clamped - headWidth / 2) / (w - headWidth))
                                            // Reverse input if direction is "left"
                                            if shouldReverse {
                                                normalized = 1.0 - normalized
                                            }
                                            value = max(0, min(1, normalized))
                                            sendCC()
                                        }
                                        .onEnded { _ in if !isEditing { sendCC() } }
                                )
                        }
                    } else {
                        // VERTICAL FADER
                        let headHeight: CGFloat = 20
                        let h = max(0, geo.size.height - headHeight)
                        // shouldReverse is only used for input mapping in gesture, not for visual rendering
                        let shouldReverse = (direction == "down")
                        // Fill alignment: "up" fills from bottom, "down" fills from top
                        // The alignment handles the directional flip, so we use the same value for both
                        let fillAlignment: Alignment = (direction == "up") ? .bottom : .top

                        ZStack(alignment: fillAlignment) {
                            // Main fader track background - filled style with 8pt corners
                            RoundedRectangle(cornerRadius: 8)
                                .fill(faderColor.opacity(0.2))

                            // Fader fill (dynamic based on value) - alignment handles the direction
                            RoundedRectangle(cornerRadius: 8)
                                .fill(faderColor.opacity(0.85))
                                .frame(height: h * value)
                                .padding(3)

                            // Fader head (dynamic position) - conditional offset for direction
                            RoundedRectangle(cornerRadius: 6)
                                .fill(faderColor)
                                .frame(height: headHeight)
                                .offset(y: (direction == "up") ? -(h * value) : (h * value))
                                .padding(.horizontal, 6)

                            // Text overlay inside fader at top
                            // Adaptive text color: for "up" direction title at top needs high fill, for "down" title covered early
                            VStack(spacing: 2) {
                                let filledTextColor: Color = faderColor.needsDarkText() ? .black : .white
                                let emptyTextColor: Color = .white  // Dark mode background
                                let titleOnFill = (direction == "up") ? value > 0.75 : value > 0.15
                                let midiOnFill = (direction == "up") ? value > 0.15 : value > 0.75
                                Text(button.title)
                                    .font(.custom("Sora-Bold", size: 11))
                                    .lineLimit(1)
                                    .foregroundColor(titleOnFill ? filledTextColor : emptyTextColor)
                                    .minimumScaleFactor(0.7)
                                Text("CC\(button.number)")
                                    .font(.custom("Sora-Regular", size: 9))
                                    .foregroundColor((midiOnFill ? filledTextColor : emptyTextColor).opacity(0.5))
                                Text("Ch\(button.channel)")
                                    .font(.custom("Sora-Regular", size: 9))
                                    .foregroundColor((midiOnFill ? filledTextColor : emptyTextColor).opacity(0.5))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .padding(.top, 6)
                            .allowsHitTesting(false)

                            // Full-track gesture: tap/drag anywhere
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { g in
                                            guard !isEditing else { return }
                                            let localY = g.location.y
                                            let clamped = max(headHeight / 2, min(h - headHeight / 2, h - localY))
                                            var normalized = Double((clamped - headHeight / 2) / (h - headHeight))
                                            // Reverse input if direction is "down"
                                            if shouldReverse {
                                                normalized = 1.0 - normalized
                                            }
                                            value = max(0, min(1, normalized))
                                            sendCC()
                                        }
                                        .onEnded { _ in if !isEditing { sendCC() } }
                                )
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // FIX: Removed padding to make faders fill grid cells like buttons
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.clear)
                )
                if isEditing {
                    Button(action: onDelete) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.9))
                                .frame(width: 30, height: 30)
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(uiColor: .systemBackground))
                        }
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .frame(width: 70, height: 70)
                    .offset(x: -32, y: -32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .opacity(1.0)
            .disabled(takenBy != nil && !isEditing)
            // FIX: Removed .onTapGesture to eliminate delay - edit by tapping delete button instead
            // The onTapGesture was causing ~300ms delay because SwiftUI waits to disambiguate tap vs drag
            .modifier(TimeBasedWobbleModifier(wobbleID: wobbleID, wobbleAnimator: wobbleAnimator))
            .onChange(of: isEditing) { _, editing in
                if editing { startWobble() } else { stopWobble() }
            }
            .onAppear {
                // Initialize fader value from stored value in ControlButton model
                if let storedValue = button.faderValue {
                    value = storedValue
                    debugPrint("🎚️ ControlFaderTile: Initialized fader \"\(button.title)\" with stored value: \(storedValue)")
                } else {
                    // Use default value for new faders
                    let defaultValue = Double(84) / 127.0
                    value = defaultValue
                    debugPrint("🎚️ ControlFaderTile: Initialized fader \"\(button.title)\" with default value: \(defaultValue)")
                }

                if isEditing { startWobble() }
            }
            .onDisappear {
                stopWobble()
            }
        }
        
        // MARK: - iPhone-style wobble implementation (using shared animator)
        private func startWobble() {
            guard isEditing else { return }

            var rng = SeededRandom(seed: button.id.uuidString.hashValue)
            let amplitude = 0.5 + Double(rng.nextNormalized()) * 0.3
            let scaleDelta = 0.001 + Double(rng.nextNormalized()) * 0.0005
            wobbleAnimator.startWobbling(for: wobbleID, amplitude: amplitude, scaleDelta: scaleDelta)
        }

        private func stopWobble() {
            wobbleAnimator.stopWobbling(for: wobbleID)
        }
        
        private func sendCC() {
            let intVal = Int(round(value * 127))
            // Simple post via Notification; parent view already routes via triggerControl for buttons.
            // For faders, emit a custom notification so parent can listen and forward.
            NotificationCenter.default.post(name: Notification.Name("cbFaderChanged"),
                                            object: nil,
                                            userInfo: ["id": button.id, "channel": button.channel, "cc": button.number, "value": intVal, "title": button.title])
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
    
// MARK: - Performance List moved to ControlSubviews.swift

// MARK: - Performance Row moved to ControlSubviews.swift

// MARK: - Editor: Setlist column
// MARK: - CBSetlistColumn moved to ControlSubviews.swift

// MARK: - Editor: Library column
// MARK: - CBLibraryColumn moved to ControlSubviews.swift

// MARK: - CBRowLikeLibrary moved to ControlSubviews.swift

// MARK: - Full-width batch toolbar
// MARK: - CBBatchToolbar moved to ControlSubviews.swift

// MARK: - Connections Sheet (unchanged)
// MARK: - CBConnectionsSheet moved to ControlSubviews.swift

// MARK: - Projects Sheet (unchanged core)
// MARK: - CBProjectsSheet moved to ControlSubviews.swift
private struct CBProjectsSheet_Placeholder: View {
    @Binding var projectName: String
    let projects: [String]
    @Binding var isDirty: Bool

    var onRefreshList: () -> Void
    var onTapTitleWhenUnsaved: () -> Void
    var onSave: () -> Void
    var onSaveAs: (String) -> Void
    var onNew: () -> Void
    var onLoad: (String) -> Void
    var onDelete: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete: String? = nil
    @State private var tempSaveAs: String = ""

    var body: some View { EmptyView() }
}

// MARK: - Add/Edit sheet (legacy CC-only; kept for name/cc/channel edits)
// MARK: - CBAddEditCueSheet moved to ControlSubviews.swift
private struct CBAddEditCueSheet_Placeholder: View {
    @Binding var editingSong: Song?
    let usedCCs: Set<Int>
    var onSave: (Song) -> Void
    var onCancel: () -> Void

    @State private var name: String = ""
    @State private var subtitle: String = ""
    @State private var ccText: String = ""
    @State private var channelText: String = "1"
    @State private var error: String? = nil

    var body: some View { EmptyView() }

    private func preset() {
        if let s = editingSong {
            name = s.name
            subtitle = s.subtitle ?? ""
            ccText = String(s.cc)
            channelText = String(s.channel)
        } else {
            name = ""
            subtitle = ""
            ccText = nextAvailableCC()
            channelText = "1"
        }
    }

    private func nextAvailableCC() -> String {
        for n in 1...127 where !usedCCs.contains(n) { return String(n) }
        return "1"
    }

    private func save() {
        error = nil
        guard let cc = Int(ccText), (0...127).contains(cc) else { error = "CC must be 0–127"; return }
        if let editing = editingSong, editing.cc == cc {
            // ok
        } else if usedCCs.contains(cc) {
            error = "That CC is already used"; return
        }
        guard let ch = Int(channelText), (1...16).contains(ch) else { error = "Channel must be 1–16"; return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { error = "Name required"; return }

        var song = editingSong ?? Song(name: trimmed, subtitle: subtitle.isEmpty ? nil : subtitle, cc: cc, channel: ch)
        song.name = trimmed
        song.subtitle = subtitle.isEmpty ? nil : subtitle
        song.cc = cc
        song.channel = ch
        onSave(song)
    }
}

// MARK: - MIDI Picker (shared by Song & Control button)
// MARK: - CBMIDIPickerSheet moved to ControlSubviews.swift
private struct CBMIDIPickerSheet_Placeholder: View {
    let title: String
    @State var kind: MIDIKind
    @State var number: Int
    @State var channel: Int
    @State var velocity: Int
    let conflictFor: [MIDIKey: String]
    var currentOwnerName: (MIDIKey) -> String?
    var onSave: (MIDIKind, Int, Int, Int) -> Void
    var onCancel: () -> Void

    var body: some View { EmptyView() }

    private func conflictOwner() -> String? {
        let key = MIDIKey(kind: kind, channel: channel, number: number)
        return conflictFor[key]
    }
}

// MARK: - Control Button Preview (used in editor)
// MARK: - ControlButtonPreview moved to ControlSubviews.swift
private struct ControlButtonPreview_Placeholder: View {
    let title: String
    let symbol: String
    let kind: MIDIKind
    let number: Int
    let channel: Int
    let velocity: Int

    var body: some View { EmptyView() }
}

    // Preview for fader in the editor
    // MARK: - ControlFaderPreview moved to ControlSubviews.swift
    private struct ControlFaderPreview_Placeholder: View {
        let title: String
        let cc: Int
        let channel: Int
        
        var body: some View { EmptyView() }
    }
    
    private struct CBGridDropSurface: View {
        let width: CGFloat
        let height: CGFloat
        let columns: Int
        let columnSpacing: CGFloat
        let rowSpacing: CGFloat
        let cellSize: CGFloat
        @Binding var buttons: [ControlButton]
        @Binding var dragging: ControlButton?
        @Binding var previewLocation: GridPosition?
        let isActive: Bool
        
        var body: some View {
                        Rectangle()
                .fill(Color.clear)
                .frame(width: width, height: height)
                // .onDrop(of: [UTType.text], delegate: CBGridDropSurfaceDelegate( // Disabled for iOS-style drag
                //     columns: columns,
                //     columnSpacing: columnSpacing,
                //     rowSpacing: rowSpacing,
                //     cellSize: cellSize,
                //     buttons: $buttons,
                //     dragging: $dragging,
                //     previewLocation: $previewLocation,
                //     isActive: isActive
                // ))
                .allowsHitTesting(isActive)
        }
    }
    
    private struct CBDragPreview: View {
        let dragItem: ControlButton
        let previewLocation: (col: Int, row: Int)
        let columnSpacing: CGFloat
        let rowSpacing: CGFloat
        let cellSize: CGFloat
        
        var body: some View {
            let width = CGFloat(dragItem.gridWidth) * cellSize + CGFloat(dragItem.gridWidth - 1) * columnSpacing
            let height = CGFloat(dragItem.gridHeight) * cellSize + CGFloat(dragItem.gridHeight - 1) * rowSpacing
            let x = CGFloat(previewLocation.col) * (cellSize + columnSpacing)
            let y = CGFloat(previewLocation.row) * (cellSize + rowSpacing)
            
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accentColor.opacity(0.3))
                .stroke(Color.accentColor, lineWidth: 2)
                .frame(width: width, height: height)
                .position(x: x + width/2, y: y + height/2)
                .allowsHitTesting(false)
        }
    }
    

    private struct CBGridDropSurfaceDelegate: DropDelegate {
        let columns: Int
        let columnSpacing: CGFloat
        let rowSpacing: CGFloat
        let cellSize: CGFloat
        @Binding var buttons: [ControlButton]
        @Binding var dragging: ControlButton?
        @Binding var previewLocation: GridPosition?
        let isActive: Bool
        
        func validateDrop(info: DropInfo) -> Bool {
            // Always return true to prevent 🚫 icon
            return true
        }
        
        func dropEntered(info: DropInfo) {
            guard isActive, dragging != nil else { 
                debugPrint("🔴 dropEntered: not active or no dragging")
                return 
            }
            updatePreview(info: info)
        }
        
        func dropUpdated(info: DropInfo) -> DropProposal? {
            // Continuously update preview as pointer moves
            updatePreview(info: info)
            return DropProposal(operation: .move)
        }
        
        func dropExited(info: DropInfo) {
            previewLocation = nil
        }
        
        private func updatePreview(info: DropInfo) {
            guard let dragging = dragging else { return }
            let p = info.location
            let col = max(0, Int((p.x / (cellSize + columnSpacing)).rounded(.down)))
            let row = max(0, Int((p.y / (cellSize + rowSpacing)).rounded(.down)))
            let targetWidth = dragging.gridWidth
            let fits = col + targetWidth <= columns
            previewLocation = fits ? GridPosition(col: col, row: row) : nil
        }
        
        func performDrop(info: DropInfo) -> Bool {
            guard isActive, let dragging = dragging else { 
                debugPrint("🔴 performDrop failed: active=\(isActive), dragging=\(dragging?.title ?? "nil")")
                return false 
            }
            
            // Calculate drop position from pointer location
            let p = info.location
            let col = max(0, Int((p.x / (cellSize + columnSpacing)).rounded(.down)))
            let row = max(0, Int((p.y / (cellSize + rowSpacing)).rounded(.down)))
            
            debugPrint("✅ performDrop to (\(col),\(row)) for \(dragging.title) - using smart placement")
            
            // Use smart placement to handle overlaps
            let success = smartPlacement(
                item: dragging,
                targetCol: col,
                targetRow: row,
                items: &buttons
            )
            
            if success {
                debugPrint("✅ Smart placement successful for \(dragging.title)")
            } else {
                debugPrint("🔴 Smart placement failed for \(dragging.title)")
            }
            
            // Clear preview and dragging state immediately
            previewLocation = nil
            self.dragging = nil
            
            return success
        }
        
        // Smart placement logic with repositioning
        private func smartPlacement(
            item: ControlButton,
            targetCol: Int,
            targetRow: Int,
            items: inout [ControlButton]
        ) -> Bool {
            let itemWidth = item.gridWidth
            let itemHeight = item.gridHeight
            if !hasOverlap(col: targetCol, row: targetRow, width: itemWidth, height: itemHeight, items: items, excluding: item.id) {
                if let index = items.firstIndex(where: { $0.id == item.id }) {
                    items[index].gridCol = targetCol
                    items[index].gridRow = targetRow
            return true
        }
                return false
            }
            let overlapping = findOverlappingItems(
                col: targetCol, row: targetRow, width: itemWidth, height: itemHeight, 
                items: items, excluding: item.id
            )
            var repositionPlan: [(ControlButton, Int, Int)] = []
            for overlappingItem in overlapping {
                let newPos = findFreePosition(for: overlappingItem, items: items, excluding: [item.id] + overlapping.map { $0.id })
                if let (newCol, newRow) = newPos {
                    repositionPlan.append((overlappingItem, newCol, newRow))
                } else {
                    return false
                }
            }
            for (itemToMove, newCol, newRow) in repositionPlan {
                if let index = items.firstIndex(where: { $0.id == itemToMove.id }) {
                    items[index].gridCol = newCol
                    items[index].gridRow = newRow
                }
            }
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index].gridCol = targetCol
                items[index].gridRow = targetRow
                return true
            }
            return false
        }
        
        // Check for overlaps
        private func hasOverlap(col: Int, row: Int, width: Int, height: Int, items: [ControlButton], excluding excludeId: UUID) -> Bool {
            for item in items {
                guard item.id != excludeId,
                      let itemCol = item.gridCol,
                      let itemRow = item.gridRow else { continue }

                let itemWidth = item.gridWidth
                let itemHeight = item.gridHeight
                
                if rectsOverlap(
                    r1: (col, row, width, height),
                    r2: (itemCol, itemRow, itemWidth, itemHeight)
                ) {
                    return true
                }
            }
            return false
        }
        
        // Find overlapping items
        private func findOverlappingItems(col: Int, row: Int, width: Int, height: Int, items: [ControlButton], excluding excludeId: UUID) -> [ControlButton] {
            var overlapping: [ControlButton] = []
            
            for item in items {
                guard item.id != excludeId,
                      let itemCol = item.gridCol,
                      let itemRow = item.gridRow else { continue }

                let itemWidth = item.gridWidth
                let itemHeight = item.gridHeight
                
                if rectsOverlap(
                    r1: (col, row, width, height),
                    r2: (itemCol, itemRow, itemWidth, itemHeight)
                ) {
                    overlapping.append(item)
                }
            }
            return overlapping
        }
        
        // Find free position for an item
        private func findFreePosition(for item: ControlButton, items: [ControlButton], excluding excludeIds: [UUID]) -> (Int, Int)? {
            let itemWidth = item.gridWidth
            let itemHeight = item.gridHeight
            let maxCols = 8
            let maxRows = 4
            
            // Try positions in order of preference
            for row in 0..<maxRows {
                for col in 0..<maxCols {
                    if col + itemWidth <= maxCols && row + itemHeight <= maxRows {
                        var hasConflict = false
                        for otherItem in items {
                            guard !excludeIds.contains(otherItem.id),
                                  let otherCol = otherItem.gridCol,
                                  let otherRow = otherItem.gridRow else { continue }
                            
                            let otherWidth = otherItem.gridWidth
                            let otherHeight = otherItem.gridHeight
                            
                            if rectsOverlap(
                                r1: (col, row, itemWidth, itemHeight),
                                r2: (otherCol, otherRow, otherWidth, otherHeight)
                            ) {
                                hasConflict = true
                                break
                            }
                        }
                        if !hasConflict {
                            return (col, row)
                        }
                    }
                }
            }
            return nil
        }
        
        // Rectangle overlap check
        private func rectsOverlap(r1: (Int, Int, Int, Int), r2: (Int, Int, Int, Int)) -> Bool {
            let (x1, y1, w1, h1) = r1

            let (x2, y2, w2, h2) = r2
            return !(x1 + w1 <= x2 || x2 + w2 <= x1 || y1 + h1 <= y2 || y2 + h2 <= y1)
        }
    }
}

// MARK: - Helper struct for collision detection
private struct GridRect {
    let col: Int
    let row: Int
    let width: Int
    let height: Int
}

// MARK: - Conditional Drag Modifier
private struct ConditionalDragModifier: ViewModifier {
    let isEditing: Bool
    let onDrag: () -> NSItemProvider
    let buttonTitle: String

    func body(content: Content) -> some View {
        if isEditing {
            content.onDrag {
                debugPrint("🟢 ConditionalDragModifier: onDrag triggered for: \(buttonTitle)")
                let provider = onDrag()
                debugPrint("🟢 ConditionalDragModifier: NSItemProvider created")
                return provider
            }
        } else {
            content
        }
    }
}

// MARK: - Simple seeded RNG for per-tile wobble variety
private struct SeededRandom {
    private var state: UInt64

    init(seed: Int) {
        // Mix the signed seed into a 64-bit state
        let mixed = UInt64(bitPattern: Int64(seed)) ^ 0x9E3779B97F4A7C15
        state = mixed != 0 ? mixed : 0xA4093822299F31D0 // avoid zero state
    }

    // xorshift64*
    private mutating func nextRaw() -> UInt64 {
        var x = state
        x ^= x >> 12
        x ^= x << 25
        x ^= x >> 27
        state = x
        return x &* 2685821657736338717
    }

    mutating func nextNormalized() -> Double {
        let v = nextRaw()
        return Double(v) / Double(UInt64.max)
    }
}

// MARK: - Press effect gesture only when not editing (prevents conflicts with system drag)
// Also skips on iPhone to allow ScrollView horizontal scrolling
private struct PressEffectWhenNotEditing: ViewModifier {
    let isEditing: Bool
    let onChange: () -> Void
    let onEnd: () -> Void

    private var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    func body(content: Content) -> some View {
        // Skip on iPhone to allow ScrollView scrolling, skip when editing for system drag
        if isEditing || isPhone {
            content
        } else {
            content.simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onChange() }
                    .onEnded { _ in onEnd() }
            )
        }
    }
}

// MARK: - iPad Control Tile (adapted from Mac editor)
private struct iPadControlTile: View {
    let button: ControlButton
    let takenBy: String?
    let isEditing: Bool
    let isDragging: Bool
    let defaultCueColor: Color  // Theme default cue color
    let showMIDIData: Bool  // Toggle for showing MIDI data
    var onTap: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onDrag: () -> NSItemProvider
    var onFaderMIDI: (Int, Int, Int, String, UUID) -> Void
    
    @State private var isPressed = false
    @State private var isTouching = false // Track touch state for instant feedback
    @State private var faderValue: Double = 0.66 // 0.0 to 1.0
    @State private var faderVisualValue: Double = 0.66
    @State private var lastSentValue: Double = 0.0 // Track last MIDI value sent
    // FIX #7: Replace Date() timing with frame counter for better performance
    @State private var frameCounter: Int = 0
    @State private var firedThisPress: Bool = false
    // FIX #1: Track notification subscription to prevent memory leak
    @State private var faderUpdateCancellable: AnyCancellable? = nil

    // Wobble state - now uses shared animator
    @ObservedObject private var wobbleAnimator = WobbleAnimator.shared
    @State private var wobbleID = UUID()

    // Theme access
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    // iPhone/compact mode detection
    private var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    // MARK: - iPhone-style wobble implementation (using shared animator)
    private func startWobble() {
        guard isEditing else { return }

        var rng = SeededRandom(seed: button.id.uuidString.hashValue)
        let amplitude = 0.8 + Double(rng.nextNormalized()) * 0.4
        let scaleDelta = 0.002 + Double(rng.nextNormalized()) * 0.001
        wobbleAnimator.startWobbling(for: wobbleID, amplitude: amplitude, scaleDelta: scaleDelta)
    }

    private func stopWobble() {
        wobbleAnimator.stopWobbling(for: wobbleID)
    }
    
    var body: some View {
        ZStack {
            if button.isFader == true {
                if isEditing {
                    // v1.0.8: In edit mode, wrap with tap gesture to open edit sheet
                    ZStack {
                        FaderTileContent()
                            .contentShape(Rectangle())
                    }
                    .onTapGesture { onEdit() }
                } else {
                    // In play mode, render normally with drag gestures
                    FaderTileContent()
                }
            } else {
                if isEditing {
                    // In edit mode, render as plain content to prioritize drag
                    ZStack {
                ButtonTileContent()
                            .contentShape(Rectangle())
                    }
                    .onTapGesture { onEdit() }
                } else {
                    // Fire MIDI on touch down (not touch up) for zero-latency feel
                    ButtonTileContent()
                        .contentShape(Rectangle())
                        .modifier(PressGestureModifier(isPhone: isPhone, isTouching: $isTouching, isPressed: $isPressed, onTouchDown: onTap))
                }
            }
            
            // Delete button in edit mode — positioned so circle center sits at tile corner
            if isEditing {
                Button(action: onDelete) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.9))
                            .frame(width: isPhone ? 20 : 30, height: isPhone ? 20 : 30)
                        Image(systemName: "xmark")
                            .font(.system(size: isPhone ? 10 : 13, weight: .bold))
                            .foregroundColor(Color(uiColor: .systemBackground))
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Circle().scale(2))  // Generous hit area around the circle
                .position(x: isPhone ? 4 : 0, y: isPhone ? 4 : 0)  // Slightly inset from corner
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .allowsHitTesting(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(isEditing ? Rectangle() : Rectangle())
        .background(isEditing ? Color.clear : Color.primary.opacity(0.001))
            .opacity(isDragging ? (button.isFader == true ? 0.8 : 0.5) : 1.0)
            // .modifier(ConditionalDragModifier(isEditing: isEditing, onDrag: onDrag, buttonTitle: button.title)) // Disabled in favor of smooth drag
            .allowsHitTesting(isEditing ? true : true)
        .modifier(ConditionalWobbleModifier(isPhone: isPhone, wobbleID: wobbleID, wobbleAnimator: wobbleAnimator))
        .onChange(of: isEditing) { _, editing in
            if !isPhone {
                // Only wobble on iPad
                if editing { startWobble() } else { stopWobble() }
            }
        }
        .onAppear {
            // Initialize fader value from stored value in ControlButton model
            if let storedValue = button.faderValue {
                faderValue = storedValue
                faderVisualValue = storedValue
            } else {
                // Use default value for new faders
                let defaultValue = 0.66
                faderValue = defaultValue
                faderVisualValue = defaultValue
            }
            // Only start wobble on iPad (iPhone never wobbles)
            if isEditing && !isPhone { startWobble() }

            // FIX #1: Setup notification subscription using Combine to prevent memory leak
            faderUpdateCancellable = NotificationCenter.default.publisher(for: Notification.Name("cbUpdateFaderFromDAW"))
                .sink { [self] notif in
                    guard let info = notif.userInfo as? [String: Any],
                          let buttonID = info["buttonID"] as? String,
                          let value = info["value"] as? Double,
                          buttonID == button.id.uuidString else {
                        return
                    }

                    // Update fader values from DAW MIDI input
                    faderValue = value
                    faderVisualValue = value
                }
        }
        .onDisappear {
            stopWobble()
            // FIX #1: Clean up notification subscription to prevent memory leak
            faderUpdateCancellable?.cancel()
            faderUpdateCancellable = nil
        }
    }
    
    // Get custom button color or default to theme's defaultCueColor
    private var customButtonColor: Color {
        if let hex = button.colorHex, !hex.isEmpty {
            return Color(hex: hex)
        }
        return defaultCueColor
    }

    // Filled tile background — always accent color (palette style)
    private var buttonBackgroundColor: Color {
        if button.isToggle == true {
            // Toggle buttons: clear visual distinction between ON and OFF
            let isOn = button.toggleState || isPressed
            return isOn ? customButtonColor : customButtonColor.opacity(0.45)
        } else {
            // Momentary buttons: subtle press feedback
            return isPressed ? customButtonColor : customButtonColor.opacity(0.9)
        }
    }

    // Adaptive text color based on tile background brightness (palette style)
    private var buttonTextColor: Color {
        customButtonColor.needsDarkText() ? .black : .white
    }

    // Icon color matches text color (palette style)
    private var buttonIconColor: Color {
        buttonTextColor
    }

    @ViewBuilder
    private func ButtonTileContent() -> some View {
        VStack(spacing: isPhone ? 1 : 4) {
            Spacer(minLength: 0)

            if button.symbol.isEmpty {
                // Text only
                Text(button.title)
                    .font(.custom("Sora-Bold", size: isPhone ? 11 : 12))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            } else if button.title.isEmpty {
                // Icon only
                Image(systemName: button.symbol)
                    .font(.system(size: isPhone ? 16 : 22, weight: .semibold))
                    .foregroundColor(buttonIconColor)
            } else {
                // Icon + text
                Image(systemName: button.symbol)
                    .font(.system(size: isPhone ? 14 : 22, weight: .semibold))
                    .foregroundColor(buttonIconColor)
                Text(button.title)
                    .font(.custom("Sora-Bold", size: isPhone ? 10 : 12))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            if showMIDIData {
                Text(midiLabel())
                    .font(.custom("Sora-Regular", size: isPhone ? 8 : 9))
                    .foregroundColor(buttonTextColor.opacity(0.5))
            }

            Spacer(minLength: 0)
        }
        .foregroundColor(buttonTextColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(buttonBackgroundColor)
        )
        .opacity(isTouching ? 0.7 : 1.0)
        .transaction { t in
            // Instant dim on press, animated restore on release
            if isTouching { t.animation = nil } else { t.animation = .easeOut(duration: 0.1) }
        }
        .animation(.easeOut(duration: 0.08), value: button.toggleState)
    }

    @ViewBuilder
    private func FaderTileContent() -> some View {
        GeometryReader { geo in
            let isHorizontal = (button.faderOrientation == "horizontal")
            let direction = button.faderDirection ?? (isHorizontal ? "right" : "up")

            if isHorizontal {
                // HORIZONTAL FADER
                let headWidth: CGFloat = 20
                let w = max(0, geo.size.width - headWidth)
                // shouldReverse is only used for input mapping in gesture, not for visual rendering
                let shouldReverse = (direction == "left")
                // Fill alignment: "right" fills from left, "left" fills from right
                // The alignment handles the directional flip, so we use the same value for both
                let fillAlignment: Alignment = (direction == "right") ? .leading : .trailing

                ZStack(alignment: fillAlignment) {
                    // Main fader track background - filled style with 8pt corners
                    RoundedRectangle(cornerRadius: 8)
                        .fill(customButtonColor.opacity(0.2))

                    // Fader fill (dynamic based on faderValue) - alignment handles the direction
                    RoundedRectangle(cornerRadius: 8)
                        .fill(customButtonColor.opacity(0.85))
                        .frame(width: w * faderVisualValue)
                        .padding(3)

                    // Fader head (dynamic position) - conditional offset for direction
                    RoundedRectangle(cornerRadius: 6)
                        .fill(customButtonColor)
                        .frame(width: headWidth)
                        .offset(x: (direction == "right") ? (w * faderVisualValue) : -(w * faderVisualValue))
                        .padding(.vertical, 6)
                }
                .gesture(
                    // Apply drag gesture directly to the fader track area
                    isEditing ? nil : DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            // Instant touch feedback on first touch
                            if !isTouching {
                                isTouching = true
                            }

                            let dragX = value.location.x
                            let faderTrackWidth = w

                            // Convert X position to fader value (0.0 to 1.0)
                            let normalizedX = max(0, min(faderTrackWidth, dragX - headWidth/2))
                            var targetValue = max(0.0, min(1.0, Double(normalizedX) / Double(faderTrackWidth)))

                            // Reverse if direction is "left"
                            if shouldReverse {
                                targetValue = 1.0 - targetValue
                            }

                            // Update both values immediately for maximum responsiveness
                            faderValue = targetValue
                            faderVisualValue = targetValue

                            // FIX #7: Use frame counter instead of Date() for throttling
                            frameCounter += 1
                            let valueChange = abs(targetValue - lastSentValue)

                            // Send MIDI every 2nd frame or if value changed significantly
                            // 1. Every 2nd frame (avoids Date() overhead)
                            // 2. Value changed significantly (>0.01 = ~1.3 MIDI steps)
                            // 3. At extreme values (0.0 or 1.0)
                            if frameCounter % 2 == 0 || valueChange > 0.01 || targetValue == 0.0 || targetValue == 1.0 {
                                let midiValue = Int(round(targetValue * 127))
                                lastSentValue = targetValue
                                onFaderMIDI(button.channel, button.number, midiValue, button.title, button.id)
                            }
                        }
                        .onEnded { _ in
                            // End touch feedback
                            isTouching = false

                            // Ensure final MIDI value is sent
                            let finalMidiValue = Int(round(faderValue * 127))
                            onFaderMIDI(button.channel, button.number, finalMidiValue, button.title, button.id)
                            lastSentValue = faderValue
                            // FIX #7: Reset frame counter
                            frameCounter = 0
                        }
                )

                // Title overlay - centered
                // Text color adapts to whether the fader fill is behind the text
                // For horizontal: text is centered, so it's covered when fill > ~50%
                HStack {
                    let filledTextColor: Color = customButtonColor.needsDarkText() ? .black : .white
                    let emptyTextColor: Color = .white  // Dark mode background
                    let textOnFill = faderVisualValue > 0.45
                    let faderTextColor = textOnFill ? filledTextColor : emptyTextColor
                    Text(button.title)
                        .font(.custom("Sora-Bold", size: 11))
                        .foregroundColor(faderTextColor)
                        .multilineTextAlignment(.center)
                        .padding(.leading, isPhone ? 2 : 4)
                    Spacer()
                    if showMIDIData {
                        Text(midiLabel())
                            .font(.custom("Sora-Regular", size: 9))
                            .foregroundColor(faderTextColor.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.trailing, isPhone ? 2 : 4)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .allowsHitTesting(false) // Don't interfere with fader drag
            } else {
                // VERTICAL FADER
                let headHeight: CGFloat = 20
                let h = max(0, geo.size.height - headHeight)
                // shouldReverse is only used for input mapping in gesture, not for visual rendering
                let shouldReverse = (direction == "down")
                // Fill alignment: "up" fills from bottom, "down" fills from top
                // The alignment handles the directional flip, so we use the same value for both
                let fillAlignment: Alignment = (direction == "up") ? .bottom : .top

                ZStack(alignment: fillAlignment) {
                    // Main fader track background - filled style with 8pt corners
                    RoundedRectangle(cornerRadius: 8)
                        .fill(customButtonColor.opacity(0.2))

                    // Fader fill (dynamic based on faderValue) - alignment handles the direction
                    RoundedRectangle(cornerRadius: 8)
                        .fill(customButtonColor.opacity(0.85))
                        .frame(height: h * faderVisualValue)
                        .padding(3)

                    // Fader head (dynamic position) - conditional offset for direction
                    RoundedRectangle(cornerRadius: 6)
                        .fill(customButtonColor)
                        .frame(height: headHeight)
                            .offset(y: (direction == "up") ? -(h * faderVisualValue) : (h * faderVisualValue))
                        .padding(.horizontal, 6)
                }
                .gesture(
                    // Apply drag gesture directly to the fader track area
                    isEditing ? nil : DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            // Instant touch feedback on first touch
                            if !isTouching {
                                isTouching = true
                            }

                            let dragY = value.location.y
                            let faderTrackHeight = h

                            // Convert Y position to fader value (0.0 to 1.0)
                            let normalizedY = max(0, min(faderTrackHeight, dragY - headHeight/2))
                            var targetValue = max(0.0, min(1.0, 1.0 - (Double(normalizedY) / Double(faderTrackHeight))))

                            // Reverse if direction is "down"
                            if shouldReverse {
                                targetValue = 1.0 - targetValue
                            }

                            // Update both values immediately for maximum responsiveness
                            faderValue = targetValue
                            faderVisualValue = targetValue

                            // FIX #7: Use frame counter instead of Date() for throttling
                            frameCounter += 1
                            let valueChange = abs(targetValue - lastSentValue)

                            // Send MIDI every 2nd frame or if value changed significantly
                            // 1. Every 2nd frame (avoids Date() overhead)
                            // 2. Value changed significantly (>0.01 = ~1.3 MIDI steps)
                            // 3. At extreme values (0.0 or 1.0)
                            if frameCounter % 2 == 0 || valueChange > 0.01 || targetValue == 0.0 || targetValue == 1.0 {
                                let midiValue = Int(round(targetValue * 127))
                                lastSentValue = targetValue
                                onFaderMIDI(button.channel, button.number, midiValue, button.title, button.id)
                            }
                        }
                        .onEnded { _ in
                            // End touch feedback
                            isTouching = false

                            // Ensure final MIDI value is sent
                            let finalMidiValue = Int(round(faderValue * 127))
                            onFaderMIDI(button.channel, button.number, finalMidiValue, button.title, button.id)
                            lastSentValue = faderValue
                            // FIX #7: Reset frame counter
                            frameCounter = 0
                        }
                )

                // Title overlay - centered
                // Text color adapts to whether the fader fill is behind the text
                // For vertical "up": title at top needs high fill, MIDI at bottom covered first
                // For vertical "down": title at top covered first, MIDI at bottom needs high fill
                VStack(spacing: 2) {
                    let filledTextColor: Color = customButtonColor.needsDarkText() ? .black : .white
                    let emptyTextColor: Color = .white  // Dark mode background
                    let titleOnFill = (direction == "up") ? faderVisualValue > 0.75 : faderVisualValue > 0.15
                    let midiOnFill = (direction == "up") ? faderVisualValue > 0.15 : faderVisualValue > 0.75
                    Text(button.title)
                        .font(.custom("Sora-Bold", size: 11))
                        .foregroundColor(titleOnFill ? filledTextColor : emptyTextColor)
                        .multilineTextAlignment(.center)
                        .padding(.top, isPhone ? 2 : 4)
                    Spacer()
                    if showMIDIData {
                        Text(midiLabel())
                            .font(.custom("Sora-Regular", size: 9))
                            .foregroundColor((midiOnFill ? filledTextColor : emptyTextColor).opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.bottom, isPhone ? 2 : 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .allowsHitTesting(false) // Don't interfere with fader drag
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.clear))
        .contentShape(Rectangle())  // Ensure entire frame is tappable
        .highPriorityGesture(
            // Only apply TapGesture for buttons, not faders (faders have DragGesture with minimumDistance: 0)
            button.isFader == true ? nil : TapGesture().onEnded {
                if isEditing {
                    onEdit()
                } else {
                    onTap()
                }
            }
        )
        .animation(.spring(response: 0.15, dampingFraction: 0.75), value: isTouching)
        .animation(.spring(response: 0.15, dampingFraction: 0.75), value: isDragging)
    }

    private func midiLabel() -> String {
        switch button.kind {
        case .cc:   return "\(button.channel)•\(button.number)"
        case .note: return "\(button.channel)•\(button.number)•\(button.velocity)"
        }
    }
}

// MARK: - iPad Drop Delegate (adapted from Mac editor)
private struct iPadDropDelegate: DropDelegate {
    let columns: Int
    let columnSpacing: CGFloat
    let rowSpacing: CGFloat
    let cellSize: CGFloat
    let displayRows: Int
    @Binding var buttons: [ControlButton]
    @Binding var dragging: ControlButton?
    @Binding var previewLocation: GridPosition?
    @Binding var dropSurfaceElevated: Bool
    @Binding var isDragOperation: Bool
    @Binding var lastDropTime: Date
    let isActive: Bool
    let clearDragState: (String) -> Void
    
    func validateDrop(info: DropInfo) -> Bool {
            // Always return true to prevent 🚫 icon - we'll handle validation in performDrop
            return true
    }
    
    func dropEntered(info: DropInfo) {
        debugPrint("🟦 dropEntered called - isActive: \(isActive), dragging: \(dragging?.title ?? "nil")")
        debugPrint("🟦 dropEntered location: (\(info.location.x), \(info.location.y))")
        guard isActive, dragging != nil else { 
            debugPrint("🔴 dropEntered: not active or no dragging")
            return 
        }
        updatePreview(info: info)
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        // Always update preview, even during fast drags
        updatePreview(info: info)
        // Ensure we maintain drag state during fast movement
        if dragging != nil {
        return DropProposal(operation: .move)
        } else {
            return DropProposal(operation: .forbidden)
        }
    }
    
    func dropExited(info: DropInfo) {
        // Don't clear preview immediately - give a brief moment to return
        // Only clear if we're truly exiting the drop area
        debugPrint("🚪 dropExited: keeping drag state for potential return")
    }
    
    private func updatePreview(info: DropInfo) {
        guard let dragging = dragging else {
            debugPrint("🔴 updatePreview: no dragging item")
            return
        }
        
        let p = info.location
        let rawCol = Int((p.x / (cellSize + columnSpacing)).rounded(.down))
        let rawRow = Int((p.y / (cellSize + rowSpacing)).rounded(.down))
        let row = max(0, min(rawRow, displayRows - 1))

        let targetWidth = dragging.gridWidth
        let col = max(0, min(rawCol, columns - targetWidth))
        
        let fits = col + targetWidth <= columns && row >= 0 && col >= 0

        let newPosition = fits ? GridPosition(col: col, row: row) : nil
        
        // Always update preview location during active drags to handle fast movement
        previewLocation = newPosition
        if let pos = newPosition {
            debugPrint("🟦 Preview updated to: (\(pos.col), \(pos.row))")
        } else {
            debugPrint("🟦 Preview cleared - doesn't fit")
        }
    }
    
    func performDrop(info: DropInfo) -> Bool {
        debugPrint("✅ performDrop called: active=\(isActive), dragging=\(dragging?.title ?? "nil")")
        guard isActive, let draggingButton = dragging else { 
            debugPrint("🔴 performDrop failed: active=\(isActive), dragging=\(dragging?.title ?? "nil")")
            return false 
        }
        
        let p = info.location
        let rawCol = Int((p.x / (cellSize + columnSpacing)).rounded(.down))
        let rawRow = Int((p.y / (cellSize + rowSpacing)).rounded(.down))
        let row = max(0, min(rawRow, displayRows - 1))
        let targetWidth = draggingButton.gridWidth
        let col = max(0, min(rawCol, columns - targetWidth))
        
        debugPrint("✅ performDrop to (\(col),\(row)) for \(draggingButton.title) - using smart placement")
        
        // Use smart placement to handle overlaps and find best position
        smartPlacement(dragging: draggingButton, targetCol: col, targetRow: row)
        
        // Verify the placement was successful
        if let buttonIndex = buttons.firstIndex(where: { $0.id == draggingButton.id }) {
            let finalCol = buttons[buttonIndex].gridCol ?? -1
            let finalRow = buttons[buttonIndex].gridRow ?? -1
            debugPrint("✅ Final position for \(draggingButton.title): (\(finalCol), \(finalRow))")
        }
        
        // Record drop time to prevent auto-assignment interference
        lastDropTime = Date()
        
        // Add a small delay before clearing drag state to ensure position is committed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            clearDragState("drop completed successfully")
        }
        return true
    }
    
    // Smart placement helper functions (from Mac editor)
    private func smartPlacement(dragging: ControlButton, targetCol: Int, targetRow: Int) {
            let draggedWidth = dragging.gridWidth
            let draggedHeight = dragging.gridHeight
        guard let draggedIndex = buttons.firstIndex(where: { $0.id == dragging.id }) else { 
            debugPrint("🔴 smartPlacement: Could not find dragged button \(dragging.title) in buttons array")
            return 
        }
        
        let _ = buttons[draggedIndex].gridCol ?? -1
        let _ = buttons[draggedIndex].gridRow ?? -1
        // Removed verbose height calculation logs for cleaner testing
        debugPrint("🔍 smartPlacement: buttons array has \(buttons.count) items, draggedIndex = \(draggedIndex)")
        
        buttons[draggedIndex].gridCol = nil
        buttons[draggedIndex].gridRow = nil
        let draggedRect = GridRect(col: targetCol, row: targetRow, width: draggedWidth, height: draggedHeight)
        let overlapping = findOverlappingItems(for: draggedRect)
        if overlapping.isEmpty {
            buttons[draggedIndex].gridCol = targetCol
            buttons[draggedIndex].gridRow = targetRow
            debugPrint("✅ smartPlacement: Placed \(dragging.title) at (\(targetCol), \(targetRow)) - no overlaps")
        } else {
            var displacedItems: [(index: Int, originalCol: Int, originalRow: Int, item: ControlButton)] = []
            for overlappingIndex in overlapping {
                let originalCol = buttons[overlappingIndex].gridCol ?? 0
                let originalRow = buttons[overlappingIndex].gridRow ?? 0
                displacedItems.append((index: overlappingIndex, originalCol: originalCol, originalRow: originalRow, item: buttons[overlappingIndex]))
                buttons[overlappingIndex].gridCol = nil
                buttons[overlappingIndex].gridRow = nil
            }
            buttons[draggedIndex].gridCol = targetCol
            buttons[draggedIndex].gridRow = targetRow
            debugPrint("✅ smartPlacement: Placed \(dragging.title) at (\(targetCol), \(targetRow)) - handling \(displacedItems.count) overlaps")
            // Use iPhone-like smart positioning for displaced items
            for (index, originalCol, originalRow, item) in displacedItems {
                let itemWidth = item.gridWidth
                let itemHeight = item.gridHeight

                // Try to find a smart position (right first, then down)
                if let newPos = findSmartPosition(
                    forItemAt: (originalCol, originalRow),
                    width: itemWidth,
                    height: itemHeight,
                    excluding: index
                ) {
                    buttons[index].gridCol = newPos.col
                    buttons[index].gridRow = newPos.row
                    debugPrint("🔄 Displaced \(item.title) to new position (\(newPos.col), \(newPos.row))")
                } else {
                    buttons[index].gridCol = originalCol
                    buttons[index].gridRow = originalRow
                    debugPrint("⚠️ Could not find new position for \(item.title), keeping at original (\(originalCol), \(originalRow))")
                }
            }
        }
    }
    
    private func findOverlappingItems(for rect: GridRect) -> [Int] {
        var overlapping: [Int] = []
        for (index, item) in buttons.enumerated() {
            guard let col = item.gridCol, let row = item.gridRow else { continue }
            let itemRect = GridRect(
                col: col, row: row,
                    width: item.gridWidth,
                    height: item.gridHeight
            )
            if rectsOverlap(rect, itemRect) {
                    debugPrint("🔍 Found overlap: \(item.title) at (\(col),\(row)) size \(itemRect.width)x\(itemRect.height) overlaps with target rect (\(rect.col),\(rect.row)) size \(rect.width)x\(rect.height)")
                overlapping.append(index)
            }
        }
        return overlapping
    }
    
    private func findFreePosition(width: Int, height: Int) -> (col: Int, row: Int)? {
        let maxSearchRows = 4
        for row in 0..<maxSearchRows {
            for col in 0...(columns - width) {
                let testRect = GridRect(col: col, row: row, width: width, height: height)
                    if !hasOverlap(testRect) { return (col: col, row: row) }
                }
            }
        return nil
    }

    // iPhone-like smart positioning: prioritize right, then down, then general search
    private func findSmartPosition(
        forItemAt originalPos: (Int, Int),
        width: Int,
        height: Int,
        excluding excludeIndex: Int
    ) -> (col: Int, row: Int)? {
        let (originalCol, originalRow) = originalPos

        // 1. Try moving right first (same row, next column)
        let rightCol = originalCol + 1
        if rightCol + width <= columns {
            let testRect = GridRect(col: rightCol, row: originalRow, width: width, height: height)
            if !hasOverlapExcluding(testRect, excluding: excludeIndex) {
                return (rightCol, originalRow)
            }
        }

        // 2. Try moving down and left (cascade to next row)
        let nextRow = originalRow + 1
        if nextRow + height <= 4 { // max 4 rows
            for col in 0...(columns - width) {
                let testRect = GridRect(col: col, row: nextRow, width: width, height: height)
                if !hasOverlapExcluding(testRect, excluding: excludeIndex) {
                    return (col, nextRow)
                }
            }
        }

        // 3. Fallback to general search (left-to-right, top-to-bottom)
        return findFreePositionExcluding(width: width, height: height, excluding: excludeIndex)
    }

    private func findFreePositionExcluding(width: Int, height: Int, excluding excludeIndex: Int) -> (col: Int, row: Int)? {
        let maxSearchRows = 4
        for row in 0..<maxSearchRows {
            for col in 0...(columns - width) {
                let testRect = GridRect(col: col, row: row, width: width, height: height)
                if !hasOverlapExcluding(testRect, excluding: excludeIndex) {
                    return (col: col, row: row)
                }
            }
        }
        return nil
    }

    private func hasOverlapExcluding(_ rect: GridRect, excluding excludeIndex: Int) -> Bool {
        for (index, item) in buttons.enumerated() {
            if index == excludeIndex { continue }
            guard let col = item.gridCol, let row = item.gridRow else { continue }
            let itemRect = GridRect(
                col: col, row: row,
                width: item.gridWidth,
                height: item.gridHeight
            )
            if rectsOverlap(rect, itemRect) { return true }
        }
        return false
    }
    
    private func hasOverlap(_ rect: GridRect) -> Bool {
        for item in buttons {
            guard let col = item.gridCol, let row = item.gridRow else { continue }
            let itemRect = GridRect(
                col: col, row: row,
                    width: item.gridWidth,
                    height: item.gridHeight
            )
                if rectsOverlap(rect, itemRect) { return true }
        }
        return false
    }
    
    private func rectsOverlap(_ rect1: GridRect, _ rect2: GridRect) -> Bool {
        return !(rect1.col + rect1.width <= rect2.col ||
                rect2.col + rect2.width <= rect1.col ||
                rect1.row + rect1.height <= rect2.row ||
                rect2.row + rect2.height <= rect1.row)
    }
}

// MARK: - MIDI Table Sheet
struct MidiTableSheet: View {
    let setlist: [Song]
    @Binding var controlButtons: [ControlButton]
    @Binding var isGlobalChannel: Bool
    @Binding var globalChannel: Int
    @Binding var midiFiltersEnabled: Bool
    @Binding var midiFilter: Set<Int>
    @Binding var customMidiFilters: [(Int, String)]
    var onDismiss: () -> Void
        var onApply: (([MidiTableItem]) -> Void)? = nil

    @State private var editableItems: [MidiTableItem] = []
    @State private var showingConflictAlert = false
    @State private var pendingConflict: MidiConflict? = nil
        @State private var sortKey: MidiSortKey = .name
        @State private var sortAscending: Bool = true
        @State private var allowFullCCR: Bool = false

        enum MidiSortKey { case name, type, channel, value }

    @State private var showMidiAssignmentsSheet = false

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    var body: some View {
        NavigationView {
            Form {
                // Section 1: Global MIDI Channel
                Section {
                    Toggle("Global MIDI Channel", isOn: $isGlobalChannel)
                        .toggleStyle(SwitchToggleStyle(tint: selectedTheme.successColor(for: colorScheme)))
                        .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))

                    if isGlobalChannel {
                        ChannelPicker(title: "Channel", channel: $globalChannel, disabled: false)
                            .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                    }
                } footer: {
                    Text("When enabled, all cues and controls will be assigned to the same MIDI channel. When disabled, each item can use any of the 16 MIDI channels.")
                        .font(.footnote)
                }

                // Section 2: MIDI Filter
                Section {
                    NavigationLink(destination: MidiFilterView(midiFilter: $midiFilter, customMidiFilters: $customMidiFilters)) {
                        Text("MIDI Filter")
                    }
                    .tint(selectedTheme.accentColor(for: colorScheme))
                    .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                } header: {
                    Text("Auto-Assignment")
                } footer: {
                    Text("Exclude MIDI CC numbers from automatic assignment")
                }

                // Section 3: MIDI Assignments
                Section {
                    NavigationLink(destination: MidiAssignmentsView(
                        setlist: setlist,
                        controlButtons: $controlButtons,
                        isGlobalChannel: $isGlobalChannel,
                        globalChannel: $globalChannel,
                        midiFiltersEnabled: midiFiltersEnabled,
                        midiFilter: midiFilter,
                        onApply: onApply,
                        onDismissAll: onDismiss
                    )) {
                        Text("MIDI Assignments")
                    }
                    .tint(selectedTheme.accentColor(for: colorScheme))
                    .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                } footer: {
                    Text("View and edit MIDI assignments for all cues and controls")
                }
            }
            .scrollContentBackground(.hidden)
            .background(selectedTheme.backgroundColor(for: colorScheme))
            .navigationTitle("MIDI Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    CBSheetButton(title: "Done", bold: true) { onDismiss() }
                }
            }
            .tint(selectedTheme.accentColor(for: colorScheme))
        }
        .preferredColorScheme(selectedTheme.preferredColorScheme(for: colorScheme))
    }
}

// MARK: - MIDI Assignments View (NavigationLink destination)
struct MidiAssignmentsView: View {
    let setlist: [Song]
    @Binding var controlButtons: [ControlButton]
    @Binding var isGlobalChannel: Bool
    @Binding var globalChannel: Int
    let midiFiltersEnabled: Bool
    let midiFilter: Set<Int>
    var onApply: (([MidiTableItem]) -> Void)? = nil
    var onDismissAll: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    @State private var editableItems: [MidiTableItem] = []
    @State private var showingConflictAlert = false
    @State private var pendingConflict: MidiConflict? = nil
    @State private var sortKey: MidiSortKey = .name
    @State private var sortAscending: Bool = true
    @State private var allowFullCCR: Bool = false

    enum MidiSortKey { case name, type, channel, value }

    var body: some View {
        VStack(spacing: 0) {
            // MIDI Table
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Table Header
                        HStack(spacing: 0) {
                                Button(action: { toggleSort(.name) }) {
                                    HStack(spacing: 4) {
                                        Text("Name").font(.subheadline.weight(.semibold)).foregroundColor(.secondary)
                                        sortIndicator(for: .name)
                                    }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: { toggleSort(.type) }) {
                                    HStack(spacing: 4) {
                                        Text("Type").font(.subheadline.weight(.semibold)).foregroundColor(.secondary)
                                        sortIndicator(for: .type)
                                    }
                                .frame(width: 70, alignment: .center)
                                }
                                .buttonStyle(.plain)
                            
                            if !isGlobalChannel {
                                    Button(action: { toggleSort(.channel) }) {
                                        HStack(spacing: 4) {
                                            Text("Channel").font(.subheadline.weight(.semibold)).foregroundColor(.secondary)
                                            sortIndicator(for: .channel)
                                        }
                                    .frame(width: 80, alignment: .center)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                Button(action: { toggleSort(.value) }) {
                                    HStack(spacing: 4) {
                                        Text("Value").font(.subheadline.weight(.semibold)).foregroundColor(.secondary)
                                        sortIndicator(for: .value)
                                    }
                                .frame(width: 90, alignment: .center)
                                }
                                .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color(UIColor.systemGray6))
                        
                        ForEach(editableItems.indices, id: \.self) { index in
                            MidiTableRow(
                                item: $editableItems[index],
                                isGlobalChannel: isGlobalChannel,
                                globalChannel: globalChannel,
                                    allowFullCCR: allowFullCCR,
                                midiFiltersEnabled: midiFiltersEnabled,
                                midiFilter: midiFilter,
                                getEditableItems: { editableItems },
                                onMidiChange: { item, newMidiType, newChannel, newValue in
                                    handleMidiChange(item: item, newMidiType: newMidiType, newChannel: newChannel, newValue: newValue)
                                },
                                getOwnerName: { midiType, channel, value, excludeId, excludeName in
                                    getOwnerName(for: midiType, channel: channel, value: value, excluding: excludeId, excludeName: excludeName)
                                },
                                onDismissAll: onDismissAll,
                                onApply: onApply
                            )
                            .background(Color(UIColor.systemBackground))
                            
                            if index < editableItems.count - 1 {
                                Divider()
                                    .padding(.leading, 20)
                            }
                        }
                    }
                }
                .background(Color(UIColor.systemGroupedBackground))
        }
        .onAppear {
            buildMidiTableItems()
        }
        .cbDialog("MIDI Conflict", isPresented: $showingConflictAlert, themeFont: selectedTheme.font,
            message: pendingConflict.map { c in
                "MIDI \(c.midiKey.kind == .cc ? "CC" : "Note") #\(c.midiKey.number) on Channel \(c.midiKey.channel) is already used by \"\(c.existingOwner)\". Reassign to \"\(c.newItem.name)\"? Previous mapping will be removed."
            } ?? "",
            buttons: [
                .init("Reassign", role: .primary) {
                    if let conflict = pendingConflict {
                        resolveMidiConflict(conflict)
                    }
                    pendingConflict = nil
                },
                .init("Cancel", role: .cancel) {
                    pendingConflict = nil
                }
            ]
        )
        .navigationTitle("MIDI Assignments")
        .navigationBarTitleDisplayMode(.inline)
        .background(selectedTheme.backgroundColor(for: colorScheme))
        .toolbarBackground(.hidden, for: .navigationBar)
        .tint(selectedTheme.accentColor(for: colorScheme))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                CBSheetButton(title: "Done", bold: true) {
                    debugPrint("🎛️ [MIDI Assignments] Done button clicked - applying \(editableItems.count) items")
                    onApply?(editableItems)
                    if let onDismissAll = onDismissAll {
                        onDismissAll()
                    } else {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func buildMidiTableItems() {
        debugPrint("🎛️ [Build Items] Starting - setlist.count=\(setlist.count), controlButtons.count=\(controlButtons.count)")
        var items: [MidiTableItem] = []
        var seenIDs: Set<UUID> = []

        // Add setlist items
        for song in setlist {
            // Skip if we've already added this ID (prevents duplicates)
            guard !seenIDs.contains(song.id) else { continue }
            seenIDs.insert(song.id)

            items.append(MidiTableItem(
                id: song.id,
                name: song.name,
                type: .setlistItem,
                midiType: song.kind,
                channel: song.channel,
                value: song.kind == .cc ? song.cc : (song.note ?? 0)
            ))
        }
        debugPrint("🎛️ [Build Items] Added \(items.count) setlist items")

        // Add control buttons and faders
        for button in controlButtons {
            // Skip if we've already added this ID (prevents duplicates)
            guard !seenIDs.contains(button.id) else { continue }
            seenIDs.insert(button.id)

            let itemType: MidiItemType = button.isFader == true ? .fader : .button
            debugPrint("🎛️ [Build Items] Adding \(itemType.displayName): '\(button.title)' - \(button.kind) Ch\(button.channel) #\(button.number)")

            items.append(MidiTableItem(
                id: button.id,
                name: button.title,
                type: itemType,
                midiType: button.kind,
                channel: button.channel,
                value: button.number
            ))
        }
        debugPrint("🎛️ [Build Items] Total items: \(items.count) (setlist + controls)")

            editableItems = items
            sortEditableItems()
        debugPrint("🎛️ [Build Items] Finished - editableItems.count=\(editableItems.count)")
    }
    
    private func applyGlobalChannel() {
        // Apply the global channel to all items
        for index in editableItems.indices {
            editableItems[index].channel = globalChannel
        }
    }
    
    private func handleMidiChange(item: MidiTableItem, newMidiType: MIDIKind, newChannel: Int, newValue: Int) {
        debugPrint("🎛️ [MIDI Assignments] handleMidiChange for '\(item.name)' (\(item.type.displayName)): \(newMidiType) Ch\(newChannel) #\(newValue)")

        // Check if this creates a conflict
        if let conflict = checkForMidiConflict(item: item, newMidiType: newMidiType, newChannel: newChannel, newValue: newValue) {
            debugPrint("🎛️ [MIDI Assignments] Conflict detected with: \(conflict.existingOwner)")
            // Show conflict alert
            pendingConflict = conflict
            showingConflictAlert = true
        } else {
            // No conflict, update directly
            if let itemIndex = editableItems.firstIndex(where: { $0.id == item.id }) {
                debugPrint("🎛️ [MIDI Assignments] Updating editableItems[\(itemIndex)] for '\(item.name)'")
                editableItems[itemIndex].midiType = newMidiType
                editableItems[itemIndex].channel = newChannel
                editableItems[itemIndex].value = newValue
            } else {
                debugPrint("🎛️ [MIDI Assignments] ERROR: Could not find item in editableItems!")
            }
        }
    }
    
    private func checkForMidiConflict(item: MidiTableItem, newMidiType: MIDIKind, newChannel: Int, newValue: Int) -> MidiConflict? {
        let newKey = MIDIKey(kind: newMidiType, channel: newChannel, number: newValue)

        // Collect all owners of this MIDI key
        let owners = editableItems.filter { otherItem in
            otherItem.id != item.id && MIDIKey(kind: otherItem.midiType, channel: otherItem.channel, number: otherItem.value) == newKey
        }.map { $0.name }

        if !owners.isEmpty {
            // Format multiple owners
            let ownerString: String
            if owners.count == 1 {
                ownerString = owners[0]
            } else if owners.count == 2 {
                ownerString = "\(owners[0]) and \(owners[1])"
            } else if owners.count <= 4 {
                ownerString = owners.dropLast().joined(separator: ", ") + ", and " + owners.last!
            } else {
                let shown = owners.prefix(3).joined(separator: ", ")
                ownerString = "\(shown), and \(owners.count - 3) more"
            }

            return MidiConflict(
                newItem: item,
                existingOwner: ownerString,
                midiKey: newKey
            )
        }
        return nil
    }
    
    private func resolveMidiConflict(_ conflict: MidiConflict) {
        // Find the conflicting item and update it to use a free MIDI value
        if let conflictingIndex = editableItems.firstIndex(where: { 
            let key = MIDIKey(kind: $0.midiType, channel: $0.channel, number: $0.value)
            return key == conflict.midiKey && $0.id != conflict.newItem.id
        }) {
            // Find a free MIDI value for the conflicting item
            let freeValue = findFreeMidiValue(for: editableItems[conflictingIndex].midiType, channel: editableItems[conflictingIndex].channel)
            editableItems[conflictingIndex].value = freeValue
        }
        
        // Update the new item with the desired values
        if let newItemIndex = editableItems.firstIndex(where: { $0.id == conflict.newItem.id }) {
            editableItems[newItemIndex].midiType = conflict.midiKey.kind
            editableItems[newItemIndex].channel = conflict.midiKey.channel
            editableItems[newItemIndex].value = conflict.midiKey.number
        }
    }
    
    private func findFreeMidiValue(for midiType: MIDIKind, channel: Int) -> Int {
        for value in 0...127 {
            let testKey = MIDIKey(kind: midiType, channel: channel, number: value)
            let isUsed = editableItems.contains { item in
                let itemKey = MIDIKey(kind: item.midiType, channel: item.channel, number: item.value)
                return itemKey == testKey
            }
            if !isUsed {
                return value
            }
        }
        return 0 // Fallback
    }
    
    private func getOwnerName(for midiType: MIDIKind, channel: Int, value: Int, excluding excludeId: UUID, excludeName: String) -> String? {
        let testKey = MIDIKey(kind: midiType, channel: channel, number: value)
        let owners = editableItems.filter { item in
            item.id != excludeId && MIDIKey(kind: item.midiType, channel: item.channel, number: item.value) == testKey
        }.map { $0.name }

        debugPrint("🔍 [MIDI Assignments] getOwnerName for \(midiType) Ch\(channel) #\(value), excluding '\(excludeName)': found \(owners.count) owners: \(owners)")

        // Remove duplicate names (filter out the item being edited by name as well)
        let uniqueOwners = owners.filter { $0 != excludeName }
        let dedupedOwners = Array(Set(uniqueOwners)).sorted()

        // Format multiple owners
        if dedupedOwners.isEmpty {
            return nil
        } else if dedupedOwners.count == 1 {
            return dedupedOwners[0]
        } else if dedupedOwners.count == 2 {
            return "\(dedupedOwners[0]) and \(dedupedOwners[1])"
        } else if dedupedOwners.count <= 4 {
            return dedupedOwners.dropLast().joined(separator: ", ") + ", and " + dedupedOwners.last!
        } else {
            let shown = dedupedOwners.prefix(3).joined(separator: ", ")
            return "\(shown), and \(dedupedOwners.count - 3) more"
        }
    }

    // MARK: - Sorting
    private func toggleSort(_ key: MidiSortKey) {
        if sortKey == key {
            sortAscending.toggle()
        } else {
            sortKey = key
            sortAscending = true
        }
        sortEditableItems()
    }

    @ViewBuilder
    private func sortIndicator(for key: MidiSortKey) -> some View {
        if sortKey == key {
            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                .font(.caption2)
                .foregroundColor(.secondary)
        } else {
            EmptyView()
        }
    }

    private func sortEditableItems() {
        editableItems.sort { a, b in
            switch sortKey {
            case .name:
                let cmp = a.name.localizedCaseInsensitiveCompare(b.name)
                return sortAscending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
            case .type:
                let va = a.midiType == .cc ? 0 : 1
                let vb = b.midiType == .cc ? 0 : 1
                return sortAscending ? (va, a.name) < (vb, b.name) : (va, a.name) > (vb, b.name)
            case .channel:
                return sortAscending ? (a.channel, a.name) < (b.channel, b.name) : (a.channel, a.name) > (b.channel, b.name)
            case .value:
                return sortAscending ? (a.value, a.name) < (b.value, b.name) : (a.value, a.name) > (b.value, b.name)
            }
        }
    }
}

struct MidiTableItem: Identifiable {
    let id: UUID
    let name: String
    let type: MidiItemType
    var midiType: MIDIKind
    var channel: Int
    var value: Int
}

struct MidiConflict {
    let newItem: MidiTableItem
    let existingOwner: String
    let midiKey: MIDIKey
}

enum MidiItemType {
    case setlistItem
    case button
    case fader
    
    var displayName: String {
        switch self {
        case .setlistItem: return "Setlist"
        case .button: return "Button"
        case .fader: return "Fader"
        }
    }
}

// MARK: - MidiValueMenu Component
struct MidiValueMenu: View {
    let item: MidiTableItem
    let isGlobalChannel: Bool
    let globalChannel: Int
    let allowFullCCR: Bool
    let onMidiChange: (MidiTableItem, MIDIKind, Int, Int) -> Void
    let getOwnerName: (MIDIKind, Int, Int, UUID, String) -> String?
    
    var body: some View {
        Menu {
            if item.midiType == .cc && !allowFullCCR {
                ForEach(1...119, id: \.self) { val in
                    let channel = isGlobalChannel ? globalChannel : item.channel
                    let owner = getOwnerName(item.midiType, channel, val, item.id, item.name)
                    let displayText = owner == nil ? "\(val)" : "\(val) (Used by: \(owner!))"
                    Button(displayText) { onMidiChange(item, item.midiType, channel, val) }
                        .foregroundColor(owner == nil ? .primary : .secondary)
                }
            } else {
                ForEach(0...127, id: \.self) { val in
                    let channel = isGlobalChannel ? globalChannel : item.channel
                    let owner = getOwnerName(item.midiType, channel, val, item.id, item.name)
                    let displayText = item.midiType == .note ?
                        (owner == nil ? "\(val) - \(val.midiNoteName)" : "\(val) - \(val.midiNoteName) (Used by: \(owner!))") :
                        (owner == nil ? "\(val)" : "\(val) (Used by: \(owner!))")
                    Button(displayText) { onMidiChange(item, item.midiType, channel, val) }
                        .foregroundColor(owner == nil ? .primary : .secondary)
                }
            }
        } label: {
            HStack(spacing: 4) {
                let displayText = item.midiType == .note ? 
                    "\(item.value) - \(item.value.midiNoteName)" :
                    "\(item.value)"
                Text(displayText)
                    .font(.body)
                    .foregroundColor(.primary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .id("\(item.id)-\(item.midiType)-\(isGlobalChannel)-\(globalChannel)-\(allowFullCCR)")
    }
}

// MARK: - MIDI Assignment Edit Sheet
struct MidiAssignmentEditSheet: View {
    @Binding var item: MidiTableItem
    let isGlobalChannel: Bool
    let globalChannel: Int
    let allowFullCCR: Bool
    let midiFiltersEnabled: Bool
    let midiFilter: Set<Int>
    let getEditableItems: () -> [MidiTableItem]  // Closure to get current editableItems
    let onMidiChange: (MidiTableItem, MIDIKind, Int, Int) -> Void
    let getOwnerName: (MIDIKind, Int, Int, UUID, String) -> String?
    var onDismissAll: (() -> Void)? = nil
    var onApply: (([MidiTableItem]) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""

    @State private var editedType: MIDIKind
    @State private var editedChannel: Int
    @State private var editedValue: Int

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    init(item: Binding<MidiTableItem>, isGlobalChannel: Bool, globalChannel: Int, allowFullCCR: Bool, midiFiltersEnabled: Bool, midiFilter: Set<Int>, getEditableItems: @escaping () -> [MidiTableItem], onMidiChange: @escaping (MidiTableItem, MIDIKind, Int, Int) -> Void, getOwnerName: @escaping (MIDIKind, Int, Int, UUID, String) -> String?, onDismissAll: (() -> Void)? = nil, onApply: (([MidiTableItem]) -> Void)? = nil) {
        self._item = item
        self.isGlobalChannel = isGlobalChannel
        self.globalChannel = globalChannel
        self.allowFullCCR = allowFullCCR
        self.midiFiltersEnabled = midiFiltersEnabled
        self.midiFilter = midiFilter
        self.getEditableItems = getEditableItems
        self.onMidiChange = onMidiChange
        self.getOwnerName = getOwnerName
        self.onDismissAll = onDismissAll
        self.onApply = onApply
        self._editedType = State(initialValue: item.wrappedValue.midiType)
        self._editedChannel = State(initialValue: item.wrappedValue.channel)
        self._editedValue = State(initialValue: item.wrappedValue.value)
    }

    var body: some View {
        Form {
            Section(header: Text("Item")) {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(item.name)
                            .foregroundColor(.secondary)
                    }
                    .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))

                    HStack {
                        Text("Type")
                        Spacer()
                        Text(item.type.displayName)
                            .foregroundColor(.secondary)
                    }
                    .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                }

                Section(header: Text("MIDI Assignment")) {
                    if midiFiltersEnabled && !midiFilter.isEmpty {
                        Text("Some MIDI values are unavailable because MIDI filters are enabled. Go to MIDI Settings to change this.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                    }
                    if item.type != .fader {
                        Picker("MIDI Type", selection: $editedType) {
                            Text("Control Change").tag(MIDIKind.cc)
                            Text("Note").tag(MIDIKind.note)
                        }
                        .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                        .tint(selectedTheme.secondaryTextColor(for: colorScheme))
                        .foregroundStyle(selectedTheme.primaryTextColor(for: colorScheme))
                    }

                    if !isGlobalChannel {
                        ChannelPicker(title: "Channel", channel: $editedChannel, disabled: false)
                            .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                    } else {
                        HStack {
                            Text("Channel")
                            Spacer()
                            Text("\(globalChannel) (Global)")
                                .foregroundColor(.secondary)
                        }
                        .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                    }

                    // Value picker with ownership warnings
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 12) {
                            Text(editedType == .cc ? "CC Number" : "Note Number")
                                .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))

                            Spacer()

                            if editedType == .note {
                                Text(editedValue.midiNoteName)
                                    .font(.system(size: 14))
                                    .foregroundColor(selectedTheme.secondaryTextColor(for: colorScheme))
                            }

                            // Minus button
                            Button(action: {
                                if editedValue > (editedType == .cc && !allowFullCCR ? 1 : 0) {
                                    editedValue -= 1
                                }
                            }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(editedValue > (editedType == .cc && !allowFullCCR ? 1 : 0) ? selectedTheme.primaryTextColor(for: colorScheme) : selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3))
                                    .frame(width: 28, height: 28)
                                    .background(selectedTheme.titleBarColor(for: colorScheme))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .disabled(editedValue <= (editedType == .cc && !allowFullCCR ? 1 : 0))

                            // Text field
                            TextField("", value: $editedValue, format: .number)
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.center)
                                .frame(width: 50)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(selectedTheme.backgroundColor(for: colorScheme))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3), lineWidth: 1)
                                )
                                .foregroundColor(selectedTheme.primaryTextColor(for: colorScheme))
                                .keyboardType(.numberPad)

                            // Plus button
                            Button(action: {
                                let maxValue = (editedType == .cc && !allowFullCCR) ? 119 : 127
                                if editedValue < maxValue {
                                    editedValue += 1
                                }
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(editedValue < ((editedType == .cc && !allowFullCCR) ? 119 : 127) ? selectedTheme.primaryTextColor(for: colorScheme) : selectedTheme.secondaryTextColor(for: colorScheme).opacity(0.3))
                                    .frame(width: 28, height: 28)
                                    .background(selectedTheme.titleBarColor(for: colorScheme))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .disabled(editedValue >= ((editedType == .cc && !allowFullCCR) ? 119 : 127))
                        }

                        // Show ownership warning
                        if let owner = getOwnerName(editedType, isGlobalChannel ? globalChannel : editedChannel, editedValue, item.id, item.name) {
                            Text("⚠️ MIDI taken by: \(owner)")
                                .font(.caption)
                                .foregroundColor(selectedTheme.warningColor(for: colorScheme))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Show filtered MIDI warning only when filters are enabled
                        if midiFiltersEnabled && !midiFilter.isEmpty && editedType == .cc && midiFilter.contains(editedValue) {
                            Text("⚠️ This CC is filtered. Turn off filter to use it.")
                                .font(.caption)
                                .foregroundColor(selectedTheme.warningColor(for: colorScheme))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                }

            // Save button section at bottom
            Section {
                let channel = isGlobalChannel ? globalChannel : editedChannel
                let hasConflict = getOwnerName(editedType, channel, editedValue, item.id, item.name) != nil
                let isFiltered = midiFiltersEnabled && !midiFilter.isEmpty && editedType == .cc && midiFilter.contains(editedValue)
                let isDisabled = hasConflict || isFiltered

                Button(action: {
                    debugPrint("🎛️ [Edit Sheet] Save clicked for '\(item.name)' - type:\(editedType) ch:\(channel) val:\(editedValue)")

                    // Call onMidiChange to check for conflicts and update if valid
                    // This will update editableItems in the parent view
                    onMidiChange(item, editedType, channel, editedValue)

                    // Small delay to ensure editableItems is updated before applying
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        // Get the current editableItems and apply changes
                        let currentItems = getEditableItems()
                        debugPrint("🎛️ [Edit Sheet] Applying \(currentItems.count) items and dismissing all sheets")
                        onApply?(currentItems)

                        // Dismiss all sheets (MIDI Settings + MIDI Assignments)
                        if let onDismissAll = onDismissAll {
                            onDismissAll()
                        } else {
                            dismiss()
                        }
                    }
                }) {
                    Text("Save")
                        .font(.headline)
                        .foregroundColor(isDisabled ? Color.gray.opacity(0.5) : Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isDisabled ? Color.gray.opacity(0.3) : selectedTheme.accentColor(for: colorScheme))
                        .cornerRadius(10)
                }
                .disabled(isDisabled)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .scrollContentBackground(.hidden)
        .background(selectedTheme.backgroundColor(for: colorScheme))
        .navigationTitle("Edit MIDI Assignment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                CBSheetButton(title: "Cancel") { dismiss() }
            }
        }
        .preferredColorScheme(selectedTheme.preferredColorScheme(for: colorScheme))
    }
}

struct MidiTableRow: View {
    @Binding var item: MidiTableItem
    let isGlobalChannel: Bool
    let globalChannel: Int
    let allowFullCCR: Bool
    let midiFiltersEnabled: Bool
    let midiFilter: Set<Int>
    let getEditableItems: () -> [MidiTableItem]
    let onMidiChange: (MidiTableItem, MIDIKind, Int, Int) -> Void
    let getOwnerName: (MIDIKind, Int, Int, UUID, String) -> String?
    var onDismissAll: (() -> Void)? = nil
    var onApply: (([MidiTableItem]) -> Void)? = nil

    var body: some View {
        NavigationLink(destination: MidiAssignmentEditSheet(
            item: $item,
            isGlobalChannel: isGlobalChannel,
            globalChannel: globalChannel,
            allowFullCCR: allowFullCCR,
            midiFiltersEnabled: midiFiltersEnabled,
            midiFilter: midiFilter,
            getEditableItems: getEditableItems,
            onMidiChange: onMidiChange,
            getOwnerName: getOwnerName,
            onDismissAll: onDismissAll,
            onApply: onApply
        )) {
            HStack(spacing: 0) {
                // Name Column
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body)
                        .lineLimit(1)
                    Text(item.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Type Column
                Text(item.midiType == .cc ? "CC" : "Note")
                    .font(.body)
                    .foregroundColor(.primary)
                    .frame(width: 70, alignment: .center)

                // Channel Column (only shown if not global)
                if !isGlobalChannel {
                    Text("\(item.channel)")
                        .font(.body)
                        .foregroundColor(.primary)
                        .frame(width: 80, alignment: .center)
                }

                // Value Column
                Text(item.midiType == .note ? "\(item.value) - \(item.value.midiNoteName)" : "\(item.value)")
                    .font(.body)
                    .foregroundColor(.primary)
                    .frame(width: 90, alignment: .center)

                // Chevron to indicate tappable
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
    }
}

// MARK: - MIDI Filter View
struct MidiFilterView: View {
    @AppStorage("midiFiltersEnabled") private var midiFiltersEnabled: Bool = true
    @Binding var midiFilter: Set<Int>
    @Binding var customMidiFilters: [(Int, String)]

    // Standard CC recommendations
    private let recommendedFilters: [(Int, String)] = [
        (1, "Mod Wheel"),
        (7, "Volume"),
        (10, "Pan"),
        (11, "Expression"),
        (64, "Sustain Pedal"),
        (120, "All Sound Off"),
        (121, "Reset All Controllers"),
        (122, "Local Control"),
        (123, "All Notes Off"),
        (124, "Omni Mode Off"),
        (125, "Omni Mode On"),
        (126, "Mono Mode On"),
        (127, "Poly Mode On")
    ]

    var body: some View {
        Form {
            // Master toggle section
            Section {
                Toggle(isOn: $midiFiltersEnabled) {
                    Text("Enable MIDI Filters")
                }
                .toggleStyle(SwitchToggleStyle(tint: selectedTheme.successColor(for: colorScheme)))
                .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
            }

            Section {
                Text("Exclude these MIDI CC numbers from auto-assignment. Common performance controllers (mod wheel, volume, sustain) are filtered by default to prevent conflicts.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))

            // Add Custom Filter Button
            Section {
                NavigationLink(destination: AddCustomFilterView(
                    midiFilter: $midiFilter,
                    customMidiFilters: $customMidiFilters
                )) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(selectedTheme.accentColor(for: colorScheme))
                        Text("Add Custom Filter")
                    }
                }
                .tint(selectedTheme.accentColor(for: colorScheme))
                .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                .disabled(!midiFiltersEnabled)
            }

            // Custom Filters Section
            if !customMidiFilters.isEmpty {
                Section("Custom Filters") {
                    ForEach(Array(customMidiFilters.enumerated()), id: \.offset) { index, filter in
                        let cc = filter.0
                        let name = filter.1

                        Toggle(isOn: Binding(
                            get: { midiFilter.contains(cc) },
                            set: { isOn in
                                if isOn {
                                    midiFilter.insert(cc)
                                } else {
                                    midiFilter.remove(cc)
                                }
                            }
                        )) {
                            HStack {
                                Text("CC \(cc)")
                                    .font(.body)
                                    .frame(width: 60, alignment: .leading)
                                Text(name)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: selectedTheme.successColor(for: colorScheme)))
                        .disabled(!midiFiltersEnabled)
                        .swipeActions {
                            Button(role: .destructive) {
                                midiFilter.remove(cc)
                                customMidiFilters.removeAll { $0.0 == cc && $0.1 == name }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let cc = customMidiFilters[index].0
                            midiFilter.remove(cc)
                        }
                        customMidiFilters.remove(atOffsets: indexSet)
                    }
                }
            }

            Section("Recommended Filters") {
                ForEach(recommendedFilters, id: \.0) { cc, name in
                    Toggle(isOn: Binding(
                        get: { midiFilter.contains(cc) },
                        set: { isOn in
                            if isOn {
                                midiFilter.insert(cc)
                            } else {
                                midiFilter.remove(cc)
                            }
                        }
                    )) {
                        HStack {
                            Text("CC \(cc)")
                                .font(.body)
                                .frame(width: 60, alignment: .leading)
                            Text(name)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: selectedTheme.successColor(for: colorScheme)))
                    .disabled(!midiFiltersEnabled)
                    .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(selectedTheme.backgroundColor(for: colorScheme))
        .navigationTitle("MIDI Filter")
        .navigationBarTitleDisplayMode(.inline)
        .tint(selectedTheme.accentColor(for: colorScheme))
    }

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }
}

// MARK: - Add Custom MIDI Filter View
struct AddCustomFilterView: View {
    @Binding var midiFilter: Set<Int>
    @Binding var customMidiFilters: [(Int, String)]

    @State private var customCC: Int = 0
    @State private var customDescription: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                CCNumberPicker(title: "CC Number", ccNumber: $customCC, disabled: false)
                    .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))

                TextField("Description", text: $customDescription)
                    .textInputAutocapitalization(.words)
                    .listRowBackground(selectedTheme.titleBarColor(for: colorScheme))
            } header: {
                Text("Custom MIDI Filter")
            } footer: {
                Text("Add a MIDI CC number with a custom description to exclude from auto-assignment")
            }
        }
        .scrollContentBackground(.hidden)
        .background(selectedTheme.backgroundColor(for: colorScheme))
        .navigationTitle("Add Custom Filter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                CBSheetButton(title: "Add", bold: true, disabled: customDescription.isEmpty) {
                    if !customDescription.isEmpty {
                        customMidiFilters.append((customCC, customDescription))
                        midiFilter.insert(customCC)
                    }
                    dismiss()
                }
            }
        }
        .tint(selectedTheme.accentColor(for: colorScheme))
    }

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") private var customDefaultCueColorStorage: String = ""

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }
}

// MARK: - Nav Pill Content Component
struct NavPillContent: View {
    let canPrev: Bool
    let canNext: Bool
    let onPrev: () -> Void
    let onNext: () -> Void
    let flashPrev: () -> Void
    let flashNext: () -> Void
    @Binding var isPrevPressed: Bool
    @Binding var isNextPressed: Bool
    let isDragging: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Top button: Up arrow (PREVIOUS)
            Button(action: {
                guard canPrev && !isDragging else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onPrev()
                flashPrev()
            }) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 35, weight: .bold))
                    .foregroundColor(canPrev ? .primary : .secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(IOSPressButtonStyle())
            .disabled(!canPrev || isDragging)

            Divider().frame(height: 1)

            // Bottom button: Down arrow (NEXT)
            Button(action: {
                guard canNext && !isDragging else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onNext()
                flashNext()
            }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 35, weight: .bold))
                    .foregroundColor(canNext ? .primary : .secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(IOSPressButtonStyle())
            .disabled(!canNext || isDragging)
        }
    }
}

// MARK: - Draggable Navigation Capsule (for Regular mode)
struct DraggableNavigationCapsule: View {
    let canPrev: Bool
    let canNext: Bool
    let onPrev: () -> Void
    let onNext: () -> Void
    @Binding var controlAreaHeight: CGFloat
    let isEditing: Bool  // Track control area mode for collision detection
    let titleBarBottom: CGFloat  // Bottom edge of title bar to avoid
    let editCapsuleBottom: CGFloat  // Bottom edge of edit capsules (0 if not visible)
    let sizeMultiplier: Double  // Appearance setting for pill size (0.7-1.5x)
    let isControlAreaCollapsed: Bool  // Whether control area is collapsed to small capsule
    let capsuleBounds: [String: CGRect]  // All UI capsule bounds for collision detection
    let hasControlButtons: Bool  // Whether there are control buttons in the control area
    let themeColor: Color  // Theme color for background
    var onTutorialDismiss: (() -> Void)? = nil  // Called when tutorial is dismissed, to resume interrupted tutorial

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var position: CGPoint = .zero
    @State private var isTrackingDrag: Bool = false
    @State private var isDragging: Bool = false
    @State private var dragDelayTask: Task<Void, Never>?
    @State private var isDragDelayComplete: Bool = false
    @State private var startDragPosition: CGPoint = .zero  // Position when drag started
    @State private var isPrevPressed: Bool = false
    @State private var isNextPressed: Bool = false
    @State private var prevFlashOpacity: Double = 0.0  // Flash for top half
    @State private var nextFlashOpacity: Double = 0.0  // Flash for bottom half
    @State private var distanceFromControlAreaTop: CGFloat = 100  // Distance to maintain from control area
    @State private var justFinishedDragging: Bool = false  // Prevent button clicks right after drag
    @State private var userDesiredPosition: CGPoint = .zero  // User's actual desired position (before collision adjustments)
    @State private var isExpanded: Bool = true  // Whether pill is expanded or collapsed - default is open
    @State private var hasSeenNavPillTutorial: Bool = false  // Track if user has seen the tutorial
    @State private var showNavPillTutorial: Bool = false  // Show tutorial popup
    @State private var tutorialFloatOffset: CGFloat = 4  // For continuous ghost-like floating animation (start at bottom)
    @State private var tutorialPosition: CGPoint = .zero  // Tutorial's calculated position
    @State private var tutorialWidth: CGFloat = 0  // Tutorial's measured width

    private let config = SwipeableCapsuleConfig.navPill

    // Vertical pill size - changes based on expanded state (uses config for consistency with cue capsule)
    private var pillSize: CGSize {
        isExpanded
            ? CGSize(width: config.expandedWidth * sizeMultiplier, height: config.expandedHeight * sizeMultiplier)
            : CGSize(width: config.collapsedWidth * sizeMultiplier, height: config.collapsedHeight * sizeMultiplier)
    }

    // Computed tutorial position that includes floating animation
    private var computedTutorialPosition: CGPoint {
        guard tutorialWidth > 0 else { return .zero }
        let navPillLeftEdge = position.x - pillSize.width / 2
        let tutorialX = navPillLeftEdge - config.tutorialSpacing - tutorialWidth / 2
        return CGPoint(x: tutorialX, y: position.y + tutorialFloatOffset)
    }

    // Collision detection: prevent nav pill from overlapping with UI capsules
    // Returns a position that doesn't collide, clamping to obstacle edges
    private func clampPositionAvoidingCapsules(_ proposedPoint: CGPoint, previousPoint: CGPoint, screenBounds: CGRect, isDragging: Bool = false) -> CGPoint {
        // If no capsuleBounds to check, return proposed position (no collision possible)
        guard !capsuleBounds.isEmpty else {
            return proposedPoint
        }

        // Filter out capsules that are off-screen (e.g., during transitions)
        // Only consider capsules that are actually visible on screen
        // EXCLUDE nav pill and cue capsule from collision check
        let visibleCapsules = capsuleBounds.filter { key, rect in
            key != "navPill.bounds" && key != "cueCapsule.bounds" && rect.intersects(screenBounds) && rect.minY < screenBounds.maxY && rect.maxY > 0
        }

        // Get nav pill's actual bounds if available, otherwise calculate from position
        let navPillActualBounds = capsuleBounds["navPill.bounds"]

        guard !visibleCapsules.isEmpty else {
            return proposedPoint
        }

        // Add spacing buffer around obstacles
        // Near-zero spacing for rounded shapes - they can nestle very close
        let spacing: CGFloat = 0.5

        // Helper function to check if a position collides with any UI capsule and is within screen bounds
        func isPositionValid(_ point: CGPoint) -> Bool {
            // Use actual nav pill bounds if available, otherwise calculate
            let testRect: CGRect
            if let actualBounds = navPillActualBounds {
                // Calculate what the bounds would be if nav pill moves to this point
                let offset = CGPoint(x: point.x - previousPoint.x, y: point.y - previousPoint.y)
                testRect = actualBounds.offsetBy(dx: offset.x, dy: offset.y)
            } else {
                // Fallback: calculate from size
                testRect = CGRect(
                    x: point.x - pillSize.width / 2,
                    y: point.y - pillSize.height / 2,
                    width: pillSize.width,
                    height: pillSize.height
                )
            }

            // Check if position is within screen bounds
            if testRect.minX < 0 || testRect.maxX > screenBounds.width ||
               testRect.minY < 0 || testRect.maxY > screenBounds.height {
                return false
            }

            // Check if position collides with any visible UI capsule
            for (_, capsuleRect) in visibleCapsules {
                let expandedRect = capsuleRect.insetBy(dx: -spacing, dy: -spacing)
                if testRect.intersects(expandedRect) {
                    return false
                }
            }
            return true
        }

        // If proposed position is valid, use it
        if isPositionValid(proposedPoint) {
            return proposedPoint
        }

        // During drag, allow movement along edges by only constraining the problematic axis
        if isDragging {
            // Calculate drag direction to prioritize the right axis
            let deltaX = abs(proposedPoint.x - previousPoint.x)
            let deltaY = abs(proposedPoint.y - previousPoint.y)

            // Prioritize the axis with more movement
            if deltaY > deltaX {
                // Vertical movement is stronger - try Y first (for sliding down corners)
                let yOnlyPoint = CGPoint(x: previousPoint.x, y: proposedPoint.y)
                if isPositionValid(yOnlyPoint) {
                    return yOnlyPoint
                }

                // Then try X movement
                let xOnlyPoint = CGPoint(x: proposedPoint.x, y: previousPoint.y)
                if isPositionValid(xOnlyPoint) {
                    return xOnlyPoint
                }
            } else {
                // Horizontal movement is stronger - try X first (for sliding along edges)
                let xOnlyPoint = CGPoint(x: proposedPoint.x, y: previousPoint.y)
                if isPositionValid(xOnlyPoint) {
                    return xOnlyPoint
                }

                // Then try Y movement
                let yOnlyPoint = CGPoint(x: previousPoint.x, y: proposedPoint.y)
                if isPositionValid(yOnlyPoint) {
                    return yOnlyPoint
                }
            }

            // Try diagonal movement with near-zero spacing for rounded edges
            let reducedSpacing: CGFloat = 0.5
            let testRect = CGRect(x: proposedPoint.x - pillSize.width / 2, y: proposedPoint.y - pillSize.height / 2, width: pillSize.width, height: pillSize.height)
            var hasCollision = false
            for (_, capsuleRect) in visibleCapsules {
                let expandedRect = capsuleRect.insetBy(dx: -reducedSpacing, dy: -reducedSpacing)
                if testRect.intersects(expandedRect) {
                    hasCollision = true
                    break
                }
            }
            if !hasCollision {
                return proposedPoint
            }

            // If all else fails, stay at previous position
            return previousPoint
        }

        // If proposed position would collide when not dragging, try to find a valid position nearby
        // First, try moving up (away from control area) - search further up (200pt)
        for yOffset in stride(from: -spacing, through: -200, by: -10) {
            let testPoint = CGPoint(x: proposedPoint.x, y: proposedPoint.y + yOffset)
            if isPositionValid(testPoint) {
                return testPoint
            }
        }

        // If still no valid position, try moving sideways
        for xOffset in stride(from: -spacing, through: -50, by: -10) {
            let testPoint = CGPoint(x: proposedPoint.x + xOffset, y: proposedPoint.y)
            if isPositionValid(testPoint) {
                return testPoint
            }
        }
        for xOffset in stride(from: spacing, through: 50, by: 10) {
            let testPoint = CGPoint(x: proposedPoint.x + xOffset, y: proposedPoint.y)
            if isPositionValid(testPoint) {
                return testPoint
            }
        }

        // If no valid position found, stay at previous position (stop movement)
        return previousPoint
    }

    // MARK: - Button Views

    private var collapsedChevron: some View {
        Button(action: {
            withAnimation(.easeOut(duration: 0.15)) {
                isExpanded = true
            }
        }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(IOSPressButtonStyle())
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            // Tutorial popup - positioned to the left of nav pill
            if showNavPillTutorial && isExpanded {
                SwipeableCapsuleTutorial(
                    text: config.tutorialText,
                    width: tutorialWidth,
                    position: computedTutorialPosition,
                    floatOffset: tutorialFloatOffset,
                    onDismiss: {
                        showNavPillTutorial = false
                        UserDefaults.standard.set(true, forKey: config.tutorialUserDefaultsKey)
                        // Resume any interrupted tutorial
                        onTutorialDismiss?()
                    }
                )
                .onPreferenceChange(TutorialWidthPreferenceKey.self) { width in
                    tutorialWidth = width
                }
                .zIndex(1000)  // Ensure tutorial appears above control area
            }

            VStack(spacing: 0) {
                if isExpanded {
                    NavPillContent(
                        canPrev: canPrev,
                        canNext: canNext,
                        onPrev: onPrev,
                        onNext: onNext,
                        flashPrev: flashPrev,
                        flashNext: flashNext,
                        isPrevPressed: $isPrevPressed,
                        isNextPressed: $isNextPressed,
                        isDragging: false
                    )
                } else {
                    collapsedChevron
                }
            }
            .frame(width: pillSize.width, height: pillSize.height)
            .background(
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .preference(
                            key: CapsuleBoundsPreferenceKey.self,
                            value: ["navPill.bounds": geo.frame(in: .global)]
                        )
                }
            )
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 30, coordinateSpace: .global)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) * 2 else { return }

                        if value.translation.width < -40 && !isExpanded {
                            withAnimation(.easeOut(duration: config.collapseAnimationDuration)) {
                                isExpanded = true
                            }
                        } else if value.translation.width > 40 && isExpanded {
                            withAnimation(.easeOut(duration: config.collapseAnimationDuration)) {
                                isExpanded = false
                            }
                        }
                    }
            )
            .position(position)
            .task(id: "\(width)-\(height)-\(isControlAreaCollapsed ? 1 : 0)-\(controlAreaHeight)") {
                guard width > 0 && height > 0 else { return }

                // Fixed to right edge - use current width based on expanded state
                let currentHalfWidth = isExpanded ? (config.expandedWidth * sizeMultiplier) / 2 : (config.collapsedWidth * sizeMultiplier) / 2
                let rightEdgeX = width - currentHalfWidth - 16  // 16pt padding from edge (matches other capsules)

                // Center vertically in available space (above control area)
                let currentControlHeight = isControlAreaCollapsed ? 56 : controlAreaHeight
                let availableHeight = height - currentControlHeight
                let centerY = availableHeight / 2

                position = CGPoint(x: rightEdgeX, y: centerY)
            }
            .onChange(of: isControlAreaCollapsed) { _, _ in
                // Recalculate Y position when control area collapses/expands
                let currentControlHeight = isControlAreaCollapsed ? 56 : controlAreaHeight
                let availableHeight = height - currentControlHeight
                let centerY = availableHeight / 2

                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    position = CGPoint(x: position.x, y: centerY)
                }
            }
            .onChange(of: controlAreaHeight) { oldHeight, newHeight in
                // Animate position when control area height changes smoothly
                // Skip if collapsed or if change is too small (debounce tiny adjustments)
                guard !isControlAreaCollapsed else { return }
                guard abs(newHeight - oldHeight) > 5 else { return }

                let availableHeight = height - newHeight
                let centerY = availableHeight / 2

                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    position = CGPoint(x: position.x, y: centerY)
                }
            }
            .onChange(of: isExpanded) { oldValue, newValue in
                // Adjust X position to keep collapsed pill flush to right edge
                // Expanded stays at same position, collapsed moves right
                let targetX: CGFloat
                if newValue {
                    // Expanding - position based on expanded width
                    targetX = width - (config.expandedWidth * sizeMultiplier / 2) - 16
                } else {
                    // Collapsing - position based on collapsed width (flush to edge)
                    targetX = width - (config.collapsedWidth * sizeMultiplier / 2) - 16
                }

                // Use fast animation for smooth horizontal movement
                withAnimation(.easeOut(duration: 0.15)) {
                    position = CGPoint(x: targetX, y: position.y)
                }

                // Hide tutorial when user interacts with nav pill
                showNavPillTutorial = false

                // Mark tutorial as seen
                UserDefaults.standard.set(true, forKey: config.tutorialUserDefaultsKey)
            }
            .onAppear {
                // Check if user has seen tutorial
                let hasSeenTutorial = UserDefaults.standard.bool(forKey: config.tutorialUserDefaultsKey)
                let shouldShowTutorial = !hasSeenTutorial

                if shouldShowTutorial {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        showNavPillTutorial = true
                        // Start ghost-like floating animation (bobs up and down from center)
                        withAnimation(.easeInOut(duration: config.tutorialFloatDuration).repeatForever(autoreverses: true)) {
                            tutorialFloatOffset = -4  // Animate from +4 to -4
                        }
                    }
                }
            }
        }
    }

    private func flashPrev() {
        prevFlashOpacity = 1.0
        withAnimation(.easeOut(duration: 0.25)) {
            prevFlashOpacity = 0.0
        }
    }

    private func flashNext() {
        nextFlashOpacity = 1.0
        withAnimation(.easeOut(duration: 0.25)) {
            nextFlashOpacity = 0.0
        }
    }
}

// MARK: - Swipeable Cue Capsule (matching nav pill design)
struct SimpleDraggableTransportDock: View {
    let cuedName: String?
    let canPrev: Bool
    let canNext: Bool
    let isGoEnabled: Bool
    let onPrev: () -> Void
    let onGo: () -> Void
    let onNext: () -> Void
    let onClear: () -> Void
    @Binding var controlAreaHeight: CGFloat
    let isEditing: Bool
    let titleBarBottom: CGFloat
    let editCapsuleBottom: CGFloat
    let sizeMultiplier: Double
    let isControlAreaCollapsed: Bool
    let capsuleBounds: [String: CGRect]
    let hasControlButtons: Bool
    let themeColor: Color  // Theme color for background
    var onTutorialDismiss: (() -> Void)? = nil  // Called when tutorial is dismissed, to resume interrupted tutorial

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var position: CGPoint = .zero
    @State private var isExpanded: Bool = true  // Default is open
    @State private var showCueCapsuleTutorial: Bool = false
    @State private var tutorialFloatOffset: CGFloat = 4  // Start at bottom of float range
    @State private var tutorialWidth: CGFloat = 0

    private let config = SwipeableCapsuleConfig.cueCapsule

    // Capsule size - changes based on expanded state
    private var capsuleSize: CGSize {
        isExpanded
            ? CGSize(width: config.expandedWidth * sizeMultiplier, height: config.expandedHeight * sizeMultiplier)
            : CGSize(width: config.collapsedWidth * sizeMultiplier, height: config.collapsedHeight * sizeMultiplier)
    }

    // Computed tutorial position that includes floating animation
    private var computedTutorialPosition: CGPoint {
        guard tutorialWidth > 0 else { return .zero }
        let capsuleLeftEdge = position.x - capsuleSize.width / 2
        let tutorialX = capsuleLeftEdge - config.tutorialSpacing - tutorialWidth / 2
        return CGPoint(x: tutorialX, y: position.y + tutorialFloatOffset)
    }

    // Collapsed chevron - matches nav pill design exactly
    private var collapsedChevron: some View {
        Button(action: {
            withAnimation(.easeOut(duration: config.collapseAnimationDuration)) {
                isExpanded = true
            }
        }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
                .frame(width: capsuleSize.width, height: capsuleSize.height, alignment: .center)
                .contentShape(Rectangle())
        }
        .buttonStyle(IOSPressButtonStyle())
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            // Tutorial popup - positioned to the left of cue capsule
            if showCueCapsuleTutorial && isExpanded {
                SwipeableCapsuleTutorial(
                    text: config.tutorialText,
                    width: tutorialWidth,
                    position: computedTutorialPosition,
                    floatOffset: tutorialFloatOffset,
                    onDismiss: {
                        showCueCapsuleTutorial = false
                        UserDefaults.standard.set(true, forKey: config.tutorialUserDefaultsKey)
                        // Resume any interrupted tutorial
                        onTutorialDismiss?()
                    }
                )
                .onPreferenceChange(TutorialWidthPreferenceKey.self) { width in
                    tutorialWidth = width
                }
                .zIndex(1000)  // Ensure tutorial appears above control area
            }

            VStack(spacing: 0) {
                if isExpanded {
                    CBTransportDock(
                        cuedName: cuedName,
                        canPrev: canPrev,
                        canNext: canNext,
                        isGoEnabled: isGoEnabled,
                        isDragging: false,
                        onPrev: onPrev,
                        onGo: onGo,
                        onNext: onNext,
                        onClear: onClear
                    )
                } else {
                    collapsedChevron
                }
            }
            .frame(width: capsuleSize.width, height: capsuleSize.height)
            .background(
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .preference(
                            key: CapsuleBoundsPreferenceKey.self,
                            value: ["cueCapsule.bounds": geo.frame(in: .global)]
                        )
                }
            )
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 30, coordinateSpace: .global)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) * 2 else { return }

                        if value.translation.width < -40 && !isExpanded {
                            withAnimation(.easeOut(duration: config.collapseAnimationDuration)) {
                                isExpanded = true
                            }
                        } else if value.translation.width > 40 && isExpanded {
                            withAnimation(.easeOut(duration: config.collapseAnimationDuration)) {
                                isExpanded = false
                            }
                        }
                    }
            )
            .position(position)
            .task(id: "\(width)-\(height)-\(isControlAreaCollapsed ? 1 : 0)-\(controlAreaHeight)") {
                guard width > 0 && height > 0 else { return }

                // Fixed to right edge - use current width based on expanded state
                let currentHalfWidth = isExpanded
                    ? (config.expandedWidth * sizeMultiplier) / 2
                    : (config.collapsedWidth * sizeMultiplier) / 2
                let rightEdgeX = width - currentHalfWidth - 16  // 16pt padding from edge (matches other capsules)

                // Center vertically in available space (above control area)
                let currentControlHeight = isControlAreaCollapsed ? 56 : controlAreaHeight
                let availableHeight = height - currentControlHeight
                let centerY = availableHeight / 2

                position = CGPoint(x: rightEdgeX, y: centerY)
            }
            .onChange(of: isControlAreaCollapsed) { _, _ in
                // Recalculate Y position when control area collapses/expands
                let currentControlHeight = isControlAreaCollapsed ? 56 : controlAreaHeight
                let availableHeight = height - currentControlHeight
                let centerY = availableHeight / 2

                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    position = CGPoint(x: position.x, y: centerY)
                }
            }
            .onChange(of: controlAreaHeight) { oldHeight, newHeight in
                // Animate position when control area height changes smoothly
                // Skip if collapsed or if change is too small (debounce tiny adjustments)
                guard !isControlAreaCollapsed else { return }
                guard abs(newHeight - oldHeight) > 5 else { return }

                let availableHeight = height - newHeight
                let centerY = availableHeight / 2

                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    position = CGPoint(x: position.x, y: centerY)
                }
            }
            .onChange(of: isExpanded) { oldValue, newValue in
                // Adjust X position to keep collapsed capsule flush to right edge
                // Expanded stays at same position, collapsed moves right
                let targetX: CGFloat
                if newValue {
                    // Expanding - position based on expanded width
                    targetX = width - (config.expandedWidth * sizeMultiplier / 2) - 16
                } else {
                    // Collapsing - position based on collapsed width (flush to edge)
                    targetX = width - (config.collapsedWidth * sizeMultiplier / 2) - 16
                }

                // Use fast animation for smooth horizontal movement
                withAnimation(.easeOut(duration: config.collapseAnimationDuration)) {
                    position = CGPoint(x: targetX, y: position.y)
                }

                // Hide tutorial when user interacts
                showCueCapsuleTutorial = false

                // Mark tutorial as seen
                UserDefaults.standard.set(true, forKey: config.tutorialUserDefaultsKey)
            }
            .onAppear {
                // Check if user has seen tutorial
                let hasSeenTutorial = UserDefaults.standard.bool(forKey: config.tutorialUserDefaultsKey)
                let shouldShowTutorial = !hasSeenTutorial

                if shouldShowTutorial {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        showCueCapsuleTutorial = true
                        // Start ghost-like floating animation (bobs up and down from center)
                        withAnimation(.easeInOut(duration: config.tutorialFloatDuration).repeatForever(autoreverses: true)) {
                            tutorialFloatOffset = -4  // Animate from +4 to -4
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Design Preview Sheet
struct DesignPreviewSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
    
    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }
    
    // Sample cues for preview
    private var sampleCues: [Song] {
        var cue1 = Song(id: UUID(), name: "Opening Number", subtitle: "Full Band", cc: 0, channel: 1)
        cue1.colorHex = "FF9500"

        var cue2 = Song(id: UUID(), name: "Act 1 Scene 2", subtitle: "Piano & Strings", cc: 1, channel: 1)
        cue2.colorHex = "30D158"

        var cue3 = Song(id: UUID(), name: "Intermission", subtitle: nil, cc: 2, channel: 1)
        cue3.colorHex = "0A84FF"

        var cue4 = Song(id: UUID(), name: "Finale", subtitle: "Full Orchestra", cc: 3, channel: 1)
        cue4.colorHex = "FF453A"

        return [cue1, cue2, cue3, cue4]
    }
    
    @State private var selectedCue: UUID? = nil
    @State private var lastPlayedCue: UUID? = nil
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Tap cues to see different states")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                    
                    // Preview cue list
                    VStack(spacing: 12) {
                        ForEach(sampleCues) { cue in
                            previewCueButton(cue)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .background(selectedTheme.backgroundColor(for: colorScheme))
            .navigationTitle("Design Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    CBSheetButton(title: "Done", bold: true) { dismiss() }
                }
            }
        }
    }

    private func previewCueButton(_ cue: Song) -> some View {
        let isCued = selectedCue == cue.id
        let isLastPlayed = lastPlayedCue == cue.id
        let baseColor = Color(hex: cue.colorHex ?? "0A84FF")
        let corner: CGFloat = 16

        return Button(action: {
            if selectedCue == cue.id {
                lastPlayedCue = cue.id
                selectedCue = nil
            } else {
                lastPlayedCue = selectedCue
                selectedCue = cue.id
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }) {
            ZStack(alignment: .center) {
                // Simple button background
                RoundedRectangle(cornerRadius: corner)
                    .fill(baseColor)
                    .frame(maxWidth: .infinity, minHeight: isCued ? 103.2 : 86)

                HStack(spacing: 14) {
                    // Play icon
                    if isCued || isLastPlayed {
                        Image(systemName: "play.fill")
                            .font(.system(size: isCued ? 28 : 24, weight: .bold))
                            .foregroundColor(Color(uiColor: .systemBackground))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(cue.name)
                            .font(.system(size: isCued ? 28 : 22, weight: .bold))
                            .foregroundColor(Color(uiColor: .systemBackground))
                            .lineLimit(1)
                        if let sub = cue.subtitle, !sub.isEmpty {
                            Text(sub)
                                .font(isCued ? .headline : .footnote)
                                .foregroundColor(Color(uiColor: .systemBackground).opacity(0.8))
                        }
                    }

                    Spacer()

                    // MIDI info
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("CC \(cue.cc)")
                            .font(.caption.bold())
                            .foregroundColor(Color(uiColor: .systemBackground).opacity(0.7))
                        Text("Ch \(cue.channel)")
                            .font(.caption2)
                            .foregroundColor(Color(uiColor: .systemBackground).opacity(0.6))
                    }
                }
                .padding(.horizontal, isCued ? 24 : 20)
                .padding(.vertical, isCued ? 12 : 8)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCued)
    }
}
