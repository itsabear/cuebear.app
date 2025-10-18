//
//  TutorialView.swift — Cue Bear
//  Interactive tutorial that guides users through key features
//

import SwiftUI

// MARK: - Tutorial Coordinator
/// Manages the interactive tutorial flow with contextual overlays
class TutorialCoordinator: ObservableObject {
    @Published var isActive: Bool = false
    @Published var currentStep: TutorialStep = .welcome
    @Published var highlightedArea: TutorialHighlight? = nil

    enum TutorialStep: Int, CaseIterable {
        case welcome
        case addFirstCue
        case testCue
        case editCue
        case addControl
        case editControl
        case explore
        case complete

        var title: String {
            switch self {
            case .welcome: return "Let's Get Started!"
            case .addFirstCue: return "Add Your First Cue"
            case .testCue: return "Test Your Cue"
            case .editCue: return "Edit a Cue"
            case .addControl: return "Add a Control"
            case .editControl: return "Edit a Control"
            case .explore: return "Explore More"
            case .complete: return "You're All Set!"
            }
        }

        var description: String {
            switch self {
            case .welcome:
                return "This quick tutorial will show you how to use Cue Bear's main features."
            case .addFirstCue:
                return "Tap the + button in the Cue Mode tab to add your first cue."
            case .testCue:
                return "Great! Now tap your new cue to send MIDI and see it flash."
            case .editCue:
                return "Long-press any cue to edit its name, MIDI values, or delete it."
            case .addControl:
                return "Switch to the Control Area tab and tap + to add a control button."
            case .editControl:
                return "Long-press a control to edit it or change its MIDI assignment."
            case .explore:
                return "Try the Settings tab to manage connections, change themes, and customize your experience."
            case .complete:
                return "You're ready to rock! Keep exploring and don't hesitate to reach out if you need help."
            }
        }

        var icon: String {
            switch self {
            case .welcome: return "hand.wave.fill"
            case .addFirstCue: return "plus.circle.fill"
            case .testCue: return "hand.tap.fill"
            case .editCue: return "pencil.circle.fill"
            case .addControl: return "plus.square.fill"
            case .editControl: return "slider.horizontal.3"
            case .explore: return "magnifyingglass.circle.fill"
            case .complete: return "checkmark.circle.fill"
            }
        }

        var actionButtonTitle: String {
            switch self {
            case .complete: return "Finish Tutorial"
            default: return "Next"
            }
        }
    }

    enum TutorialHighlight {
        case addCueButton
        case cueList
        case addControlButton
        case controlButtons
        case settingsTab
    }

    func start() {
        isActive = true
        currentStep = .welcome
    }

    func nextStep() {
        if let nextStep = TutorialStep(rawValue: currentStep.rawValue + 1) {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = nextStep
            }
            updateHighlight()
        } else {
            complete()
        }
    }

    func skipTutorial() {
        complete()
    }

    func complete() {
        UserDefaults.standard.set(true, forKey: "hasCompletedTutorial")
        withAnimation(.easeInOut(duration: 0.3)) {
            isActive = false
        }
    }

    private func updateHighlight() {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch currentStep {
            case .addFirstCue:
                highlightedArea = .addCueButton
            case .testCue:
                highlightedArea = .cueList
            case .editCue:
                highlightedArea = .cueList
            case .addControl:
                highlightedArea = .addControlButton
            case .editControl:
                highlightedArea = .controlButtons
            case .explore:
                highlightedArea = .settingsTab
            default:
                highlightedArea = nil
            }
        }
    }
}

// MARK: - Tutorial Overlay
/// Full-screen overlay that shows tutorial instructions
struct TutorialOverlay: View {
    @ObservedObject var coordinator: TutorialCoordinator

    var body: some View {
        if coordinator.isActive {
            ZStack {
                // Semi-transparent backdrop
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .transition(.opacity)

                // Tutorial card
                VStack(spacing: 0) {
                    // Step indicator
                    HStack {
                        Text("Step \(coordinator.currentStep.rawValue + 1) of \(TutorialCoordinator.TutorialStep.allCases.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    Spacer()

                    // Icon
                    Image(systemName: coordinator.currentStep.icon)
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(.accentColor)
                        .padding(.bottom, 24)

                    // Title
                    Text(coordinator.currentStep.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 16)

                    // Description
                    Text(coordinator.currentStep.description)
                        .font(.system(size: 17))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 32)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            coordinator.nextStep()
                        }) {
                            Text(coordinator.currentStep.actionButtonTitle)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        if coordinator.currentStep != .complete {
                            Button(action: {
                                coordinator.skipTutorial()
                            }) {
                                Text("Skip Tutorial")
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
                .frame(maxWidth: 500)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                .padding(40)
            }
            .transition(.opacity)
        }
    }
}

// MARK: - Tutorial Highlight Modifier
/// View modifier that adds a pulsing highlight effect to specific UI elements
struct TutorialHighlightModifier: ViewModifier {
    let isHighlighted: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .opacity(isHighlighted ? 1 : 0)
                    .scaleEffect(isHighlighted ? 1.05 : 1)
                    .animation(
                        isHighlighted ?
                            Animation.easeInOut(duration: 1.0)
                                .repeatForever(autoreverses: true) :
                            .default,
                        value: isHighlighted
                    )
            )
    }
}

extension View {
    func tutorialHighlight(_ isHighlighted: Bool) -> some View {
        self.modifier(TutorialHighlightModifier(isHighlighted: isHighlighted))
    }
}

// MARK: - Tutorial Step Completion Tracking
extension TutorialCoordinator {
    /// Call this when user completes a specific action during tutorial
    func markStepCompleted(_ step: TutorialStep) {
        if currentStep == step {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.nextStep()
            }
        }
    }

    /// Check if user should see tutorial
    static func shouldShowTutorial() -> Bool {
        let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        let hasCompletedTutorial = UserDefaults.standard.bool(forKey: "hasCompletedTutorial")
        return hasSeenOnboarding && !hasCompletedTutorial
    }
}

// MARK: - Previews
#Preview("Tutorial - Welcome") {
    TutorialOverlay(coordinator: {
        let coordinator = TutorialCoordinator()
        coordinator.isActive = true
        coordinator.currentStep = .welcome
        return coordinator
    }())
}

#Preview("Tutorial - Add Cue") {
    TutorialOverlay(coordinator: {
        let coordinator = TutorialCoordinator()
        coordinator.isActive = true
        coordinator.currentStep = .addFirstCue
        return coordinator
    }())
}

#Preview("Tutorial - Complete") {
    TutorialOverlay(coordinator: {
        let coordinator = TutorialCoordinator()
        coordinator.isActive = true
        coordinator.currentStep = .complete
        return coordinator
    }())
}

#Preview("Tutorial - Dark Mode") {
    TutorialOverlay(coordinator: {
        let coordinator = TutorialCoordinator()
        coordinator.isActive = true
        coordinator.currentStep = .addControl
        return coordinator
    }())
    .preferredColorScheme(.dark)
}
