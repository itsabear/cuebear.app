import SwiftUI

@main
struct CueBearApp: App {
    @StateObject private var store = SetlistStore()
    @StateObject private var usbServer = ConnectionManager()
    @StateObject private var wifiClient = BridgeOutput()
    @StateObject private var connectionCoordinator = ConnectionCoordinator()

    var body: some Scene {
        WindowGroup {
            Cue_Bear.ContentView()
                .environmentObject(store)
                .environmentObject(usbServer)
                .environmentObject(wifiClient)
                .environmentObject(connectionCoordinator)
                .task {
                    debugPrint("📱 iPad: starting connection coordinator")

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
        .windowResizability(.contentSize)
    }
}
