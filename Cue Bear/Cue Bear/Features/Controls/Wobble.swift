//
//  Wobble.swift — Cue Bear
//  (split out of ContentView.swift)
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Combine

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
