import SwiftUI
import AppKit

// UserDefaults key for tracking if onboarding has been shown
extension UserDefaults {
    private static let hasShownOnboardingKey = "hasShownOnboarding"

    var hasShownOnboarding: Bool {
        get { bool(forKey: Self.hasShownOnboardingKey) }
        set { set(newValue, forKey: Self.hasShownOnboardingKey) }
    }
}

// Onboarding Window View
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage: Int = 0
    @State private var dontShowAgain: Bool = false
    @State private var isMovingForward: Bool = true
    @Environment(\.colorScheme) var colorScheme

    private let totalPages = 4

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                // Page content area
                ZStack {
                    // Page 1: Welcome
                    if currentPage == 0 {
                        welcomePage
                            .id(0)
                            .transition(.asymmetric(insertion: .move(edge: isMovingForward ? .trailing : .leading),
                                                   removal: .move(edge: isMovingForward ? .leading : .trailing)))
                    }

                    // Page 2: Download App
                    if currentPage == 1 {
                        downloadPage
                            .id(1)
                            .transition(.asymmetric(insertion: .move(edge: isMovingForward ? .trailing : .leading),
                                                   removal: .move(edge: isMovingForward ? .leading : .trailing)))
                    }

                    // Page 3: Connect
                    if currentPage == 2 {
                        connectPage
                            .id(2)
                            .transition(.asymmetric(insertion: .move(edge: isMovingForward ? .trailing : .leading),
                                                   removal: .move(edge: isMovingForward ? .leading : .trailing)))
                    }

                    // Page 4: Enjoy
                    if currentPage == 3 {
                        enjoyPage
                            .id(3)
                            .transition(.asymmetric(insertion: .move(edge: isMovingForward ? .trailing : .leading),
                                                   removal: .move(edge: isMovingForward ? .leading : .trailing)))
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: currentPage)
                .frame(maxHeight: .infinity)

                // Footer with navigation
                VStack(spacing: 12) {
                    // Don't show again checkbox (only on last page)
                    if currentPage == totalPages - 1 {
                        Toggle("Don't show this again", isOn: $dontShowAgain)
                            .padding(.horizontal, 40)
                            .padding(.top, 12)
                    }

                    // Page indicator
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.bottom, 8)

                    // Single CTA button (always visible in same position)
                    Button(action: {
                        if currentPage < totalPages - 1 {
                            withAnimation {
                                isMovingForward = true
                                currentPage += 1
                            }
                        } else {
                            // Last page - close onboarding
                            if dontShowAgain {
                                UserDefaults.standard.hasShownOnboarding = true
                            }
                            isPresented = false
                        }
                    }) {
                        Text(currentPage < totalPages - 1 ? "Next" : "Get Started")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.accentColor)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 40)
                }
                .padding(.bottom, 20)
            }

            // Back chevron button (top-left, only when not on first page)
            if currentPage > 0 {
                Button(action: {
                    withAnimation {
                        isMovingForward = false
                        currentPage -= 1
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.leading, 20)
                .padding(.top, 20)
            }
        }
        .frame(width: 500, height: 480)
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: 30) {
            Spacer()

            // App icon (3D bear paw)
            Image("CueBearAppIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 128, height: 128)

            Text("Welcome to Cue Bear Bridge")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    private var downloadPage: some View {
        VStack(spacing: 30) {
            Spacer()

            // QR Code - standard black QR works in both light and dark mode
            Image("AppStoreQR")
                .resizable()
                .interpolation(.none)
                .frame(width: 128, height: 128)
                .cornerRadius(8)

            Text("Download the cue bear app")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    private var connectPage: some View {
        VStack(spacing: 30) {
            Spacer()

            Text("Connect Your iPad")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            HStack(alignment: .center, spacing: 40) {
                // USB option
                VStack(spacing: 12) {
                    Image(systemName: "cable.connector")
                        .font(.system(size: 56))
                        .foregroundColor(.accentColor)
                        .frame(height: 56)
                    Text("USB")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(height: 20)
                }
                .frame(width: 80)

                Text("or")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .frame(width: 40)

                // WiFi option
                VStack(spacing: 12) {
                    Image(systemName: "wifi")
                        .font(.system(size: 56))
                        .foregroundColor(.accentColor)
                        .frame(height: 56)
                    Text("WiFi")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(height: 20)
                }
                .frame(width: 80)
            }

            Spacer()
        }
    }

    private var enjoyPage: some View {
        VStack(spacing: 30) {
            Spacer()

            Text("Enjoy using Cue Bear App!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Text("We'd love to hear from you on")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("info@cuebear.app")
                .font(.body)
                .foregroundColor(.accentColor)
                .multilineTextAlignment(.center)

            Spacer()
        }
    }
}

// Window controller for the onboarding window
class OnboardingWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 480),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = ""
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false

        self.init(window: window)
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// Helper class to manage onboarding window
@MainActor
class OnboardingManager: ObservableObject {
    @Published var isShowingOnboarding = false
    private var windowController: OnboardingWindowController?
    private var hasCheckedOnboarding = false

    init() {
        // Schedule onboarding check to run immediately after app launches
        // This ensures it shows on first launch without waiting for menu bar click
        Task { @MainActor in
            // Small delay to let app fully initialize
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            self.showOnboardingIfNeeded()
        }
    }

    func showOnboarding() {
        isShowingOnboarding = true

        if windowController == nil {
            windowController = OnboardingWindowController()
        }

        let hostingView = NSHostingView(
            rootView: OnboardingView(isPresented: Binding(
                get: { self.isShowingOnboarding },
                set: { newValue in
                    self.isShowingOnboarding = newValue
                    if !newValue {
                        // Close the window when isPresented becomes false
                        self.windowController?.window?.close()
                    }
                }
            ))
        )

        windowController?.window?.contentView = hostingView
        windowController?.show()
    }

    func showOnboardingIfNeeded() {
        // Only check once to avoid showing multiple times
        guard !hasCheckedOnboarding else { return }
        hasCheckedOnboarding = true

        if !UserDefaults.standard.hasShownOnboarding {
            showOnboarding()
        }
    }
}

// MARK: - Xcode Preview
#Preview("Onboarding Window") {
    OnboardingView(isPresented: .constant(true))
        .frame(width: 500, height: 480)
}
