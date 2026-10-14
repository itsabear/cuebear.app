    import SwiftUI

    @main
    struct CueBearApp: App {
        @StateObject private var store = SetlistStore()
        @StateObject private var usbServer = ConnectionManager()
        @StateObject private var wifiClient = BridgeOutput()
        @StateObject private var connectionCoordinator = ConnectionCoordinator()

        @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
        @State private var showingCrashAlert = false
        @State private var crashAlertWasDismissed = false

        private var selectedTheme: AppTheme {
            AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
        }

        init() {
            // Setup crash handlers as early as possible
            CrashReporter.shared.setupCrashHandlers()
            CBAppearance.apply()   // design foundation: UIKit fonts and colors (Design/CBTokens.swift)
        }

        var body: some Scene {
            WindowGroup {
                ThemedContentView(crashAlertActive: $showingCrashAlert)
                    .environmentObject(store)
                    .environmentObject(usbServer)
                    .environmentObject(wifiClient)
                    .environmentObject(connectionCoordinator)
                    .sheet(isPresented: $showingCrashAlert) {
                        CrashAlertView()
                            .interactiveDismissDisabled() // Prevent dismissing by swiping down
                            .onDisappear {
                                crashAlertWasDismissed = true
                            }
                    }
                    .task {
                        // Check if previous session crashed BEFORE marking as launched
                        if CrashReporter.shared.checkForCrash() {
                            // Show crash alert after UI is initialized
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showingCrashAlert = true
                            }
                        }

                        // Mark app as launched successfully (clears crash flag if no crash occurred)
                        CrashReporter.shared.markAppLaunched()

                        debugPrint("📱 iPad: starting connection coordinator")

                        #if DEBUG
                        // Debug: Check if custom fonts are loaded
                        FontDebugHelper.checkCustomFonts()
                        #endif

                        // v1.3 (Cue Bear Next): demo shows install on every device, so a new user
                        // can press GO before setting anything up.
                        DemoShows.installIfNeeded()

                        // Prevent screen from locking during live performance
                        UIApplication.shared.isIdleTimerDisabled = true
                        debugPrint("📱 iPad: Screen lock disabled for live performance")

                        // Fix window size on iPad (prevents height resizing in Stage Manager on iPadOS 18+)
                        // Setting min and max to the same size makes the window non-resizable
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            windowScene.sizeRestrictions?.minimumSize = CGSize(width: 1024, height: 768)
                            windowScene.sizeRestrictions?.maximumSize = CGSize(width: 1024, height: 768)
                            debugPrint("📱 iPad: Window size fixed to 1024x768 (non-resizable)")
                        }

                        // Configure the connection coordinator
                        connectionCoordinator.configure(usbServer: usbServer, wifiClient: wifiClient)
                        // Start connections through coordinator
                        connectionCoordinator.startConnections()
                        // v1.3: two computers at once (backup Mac), if one has been chosen
                        BackupRigManager.shared.configure(mainWiFi: wifiClient, usbServer: usbServer, tint: .accentColor)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                        debugPrint("📱 iPad: App entered background - iOS grants ~30s before suspension")
                        // beginBackgroundTask gives ~30s of background time on iOS (no UIBackgroundModes declared).
                        // Connection will auto-reconnect immediately when returning to foreground.
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                        debugPrint("📱 iPad: App entering foreground - reconnecting if needed")
                        // Check if connections are still alive and restart if needed (typically 1-3 seconds)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if !usbServer.isConnected && !wifiClient.isConnected {
                                debugPrint("📱 iPad: No connections active, restarting...")
                                connectionCoordinator.startConnections()
                            }
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                        debugPrint("📱 iPad: App became active - ensuring connections are healthy")
                        // Ensure connections are healthy when app becomes active
                        connectionCoordinator.checkConnectionHealth()
                    }
            }
            .windowResizability(.contentMinSize)
        }

    }

    // Wrapper to apply theme-based tint at root level (needs @Environment for colorScheme)
    private struct ThemedContentView: View {
        @Binding var crashAlertActive: Bool
        @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"
        @Environment(\.colorScheme) private var colorScheme
        @EnvironmentObject private var wifiClient: BridgeOutput

        private var selectedTheme: AppTheme {
            AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
        }

        var body: some View {
            ContentView(crashAlertActive: $crashAlertActive)
                .font(.cb(.body))   // the interface typeface everywhere, unless a view sets its own
                .tint(selectedTheme.accentColor(for: colorScheme))
                // v1.2.1: pairing with the Mac Bridge, shown in its own top-level window
                // so it appears above sheets and popovers (see PairingOverlay.swift).
                .onChange(of: wifiClient.pairingPrompt != nil) { _, showing in
                    PairingWindowPresenter.shared.setVisible(showing, wifiClient: wifiClient,
                                                             tint: selectedTheme.accentColor(for: colorScheme))
                }
        }
    }
