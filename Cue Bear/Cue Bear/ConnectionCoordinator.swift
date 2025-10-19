import Foundation
import Combine

/// Coordinates USB and WiFi connections to ensure only one active connection
/// USB always takes priority over WiFi
@MainActor
class ConnectionCoordinator: ObservableObject {
    @Published var activeConnection: ConnectionType = .none
    @Published var connectionStatus: String = "Disconnected"
    
    private var usbServer: ConnectionManager?
    private var wifiClient: BridgeOutput?
    private var cancellables = Set<AnyCancellable>()

    // Flags to track user intent for connections
    private var isManualWiFiConnection = false
    private var isManualUSBConnection = false
    private var isManualUSBDisconnection = false  // Track when user explicitly disconnects USB

    // Timer references to prevent memory leaks
    private var usbMonitorTimer: Timer?
    private var wifiMonitorTimer: Timer?
    
    enum ConnectionType {
        case none
        case usb
        case wifi
    }
    
    init() {
        // Objects will be injected later via configure()
    }

    deinit {
        // Invalidate timers to prevent memory leaks
        usbMonitorTimer?.invalidate()
        wifiMonitorTimer?.invalidate()
    }

    func configure(usbServer: ConnectionManager, wifiClient: BridgeOutput) {
        self.usbServer = usbServer
        self.wifiClient = wifiClient
        setupConnectionMonitoring()
        
        // Set up direct connection state callback for immediate updates
        usbServer.setConnectionStateCallback { [weak self] isConnected in
            Task { @MainActor in
                self?.handleUSBConnectionChange(isConnected)
            }
        }
        
        // Add additional monitoring for debugging
        monitorConnectionState()
    }
    
    private func monitorConnectionState() {
        // Replaced polling timers with event-driven Combine publishers in setupConnectionMonitoring()
        // No need for periodic polling - connection state changes trigger updates immediately
        debugPrint("🔌 ConnectionCoordinator: Using event-driven connection monitoring (no polling)")
    }
    
    private func setupConnectionMonitoring() {
        guard let usbServer = usbServer, let wifiClient = wifiClient else { return }

        // Monitor USB connection changes (event-driven, no polling)
        usbServer.$isConnected
            .removeDuplicates()
            .sink { [weak self] isConnected in
                Task { @MainActor in
                    self?.handleUSBConnectionChange(isConnected)
                }
            }
            .store(in: &cancellables)

        // Monitor WiFi connection changes (event-driven, no polling)
        wifiClient.$isConnected
            .removeDuplicates()
            .sink { [weak self] isConnected in
                Task { @MainActor in
                    self?.handleWiFiConnectionChange(isConnected)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleUSBConnectionChange(_ isConnected: Bool) {
        guard let wifiClient = wifiClient else { return }

        debugPrint("🔌 ConnectionCoordinator: USB connection change - isConnected: \(isConnected), current activeConnection: \(activeConnection)")
        debugPrint("🔌 ConnectionCoordinator: DEBUG - This callback was triggered")

        if isConnected {
            // USB connected - suspend WiFi (don't destroy it) and set USB as active
            debugPrint("🔌 USB connected - suspending WiFi connection (preserving for later resume)")
            wifiClient.suspend()  // v1.0.8: Suspend instead of disconnect to preserve connection object
            activeConnection = .usb
            connectionStatus = "USB Connected"
            debugPrint("🔌 ConnectionCoordinator: Updated activeConnection to .usb")

            // Reset manual flags since connection is now established
            isManualUSBConnection = false
            isManualUSBDisconnection = false  // Clear disconnect flag when reconnected
        } else {
            // USB disconnected - don't auto-connect to WiFi (user choice only)
            debugPrint("🔌 USB disconnected - WiFi available for manual connection")

            // Reset manual USB flag since connection is lost
            isManualUSBConnection = false

            // v1.0.8: Resume WiFi connection ONLY if it was actually suspended by USB
            // CRITICAL FIX: Check isSuspended flag instead of connection != nil
            // This prevents incorrectly "resuming" WiFi that was never suspended
            if wifiClient.isSuspended {
                debugPrint("🔌 ConnectionCoordinator: WiFi connection was suspended - resuming it now")
                wifiClient.resume()  // v1.0.8: Resume the suspended WiFi connection
                activeConnection = .wifi
                connectionStatus = "WiFi Connected"
                debugPrint("🔌 ConnectionCoordinator: ✅ WiFi resumed and activeConnection switched to .wifi")
            } else if wifiClient.isConnected {
                // WiFi is already active (Story 6: USB cable was plugged but didn't connect)
                activeConnection = .wifi
                connectionStatus = "WiFi Connected"
                debugPrint("🔌 ConnectionCoordinator: WiFi is already active, switching activeConnection to .wifi")
            } else {
                activeConnection = .none
                connectionStatus = "Disconnected"
                debugPrint("🔌 ConnectionCoordinator: No WiFi connection, updated activeConnection to .none")
            }
            
            // Add a small delay to allow WiFi connection state to update
            // This prevents the race condition where USB disconnects before WiFi state is updated
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                guard let self = self, let usbServer = self.usbServer else { return }

                // Check if user manually disconnected USB - if so, don't auto-reconnect
                if self.isManualUSBDisconnection {
                    debugPrint("🔌 User manually disconnected USB - NOT auto-reconnecting (staying disconnected)")
                    return
                }

                // Check if this is a manual WiFi connection attempt
                if self.isManualWiFiConnection {
                    debugPrint("🔌 USB disconnected during manual WiFi connection - keeping USB server stopped to prevent loop")
                    return
                }

                // Only restart USB server if WiFi is not connected
                // This prevents the loop where WiFi connects -> USB restarts -> Bridge connects to USB
                if !usbServer.isServerListening && !wifiClient.isConnected {
                    debugPrint("🔌 USB disconnected and WiFi not connected - restarting USB server")
                    usbServer.start()
                } else if wifiClient.isConnected {
                    debugPrint("🔌 USB disconnected but WiFi is connected - keeping USB server stopped to prevent loop")
                } else {
                    debugPrint("🔌 USB disconnected - USB server already listening")
                }
            }
        }
    }
    
    private func handleWiFiConnectionChange(_ isConnected: Bool) {
        guard let usbServer = usbServer else { return }
        
        // Inform USB server about WiFi connection state to keep USB chip visible
        usbServer.setWiFiConnectionState(isConnected)
        
        // Allow manual WiFi connections even when USB is active
        // This enables user override functionality
        if isConnected {
            // WiFi connected - update status immediately
            activeConnection = .wifi
            connectionStatus = "WiFi Connected"
            debugPrint("✅ WiFi connection established")
            
            // Reset manual WiFi flag since connection is now established
            isManualWiFiConnection = false
            
            // If USB is also connected, cleanly terminate it without triggering callbacks
            // This prevents USB disconnection handlers from interfering with the fresh WiFi connection
            if usbServer.isConnected {
                debugPrint("🔌 WiFi connected manually - cleanly terminating USB without callbacks")
                usbServer.stop(notifyCallback: false)
            }
        } else {
            // WiFi disconnected - only update if we were using WiFi
            if activeConnection == .wifi {
                activeConnection = .none
                connectionStatus = "Disconnected"
                debugPrint("❌ WiFi connection lost")
                
                // Reset manual WiFi flag since connection is lost
                isManualWiFiConnection = false
                
                // BULLETPROOF: Automatically attempt USB reconnection when WiFi disconnects
                debugPrint("🔌 WiFi disconnected - attempting automatic USB reconnection")
                attemptUSBReconnection()
            }
        }
    }
    
    private func attemptUSBReconnection() {
        guard let usbServer = usbServer else { return }

        // STORY 7 FIX: Only auto-connect USB if cable is present
        if !usbServer.isUSBCableConnected {
            debugPrint("🔌 WiFi disconnected but USB cable not present - no auto-connect")
            return
        }

        debugPrint("🔌 WiFi disconnected and USB cable present - auto-connecting USB")

        // If USB server is listening but not connected, try to reconnect immediately
        if usbServer.isServerListening && !usbServer.isConnected {
            debugPrint("🔌 Attempting immediate USB reconnection...")

            // IMMEDIATE reconnection - no delay needed
            self.forceUSBReconnection()
        } else if !usbServer.isServerListening {
            debugPrint("🔌 USB server not listening - starting USB server")
            usbServer.start()
        }
    }
    
    // MARK: - Public Interface
    
    func sendMIDI(type: MIDIKind, channel: Int, number: Int, value: Int, label: String, buttonID: String) {
        switch activeConnection {
        case .usb:
            usbServer?.sendMIDI(type: type, channel: channel, number: number, value: value, label: label, buttonID: buttonID)
        case .wifi:
            guard let wifiClient = wifiClient else { return }
            switch type {
            case .cc:
                wifiClient.sendCC(channel: channel, cc: number, value: value, label: label, buttonID: buttonID)
            case .note:
                wifiClient.sendNote(channel: channel, note: number, velocity: value, label: label, buttonID: buttonID)
            }
        case .none:
            // Try both USB and WiFi if no active connection is set
            Logger.shared.log("⚠️ No active connection - trying both USB and WiFi")
            
            // Try USB first
            if let usbServer = usbServer, usbServer.isConnected {
                Logger.shared.log("🔌 Attempting USB MIDI send")
                usbServer.sendMIDI(type: type, channel: channel, number: number, value: value, label: label, buttonID: buttonID)
            }
            // Try WiFi as fallback
            else if let wifiClient = wifiClient, wifiClient.isConnected {
                Logger.shared.log("📡 Attempting WiFi MIDI send")
                switch type {
                case .cc:
                    wifiClient.sendCC(channel: channel, cc: number, value: value, label: label, buttonID: buttonID)
                case .note:
                    wifiClient.sendNote(channel: channel, note: number, velocity: value, label: label, buttonID: buttonID)
                }
            } else {
                Logger.shared.log("❌ No connection available - MIDI message dropped")
            }
        }
    }
    
    func sendTransport(action: String) {
        switch activeConnection {
        case .usb:
            // USB doesn't have transport commands yet - could add them
            debugPrint("🔌 Transport via USB not implemented yet")
        case .wifi:
            wifiClient?.sendTransport(action: action)
        case .none:
            debugPrint("⚠️ No active connection - transport message dropped")
        }
    }
    
    // Manual connection methods (for user override)
    func connectToWiFi(bridge: BridgeOutput.Item) {
        debugPrint("🔌 DEBUG: Manual WiFi connection requested to: \(bridge.name)")
        debugPrint("🔌 DEBUG: wifiClient is nil: \(wifiClient == nil)")
        
        // Set flag to indicate this is a manual WiFi connection
        isManualWiFiConnection = true
        
        // Disconnect USB if it's connected to allow WiFi connection
        // Use notifyCallback: false to cleanly terminate USB without interfering with fresh WiFi connection
        if let usbServer = usbServer, usbServer.isConnected {
            debugPrint("🔌 Disconnecting USB to allow manual WiFi connection (clean termination)")
            usbServer.stop(notifyCallback: false)
        }
        
        // Connect to WiFi
        debugPrint("🔌 DEBUG: Calling wifiClient.connect(to: bridge)")
        wifiClient?.connect(to: bridge)
        
        // Update status immediately to show we're attempting connection
        connectionStatus = "Connecting to WiFi..."
        debugPrint("🔌 DEBUG: Connection status updated to: \(connectionStatus)")
    }
    
    func disconnectWiFi() {
        debugPrint("🔌 Manual WiFi disconnection requested")
        wifiClient?.disconnect()
    }

    func disconnectUSB() {
        debugPrint("🔌 Manual USB disconnection requested")

        // Set flag to indicate this is a manual disconnection
        // This prevents automatic reconnection
        isManualUSBDisconnection = true

        // Stop the USB server
        usbServer?.stop()

        // Update status
        activeConnection = .none
        connectionStatus = "Disconnected"

        debugPrint("🔌 USB manually disconnected - will NOT auto-reconnect until user chooses")
    }

    // STORY 8: Manual USB connection (disconnect WiFi first, then connect USB)
    func connectToUSB() {
        debugPrint("🔌 Manual USB connection requested")

        // Set flag to indicate this is a manual USB connection
        isManualUSBConnection = true
        // Clear manual disconnection flag - user wants to connect
        isManualUSBDisconnection = false

        // Disconnect WiFi if it's connected to allow USB connection
        if let wifiClient = wifiClient, wifiClient.isConnected {
            debugPrint("🔌 Disconnecting WiFi to allow manual USB connection")
            wifiClient.disconnect()
        }

        // Start USB server to accept connections
        if let usbServer = usbServer, !usbServer.isServerListening {
            debugPrint("🔌 Starting USB server for manual connection")
            usbServer.start()
        }

        // Update status immediately to show we're attempting connection
        connectionStatus = "Connecting to USB..."
        debugPrint("🔌 Connection status updated to: \(connectionStatus)")
    }
    
    func startConnections() {
        debugPrint("🔌 Starting connection coordinator")
        usbServer?.start()
        wifiClient?.start()
        
        // Auto-connect to USB if available
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1.0 seconds
            guard let self = self else { return }
            if let usbServer = self.usbServer, usbServer.usbBridgeAvailable && !usbServer.isConnected {
                debugPrint("🔌 Auto-connecting to USB bridge...")
                self.forceUSBReconnection()
            }
        }
    }
    
    func stopConnections() {
        debugPrint("🔌 Stopping connection coordinator")
        usbServer?.stop()
        wifiClient?.stop()
        activeConnection = .none
        connectionStatus = "Disconnected"
    }
    
    // MARK: - Bulletproof Connection Recovery
    
    func forceConnectionRecovery() {
        debugPrint("🔌 Force connection recovery initiated")
        
        // Step 1: Stop all connections
        usbServer?.stop()
        wifiClient?.stop()
        activeConnection = .none
        connectionStatus = "Recovering..."
        
        // Step 2: Wait for cleanup
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            guard let self = self else { return }
            
            // Step 3: Restart everything
            debugPrint("🔌 Restarting all connections...")
            self.usbServer?.start()
            self.wifiClient?.start()
            
            // Step 4: Reset status
            self.connectionStatus = "Disconnected"
            
            debugPrint("✅ Connection recovery completed")
        }
    }
    
    func ensureUSBServerRunning() {
        guard let usbServer = usbServer, let wifiClient = wifiClient else { return }
        
        // Don't start USB server if WiFi is connected - this prevents the loop
        if wifiClient.isConnected {
            debugPrint("🔌 WiFi is connected - keeping USB server stopped to prevent loop")
            return
        }
        
        if !usbServer.isServerListening {
            debugPrint("🔌 USB server not listening - starting server")
            usbServer.start()
        } else {
            debugPrint("🔌 USB server already listening")
        }
    }
    
    func forceUSBReconnection() {
        debugPrint("🔌 Force USB reconnection requested")
        guard let usbServer = usbServer else { return }

        // Clear manual disconnection flag - user wants to reconnect
        isManualUSBDisconnection = false

        // Force restart USB server regardless of WiFi state
        usbServer.stop()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            usbServer.start()
        }
    }
    
    // MARK: - App Lifecycle Support
    
    func checkConnectionHealth() {
        debugPrint("🔌 ConnectionCoordinator: Checking connection health after app wake")
        
        guard let usbServer = usbServer, let wifiClient = wifiClient else { return }
        
        // Check if we have any active connections
        let hasUSBConnection = usbServer.isConnected
        let hasWiFiConnection = wifiClient.isConnected
        
        debugPrint("🔌 Connection health check - USB: \(hasUSBConnection), WiFi: \(hasWiFiConnection)")
        
        // If no connections are active, try to restart them
        if !hasUSBConnection && !hasWiFiConnection {
            debugPrint("🔌 No active connections detected - restarting connections")
            startConnections()
        } else if hasUSBConnection && activeConnection != .usb {
            debugPrint("🔌 USB connection detected but not tracked - updating state")
            activeConnection = .usb
            connectionStatus = "USB Connected"
        } else if hasWiFiConnection && activeConnection != .wifi {
            debugPrint("🔌 WiFi connection detected but not tracked - updating state")
            activeConnection = .wifi
            connectionStatus = "WiFi Connected"
        }
        
        // Ensure USB server is running if no WiFi connection
        if !hasWiFiConnection && !usbServer.isServerListening {
            debugPrint("🔌 No WiFi connection and USB server not listening - starting USB server")
            usbServer.start()
        }
    }
}
