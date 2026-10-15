//
//  NavigationCapsule.swift — Cue Bear
//  (split out of ContentView.swift)
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Combine

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
                    .font(.cbIcon(.heading, .bold))
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
                    .font(.cbIcon(.heading, .bold))
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
                .font(.cbIcon(.large, .bold))
                .foregroundStyle(CBColor.textPrimary)
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
                    RoundedRectangle(cornerRadius: CBRadius.panel)
                        .fill(CBColor.chip)
                        .overlay(
                            RoundedRectangle(cornerRadius: CBRadius.panel)
                                .stroke(CBColor.stroke, lineWidth: CBSize.hairline)
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
                .font(.cbIcon(.large, .bold))
                .foregroundStyle(CBColor.textPrimary)
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
                    RoundedRectangle(cornerRadius: CBRadius.panel)
                        .fill(Color.black.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: CBRadius.panel)
                                .stroke(CBColor.stroke, lineWidth: CBSize.hairline)
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
