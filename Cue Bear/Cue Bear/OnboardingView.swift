//
//  OnboardingView.swift — Cue Bear
//  3-step onboarding flow with swipeable pages
//

import SwiftUI

// MARK: - Onboarding View
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    @State private var dontShowAgain = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Welcome to Cue Bear",
            description: "A MIDI controller built around your set list.",
            systemIcon: "music.note.list",
            accentColor: .blue
        ),
        OnboardingPage(
            title: "Connect Your Mac",
            description: "Go to cuebear.app/bridge to download our companion app and install it on your Mac to connect seamlessly to your iPad over USB or WiFi.",
            systemIcon: "laptopcomputer",
            accentColor: .blue
        ),
        OnboardingPage(
            title: "Enable MIDI Device",
            description: "Enable \"Bear Bridge\" virtual MIDI device in your DAW.",
            systemIcon: "slider.horizontal.3",
            accentColor: .blue
        ),
        OnboardingPage(
            title: "We'd Love Your Feedback",
            description: "This app is in beta. We'd love to hear your take on our app. Hit us up on info@cuebear.app",
            systemIcon: "envelope.fill",
            accentColor: .blue
        )
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Main content with TabView for swiping
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(
                            page: page,
                            isLastPage: index == pages.count - 1,
                            dontShowAgain: $dontShowAgain,
                            onGetStarted: {
                                if dontShowAgain {
                                    UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                                }
                                dismiss()
                            }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
            .navigationTitle("Get Started")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if currentPage < pages.count - 1 {
                        Button("Skip") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Onboarding Page Model
struct OnboardingPage {
    let title: String
    let description: String
    let systemIcon: String
    let accentColor: Color
}

// MARK: - Individual Page View
struct OnboardingPageView: View {
    let page: OnboardingPage
    let isLastPage: Bool
    @Binding var dontShowAgain: Bool
    let onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                // Icon - fixed height
                Image(systemName: page.systemIcon)
                    .font(.system(size: 72, weight: .light))
                    .foregroundColor(page.accentColor)
                    .frame(height: 72)

                // Title - fixed height with padding
                Text(page.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .frame(minHeight: 70)
                    .fixedSize(horizontal: false, vertical: true)

                // Description - fixed height with padding
                Text(page.description)
                    .font(.system(size: 17, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 50)
                    .frame(minHeight: 110)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // "Get Started" button and "Don't show again" on last page
            if isLastPage {
                VStack(spacing: 20) {
                    // Don't show again checkbox - centered
                    Button(action: {
                        dontShowAgain.toggle()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: dontShowAgain ? "checkmark.square.fill" : "square")
                                .foregroundColor(dontShowAgain ? page.accentColor : .secondary)
                                .font(.system(size: 22))
                            Text("Don't show again")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Get Started button
                    Button(action: onGetStarted) {
                        Text("Get Started")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(page.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 40)
                }
                .padding(.bottom, 50)
            } else {
                // Spacer to maintain consistent layout on non-final pages
                Color.clear.frame(height: 120)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Compact Variant (Alternative Design)
/// Alternative compact design that uses a card-based layout similar to the connection sheets
struct OnboardingViewCompact: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    private let totalPages = 3

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                // Content changes based on current page
                VStack(spacing: 32) {
                    // Icon
                    Image(systemName: pageIcon)
                        .font(.system(size: 70, weight: .light))
                        .foregroundColor(.accentColor)

                    // Title & Description
                    VStack(spacing: 16) {
                        Text(pageTitle)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)

                        Text(pageDescription)
                            .font(.system(size: 17, weight: .regular))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 32)
                }

                Spacer()

                // Page indicators (dots)
                HStack(spacing: 10) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }
                .padding(.bottom, 20)

                // Navigation buttons
                HStack(spacing: 16) {
                    if currentPage > 0 {
                        Button(action: previousPage) {
                            Text("Back")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.accentColor)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    Button(action: currentPage < totalPages - 1 ? nextPage : dismiss.callAsFunction) {
                        Text(currentPage < totalPages - 1 ? "Next" : "Get Started")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if currentPage < totalPages - 1 {
                        Button("Skip") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // Page content computed properties
    private var pageIcon: String {
        switch currentPage {
        case 0: return "music.note.list"
        case 1: return "laptopcomputer"
        case 2: return "envelope.fill"
        default: return "music.note.list"
        }
    }

    private var pageTitle: String {
        switch currentPage {
        case 0: return "Welcome to Cue Bear"
        case 1: return "Connect Your Mac"
        case 2: return "We'd Love Your Feedback"
        default: return ""
        }
    }

    private var pageDescription: String {
        switch currentPage {
        case 0: return "A MIDI controller built around your set list."
        case 1: return "Go to cuebear.app/bridge to download our companion app and enjoy seamless connection to your Mac via USB or WiFi."
        case 2: return "This app is in beta. We'd love to hear your take on our app. Hit us up on info@cuebear.app"
        default: return ""
        }
    }

    // Navigation helpers
    private func nextPage() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPage = min(currentPage + 1, totalPages - 1)
        }
    }

    private func previousPage() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPage = max(currentPage - 1, 0)
        }
    }
}

// MARK: - Previews
#Preview("Onboarding Flow - Swipeable") {
    OnboardingView()
}

#Preview("Onboarding - Step 1") {
    NavigationView {
        OnboardingPageView(
            page: OnboardingPage(
                title: "Welcome to Cue Bear",
                description: "A MIDI controller built around your set list.",
                systemIcon: "music.note.list",
                accentColor: .blue
            ),
            isLastPage: false,
            dontShowAgain: .constant(false),
            onGetStarted: {}
        )
        .navigationTitle("Get Started")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Onboarding - Step 2") {
    NavigationView {
        OnboardingPageView(
            page: OnboardingPage(
                title: "Connect Your Mac",
                description: "Go to cuebear.app/bridge to download our companion app and enjoy seamless connection to your Mac via USB or WiFi.",
                systemIcon: "laptopcomputer",
                accentColor: .blue
            ),
            isLastPage: false,
            dontShowAgain: .constant(false),
            onGetStarted: {}
        )
        .navigationTitle("Get Started")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Onboarding - Step 3") {
    NavigationView {
        OnboardingPageView(
            page: OnboardingPage(
                title: "Enable MIDI Device",
                description: "Enable \"Bear Bridge\" virtual MIDI device in your DAW.",
                systemIcon: "slider.horizontal.3",
                accentColor: .blue
            ),
            isLastPage: false,
            dontShowAgain: .constant(false),
            onGetStarted: {}
        )
        .navigationTitle("Get Started")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Onboarding - Step 4 (Final)") {
    NavigationView {
        OnboardingPageView(
            page: OnboardingPage(
                title: "We'd Love Your Feedback",
                description: "This app is in beta. We'd love to hear your take on our app. Hit us up on info@cuebear.app",
                systemIcon: "envelope.fill",
                accentColor: .blue
            ),
            isLastPage: true,
            dontShowAgain: .constant(false),
            onGetStarted: {}
        )
        .navigationTitle("Get Started")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Onboarding Flow - Compact (Button Navigation)") {
    OnboardingViewCompact()
}

#Preview("Onboarding - Dark Mode") {
    OnboardingView()
        .preferredColorScheme(.dark)
}

#Preview("Onboarding Compact - Dark Mode") {
    OnboardingViewCompact()
        .preferredColorScheme(.dark)
}
