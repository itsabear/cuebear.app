// Event-driven USB connection manager - clean version
import Foundation
import Network
import Combine
import AppKit // For USB device notifications

final class MacConnectionManager: ObservableObject {
    @Published var connectionStatus: String = "USB: idle"

    private let iproxyManager: IProxyManager
    private var connection: NWConnection?
    private var host: NWEndpoint.Host = "127.0.0.1"
    private var isReceiving = false

    private var reconnectSource: DispatchSourceTimer?

    // Fix Issue #11 & #12: Use NSLock to protect shared state
    private let stateLock = NSLock()
    private var reconnectPending = false
    private var connecting = false
    private var didSendHandshake = false
    private var connID = UUID()
    private var rxBuffer = Data()

    private var handshakeTimeout: DispatchSourceTimer?
    private var usbDeviceObserver: NSObjectProtocol?
    private var deviceDisconnectObserver: NSObjectProtocol?
    private var wakeNotificationObserver: NSObjectProtocol?

    // Retry limiting for reconnection attempts
    private var consecutiveReconnectFailures = 0
    private let maxConsecutiveReconnects = 20  // Increased from 10 for better device ready detection

    // Reference to BridgeApp for triggering MIDI activity indicator
    private weak var bridgeApp: BridgeApp?

    init(iproxyManager: IProxyManager) {
        self.iproxyManager = iproxyManager
        setupUSBDeviceMonitoring()
        setupDeviceDisconnectNotification()
        setupWakeNotificationObserver()
    }
    
    func setBridgeApp(_ app: BridgeApp) {
        self.bridgeApp = app
    }
    
    deinit {
        stopUSBDeviceMonitoring()
        stopDeviceDisconnectNotification()
        stopWakeNotificationObserver()
        stopHeartbeatSending()
        reconnectSource?.cancel()
        handshakeTimeout?.cancel()
        connection?.cancel()
        Logger.shared.log("🔗 MacConnectionManager: deinit - all resources cleaned up")
    }

    func stop() {
        cancelHandshakeTimeout()
        stopReconnectTimer()
        stopHeartbeatSending()
        connection?.cancel()
        connection = nil
        isReceiving = false
        // Fix Issue #12: Protect state flags with lock
        stateLock.lock()
        connecting = false
        didSendHandshake = false
        stateLock.unlock()
        // Fix Issue #10: Ensure @Published updates on main queue
        DispatchQueue.main.async { [weak self] in
            self?.connectionStatus = "USB: stopped"
        }
    }

    func waitAndConnect() {
        Logger.shared.log("🔗 MacConnectionManager: waitAndConnect() called")

        // Fix Issue #12: Protect state flag access with lock
        stateLock.lock()
        let isConnecting = connecting
        stateLock.unlock()

        Logger.shared.log("🔗 MacConnectionManager: connection == nil: \(connection == nil), connecting: \(isConnecting)")

        guard connection == nil, !isConnecting else {
            Logger.shared.log("🔗 MacConnectionManager: Already connected or connecting, skipping")
            return
        }
        
        guard let port = iproxyManager.boundLocalPort, iproxyManager.isRunning else {
            Logger.shared.log("🔗 MacConnectionManager: iproxy not ready - port: \(iproxyManager.boundLocalPort?.description ?? "nil"), running: \(iproxyManager.isRunning)")
            // Fix Issue #10: Ensure @Published updates on main queue
            DispatchQueue.main.async { [weak self] in
                self?.connectionStatus = "USB: Waiting for iproxy…"
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) { [weak self] in self?.waitAndConnect() }
            return
        }
        
        // SPEED FIX: Removed 0.5s wait - connect immediately
        // Retry logic handles cases where iPad isn't ready yet
        Logger.shared.log("🔗 MacConnectionManager: iproxy ready on port \(port), attempting connection immediately")
        self.connect(to: port)
    }

    private func connect(to port: UInt16) {
        Logger.shared.log("🔗 MacConnectionManager: connect(to: \(port)) called")

        guard port > 0, port <= 65535 else {
            Logger.shared.log("🔗 MacConnectionManager: Invalid port: \(port)")
            return
        }

        // Fix Issue #12: Protect state flag access with lock
        stateLock.lock()
        let isConnecting = connecting
        stateLock.unlock()

        guard connection == nil, !isConnecting else {
            Logger.shared.log("🔗 MacConnectionManager: Already connected or connecting, skipping")
            return
        }

        // Security: Validate connection attempt
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            Logger.shared.log("🔗 MacConnectionManager: Invalid port for security validation: \(port)")
            return
        }
        let endpoint = NWEndpoint.hostPort(host: host, port: nwPort)
        guard ConnectionSecurity.shared.validateConnection(from: endpoint) else {
            Logger.shared.log("🔗 MacConnectionManager: Connection rejected by security")
            return
        }

        Logger.shared.log("🔗 MacConnectionManager: Creating connection to \(host):\(port)")
        // Fix Issue #12: Protect state flag updates with lock
        stateLock.lock()
        connecting = true
        didSendHandshake = false
        let myID = UUID()
        connID = myID
        stateLock.unlock()

        let params = NWParameters.tcp
        guard let endpoint = NWEndpoint.Port(rawValue: port) else { 
            Logger.shared.log("🔗 MacConnectionManager: Failed to create endpoint for port \(port)")
            return 
        }
        let conn = NWConnection(host: host, port: endpoint, using: params)
        connection = conn
        
        Logger.shared.log("🔗 MacConnectionManager: Connection created, starting state handler")

        conn.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }

            // Fix Issue #12: Protect connID check with lock
            self.stateLock.lock()
            let currentConnID = self.connID
            self.stateLock.unlock()

            guard currentConnID == myID else { return }

            switch state {
            case .ready:
                // Fix Issue #12: Protect state flag updates with lock
                self.stateLock.lock()
                self.connecting = false
                let shouldSendHandshake = !self.didSendHandshake
                if shouldSendHandshake {
                    self.didSendHandshake = true
                }
                self.stateLock.unlock()

                self.receiveLoop() // start receiving first
                if shouldSendHandshake {
                    self.sendHandshake()
                }
                DispatchQueue.main.async { [weak self] in self?.connectionStatus = "USB: Looking for Cue Bear" }

                // SPEED FIX: Fast zombie detection - check if handshake response arrives within 1s
                // If connection is ready but no response, fail fast and retry
                DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [weak self, weak conn] in
                    guard let self = self, let conn = conn else { return }

                    // Check if we're still waiting for handshake response (not yet connected)
                    let currentStatus = self.connectionStatus
                    let isStillWaiting = currentStatus.contains("Looking for") || currentStatus.contains("Waiting")

                    if isStillWaiting && conn.state == .ready {
                        Logger.shared.log("🔗 MacConnectionManager: ⚠️ Connection ready but no handshake response after 1s - fast retry")
                        self.cancelHandshakeTimeout()
                        conn.cancel()
                        self.startReconnectTimer()
                    }
                }

            case .failed(let err):
                self.stateLock.lock()
                self.connecting = false
                self.stateLock.unlock()
                self.cancelHandshakeTimeout()
                self.disconnect()
                self.startReconnectTimer()
                DispatchQueue.main.async { [weak self] in self?.connectionStatus = "USB: Failed: \(err.localizedDescription)" }

            case .cancelled:
                self.stateLock.lock()
                self.connecting = false
                self.stateLock.unlock()
                self.cancelHandshakeTimeout()
                self.disconnect()
                self.startReconnectTimer()
                DispatchQueue.main.async { [weak self] in self?.connectionStatus = "USB: Disconnected" }

            default:
                break
            }
        }

        conn.start(queue: .global(qos: .userInitiated))
        DispatchQueue.main.async { [weak self] in self?.connectionStatus = "USB: Connecting to localhost:\(port)…" }
    }

    private func disconnect() {
        connection?.cancel()
        connection = nil
        isReceiving = false
    }

    // Helper function to get user-friendly display name
    private func getDisplayName() -> String {
        let computerName = Host.current().name ?? "Mac" // Use .name to avoid duplication
        return computerName
    }
    
    private func sendHandshake() {
        // Get user's full name and computer name for display
        let displayName = getDisplayName()
        
        // Send CB/2 protocol handshake with name parameter for better display
        let handshakeMessage = "CB/2 auth=psk1 name=\(displayName)\n"
        guard let data = handshakeMessage.data(using: .utf8) else { return }

        connection?.send(content: data, completion: .contentProcessed { [weak self] err in
            guard let self = self else { return }
            if let err = err {
                Logger.shared.log("🔗 MacConnectionManager: handshake send error: \(err)")
                self.disconnect()
                self.startReconnectTimer()
                return
            }
            Logger.shared.log("🔗 MacConnectionManager: Handshake sent — waiting for response…")
            DispatchQueue.main.async { self.connectionStatus = "USB: Looking for Cue Bear" }
            // SPEED FIX: Reduced timeout from 10s to 3s for faster failure detection
            self.startHandshakeTimeout(seconds: 3.0)
        })
    }

    private func startHandshakeTimeout(seconds: TimeInterval) {
        cancelHandshakeTimeout()
        let t = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
        t.schedule(deadline: .now() + seconds)
        t.setEventHandler { [weak self] in
            guard let self = self else { return }
            Logger.shared.log("🔗 MacConnectionManager: Handshake timed out; reconnecting")

            // Fix: Clean up state properly before reconnecting
            self.stateLock.lock()
            self.connecting = false
            self.didSendHandshake = false
            self.stateLock.unlock()

            self.connection?.cancel()
            self.connection = nil
            self.isReceiving = false
            self.startReconnectTimer()
        }
        handshakeTimeout = t
        t.resume()
    }

    private func cancelHandshakeTimeout() {
        handshakeTimeout?.cancel()
        handshakeTimeout = nil
    }

    private func receiveLoop() {
        guard !isReceiving else { return }
        isReceiving = true

        connection?.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            if let d = data, !d.isEmpty {
                // Fix Issue #11: Protect rxBuffer access with lock
                self.stateLock.lock()
                self.rxBuffer.append(d)
                while let nl = self.rxBuffer.firstIndex(of: 0x0A) {
                    let line = self.rxBuffer.prefix(upTo: nl)
                    self.rxBuffer.removeSubrange(...nl)
                    self.stateLock.unlock()
                    self.handleJSONLine(Data(line))
                    self.stateLock.lock()
                }
                self.stateLock.unlock()
            }

            if let error = error {
                Logger.shared.log("🔗 MacConnectionManager: receive error: \(error)")
                self.cancelHandshakeTimeout()
                self.isReceiving = false
                DispatchQueue.main.async { [weak self] in 
                    self?.connectionStatus = "USB: Disconnected"
                    self?.connection = nil  // Clear the connection object
                }
                self.startReconnectTimer()
                return
            }

            if isComplete {
                Logger.shared.log("🔗 MacConnectionManager: connection closed by peer")
                self.cancelHandshakeTimeout()
                self.isReceiving = false
                DispatchQueue.main.async { [weak self] in 
                    self?.connectionStatus = "USB: Disconnected"
                    self?.connection = nil  // Clear the connection object
                }
                self.startReconnectTimer()
                return
            }

            self.isReceiving = false
            self.receiveLoop()
        }
    }

    private func handleJSONLine(_ data: Data) {
        // Handle CB/2 protocol response (OK/2 hmac=) - check this FIRST before JSON parsing
        if let messageString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
            if messageString.hasPrefix("OK/") {
                cancelHandshakeTimeout()
                consecutiveReconnectFailures = 0  // Reset failure counter on successful connection
                DispatchQueue.main.async { [weak self] in self?.connectionStatus = "USB: Connected" }
                Logger.shared.log("🔗 MacConnectionManager: Received CB/2 handshake response — connected")

                // Start sending heartbeats to detect disconnection
                startHeartbeatSending()
                return
            }
        }
        
        // Try to parse as JSON for other message types
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { 
            Logger.shared.log("🔗 MacConnectionManager: Failed to parse message as JSON or plain text: \(String(data: data, encoding: .utf8) ?? "unknown")")
            return 
        }
        
        // Security: Validate and sanitize message
        guard let sanitizedObj = ConnectionSecurity.shared.validateAndSanitizeMIDIMessage(obj) else {
            Logger.shared.log("🔗 MacConnectionManager: Message rejected by security validation")
            return
        }
        
        // Security: Check message rate limiting
        let deviceId = "usb_connection"
        guard ConnectionSecurity.shared.validateMessageRate(for: deviceId) else {
            Logger.shared.log("🔗 MacConnectionManager: Message rate limit exceeded")
            return
        }
        
        guard let type = sanitizedObj["type"] as? String else { return }

        switch type {
        case "heartbeat":
            // Respond to iPad heartbeat with our own heartbeat
            sendHeartbeat()

        case "batch":
            // Handle batched MIDI messages
            handleBatchMessage(sanitizedObj)

        case "midi_cc", "midi_note":
            // Handle individual MIDI messages
            handleMIDIMessage(sanitizedObj)

        default:
            print("🔗 MacConnectionManager: Unhandled type: \(type)")
        }
    }

    private func startReconnectTimer() {
        // SLEEP/WAKE FIX: Removed reconnection attempt limit to ensure Bridge keeps trying
        // This prevents "giving up" after Mac wake when iPad might take longer to be ready
        // The backoff strategy prevents infinite fast loops while still allowing unlimited retries

        // Log warning after many attempts, but don't stop trying
        if consecutiveReconnectFailures >= maxConsecutiveReconnects {
            Logger.shared.log("🔗 MacConnectionManager: ⚠️ High reconnection attempts (\(consecutiveReconnectFailures)) - continuing to retry with backoff")
        }

        // Fix Issue #12: Protect reconnectPending with lock
        stateLock.lock()
        let isPending = reconnectPending
        if !isPending {
            reconnectPending = true
        }
        stateLock.unlock()

        guard !isPending else { return }

        consecutiveReconnectFailures += 1

        // Smart backoff: Fast retries for first 5 attempts, then progressively slower, max 10s
        // Attempts 1-5: 1s delay (5 seconds total) - iPad usually ready quickly
        // Attempts 6-15: 3s delay (30 seconds more = 35s total) - Give more time after sleep/wake
        // Attempts 16+: 10s delay (unlimited attempts with reasonable backoff)
        let delay: TimeInterval = {
            if consecutiveReconnectFailures <= 5 {
                return 1.0  // Fast retry for first 5 attempts
            } else if consecutiveReconnectFailures <= 15 {
                return 3.0  // Medium retry for next 10 attempts
            } else {
                return 10.0  // Slower retry for extended attempts (was 5.0, now 10.0 for less aggressive polling)
            }
        }()

        Logger.shared.log("🔗 MacConnectionManager: 🔄 Scheduling reconnect attempt #\(consecutiveReconnectFailures) in \(Int(delay))s")

        let src = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
        src.schedule(deadline: .now() + delay)
        src.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.stateLock.lock()
            self.reconnectPending = false
            self.stateLock.unlock()
            self.waitAndConnect()
        }
        reconnectSource = src
        src.resume()
    }

    private func stopReconnectTimer() {
        reconnectSource?.cancel()
        reconnectSource = nil
        stateLock.lock()
        reconnectPending = false
        stateLock.unlock()
    }
    
    // MARK: - Event-Driven USB Device Monitoring
    
    private func setupUSBDeviceMonitoring() {
        Logger.shared.log("🔗 MacConnectionManager: Setting up USB device monitoring for instant reconnection")
        
        // Listen for USB device mount events to trigger immediate reconnection
        usbDeviceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleUSBDeviceMounted(notification)
        }
        
        Logger.shared.log("🔗 MacConnectionManager: ✅ USB device monitoring active")
    }
    
    private func stopUSBDeviceMonitoring() {
        if let observer = usbDeviceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            usbDeviceObserver = nil
        }
        Logger.shared.log("🔗 MacConnectionManager: USB device monitoring stopped")
    }

    private func setupDeviceDisconnectNotification() {
        Logger.shared.log("🔗 MacConnectionManager: Setting up device disconnect notification listener")

        deviceDisconnectObserver = NotificationCenter.default.addObserver(
            forName: .iosDeviceDisconnected,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDeviceDisconnected()
        }

        Logger.shared.log("🔗 MacConnectionManager: ✅ Device disconnect notification listener active")
    }

    private func stopDeviceDisconnectNotification() {
        if let observer = deviceDisconnectObserver {
            NotificationCenter.default.removeObserver(observer)
            deviceDisconnectObserver = nil
        }
        Logger.shared.log("🔗 MacConnectionManager: Device disconnect notification listener stopped")
    }

    private func handleDeviceDisconnected() {
        Logger.shared.log("🔗 MacConnectionManager: 📱 iOS device disconnected! Updating UI and stopping connection...")

        // Immediately update UI
        DispatchQueue.main.async { [weak self] in
            self?.connectionStatus = "USB: Disconnected"
        }

        // Cancel existing connection
        connection?.cancel()
        connection = nil
        isReceiving = false

        // Stop reconnect attempts
        stopReconnectTimer()
        stopHeartbeatSending()
        cancelHandshakeTimeout()

        // Reset state
        stateLock.lock()
        connecting = false
        didSendHandshake = false
        reconnectPending = false
        consecutiveReconnectFailures = 0
        stateLock.unlock()
    }

    // MARK: - Wake Notification Observer (SLEEP/WAKE FIX)

    private func setupWakeNotificationObserver() {
        Logger.shared.log("🔗 MacConnectionManager: Setting up iproxy wake notification observer")

        wakeNotificationObserver = NotificationCenter.default.addObserver(
            forName: .iproxyDidRestartAfterWake,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleIProxyRestartAfterWake()
        }

        Logger.shared.log("🔗 MacConnectionManager: ✅ iproxy wake notification observer active")
    }

    private func stopWakeNotificationObserver() {
        if let observer = wakeNotificationObserver {
            NotificationCenter.default.removeObserver(observer)
            wakeNotificationObserver = nil
        }
        Logger.shared.log("🔗 MacConnectionManager: iproxy wake notification observer stopped")
    }

    private func handleIProxyRestartAfterWake() {
        Logger.shared.log("🔗 MacConnectionManager: ⏰ iproxy restarted after wake - resetting failure counter for fresh attempts")

        // Reset failure counter to give Bridge fresh reconnection attempts after Mac wake
        stateLock.lock()
        let previousFailures = consecutiveReconnectFailures
        consecutiveReconnectFailures = 0
        stateLock.unlock()

        Logger.shared.log("🔗 MacConnectionManager: ✅ Failure counter reset from \(previousFailures) to 0 - Bridge will retry connection")

        // If we're not currently connected and not currently connecting, try to connect
        stateLock.lock()
        let shouldAttemptConnection = !connecting && connection == nil
        stateLock.unlock()

        if shouldAttemptConnection {
            Logger.shared.log("🔗 MacConnectionManager: 🔄 Attempting connection after wake...")
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.waitAndConnect()
            }
        }
    }

    private func handleUSBDeviceMounted(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let devicePath = userInfo[NSWorkspace.volumeURLUserInfoKey] as? URL else {
            return
        }
        
        Logger.shared.log("🔗 MacConnectionManager: USB device mounted at: \(devicePath.path)")
        
        // Check if this is an iOS device
        if isiOSDevicePath(devicePath.path) {
            Logger.shared.log("🔗 MacConnectionManager: 🎯 iOS device detected! Triggering immediate reconnection...")

            // Cancel any pending reconnection timer and connect immediately
            consecutiveReconnectFailures = 0  // Reset failure counter when device mounted
            stopReconnectTimer()
            
            // Wait a moment for iproxy to start, then connect immediately
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.waitAndConnect()
            }
        }
    }
    
    private func isiOSDevicePath(_ path: String) -> Bool {
        // Check for common iOS device mount points
        let iosDevicePatterns = [
            "/Volumes/iPhone",
            "/Volumes/iPad", 
            "/Volumes/iPod",
            "/Volumes/Apple iPhone",
            "/Volumes/Apple iPad"
        ]
        
        return iosDevicePatterns.contains { pattern in
            path.hasPrefix(pattern)
        }
    }
    
    // MARK: - Heartbeat for Disconnection Detection
    
    private var heartbeatTimer: Timer?
    
    private func startHeartbeatSending() {
        Logger.shared.log("🔗 MacConnectionManager: Starting heartbeat sending")
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }
    
    private func stopHeartbeatSending() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        Logger.shared.log("🔗 MacConnectionManager: Stopped heartbeat sending")
    }
    
    private func sendHeartbeat() {
        guard let connection = connection else { return }
        
        let heartbeat: [String: Any] = [
            "type": "heartbeat",
            "source": "mac_bridge",
            "timestamp": Int(Date().timeIntervalSince1970)
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: heartbeat) else { return }
        let framed = data + Data([0x0A])
        
        connection.send(content: framed, completion: .contentProcessed { error in
            if let error = error {
                Logger.shared.log("🔗 MacConnectionManager: Heartbeat send error: \(error)")
            }
        })
    }
    
    private func handleBatchMessage(_ obj: [String: Any]) {
        guard let messages = obj["messages"] as? [String] else {
            Logger.shared.log("❌ Invalid batch message format")
            return
        }
        
        Logger.shared.log("🔗 MacConnectionManager: Processing batch of \(messages.count) messages")

        // MIDI activity indicator is triggered by each individual message in handleMIDIMessage()
        // This ensures the indicator flashes for every MIDI message, not just once per batch
        
        for messageString in messages {
            guard let messageData = messageString.data(using: .utf8),
                  let messageObj = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any] else {
                continue
            }
            
            handleMIDIMessage(messageObj)
        }
    }
    
    private func handleMIDIMessage(_ obj: [String: Any]) {
        guard let type = obj["type"] as? String else { return }

        switch type {
        case "midi_cc":
            if let channel = obj["channel"] as? Int,
               let cc = obj["cc"] as? Int,
               let value = obj["value"] as? Int {
                Logger.shared.log("🔗 MacConnectionManager: Received MIDI CC: ch=\(channel) cc=\(cc) val=\(value)")
                // Forward to WiFi server for MIDI processing
                forwardMIDIToWiFiServer(obj)
            }

        case "midi_note":
            if let channel = obj["channel"] as? Int,
               let note = obj["note"] as? Int,
               let velocity = obj["velocity"] as? Int {
                Logger.shared.log("🔗 MacConnectionManager: Received MIDI Note: ch=\(channel) note=\(note) vel=\(velocity)")
                // Forward to WiFi server for MIDI processing
                forwardMIDIToWiFiServer(obj)
            }

        default:
            Logger.shared.log("🔗 MacConnectionManager: Unknown MIDI message type: \(type)")
        }
    }
    
    private func forwardMIDIToWiFiServer(_ midiObj: [String: Any]) {
        // Forward MIDI message to WiFi server for processing
        // This ensures MIDI gets sent to the virtual MIDI port
        NotificationCenter.default.post(
            name: NSNotification.Name("ForwardMIDIToWiFiServer"),
            object: midiObj
        )
    }
    
    func sendMIDIToIPad(_ message: String) {
        guard let connection = connection else {
            Logger.shared.log("🔗 MacConnectionManager: No USB connection - cannot send MIDI to iPad")
            return
        }
        
        Logger.shared.log("🔗 MacConnectionManager: Sending MIDI to iPad via USB: \(message.trimmingCharacters(in: .whitespacesAndNewlines))")
        
        connection.send(content: message.data(using: .utf8), completion: .contentProcessed { error in
            if let error = error {
                Logger.shared.log("🔗 MacConnectionManager: Failed to send MIDI to iPad: \(error)")
            } else {
                Logger.shared.log("🔗 MacConnectionManager: ✅ MIDI sent to iPad successfully")
            }
        })
    }
    
}
