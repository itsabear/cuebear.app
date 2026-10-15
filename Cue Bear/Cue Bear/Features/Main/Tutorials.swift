//
//  Tutorials.swift — Cue Bear
//  (split out of ContentView.swift)
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Combine

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
                        .font(.cbIcon(.large, .regular))
                        .foregroundStyle(CBColor.textPrimary)

                    Text(text)
                        .font(.cb(.small, .medium))
                        .foregroundStyle(CBColor.textPrimary)
                }

                if let onSkip = onSkip {
                    Button("Skip") { onSkip() }
                        .font(.cb(.caption, .regular))
                        .foregroundStyle(CBColor.textSecondary)
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
            .clipShape(RoundedRectangle(cornerRadius: CBRadius.card))
            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)

            // Arrow pointing to capsule
            Image(systemName: "arrowtriangle.right.fill")
                .font(.cbIcon(.large, .regular))
                .foregroundStyle(CBColor.highlight)
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
                    .font(.cbIcon(.body, .regular))
                    .foregroundStyle(CBColor.highlight)
                    .offset(x: arrowOffset, y: 2)

                // Main tutorial bubble
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.tap")
                            .font(.cbIcon(.large, .regular))
                            .foregroundStyle(CBColor.textPrimary)

                        Text(message)
                            .font(.cb(.small, .medium))
                            .foregroundStyle(CBColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let onSkip = onSkip {
                        Button("Skip") { onSkip() }
                            .font(.cb(.caption, .regular))
                            .foregroundStyle(CBColor.textSecondary)
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
                .clipShape(RoundedRectangle(cornerRadius: CBRadius.card))
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
                            .font(.cbIcon(.large, .regular))
                            .foregroundStyle(CBColor.textPrimary)

                        Text(message)
                            .font(.cb(.small, .medium))
                            .foregroundStyle(CBColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let onSkip = onSkip {
                        Button("Skip") { onSkip() }
                            .font(.cb(.caption, .regular))
                            .foregroundStyle(CBColor.textSecondary)
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
                .clipShape(RoundedRectangle(cornerRadius: CBRadius.card))
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
                    .font(.cbIcon(.body, .regular))
                    .foregroundStyle(CBColor.highlight)
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
