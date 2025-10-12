import SwiftUI

@main
struct CueBearApp: App {
    @StateObject private var store = SetlistStore()
    @StateObject private var usbServer = ConnectionManager()
    @StateObject private var wifiClient = BridgeOutput()
    @StateObject private var connectionCoordinator = ConnectionCoordinator()
    @StateObject private var purchaseManager = PurchaseManager.shared

    var body: some Scene {
        WindowGroup {
            Cue_Bear.ContentView()
                .environmentObject(store)
                .environmentObject(usbServer)
                .environmentObject(wifiClient)
                .environmentObject(connectionCoordinator)
                .environmentObject(purchaseManager)
                .task {
                    debugPrint("📱 iPad: starting connection coordinator")

                    // Check purchase status on launch
                    await purchaseManager.checkPurchaseStatus()
                    debugPrint("💰 Purchase status checked - Lifetime: \(purchaseManager.hasLifetimeAccess), Subscription: \(purchaseManager.hasActiveSubscription)")

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
        guard !hasInstalledDemos else {
            debugPrint("📦 Demo projects already installed, skipping")
            return
        }

        debugPrint("📦 Installing demo projects for first launch...")

        let demoNames = [
            "DJ Set - Electronic Night",
            "Live Band - Rock Concert",
            "Studio Session - Hip Hop Production",
            "Theater Production - Hamilton",
            "Worship Service - Sunday Morning"
        ]

        var installedCount = 0

        for name in demoNames {
            guard let url = Bundle.main.url(forResource: name, withExtension: "cuebearproj") else {
                debugPrint("⚠️ Demo project not found in bundle: \(name)")
                continue
            }

            do {
                let data = try Data(contentsOf: url)
                let payload = try JSONDecoder().decode(ProjectPayload.self, from: data)

                // Save using ProjectIO (saves as .cuebear format in Documents)
                try ProjectIO.save(
                    name: payload.name,
                    setlist: payload.setlist,
                    library: payload.library,
                    controls: payload.controls,
                    isGlobalChannel: payload.isGlobalChannel,
                    globalChannel: payload.globalChannel
                )

                installedCount += 1
                debugPrint("✅ Installed demo project: \(name)")
            } catch {
                debugPrint("❌ Failed to install demo project \(name): \(error)")
            }
        }

        UserDefaults.standard.set(true, forKey: "hasInstalledDemoProjects")
        debugPrint("📦 Installed \(installedCount) of \(demoNames.count) demo projects")
    }
}
