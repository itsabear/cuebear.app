// BridgeOutput.swift — iPad client to Mac Bridge
// - Browses Bonjour (_cuebear._tcp)
// - Connects and sends newline-delimited JSON
// - Helpers: sendCC / sendNote / sendTransport

import Foundation
import Network
import UIKit

final class BridgeOutput: ObservableObject {
    struct Item: Identifiable {
        let id = UUID()
        let name: String
        let endpoint: NWEndpoint
    }
    
    enum ConnectionQuality {
        case excellent, good, fair, poor, disconnected
    }
    
    // BridgeOutput now handles WiFi connections only
    // USB connections are handled by ConnectionManager
    
    // Periodic reconnection check
    private var reconnectionTimer: Timer?
    private var connectionHealthTimer: Timer?
    private var discoveryRefreshTimer: Timer?
    private var lastSuccessfulMessage: Date = Date.distantPast
    
    // Connection quality metrics
    private var connectionLatency: TimeInterval = 0
    private var packetLossCount: Int = 0
    private var totalPackets: Int = 0
    private var lastQualityUpdate: Date = Date.distantPast
    
    // Message batching for performance optimization
    private var messageBatch: [String] = []
    private var batchTimer: Timer?
    private let batchSize = 5 // Reduced for lower latency
    private let batchTimeout: TimeInterval = 0.01 // 10ms for lower latency

    @Published var discovered: [Item] = []
    @Published var isConnected: Bool = false
    @Published var isConnecting: Bool = false
    @Published var current: Item? = nil
    @Published var connectionQuality: ConnectionQuality = .disconnected

    private var browser: NWBrowser?
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "CueBear.BridgeOutput")
    private var pairToken: String = UserDefaults.standard.string(forKey: "BridgePairToken") ?? ""
    private var isPairing: Bool = false
    
    // Background task support for maintaining connections during sleep
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    // Internal method for automatic pairing
    private func setPairToken(_ token: String) {
        pairToken = token
        UserDefaults.standard.set(token, forKey: "BridgePairToken")
        debugPrint("BridgeOutput: Automatic pairing token received and stored")
    }
    
    private func initiatePairing() {
        debugPrint("BridgeOutput: Initiating automatic pairing")
        isPairing = true
        let pairRequest: [String: Any] = [
            "type": "pair_request",
            "timestamp": Date().timeIntervalSince1970
        ]
        sendJSON(pairRequest)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stop()
        debugPrint("🔌 BridgeOutput: Deallocating")
    }

    func start() {
        debugPrint("🔌 DEBUG: BridgeOutput.start() called")
        setupBackgroundTaskSupport() // Initialize background task support
        startBrowsing()
        startDiscoveryRefreshTimer()
    }
    
    private func startBrowsing() {
        let params = NWParameters.tcp
        let bonjour = NWBrowser.Descriptor.bonjour(type: "_cuebear._tcp.", domain: nil)
        let browser = NWBrowser(for: bonjour, using: params)
        self.browser = browser

        browser.stateUpdateHandler = { state in 
            debugPrint("BridgeOutput: Browser state changed to: \(state)")
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self = self else { return }
            debugPrint("BridgeOutput: Discovery results changed, found \(results.count) services")
            let items: [Item] = results.compactMap { res in
                guard case let .service(name: name, type: _, domain: _, interface: _) = res.endpoint else { 
                    debugPrint("BridgeOutput: Skipping non-service result: \(res.endpoint)")
                    return nil 
                }
                // Remove .local suffix from name for cleaner display
                let cleanName = name.hasSuffix(".local") ? String(name.dropLast(6)) : name
                debugPrint("BridgeOutput: Discovered bridge: \(cleanName)")
                return Item(name: cleanName, endpoint: res.endpoint)
            }
            DispatchQueue.main.async { 
                self.discovered = items.sorted { $0.name < $1.name }
                debugPrint("🔌 DEBUG: BridgeOutput.discovered updated to \(self.discovered.count) items")
                debugPrint("🔌 DEBUG: BridgeOutput.discovered contents: \(self.discovered.map { $0.name })")
                debugPrint("BridgeOutput: Updated discovered list with \(items.count) bridges")
                
                // Don't auto-connect - let user choose connection method
                debugPrint("BridgeOutput: Found \(items.count) bridges - waiting for user to choose connection")
            }
        }
        browser.start(queue: queue)
    }
    
    private func startDiscoveryRefreshTimer() {
        // Restart browsing every 30 seconds to catch Bridge apps that start later (reduced frequency)
        // Only run when not connected to save CPU
        discoveryRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard !self.isConnected else {
                debugPrint("BridgeOutput: Already connected, skipping discovery refresh")
                return
            }
            debugPrint("BridgeOutput: Refreshing discovery to catch late-starting Bridge apps")
            self.restartBrowsing()
        }
    }
    
    private func restartBrowsing() {
        browser?.cancel()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startBrowsing()
        }
    }

    func stop() {
        disconnect()
        browser?.cancel(); browser = nil
        discoveryRefreshTimer?.invalidate(); discoveryRefreshTimer = nil
        DispatchQueue.main.async {
            self.discovered.removeAll()
        }
    }

    func disconnect() {
        connection?.cancel(); connection = nil
        DispatchQueue.main.async {
            self.isConnected = false
            self.isConnecting = false
            self.current = nil
        }
        // Stop timers when manually disconnecting
        reconnectionTimer?.invalidate()
        reconnectionTimer = nil
        connectionHealthTimer?.invalidate()
        connectionHealthTimer = nil
        
        // Clear message batch
        batchTimer?.invalidate()
        batchTimer = nil
        messageBatch.removeAll()
    }
    
    // MARK: - Background Task Support
    
    private func setupBackgroundTaskSupport() {
        // Register for app lifecycle notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        debugPrint("📡 BridgeOutput: Background task support configured")
    }
    
    @objc private func appDidEnterBackground() {
        debugPrint("📡 BridgeOutput: App entered background - starting background task to maintain WiFi connection")
        
        // Start background task to keep WiFi connection alive
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "CueBearWiFiConnection") { [weak self] in
            debugPrint("📡 BridgeOutput: Background task expired - ending task")
            self?.endBackgroundTask()
        }
        
        // Keep WiFi connection alive during background
        if isConnected {
            debugPrint("📡 BridgeOutput: Maintaining active WiFi connection during background")
        }
    }
    
    @objc private func appWillEnterForeground() {
        debugPrint("📡 BridgeOutput: App entering foreground - ending background task")
        endBackgroundTask()
        
        // Check connection health when returning to foreground
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkWiFiConnectionAfterWake()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
            debugPrint("📡 BridgeOutput: Background task ended")
        }
    }
    
    private func checkWiFiConnectionAfterWake() {
        debugPrint("📡 BridgeOutput: Checking WiFi connection health after wake")
        
        // If we were connected before sleep, verify the connection is still alive
        if isConnected && connection != nil {
            debugPrint("📡 BridgeOutput: WiFi connection was active - verifying it's still healthy")
            
            // Send a test message to verify connection
            let testMessage: [String: Any] = [
                "type": "connection_test",
                "timestamp": Date().timeIntervalSince1970
            ]
            sendJSON(testMessage)
            
            // If connection is lost, update state
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                
                if self.isConnected && self.connection != nil {
                    debugPrint("📡 BridgeOutput: WiFi connection verified healthy after wake")
                } else {
                    debugPrint("📡 BridgeOutput: WiFi connection lost during sleep - updating state")
                    self.isConnected = false
                    self.current = nil
                    self.connectionQuality = .disconnected
                }
            }
        }
    }
    
    private func attemptReconnection() {
        // Only attempt reconnection if we're not already connected and have a preferred connection
        guard !isConnected && connection == nil else { return }
        
        // Try to reconnect to the last known connection
        if let lastConnection = current {
            debugPrint("🔄 BridgeOutput: Attempting to reconnect to \(lastConnection.name)")
            connect(to: lastConnection)
        } else {
            // If no last connection, try to find available connections
            if !discovered.isEmpty {
                let preferredConnection = discovered.first { $0.name.contains("Bear Bridge") } ?? discovered.first!
                debugPrint("🔄 BridgeOutput: Attempting to reconnect to discovered connection: \(preferredConnection.name)")
                connect(to: preferredConnection)
            } else {
                debugPrint("🔄 BridgeOutput: No connections available for reconnection")
            }
        }
    }
    
    private func startReconnectionTimer() {
        // Stop existing timer
        reconnectionTimer?.invalidate()

        // Start periodic reconnection check every 30 seconds (reduced frequency)
        // Only runs when not connected
        reconnectionTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if !self.isConnected && self.connection == nil {
                debugPrint("🔄 BridgeOutput: Periodic reconnection check - attempting to reconnect")
                self.attemptReconnection()
            } else {
                debugPrint("🔄 BridgeOutput: Already connected, skipping reconnection attempt")
            }
        }
    }
    
    private func stopReconnectionTimer() {
        reconnectionTimer?.invalidate()
        reconnectionTimer = nil
    }
    
    private func startConnectionHealthMonitoring() {
        guard isConnected else {
            debugPrint("🔌 BridgeOutput: Skipping health monitoring - not connected")
            return
        }

        // Stop existing timer
        connectionHealthTimer?.invalidate()

        // Start health check every 15 seconds (reduced frequency)
        connectionHealthTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isConnected else {
                self?.stopConnectionHealthMonitoring()
                return
            }

            // Update connection quality
            self.updateConnectionQuality()

            // Check if connection appears healthy but hasn't sent messages recently
            if self.connection != nil {
                let timeSinceLastMessage = Date().timeIntervalSince(self.lastSuccessfulMessage)

                // If no messages sent in 60 seconds, connection might be stale (less aggressive)
                if timeSinceLastMessage > 60.0 {
                    debugPrint("🔄 BridgeOutput: Connection appears stale (no messages in \(Int(timeSinceLastMessage))s), forcing reconnection")
                    self.forceReconnection()
                }
            }
        }
    }
    
    private func stopConnectionHealthMonitoring() {
        connectionHealthTimer?.invalidate()
        connectionHealthTimer = nil
    }
    
    private func forceReconnection() {
        debugPrint("🔄 BridgeOutput: Forcing reconnection due to stale connection")
        connection?.cancel()
        connection = nil
        DispatchQueue.main.async {
            self.isConnected = false
            self.current = nil
        }
        startReconnectionTimer()
    }

    func connect(to item: Item) {
        debugPrint("🔌 DEBUG: BridgeOutput.connect called for: \(item.name)")
        debugPrint("🔌 DEBUG: item.endpoint: \(item.endpoint)")
        disconnect()
        
        // Set connecting state
        DispatchQueue.main.async { 
            self.isConnecting = true
        }
        
        // Use WiFi connection only (USB handled by ConnectionManager)
        let endpoint = item.endpoint
        let useTLS = false
        debugPrint("BridgeOutput: Using WiFi connection to \(item.endpoint)")
        
        let conn = NWConnection(to: endpoint, using: useTLS ? .tls : .tcp)
        connection = conn
        current = item
        debugPrint("🔌 DEBUG: NWConnection created, starting connection...")
        
        conn.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            debugPrint("🔌 DEBUG: Connection state changed to: \(state)")
            switch state {
            case .ready:
                debugPrint("BridgeOutput: Connected successfully to \(item.name)")
                DispatchQueue.main.async { 
                    self.isConnected = true
                    self.isConnecting = false
                    self.current = item
                    self.connectionQuality = .excellent
                }
                self.receiveLoop()
                
                // Stop reconnection timer when connected
                self.stopReconnectionTimer()
                
                // Start connection health monitoring
                self.startConnectionHealthMonitoring()
                
                // Reset last successful message timestamp
                self.lastSuccessfulMessage = Date()
                
                // Automatic pairing for security
                if self.pairToken.isEmpty {
                    self.initiatePairing()
                }
            case .failed(let error):
                debugPrint("BridgeOutput: Connection failed to \(item.name): \(error)")
                DispatchQueue.main.async {
                    self.isConnected = false
                    self.isConnecting = false
                    self.current = nil
                    self.connection = nil
                    self.connectionQuality = .disconnected
                }
                // Stop health monitoring and start reconnection timer
                self.stopConnectionHealthMonitoring()
                self.startReconnectionTimer()
            case .cancelled:
                debugPrint("BridgeOutput: Connection cancelled to \(item.name)")
                DispatchQueue.main.async {
                    self.isConnected = false
                    self.isConnecting = false
                    self.current = nil
                    self.connection = nil
                    self.connectionQuality = .disconnected
                }
                // Stop health monitoring and start reconnection timer
                self.stopConnectionHealthMonitoring()
                self.startReconnectionTimer()
            case .waiting(let error):
                debugPrint("BridgeOutput: Connection waiting for \(item.name): \(error)")
            default: 
                debugPrint("BridgeOutput: Connection state changed: \(state)")
            }
        }
        conn.start(queue: queue)
    }

    // MARK: - Send helpers

    func sendCC(channel: Int, cc: Int, value: Int, label: String, buttonID: String) {
        let payload: [String: Any] = [
            "type": "midi_cc",
            "channel": channel,
            "cc": cc,
            "value": value,
            "label": label,
            "button_id": buttonID
        ]
        sendJSON(payload)
    }

    func sendNote(channel: Int, note: Int, velocity: Int, label: String, buttonID: String) {
        let payload: [String: Any] = [
            "type": "midi_note",
            "channel": channel,
            "note": note,
            "velocity": velocity,
            "label": label,
            "button_id": buttonID
        ]
        sendJSON(payload)
    }

    func sendTransport(action: String) {
        let payload: [String: Any] = [
            "type": "transport",
            "action": action,
            "timestamp": Date().timeIntervalSince1970
        ]
        sendJSON(payload)
    }
    
    // Send MIDI immediately without batching for critical messages
    func sendMIDIImmediate(channel: Int, cc: Int, value: Int, label: String, buttonID: String) {
        let payload: [String: Any] = [
            "type": "midi_cc",
            "channel": channel,
            "cc": cc,
            "value": value,
            "label": label,
            "button_id": buttonID
        ]
        sendJSONImmediate(payload)
    }

    // MARK: - Low-level IO

    private func sendJSON(_ obj: [String: Any]) {
        guard let _ = connection else {
            debugPrint("BridgeOutput: No connection, dropping message")
            return
        }
        do {
            var withToken = obj
            
            // Add token to regular messages (not pairing requests)
            if obj["type"] as? String != "pair_request" && !pairToken.isEmpty {
                withToken["token"] = pairToken
            }
            
            let data = try JSONSerialization.data(withJSONObject: withToken)
            guard var line = String(data: data, encoding: .utf8) else { return }
            line.append("\n")
            
            // Add to batch for performance optimization
            addToBatch(line)
        } catch {
            debugPrint("BridgeOutput: JSON serialization failed: \(error)")
        }
    }
    
    // Send JSON immediately without batching for critical messages
    private func sendJSONImmediate(_ obj: [String: Any]) {
        guard let connection = connection else {
            debugPrint("BridgeOutput: No connection, dropping immediate message")
            return
        }
        do {
            var withToken = obj
            
            // Add token to regular messages (not pairing requests)
            if obj["type"] as? String != "pair_request" && !pairToken.isEmpty {
                withToken["token"] = pairToken
            }
            
            let data = try JSONSerialization.data(withJSONObject: withToken)
            guard var line = String(data: data, encoding: .utf8) else { return }
            line.append("\n")
            
            // Send immediately without batching
            guard let buf = line.data(using: .utf8) else { return }
            connection.send(content: buf, completion: .contentProcessed { [weak self] error in
                if error == nil {
                    self?.lastSuccessfulMessage = Date()
                    debugPrint("BridgeOutput: Immediate message sent successfully")
                } else {
                    debugPrint("BridgeOutput: Failed to send immediate message: \(error?.localizedDescription ?? "unknown error")")
                }
            })
        } catch {
            debugPrint("BridgeOutput: JSON serialization failed for immediate message: \(error)")
        }
    }
    
    private func addToBatch(_ message: String) {
        messageBatch.append(message)
        
        // Send immediately if batch is full
        if messageBatch.count >= batchSize {
            sendBatch()
        } else {
            // Start timer for batch timeout
            startBatchTimer()
        }
    }
    
    private func startBatchTimer() {
        batchTimer?.invalidate()
        batchTimer = Timer.scheduledTimer(withTimeInterval: batchTimeout, repeats: false) { [weak self] _ in
            self?.sendBatch()
        }
    }
    
    private func sendBatch() {
        guard !messageBatch.isEmpty else { return }
        
        batchTimer?.invalidate()
        batchTimer = nil
        
        guard let connection = connection else {
            debugPrint("BridgeOutput: No connection - cannot send batch")
            messageBatch.removeAll()
            return
        }
        
        // Create batched message
        let batchedMessage = [
            "type": "batch",
            "messages": messageBatch,
            "count": messageBatch.count,
            "timestamp": Date().timeIntervalSince1970
        ] as [String: Any]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: batchedMessage)
            guard var line = String(data: data, encoding: .utf8) else { 
                messageBatch.removeAll()
                return 
            }
            line.append("\n")
            guard let buf = line.data(using: .utf8) else { 
                messageBatch.removeAll()
                return 
            }
            
            connection.send(content: buf, completion: .contentProcessed { [weak self] error in
                if error == nil {
                    // Update last successful message timestamp
                    self?.lastSuccessfulMessage = Date()
                    debugPrint("BridgeOutput: Batch sent successfully (\(self?.messageBatch.count ?? 0) messages)")
                } else {
                    debugPrint("BridgeOutput: Failed to send batch: \(error?.localizedDescription ?? "unknown error")")
                }
                self?.messageBatch.removeAll()
            })
        } catch {
            debugPrint("BridgeOutput: Failed to create batch JSON: \(error)")
            messageBatch.removeAll()
        }
    }

    private func receiveLoop() {
        guard let connection = connection else { return }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            // v1.0.4: Handle timeout errors gracefully - retry instead of disconnecting
            // This prevents WiFi disconnection when USB cable is unplugged
            if let error = error {
                let nsError = error as NSError
                // POSIX error 60 = Operation timed out (happens when no data received for ~30 seconds)
                if nsError.domain == NSPOSIXErrorDomain && nsError.code == 60 {
                    debugPrint("BridgeOutput: Receive timeout, retrying connection...")
                    // Continue the receive loop instead of disconnecting
                    self?.receiveLoop()
                    return
                }
                // For other errors, disconnect
                debugPrint("BridgeOutput: Receive error: \(error.localizedDescription), disconnecting")
                self?.disconnect()
                return
            }

            if isComplete {
                self?.disconnect()
                return
            }

            // Parse responses for automatic pairing
            if let data = data, let self = self {
                self.parseResponse(data)
            }
            self?.receiveLoop()
        }
    }
    
    private func parseResponse(_ data: Data) {
        guard let string = String(data: data, encoding: .utf8) else { return }
        let lines = string.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        for line in lines {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let type = json["type"] as? String else { continue }
            
            if type == "pair_response", let token = json["token"] as? String {
                debugPrint("BridgeOutput: Received pairing token, storing and reconnecting")
                setPairToken(token)
                isPairing = false

                // Reconnect with the new token
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    if let current = self?.current {
                        self?.connect(to: current)
                    }
                }
            } else if type == "midi_input" {
                debugPrint("BridgeOutput: Received MIDI input from DAW")
                DispatchQueue.main.async {
                    self.handleMIDIInputFromDAW(json)
                }
            }
        }
    }
    
    // Handle MIDI input from DAW and update iPad faders
    private func handleMIDIInputFromDAW(_ json: [String: Any]) {
        guard let midiBytes = json["midi"] as? [Int], midiBytes.count >= 3 else {
            debugPrint("BridgeOutput: Invalid MIDI input data")
            return
        }
        
        let statusByte = midiBytes[0]
        let data1 = midiBytes[1]
        let data2 = midiBytes[2]
        
        // Parse MIDI message
        let messageType = statusByte & 0xF0
        let channel = (statusByte & 0x0F) + 1 // Convert to 1-based channel
        
        debugPrint("BridgeOutput: MIDI input - Type: 0x\(String(format: "%02X", messageType)), Ch: \(channel), Data1: \(data1), Data2: \(data2)")
        
        switch messageType {
        case 0xB0: // Control Change (CC)
            debugPrint("BridgeOutput: MIDI CC Ch\(channel) CC\(data1)=\(data2)")
            
            // Post notification to update faders
            NotificationCenter.default.post(
                name: Notification.Name("cbMIDIInputFromDAW"),
                object: nil,
                userInfo: [
                    "type": "cc",
                    "channel": channel,
                    "cc": data1,
                    "value": data2
                ]
            )
            
        case 0x90: // Note On
            debugPrint("BridgeOutput: MIDI Note On Ch\(channel) Note\(data1) Vel\(data2)")
            
            // Post notification for note messages
            NotificationCenter.default.post(
                name: Notification.Name("cbMIDIInputFromDAW"),
                object: nil,
                userInfo: [
                    "type": "note",
                    "channel": channel,
                    "note": data1,
                    "velocity": data2
                ]
            )
            
        default:
            debugPrint("BridgeOutput: Unhandled MIDI message type: 0x\(String(format: "%02X", messageType))")
        }
    }
    
    // MARK: - Health Check
    func checkConnectionHealth() {
        // Force a health check by checking if we've sent messages recently
        let timeSinceLastMessage = Date().timeIntervalSince(lastSuccessfulMessage)
        if timeSinceLastMessage > 30 {
            debugPrint("BridgeOutput: Connection appears stale (no messages for \(timeSinceLastMessage)s), forcing reconnection")
            if let current = current {
                connect(to: current)
            }
        }
    }
    
    func restartDiscovery() {
        debugPrint("BridgeOutput: Manually restarting discovery")
        restartBrowsing()
    }
    
    // MARK: - Connection Quality Monitoring
    
    private func updateConnectionQuality() {
        let now = Date()
        let timeSinceLastMessage = now.timeIntervalSince(lastSuccessfulMessage)
        
        // Update quality based on connection health and metrics
        let quality: ConnectionQuality
        if isConnected {
            if timeSinceLastMessage < 5.0 && connectionLatency < 0.1 && packetLossCount == 0 {
                quality = .excellent
            } else if timeSinceLastMessage < 10.0 && connectionLatency < 0.2 && packetLossCount < 2 {
                quality = .good
            } else if timeSinceLastMessage < 30.0 && connectionLatency < 0.5 && packetLossCount < 5 {
                quality = .fair
            } else {
                quality = .poor
            }
        } else {
            quality = .disconnected
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.connectionQuality = quality
        }
        
        lastQualityUpdate = now
    }
}
