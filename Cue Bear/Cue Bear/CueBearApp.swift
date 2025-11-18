import SwiftUI

@main
struct CueBearApp: App {
    @StateObject private var store = SetlistStore()
    @StateObject private var usbServer = ConnectionManager()
    @StateObject private var wifiClient = BridgeOutput()
    @StateObject private var connectionCoordinator = ConnectionCoordinator()

    @State private var showingCrashAlert = false
    @State private var crashAlertWasDismissed = false

    init() {
        // Setup crash handlers as early as possible
        CrashReporter.shared.setupCrashHandlers()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(crashAlertActive: $showingCrashAlert)
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

                    // Debug: Check if custom fonts are loaded
                    FontDebugHelper.checkCustomFonts()

                    // Install demo projects on first launch
                    installDemoProjectsIfNeeded()

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
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    debugPrint("📱 iPad: App entered background - connections will gracefully disconnect if backgrounded >3min")
                    // beginBackgroundTask in ConnectionManager gives ~3 minutes of background time
                    // Connection will auto-reconnect in 1-3 seconds when returning to foreground
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

    // MARK: - Demo Project Installation

    private func installDemoProjectsIfNeeded() {
        let hasInstalledDemos = UserDefaults.standard.bool(forKey: "hasInstalledDemoProjects")

        // ALWAYS check if the demo project actually exists, even if flag is set
        let demoName = "Beethoven Live"
        let projectExists = (try? ProjectIO.load(name: demoName)) != nil

        guard !hasInstalledDemos || !projectExists else {
            debugPrint("📦 Demo project already installed, skipping")
            return
        }

        if hasInstalledDemos && !projectExists {
            debugPrint("⚠️ hasInstalledDemoProjects flag was set but project doesn't exist - reinstalling")
        }

        debugPrint("📦 Installing demo project for first launch...")

        guard let url = Bundle.main.url(forResource: demoName, withExtension: "cuebearproj") else {
            debugPrint("❌ Demo project not found in bundle: \(demoName)")
            debugPrint("❌ Make sure '\(demoName).cuebearproj' is added to Copy Bundle Resources in Xcode")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let payload = try JSONDecoder().decode(ProjectPayload.self, from: data)

            // Migrate legacy demo projects to modern format
            let cueLists: [CueList]
            let activeCueListID: UUID

            if payload.isLegacyFormat {
                // Convert legacy setlist to "Main" cue list
                let mainList = CueList(name: "Main", songs: payload.setlist ?? [])
                cueLists = [mainList]
                activeCueListID = mainList.id
                debugPrint("📦 Migrating legacy demo project '\(demoName)' to v1.2.0 format")
            } else {
                // Use modern format as-is
                cueLists = payload.cueLists ?? [CueList.defaultMain]
                activeCueListID = payload.activeCueListID ?? cueLists.first!.id
            }

            // Save using ProjectIO (saves as .cuebear format in Documents)
            try ProjectIO.save(
                name: payload.name,
                cueLists: cueLists,
                activeCueListID: activeCueListID,
                library: payload.library,
                controls: payload.controls,
                isGlobalChannel: payload.isGlobalChannel,
                globalChannel: payload.globalChannel,
                theme: payload.theme
            )

            debugPrint("✅ Installed demo project: \(demoName)")
            debugPrint("📊 Demo content: \(cueLists.count) cue lists, \(cueLists.first?.songs.count ?? 0) songs in main list, \(payload.library.count) library songs, \(payload.controls.count) controls")

            // Only set flag if installation succeeded
            UserDefaults.standard.set(true, forKey: "hasInstalledDemoProjects")
        } catch {
            debugPrint("❌ Failed to install demo project \(demoName): \(error)")
        }
    }
}
