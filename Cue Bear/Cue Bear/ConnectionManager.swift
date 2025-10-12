import Foundation
import Network
import Combine
import Darwin // For USB device notifications
import UIKit // For background task support
import CoreMIDI // For MIDI device monitoring

/// Bulletproof connection manager ensuring zero disconnections
/// Implements automatic recovery, health monitoring, and connection persistence
class ConnectionManager: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var isConnecting: Bool = false
    @Published var connectionHealth: ConnectionHealth = .disconnected
    @Published var lastConnectionTime: Date?
    @Published var connectionAttempts: Int = 0
    @Published var connectedComputerName: String? = nil
    @Published var connectionQuality: ConnectionQuality = .disconnected
    
    // Dedicated queue for all USB socket work (no UI here).
    private let usbQueue = DispatchQueue(label: "com.cuebear.usbserver")
    private var activeUSB: NWConnection?
    private var listener: NWListener?
    private var healthTimer: Timer?
    private var reconnectTimer: Timer?
    private var heartbeatTimer: Timer?
    private var connectionMonitorTimer: Timer?
    private var midiMonitorTimer: Timer?
    private let queue = DispatchQueue(label: "ConnectionManager", qos: .userInitiated)
    
    // Connection configuration
    private let port: UInt16 = 9360  // USB server port for Bridge app connection
    private let healthCheckInterval: TimeInterval = 2.0
    private let reconnectInterval: TimeInterval = 1.0
    private let heartbeatCheckInterval: TimeInterval = 1.0  // Check for heartbeat every 1 second
    private let heartbeatTimeout: TimeInterval = 3.0  // Consider disconnected if no heartbeat for 3 seconds
    private let maxReconnectAttempts = 5
    
    // Connection state tracking
    private var isListening = false
    private var shouldReconnect = true
    
    // USB device detection
    private var usbDeviceObserver: NSObjectProtocol?
    private var isMonitoringUSB = false
    @Published var isUSBCableConnected: Bool = false  // NEW: Track physical USB cable connection
    
    // MIDI device monitoring
    private var midiDeviceObserver: NSObjectProtocol?
    private var isMonitoringMIDI = false
    @Published var usbBridgeAvailable: Bool = false
    
    // Background task support for maintaining connections during sleep
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    // Public accessor for connection state
    var isServerListening: Bool {
        return isListening
    }
    private var lastHealthCheck: Date = Date.distantPast
    private var lastHeartbeat: Date = Date.distantPast
    private var consecutiveFailures = 0
    
    // Connection quality metrics
    private var connectionLatency: TimeInterval = 0
    private var packetLossCount: Int = 0
    private var totalPackets: Int = 0
    private var lastQualityUpdate: Date = Date.distantPast
    
    // JSON framing buffer for newline-delimited messages
    private var rxBuffer = Data()
    
    // Message batching for performance optimization
    private var messageBatch: [String] = []
    private var batchTimer: Timer?
    private let batchSize = 5 // Reduced for lower latency
    private let batchTimeout: TimeInterval = 0.01 // 10ms for lower latency
    private let maxBatchSize = 100 // CRITICAL: Prevent unbounded growth during stress testing
    private var isSendingBatch = false // Prevent concurrent batch sends
    
    // Handshake timeout timers per connection
    private var handshakeTimers: [ObjectIdentifier: DispatchSourceTimer] = [:]
    
    // Callback for connection state changes
    private var connectionStateCallback: ((Bool) -> Void)?
    
    // WiFi connection state (set by ConnectionCoordinator)
    private var isWiFiConnected: Bool = false
    
    enum ConnectionHealth {
        case disconnected
        case connecting
        case connected
        case degraded
        case critical
    }
    
    enum ConnectionQuality {
        case excellent, good, fair, poor, disconnected
        
        static func fromHealth(_ health: ConnectionHealth) -> ConnectionQuality {
            switch health {
            case .connected: return .excellent
            case .connecting: return .fair
            case .degraded: return .poor
            case .critical: return .poor
            case .disconnected: return .disconnected
            }
        }
    }
    
    init() {
        startHealthMonitoring()
        setupUSBDeviceMonitoring()
        setupMIDIDeviceMonitoring()
        setupBackgroundTaskSupport()

        // Initial USB cable state: Start optimistic - assume cable might be connected
        // This allows the chip to show if USB is already connected at app launch
        // The Darwin notifications will update this state when cable is actually connected/disconnected
        isUSBCableConnected = false
        debugPrint("🔗 ConnectionManager: Initialized - USB chip will appear when cable is connected")
    }
    
    deinit {
        stopUSBDeviceMonitoring()
        stopMIDIDeviceMonitoring()
        endBackgroundTask()
        stop()
    }
    
    // MARK: - Public Interface
    
    func start() {
        debugPrint("🔗 ConnectionManager: Starting bulletproof connection system")
        shouldReconnect = true
        startListening()   // USB first
    }
    
    // MARK: - MIDI Sending
    
    func sendMIDI(type: MIDIKind, channel: Int, number: Int, value: Int, label: String, buttonID: String) {
        guard isConnected && activeUSB != nil else {
            debugPrint("🔗 ConnectionManager: No connection - cannot send MIDI")
            return
        }
        
        let payload: [String: Any]
        switch type {
        case .cc:
            payload = [
                "type": "midi_cc",
                "channel": channel,
                "cc": number,
                "value": value,
                "label": label,
                "button_id": buttonID
            ]
        case .note:
            payload = [
                "type": "midi_note",
                "channel": channel,
                "note": number,
                "velocity": value,
                "label": label,
                "button_id": buttonID
            ]
        }
        
        sendJSON(payload)
    }
    
    private func sendJSON(_ obj: [String: Any]) {
        guard isConnected, let _ = activeUSB else {
            debugPrint("🔗 ConnectionManager: No connection - cannot send JSON")
            return
        }
        
        guard let data = try? JSONSerialization.data(withJSONObject: obj),
              let message = String(data: data, encoding: .utf8) else {
            debugPrint("🔗 ConnectionManager: Failed to create JSON")
            return
        }
        
        // Add to batch for performance optimization
        addToBatch(message)
    }
    
    private func addToBatch(_ message: String) {
        // CRITICAL: Enforce maximum batch size to prevent unbounded growth during stress testing
        if messageBatch.count >= maxBatchSize {
            debugPrint("🔗 ConnectionManager: ⚠️ Batch at maximum size (\(maxBatchSize)) - forcing immediate send")
            sendBatch()
        }

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
        // CRITICAL: Prevent concurrent batch sends which could cause race conditions
        guard !isSendingBatch else {
            debugPrint("🔗 ConnectionManager: Already sending batch - skipping concurrent send")
            return
        }

        guard !messageBatch.isEmpty else { return }

        batchTimer?.invalidate()
        batchTimer = nil

        guard isConnected, let connection = activeUSB else {
            debugPrint("🔗 ConnectionManager: No connection - cannot send batch")
            messageBatch.removeAll()
            return
        }

        // CRITICAL FIX: Copy batch and clear IMMEDIATELY before serialization
        // This prevents unbounded growth during stress testing
        let messagesToSend = messageBatch
        let messageCount = messagesToSend.count
        messageBatch.removeAll() // Clear NOW, not in completion handler
        isSendingBatch = true

        // CRITICAL FIX: Move JSON serialization to background thread
        // This prevents main thread freeze during stress testing
        DispatchQueue.global(qos: .userInitiated).async { [weak self, weak connection] in
            guard let self = self, let connection = connection else {
                DispatchQueue.main.async { [weak self] in
                    self?.isSendingBatch = false
                }
                return
            }

            // Create batched message (now on background thread)
            let batchedMessage = [
                "type": "batch",
                "messages": messagesToSend,
                "count": messageCount,
                "timestamp": Date().timeIntervalSince1970
            ] as [String: Any]

            // Serialize JSON on background thread
            guard let data = try? JSONSerialization.data(withJSONObject: batchedMessage),
                  let message = String(data: data, encoding: .utf8) else {
                debugPrint("🔗 ConnectionManager: ❌ Failed to create batch JSON")
                DispatchQueue.main.async { [weak self] in
                    self?.isSendingBatch = false
                }
                return
            }

            guard let messageData = (message + "\n").data(using: .utf8) else {
                debugPrint("🔗 ConnectionManager: ❌ Failed to encode batch message as UTF-8")
                DispatchQueue.main.async { [weak self] in
                    self?.isSendingBatch = false
                }
                return
            }

            // Send data (network I/O happens on connection's queue)
            connection.send(content: messageData, completion: .contentProcessed { [weak self] error in
                DispatchQueue.main.async { [weak self] in
                    self?.isSendingBatch = false
                    if let error = error {
                        debugPrint("🔗 ConnectionManager: ❌ Failed to send batch: \(error)")
                    } else {
                        debugPrint("🔗 ConnectionManager: ✅ Batch sent successfully (\(messageCount) messages)")
                    }
                }
            })
        }
    }
    
    func stop() {
        debugPrint("🔗 ConnectionManager: Stopping connection system")
        shouldReconnect = false
        
        // Cancel all handshake timers
        for timer in handshakeTimers.values {
            timer.cancel()
        }
        handshakeTimers.removeAll()
        
        // Clear message batch
        batchTimer?.invalidate()
        batchTimer = nil
        messageBatch.removeAll()
        isSendingBatch = false
        
        stopListening()
        stopHealthMonitoring()
        stopHeartbeatMonitoring()
        stopConnectionMonitoring()
        stopReconnectTimer()
    }
    
    func setConnectionStateCallback(_ callback: @escaping (Bool) -> Void) {
        self.connectionStateCallback = callback
    }
    
    // Method for ConnectionCoordinator to inform about WiFi connection state
    func setWiFiConnectionState(_ isConnected: Bool) {
        isWiFiConnected = isConnected
        // Update USB bridge availability when WiFi state changes
        checkUSBBridgeAvailability()
    }
    
    func forceReconnect() {
        debugPrint("🔗 ConnectionManager: Force reconnecting...")
        stopListening()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startListening()
        }
    }
    
    // MARK: - Private Implementation
    
    private func startListening() {
        guard !isListening else {
            debugPrint("🔗 ConnectionManager: Already listening, skipping")
            return
        }
        
        // Check if we're already in the process of starting a listener
        guard listener == nil else {
            debugPrint("🔗 ConnectionManager: Listener already exists, skipping")
            return
        }
        
        debugPrint("🔗 ConnectionManager: Starting listener on port \(port)")
        isListening = true

        // Set connecting state for UI animation
        DispatchQueue.main.async { [weak self] in
            self?.connectionHealth = .connecting
            self?.isConnecting = true
        }
        
        // Cancel any existing listener first to prevent port conflicts
        if let existingListener = listener {
            debugPrint("🔗 ConnectionManager: Cancelling existing listener to prevent port conflicts")
            existingListener.cancel()
            listener = nil
        }
        
        do {
            let params = NWParameters.tcp
            let tcp = NWProtocolTCP.Options()
            tcp.noDelay = true
            tcp.enableKeepalive = true
            params.defaultProtocolStack.transportProtocol = tcp
            params.allowLocalEndpointReuse = true
            params.allowFastOpen = true
            
            // Configure for USB connections - listen on all interfaces
            // Don't restrict interface type - let it listen on all available interfaces
            
            // Bind to localhost for USB connections (iproxy forwards to localhost)
            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                debugPrint("🔗 ConnectionManager: Invalid port number: \(port)")
                isListening = false
                handleConnectionFailure()
                return
            }
            // For USB connections, we need to listen on localhost interface
            listener = try NWListener(using: params, on: nwPort)
            
            debugPrint("🔗 ConnectionManager: Created listener for port \(port) on all interfaces")
            debugPrint("🔗 ConnectionManager: Listener parameters: \(params)")
            debugPrint("🔗 ConnectionManager: Listener port: \(nwPort)")
            debugPrint("🔗 ConnectionManager: Listener queue: \(usbQueue)")
            
            debugPrint("🔗 ConnectionManager: Setting up newConnectionHandler...")
            listener?.newConnectionHandler = { [weak self] connection in
                debugPrint("🔗 ConnectionManager: *** NEW CONNECTION HANDLER CALLED ***")
                debugPrint("🔗 ConnectionManager: Connection from: \(connection.endpoint)")
                guard let self = self else { 
                    debugPrint("🔗 ConnectionManager: Self is nil, returning")
                    return 
                }
                self.usbQueue.async {
                    self.logMain("🔗 USB: accepted \(connection.endpoint)")
                    // Gate: only one active connection (but check if existing connection is actually valid)
                    if let existingConnection = self.activeUSB {
                        // Check if the existing connection is still valid
                        let state = existingConnection.state
                        if case .ready = state {
                            // Existing connection is healthy, reject new one
                            self.logMain("⚠️ USB: already connected and healthy; closing new conn")
                            connection.cancel()
                            return
                        } else {
                            // Existing connection is stale/dead, replace it
                            self.logMain("🔗 USB: existing connection is stale (\(state)), replacing with new connection")
                            existingConnection.cancel()
                            self.activeUSB = nil
                        }
                    }
                    self.activeUSB = connection
                    connection.stateUpdateHandler = { [weak self] st in
                        self?.logMain("🔗 USB conn state: \(st)")
                        self?.handleConnectionStateChange(st, connection: connection)
                        
                        // Immediate disconnect detection for USB cable removal
                        if case .cancelled = st {
                            self?.logMain("🔗 USB connection cancelled - immediate disconnect detection")
                            DispatchQueue.main.async {
                                self?.isConnected = false
                                self?.isConnecting = false
                                self?.connectionHealth = .disconnected
                                // Don't clear connectedComputerName to keep USB chip visible
                                // self?.connectedComputerName = nil
                                self?.connectionQuality = .disconnected
                                self?.connectionStateCallback?(false)
                            }
                        }
                    }
                    connection.start(queue: self.usbQueue)
                    // Start receiving data to handle handshake properly
                    self.beginUSBReceive(on: connection)
                }
            }
            debugPrint("🔗 ConnectionManager: newConnectionHandler set successfully")
            
            listener?.stateUpdateHandler = { [weak self] state in
                debugPrint("🔗 ConnectionManager: Listener state changed to: \(state)")
                self?.handleListenerStateChange(state)
            }
            
            listener?.start(queue: usbQueue)
            debugPrint("🔗 ConnectionManager: Listener started successfully")
            
        } catch {
            debugPrint("🔗 ConnectionManager: Failed to start listener: \(error)")
            isListening = false
            listener = nil
            
            // Handle "Address already in use" error more gracefully
            if let posixError = error as? POSIXError, posixError.code == .EADDRINUSE {
                debugPrint("🔗 ConnectionManager: Port 9360 is already in use - waiting longer before retry")
                // Wait longer before retrying for port conflicts
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                    self?.attemptReconnection()
                }
            } else {
                handleConnectionFailure()
            }
        }
    }
    
    private func stopListening() {
        debugPrint("🔗 ConnectionManager: Stopping listener")
        // Don't set isListening = false to keep USB chip visible
        // isListening = false
        
        closeUSB(activeUSB)
        activeUSB = nil
        
        listener?.cancel()
        listener = nil
        
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = false
            self?.isConnecting = false
            self?.connectionHealth = .disconnected
            // Don't clear connectedComputerName to keep USB chip visible
            // self?.connectedComputerName = nil
            self?.connectionQuality = .disconnected
            
            // Notify callback of connection state change
            self?.connectionStateCallback?(false)
            
            // Update USB bridge availability to keep chip visible
            self?.checkUSBBridgeAvailability()
        }
    }
    
    private func beginUSBReceive(on conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, err in
            guard let self = self else { return }
            if let err = err {
                self.logMain("❌ USB recv error: \(err)")
                self.closeUSB(conn)
                return
            }
            if isComplete {
                self.logMain("ℹ️ USB conn completed")
                self.closeUSB(conn)
                return
            }
            if let data = data, !data.isEmpty {
                let s = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                self.logMain("🔹 USB received: \(s)")
                
                // Handle handshake from Bridge app - support CB/1, CB/2, and JSON formats
                if s == "CB/1 HELLO" {
                    self.logMain("🤝 USB: Received CB/1 handshake from Bridge")
                    guard let ack = "CB/1 HELLO_ACK\n".data(using: .utf8) else {
                        self.logMain("❌ USB: Failed to encode CB/1 HELLO_ACK as UTF-8")
                        return
                    }
                    conn.send(content: ack, completion: .contentProcessed({ [weak self] error in
                        if let error = error {
                            self?.logMain("❌ USB: Failed to send CB/1 HELLO_ACK: \(error)")
                        } else {
                            self?.logMain("🔗 USB: sent CB/1 HELLO_ACK")
                        }
                    }))
                } else if s.hasPrefix("CB/") {
                    // Handle CB/2+ protocol handshake
                    self.logMain("🤝 USB: Received CB/2+ handshake from Bridge: \(s)")
                    self.logMain("🤝 USB: Processing CB/2+ handshake...")
                    self.logMain("🤝 USB: About to call handleCBProtocolHandshake")
                    self.handleCBProtocolHandshake(s, connection: conn)
                    self.logMain("🤝 USB: handleCBProtocolHandshake call completed")
                    self.logMain("🤝 USB: Handshake processing finished, continuing to receive...")
                } else if let jsonData = s.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                          let type = json["type"] as? String,
                          type == "handshake" {
                    self.logMain("🤝 USB: Received JSON handshake from Bridge")
                    // Send JSON response
                    let response: [String: Any] = [
                        "type": "handshake_response",
                        "server": "ipad",
                        "ok": true,
                        "proto": 1
                    ]
                    guard let responseData = try? JSONSerialization.data(withJSONObject: response),
                          let responseString = String(data: responseData, encoding: .utf8),
                          let ack = (responseString + "\n").data(using: .utf8) else {
                        self.logMain("❌ USB: Failed to create JSON response")
                        return
                    }
                    conn.send(content: ack, completion: .contentProcessed({ [weak self] error in
                        if let error = error {
                            self?.logMain("❌ USB: Failed to send JSON response: \(error)")
                        } else {
                            self?.logMain("🔗 USB: sent JSON handshake response")
                        }
                    }))
                } else {
                    // TODO: route to message handler (MIDI, etc.)
                }
            }
            // Continue receiving on usbQueue (non-blocking)
            self.usbQueue.async { self.beginUSBReceive(on: conn) }
        }
    }

    private func closeUSB(_ conn: NWConnection?) {
        conn?.cancel()
        if activeUSB === conn { activeUSB = nil }
    }
    
    private func handleCBProtocolHandshake(_ message: String, connection: NWConnection) {
        self.logMain("🤝 USB: handleCBProtocolHandshake called with message: '\(message)'")
        
        // Parse CB/2+ protocol handshake
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        
        self.logMain("🤝 USB: Parsing handshake: '\(trimmed)'")
        
        guard trimmed.hasPrefix("CB/") else { 
            self.logMain("❌ USB: Handshake doesn't start with CB/")
            return 
        }
        
        let parts = trimmed.dropFirst(3).components(separatedBy: " ")
        guard let majorStr = parts.first?.components(separatedBy: "/").first,
              let major = Int(majorStr) else { 
            self.logMain("❌ USB: Failed to parse protocol major version")
            return 
        }
        
        self.logMain("🤝 USB: Parsed protocol version: CB/\(major)")
        
        var auth = "psk1"
        var _ = "" // nonce - not used in basic handshake
        var _: [String] = [] // features - not used in basic handshake
        var _: TimeInterval = 0 // timestamp - not used in basic handshake
        var computerName = ""
        
        for part in parts.dropFirst() {
            if part.hasPrefix("auth=") {
                auth = String(part.dropFirst(5))
            } else if part.hasPrefix("nonce=") {
                _ = String(part.dropFirst(6)) // nonce - not used
            } else if part.hasPrefix("features=") {
                _ = String(part.dropFirst(9)).components(separatedBy: ",") // features - not used
            } else if part.hasPrefix("ts=") {
                _ = TimeInterval(String(part.dropFirst(3))) ?? 0 // timestamp - not used
            } else if part.hasPrefix("name=") {
                computerName = String(part.dropFirst(5))
            }
        }
        
        self.logMain("🤝 USB: Parsed CB/\(major) handshake - auth: \(auth), name: \(computerName)")
        
        // Store computer name for display (remove .local suffix if present)
        let cleanComputerName = computerName.hasSuffix(".local") ? String(computerName.dropLast(6)) : computerName
        DispatchQueue.main.async {
            self.connectedComputerName = cleanComputerName
            self.logMain("🤝 USB: Set connectedComputerName to: '\(cleanComputerName)'")
        }
        
        // Send CB/2+ response in the format the Bridge expects
        let response = "OK/\(major) hmac=\n"
        guard let responseData = response.data(using: .utf8) else {
            self.logMain("❌ USB: Failed to encode OK/\(major) response as UTF-8")
            return
        }

        self.logMain("🤝 USB: Sending response: '\(response.trimmingCharacters(in: .whitespacesAndNewlines))'")
        
        connection.send(content: responseData, completion: .contentProcessed({ [weak self] error in
            if let error = error {
                self?.logMain("❌ USB: Failed to send OK/\(major) response: \(error)")
                self?.logMain("❌ USB: Error details: \(error.localizedDescription)")
            } else {
                self?.logMain("🔗 USB: sent OK/\(major) response")
                self?.logMain("🔗 USB: Connection established with \(computerName)")
                self?.logMain("🔗 USB: About to mark connection as established...")
                
                // Mark connection as established after successful handshake
                DispatchQueue.main.async {
                    self?.logMain("🔗 USB: Marking connection as established on main thread")
                    self?.isConnected = true
                    self?.connectionHealth = .connected
                    self?.lastConnectionTime = Date()
                    self?.connectionAttempts = 0
                    self?.consecutiveFailures = 0
                    // Remove .local suffix if present
                    let cleanComputerName = computerName.hasSuffix(".local") ? String(computerName.dropLast(6)) : computerName
                    self?.connectedComputerName = cleanComputerName
                    self?.connectionQuality = .excellent
                    
                    // Notify callback of connection state change
                    self?.connectionStateCallback?(true)
                }
            }
        }))
    }

    // Never block main with logging
    private func logMain(_ s: String) {
        DispatchQueue.main.async {
            debugPrint(s)  // your existing UI-safe logger
        }
    }
    
    private func handleListenerStateChange(_ state: NWListener.State) {
        switch state {
        case .ready:
            logMain("🔗 USB Listener ready on 9360")
            DispatchQueue.main.async { [weak self] in
                self?.connectionHealth = .connecting // Listener is ready, waiting for client

                // Heuristic: If listener starts successfully on localhost, assume USB cable is connected
                // This handles the case where cable is already connected at app launch
                if let self = self, !self.isUSBCableConnected {
                    self.isUSBCableConnected = true
                    debugPrint("🔗 ConnectionManager: 🎯 USB listener ready - assuming cable is connected")
                    self.checkUSBBridgeAvailability()
                }
            }
        case .failed(let error):
            logMain("❌ USB Listener failed: \(error)")
            isListening = false
            
            // Handle "Address already in use" error more gracefully
            if case let .posix(posixError) = error, posixError == .EADDRINUSE {
                logMain("🔗 ConnectionManager: Port 9360 is already in use - waiting longer before retry")
                // Wait longer before retrying for port conflicts
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                    self?.attemptReconnection()
                }
            } else {
                handleConnectionFailure()
            }
        case .cancelled:
            logMain("🔗 ConnectionManager: Listener cancelled")
            isListening = false
            handleConnectionFailure()
        case .setup:
            debugPrint("🔗 ConnectionManager: Listener setup")
        case .waiting(let error):
            debugPrint("🔗 ConnectionManager: Listener waiting: \(error)")
        @unknown default:
            debugPrint("🔗 ConnectionManager: Unknown listener state: \(state)")
            break
        }
    }
    
    private func handleConnectionStateChange(_ state: NWConnection.State, connection: NWConnection) {
        debugPrint("🔗 ConnectionManager: Connection state changed to: \(state)")
        debugPrint("🔗 ConnectionManager: Current isConnected: \(isConnected)")
        
        switch state {
        case .ready:
            debugPrint("🔗 ConnectionManager: Connection established")
            DispatchQueue.main.async { [weak self] in
                self?.isConnected = true
                self?.isConnecting = false
                self?.connectionHealth = .connected
                self?.lastConnectionTime = Date()
                self?.connectionAttempts = 0
                self?.consecutiveFailures = 0
                // Don't set connectedComputerName here - it will be set by handshake parsing
                self?.connectionQuality = .excellent
                
                // Notify callback of connection state change
                self?.connectionStateCallback?(true)
            }
            
            // ✅ Start reading right away so we can parse the Mac's "handshake"
            startReceivingData(from: connection)
            
            // Start heartbeat monitoring to detect USB disconnection
            startHeartbeatMonitoring()
            
            // Start aggressive connection monitoring for immediate disconnect detection
            startConnectionMonitoring()
            
        case .failed(let error):
            debugPrint("🔗 ConnectionManager: Connection failed: \(error)")
            debugPrint("🔗 ConnectionManager: Error details: \(error.localizedDescription)")
            debugPrint("🔗 ConnectionManager: Setting isConnected to false due to failure")
            DispatchQueue.main.async { [weak self] in
                self?.isConnected = false
                self?.isConnecting = false
                self?.connectionHealth = .disconnected
                // Don't clear connectedComputerName to keep USB chip visible
                // self?.connectedComputerName = nil
                self?.connectionQuality = .disconnected
                self?.connectionStateCallback?(false)
            }
            handleConnectionFailure()
            
        case .cancelled:
            debugPrint("🔗 ConnectionManager: Connection cancelled")
            debugPrint("🔗 ConnectionManager: Connection was cancelled - this usually means we called cancel() or the remote side closed")
            DispatchQueue.main.async { [weak self] in
                self?.isConnected = false
                self?.isConnecting = false
                self?.connectionHealth = .disconnected
                // Don't clear connectedComputerName to keep USB chip visible
                // self?.connectedComputerName = nil
                self?.connectionQuality = .disconnected
                
                // Notify callback of connection state change
                self?.connectionStateCallback?(false)
            }
            handleConnectionFailure()
            
        case .preparing:
            debugPrint("🔗 ConnectionManager: Connection preparing...")
            DispatchQueue.main.async { [weak self] in
                self?.isConnecting = true
            }
            
        case .waiting(let error):
            debugPrint("🔗 ConnectionManager: Connection waiting: \(error)")
            
        case .setup:
            debugPrint("🔗 ConnectionManager: Connection setup")
            
        @unknown default:
            debugPrint("🔗 ConnectionManager: Unknown connection state: \(state)")
        }
    }
    
    private func startReceivingData(from connection: NWConnection) {
        debugPrint("🔗 ConnectionManager: Starting to receive data from connection")
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            debugPrint("🔗 ConnectionManager: Receive callback - data: \(data?.count ?? 0) bytes, isComplete: \(isComplete), error: \(error?.localizedDescription ?? "none")")
            
            if let data = data, !data.isEmpty {
                debugPrint("🔗 ConnectionManager: Received \(data.count) bytes of data")
                // Update health on successful data reception
                self?.updateConnectionHealth(.connected)
                self?.processReceivedData(data)
            }
            
            if let error = error {
                debugPrint("🔗 ConnectionManager: Receive error: \(error)")
                debugPrint("🔗 ConnectionManager: Error details: \(error.localizedDescription)")
                self?.handleConnectionFailure()
                return
            }
            
            if isComplete {
                debugPrint("🔗 ConnectionManager: Connection completed by remote")
                
                // Update connection state when connection is completed
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    debugPrint("🔗 ConnectionManager: 🔌 Connection completed - updating state to disconnected")
                    self.isConnected = false
                    self.isConnecting = false
                    self.connectionHealth = .disconnected
                    // Don't clear connectedComputerName to keep USB chip visible
                    // self.connectedComputerName = nil
                    self.connectionQuality = .disconnected
                    
                    // Stop listening since Bridge app has quit
                    self.isListening = false
                    debugPrint("🔗 ConnectionManager: 🛑 Stopped listening - Bridge app has quit")
                    
                    // Update USB bridge availability
                    self.checkUSBBridgeAvailability()
                    
                    self.connectionStateCallback?(false)
                }
                
                return  // Don't continue receiving, but don't treat as failure
            }
            
            debugPrint("🔗 ConnectionManager: Continuing to receive data...")
            // Continue receiving if no error and not complete
            self?.continueReceiving(from: connection)
        }
    }
    
    private func continueReceiving(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.updateConnectionHealth(.connected)
                self?.processReceivedData(data)
            }
            
            if error != nil {
                self?.handleConnectionFailure()
                return
            }
            
            if isComplete {
                // Update connection state when connection is completed
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    debugPrint("🔗 ConnectionManager: 🔌 Connection completed in continueReceiving - updating state to disconnected")
                    self.isConnected = false
                    self.isConnecting = false
                    self.connectionHealth = .disconnected
                    // Don't clear connectedComputerName to keep USB chip visible
                    // self.connectedComputerName = nil
                    self.connectionQuality = .disconnected
                    
                    // Stop listening since Bridge app has quit
                    self.isListening = false
                    debugPrint("🔗 ConnectionManager: 🛑 Stopped listening - Bridge app has quit")
                    
                    // Update USB bridge availability
                    self.checkUSBBridgeAvailability()
                    
                    self.connectionStateCallback?(false)
                }
                return
            }
            
            // Continue receiving
            self?.continueReceiving(from: connection)
        }
    }
    
    private func processReceivedData(_ data: Data) {
        debugPrint("🔗 ConnectionManager: Processing received data (\(data.count) bytes)...")
        debugPrint("🔗 ConnectionManager: Raw data as string: \(String(data: data, encoding: .utf8) ?? "invalid UTF-8")")
        rxBuffer.append(data)
        
        // Split on newline to handle newline-delimited JSON
        while let nl = rxBuffer.firstIndex(of: 0x0A) { // '\n'
            let line = rxBuffer.prefix(upTo: nl)
            rxBuffer.removeSubrange(...nl)
            debugPrint("🔗 ConnectionManager: Processing line: \(String(data: Data(line), encoding: .utf8) ?? "invalid")")
            handleJSONLine(Data(line))
        }
    }
    
    private func handleJSONLine(_ data: Data) {
        guard let message = String(data: data, encoding: .utf8) else {
            debugPrint("🔗 ConnectionManager: Failed to convert line to string")
            return
        }
        
        debugPrint("🔗 ConnectionManager: Received JSON line: \(message)")
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            debugPrint("🔗 ConnectionManager: Failed to parse JSON line: \(message)")
            return
        }
        
        debugPrint("🔗 ConnectionManager: Parsed JSON message type: \(type)")
        debugPrint("🔗 ConnectionManager: Full JSON: \(json)")
        
        switch type {
        case "handshake":
            debugPrint("🔗 ConnectionManager: Received handshake from Mac bridge")
            debugPrint("🔗 ConnectionManager: Handshake source: \(json["source"] ?? "unknown")")
            debugPrint("🔗 ConnectionManager: Handshake timestamp: \(json["ts"] ?? json["timestamp"] ?? "unknown")")
            
            // Cancel handshake timeout for this connection
            if let connection = activeUSB {
                let connectionID = ObjectIdentifier(connection)
                handshakeTimers[connectionID]?.cancel()
                handshakeTimers.removeValue(forKey: connectionID)
            }
            
            sendHandshakeResponse()
            
        case "heartbeat":
            debugPrint("🔗 ConnectionManager: Received heartbeat from Mac bridge")
            lastHeartbeat = Date()
            
        case "midi_cc", "midi_note", "transport":
            debugPrint("🔗 ConnectionManager: Received MIDI/transport message: \(type)")
            // These would be handled by the main app, not ConnectionManager
            
        case "midi_input":
            debugPrint("🔗 ConnectionManager: Received MIDI input from DAW")
            handleMIDIInputFromDAW(json)
            
        default:
            debugPrint("🔗 ConnectionManager: Unknown message type: \(type)")
        }
    }
    
    private func sendHandshakeResponse() {
        debugPrint("🔗 ConnectionManager: Preparing to send handshake response...")
        guard let connection = activeUSB else { 
            debugPrint("🔗 ConnectionManager: No current connection - cannot send handshake response")
            return 
        }
        
        // Use the EXACT format the Mac bridge expects
        let response: [String: Any] = [
            "type": "handshake_response",
            "server": "ipad",
            "ok": true,
            "proto": 1
        ]
        
        debugPrint("🔗 ConnectionManager: Handshake response JSON: \(response)")
        
        guard let data = try? JSONSerialization.data(withJSONObject: response),
              let message = String(data: data, encoding: .utf8),
              let messageData = (message + "\n").data(using: .utf8) else {
            debugPrint("🔗 ConnectionManager: Failed to create handshake response JSON")
            return
        }

        debugPrint("🔗 ConnectionManager: Sending handshake response: \(message)")
        
        connection.send(content: messageData, completion: .contentProcessed { [weak self] (error: NWError?) in
            if let error = error {
                debugPrint("🔗 ConnectionManager: Failed to send handshake response: \(error)")
                debugPrint("🔗 ConnectionManager: Error details: \(error.localizedDescription)")
                self?.handleConnectionFailure()
            } else {
                debugPrint("🔗 ConnectionManager: Handshake response sent successfully!")
                debugPrint("🔗 ConnectionManager: Connection is now fully established")
                
                // Connection is already established in .ready case, just continue receiving
                // No need to promote connection again
            }
        })
    }
    
    private func handleConnectionFailure() {
        debugPrint("🔗 ConnectionManager: Handling connection failure")
        debugPrint("🔗 ConnectionManager: Consecutive failures: \(consecutiveFailures)")
        consecutiveFailures += 1
        
        // Stop monitoring
        stopHeartbeatMonitoring()
        stopConnectionMonitoring()
        
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = false
            self?.isConnecting = false
            self?.connectionHealth = .disconnected
            // Don't clear connectedComputerName to keep USB chip visible
            // self?.connectedComputerName = nil
            self?.connectionQuality = .disconnected
            
            // Notify callback of connection state change
            self?.connectionStateCallback?(false)
            
            // Update USB bridge availability to keep chip visible
            self?.checkUSBBridgeAvailability()
        }
        
        // Start reconnection if needed
        if shouldReconnect && consecutiveFailures <= maxReconnectAttempts {
            let delay = min(Double(consecutiveFailures) * reconnectInterval, 10.0)
            debugPrint("🔗 ConnectionManager: Scheduling reconnection in \(delay)s (attempt \(consecutiveFailures))")
            startReconnectTimer()
        } else if consecutiveFailures > maxReconnectAttempts {
            debugPrint("🔗 ConnectionManager: Max reconnection attempts reached")
            DispatchQueue.main.async { [weak self] in
                self?.connectionHealth = .critical
            }
        }
    }
    
    // Handle MIDI input from DAW and update iPad faders
    private func handleMIDIInputFromDAW(_ json: [String: Any]) {
        guard let midiBytes = json["midi"] as? [Int], midiBytes.count >= 3 else {
            debugPrint("🔗 ConnectionManager: Invalid MIDI input data")
            return
        }
        
        let statusByte = midiBytes[0]
        let data1 = midiBytes[1]
        let data2 = midiBytes[2]
        
        // Parse MIDI message
        let messageType = statusByte & 0xF0
        let channel = (statusByte & 0x0F) + 1 // Convert to 1-based channel
        
        debugPrint("🔗 ConnectionManager: MIDI input - Type: 0x\(String(format: "%02X", messageType)), Ch: \(channel), Data1: \(data1), Data2: \(data2)")
        
        switch messageType {
        case 0xB0: // Control Change (CC)
            debugPrint("🔗 ConnectionManager: MIDI CC Ch\(channel) CC\(data1)=\(data2)")
            
            // Post notification to update faders on main thread
            DispatchQueue.main.async {
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
            }
            
        case 0x90: // Note On
            debugPrint("🔗 ConnectionManager: MIDI Note On Ch\(channel) Note\(data1) Vel\(data2)")
            
            // Post notification for note messages on main thread
            DispatchQueue.main.async {
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
            }
            
        default:
            debugPrint("🔗 ConnectionManager: Unhandled MIDI message type: 0x\(String(format: "%02X", messageType))")
        }
    }
    
    private func startReconnectTimer() {
        stopReconnectTimer()
        
        let delay = min(Double(consecutiveFailures) * reconnectInterval, 10.0)
        debugPrint("🔗 ConnectionManager: Scheduling reconnection in \(delay)s (attempt \(consecutiveFailures))")
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.attemptReconnection()
        }
    }
    
    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
    
    private func attemptReconnection() {
        guard shouldReconnect else { return }
        
        // Don't reconnect if we already have an active connection
        guard !isConnected else {
            debugPrint("🔗 ConnectionManager: Already connected, skipping reconnection attempt")
            return
        }
        
        // Don't reconnect if we're already listening
        guard !isListening else {
            debugPrint("🔗 ConnectionManager: Already listening, skipping reconnection attempt")
            return
        }
        
        debugPrint("🔗 ConnectionManager: Attempting reconnection...")
        connectionAttempts += 1
        
        DispatchQueue.main.async { [weak self] in
            self?.connectionHealth = .connecting
        }
        
        stopListening()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startListening()
        }
    }
    
    // MARK: - Health Monitoring

    private func startHealthMonitoring() {
        guard isConnected else {
            debugPrint("🔗 ConnectionManager: Skipping health monitoring - not connected")
            return
        }

        healthTimer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { [weak self] _ in
            guard let self = self, self.isConnected else {
                self?.stopHealthMonitoring()
                return
            }
            self.performHealthCheck()
        }
    }
    
    private func stopHealthMonitoring() {
        healthTimer?.invalidate()
        healthTimer = nil
    }
    
    private func performHealthCheck() {
        guard isConnected else { return }
        
        let now = Date()
        let timeSinceLastData = now.timeIntervalSince(lastHealthCheck)
        
        // Update health based on data flow
        if timeSinceLastData > 10.0 {
            updateConnectionHealth(.critical)
        } else if timeSinceLastData > 5.0 {
            updateConnectionHealth(.degraded)
        } else {
            updateConnectionHealth(.connected)
        }
        
        lastHealthCheck = now
    }
    
    private func updateConnectionHealth(_ health: ConnectionHealth) {
        DispatchQueue.main.async { [weak self] in
            self?.connectionHealth = health
            self?.updateConnectionQuality()
        }
    }
    
    // MARK: - Heartbeat Monitoring for USB Disconnect Detection

    private func startHeartbeatMonitoring() {
        guard isConnected else {
            debugPrint("🔗 ConnectionManager: Skipping heartbeat monitoring - not connected")
            return
        }

        debugPrint("🔗 ConnectionManager: Starting heartbeat monitoring for USB disconnect detection")
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatCheckInterval, repeats: true) { [weak self] _ in
            guard let self = self, self.isConnected else {
                self?.stopHeartbeatMonitoring()
                return
            }
            self.checkHeartbeat()
        }
    }
    
    private func stopHeartbeatMonitoring() {
        debugPrint("🔗 ConnectionManager: Stopping heartbeat monitoring")
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    private func checkHeartbeat() {
        guard isConnected else { return }
        
        let now = Date()
        let timeSinceLastHeartbeat = now.timeIntervalSince(lastHeartbeat)
        
        debugPrint("🔗 ConnectionManager: Heartbeat check - time since last heartbeat: \(timeSinceLastHeartbeat)s")
        
        if timeSinceLastHeartbeat > heartbeatTimeout {
            debugPrint("🔗 ConnectionManager: Heartbeat timeout - USB connection appears to be disconnected")
            debugPrint("🔗 ConnectionManager: Last heartbeat was \(timeSinceLastHeartbeat)s ago, timeout is \(heartbeatTimeout)s")
            
            // USB connection appears to be disconnected
            DispatchQueue.main.async { [weak self] in
                self?.isConnected = false
                self?.isConnecting = false
                self?.connectionHealth = .disconnected
                // Don't clear connectedComputerName to keep USB chip visible
                // self?.connectedComputerName = nil
                self?.connectionQuality = .disconnected
                
                // Notify callback of connection state change
                self?.connectionStateCallback?(false)
            }
            
            // Stop heartbeat monitoring
            stopHeartbeatMonitoring()
            
            // Handle the connection failure
            handleConnectionFailure()
        }
    }
    
    // MARK: - Aggressive Connection Monitoring for Immediate Disconnect Detection
    
    private func startConnectionMonitoring() {
        debugPrint("🔗 ConnectionManager: Starting event-driven connection monitoring")
        
        // Set up direct connection state monitoring (no polling needed)
        if let connection = activeUSB {
            connection.stateUpdateHandler = { [weak self] state in
                debugPrint("🔗 ConnectionManager: Direct state update - \(state)")
                switch state {
                case .cancelled, .failed:
                    debugPrint("🔗 ConnectionManager: Direct disconnect detected - \(state)")
                    DispatchQueue.main.async { [weak self] in
                        self?.isConnected = false
                        self?.isConnecting = false
                        self?.connectionHealth = .disconnected
                        // Don't clear connectedComputerName to keep USB chip visible
                        // self?.connectedComputerName = nil
                        self?.connectionQuality = .disconnected
                        self?.connectionStateCallback?(false)
                    }
                default:
                    break
                }
            }
        }
    }
    
    private func stopConnectionMonitoring() {
        debugPrint("🔗 ConnectionManager: Stopping connection monitoring")
        connectionMonitorTimer?.invalidate()
        connectionMonitorTimer = nil
    }
    
    private func updateConnectionQuality() {
        let now = Date()
        let _ = now.timeIntervalSince(lastQualityUpdate)
        
        // Update quality based on health and metrics
        let quality: ConnectionQuality
        switch connectionHealth {
        case .connected:
            if connectionLatency < 0.05 && packetLossCount == 0 {
                quality = .excellent
            } else if connectionLatency < 0.1 && packetLossCount < 2 {
                quality = .good
            } else if connectionLatency < 0.2 && packetLossCount < 5 {
                quality = .fair
            } else {
                quality = .poor
            }
        case .connecting:
            quality = .fair
        case .degraded, .critical:
            quality = .poor
        case .disconnected:
            quality = .disconnected
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.connectionQuality = quality
        }
        
        lastQualityUpdate = now
    }
    
    // MARK: - Connection Persistence
    
    func saveConnectionState() {
        let state: [String: Any] = [
            "isConnected": isConnected,
            "lastConnectionTime": lastConnectionTime?.timeIntervalSince1970 ?? 0,
            "connectionAttempts": connectionAttempts
        ]
        UserDefaults.standard.set(state, forKey: "ConnectionManagerState")
    }
    
    func restoreConnectionState() {
        guard let state = UserDefaults.standard.dictionary(forKey: "ConnectionManagerState") else { return }
        
        if let lastTime = state["lastConnectionTime"] as? TimeInterval, lastTime > 0 {
            lastConnectionTime = Date(timeIntervalSince1970: lastTime)
        }
        
        connectionAttempts = state["connectionAttempts"] as? Int ?? 0
        
        // If we had a recent connection, try to restore it
        if let wasConnected = state["isConnected"] as? Bool, wasConnected {
            let timeSinceLastConnection = Date().timeIntervalSince(lastConnectionTime ?? Date.distantPast)
            if timeSinceLastConnection < 30.0 { // Within 30 seconds
                debugPrint("🔗 ConnectionManager: Restoring recent connection")
                start()
            }
        }
    }
    
    // MARK: - USB Device Detection
    
    private func setupUSBDeviceMonitoring() {
        debugPrint("🔗 ConnectionManager: Setting up USB device monitoring")
        
        // Monitor for USB host attach/detach events
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        
        // USB host attached (cable connected)
        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { (center, observer, name, object, userInfo) in
                debugPrint("🔗 ConnectionManager: 🔌 Darwin notification received: host_attached")
                guard let observer = observer else { return }
                let connectionManager = Unmanaged<ConnectionManager>.fromOpaque(observer).takeUnretainedValue()
                connectionManager.handleUSBHostAttached()
            },
            "com.apple.mobile.lockdown.host_attached" as CFString,
            nil,
            .deliverImmediately
        )
        
        // USB host detached (cable disconnected)
        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { (center, observer, name, object, userInfo) in
                debugPrint("🔗 ConnectionManager: 🔌 Darwin notification received: host_detached")
                guard let observer = observer else { return }
                let connectionManager = Unmanaged<ConnectionManager>.fromOpaque(observer).takeUnretainedValue()
                connectionManager.handleUSBHostDetached()
            },
            "com.apple.mobile.lockdown.host_detached" as CFString,
            nil,
            .deliverImmediately
        )
        
        isMonitoringUSB = true
        debugPrint("🔗 ConnectionManager: ✅ USB device monitoring active")
    }
    
    private func stopUSBDeviceMonitoring() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterRemoveObserver(center, Unmanaged.passUnretained(self).toOpaque(), nil, nil)
        isMonitoringUSB = false
        debugPrint("🔗 ConnectionManager: USB device monitoring stopped")
    }
    
    private func handleUSBHostAttached() {
        debugPrint("🔗 ConnectionManager: 🎯 USB host attached - cable connected!")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Mark USB cable as physically connected
            self.isUSBCableConnected = true
            debugPrint("🔗 ConnectionManager: ✅ USB cable connected - chip will appear")

            // USB cable connected - ensure we're listening for connections
            if !self.isListening {
                debugPrint("🔗 ConnectionManager: Starting USB server for new connection")
                self.start()
            }

            // Update USB bridge availability
            self.checkUSBBridgeAvailability()
        }
    }
    
    private func handleUSBHostDetached() {
        debugPrint("🔗 ConnectionManager: 🔌 USB host detached - cable disconnected!")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            debugPrint("🔗 ConnectionManager: 🔌 Updating connection state to disconnected")

            // Mark USB cable as physically disconnected
            self.isUSBCableConnected = false
            debugPrint("🔗 ConnectionManager: ❌ USB cable disconnected - chip will disappear")

            // USB cable disconnected - immediately update connection state
            self.isConnected = false
            self.isConnecting = false
            self.connectionHealth = .disconnected
            // Don't clear connectedComputerName to keep USB chip visible
            // self.connectedComputerName = nil
            self.connectionQuality = .disconnected

            // Stop heartbeat monitoring since connection is lost
            self.stopHeartbeatMonitoring()

            // CRITICAL: Clear the active USB connection to allow reconnection
            self.closeUSB(self.activeUSB)
            self.activeUSB = nil

            // Notify callback of disconnection
            debugPrint("🔗 ConnectionManager: 🔌 Calling connectionStateCallback(false)")
            self.connectionStateCallback?(false)

            // Update USB bridge availability to hide chip
            self.checkUSBBridgeAvailability()

            debugPrint("🔗 ConnectionManager: USB disconnection detected - connection state updated")
        }
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
        
        debugPrint("🔗 ConnectionManager: Background task support configured")
    }
    
    @objc private func appDidEnterBackground() {
        debugPrint("🔗 ConnectionManager: App entered background - starting background task to maintain connections")
        
        // Start background task to keep connections alive
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "CueBearConnection") { [weak self] in
            debugPrint("🔗 ConnectionManager: Background task expired - ending task")
            self?.endBackgroundTask()
        }
        
        // Keep connections alive during background
        if isConnected {
            debugPrint("🔗 ConnectionManager: Maintaining active connection during background")
        }
    }
    
    @objc private func appWillEnterForeground() {
        debugPrint("🔗 ConnectionManager: App entering foreground - ending background task")
        endBackgroundTask()

        // FIX: Ensure listener is running when returning to foreground
        // The listener may have stopped while in background, so restart it if needed
        if !isListening && shouldReconnect {
            debugPrint("🔗 ConnectionManager: Listener not running - restarting on foreground")
            DispatchQueue.main.async { [weak self] in
                self?.startListening()
            }
        }

        // Check connection health when returning to foreground
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkConnectionAfterWake()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
            debugPrint("🔗 ConnectionManager: Background task ended")
        }
    }
    
    private func checkConnectionAfterWake() {
        debugPrint("🔗 ConnectionManager: Checking connection health after wake")
        
        // If we were connected before sleep, verify the connection is still alive
        if isConnected && activeUSB != nil {
            debugPrint("🔗 ConnectionManager: Connection was active - verifying it's still healthy")
            
            // Send a heartbeat to verify connection
            sendHeartbeat()
            
            // If no heartbeat response, mark as disconnected
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                
                if self.isConnected && self.activeUSB != nil {
                    debugPrint("🔗 ConnectionManager: Connection verified healthy after wake")
                } else {
                    debugPrint("🔗 ConnectionManager: Connection lost during sleep - updating state")
                    self.isConnected = false
                    self.connectionHealth = .disconnected
                    self.connectionQuality = .disconnected
                    self.connectionStateCallback?(false)
                }
            }
        }
    }
    
    private func sendHeartbeat() {
        let heartbeatPayload: [String: Any] = [
            "type": "heartbeat",
            "timestamp": Date().timeIntervalSince1970
        ]
        sendJSON(heartbeatPayload)
    }
    
    // MARK: - MIDI Device Monitoring
    
    private func setupMIDIDeviceMonitoring() {
        debugPrint("🔗 ConnectionManager: Setting up MIDI device monitoring")

        // Monitor for MIDI device changes (event-driven)
        midiDeviceObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MIDIObjectPropertyChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleMIDIDeviceChange(notification)
        }

        // Reduced frequency periodic check as backup (5 seconds instead of 2)
        midiMonitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkUSBBridgeAvailability()
        }

        // Initial check for USB bridge availability
        checkUSBBridgeAvailability()

        isMonitoringMIDI = true
        debugPrint("🔗 ConnectionManager: ✅ MIDI device monitoring active")
    }
    
    private func stopMIDIDeviceMonitoring() {
        if let observer = midiDeviceObserver {
            NotificationCenter.default.removeObserver(observer)
            midiDeviceObserver = nil
        }
        midiMonitorTimer?.invalidate()
        midiMonitorTimer = nil
        isMonitoringMIDI = false
        debugPrint("🔗 ConnectionManager: MIDI device monitoring stopped")
    }
    
    private func handleMIDIDeviceChange(_ notification: Notification) {
        debugPrint("🔗 ConnectionManager: MIDI device change detected")
        
        // Check USB bridge availability when MIDI devices change
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.checkUSBBridgeAvailability()
        }
    }
    
    private func checkUSBBridgeAvailability() {
        // Show USB chip based on physical USB cable connection
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Show USB bridge chip ONLY when USB cable is physically connected
            let shouldBeAvailable = self.isUSBCableConnected
            let wasAvailable = self.usbBridgeAvailable
            self.usbBridgeAvailable = shouldBeAvailable

            if shouldBeAvailable && !wasAvailable {
                debugPrint("🔗 ConnectionManager: 🎯 USB Bridge available - showing USB chip (cable connected)")
            } else if !shouldBeAvailable && wasAvailable {
                debugPrint("🔗 ConnectionManager: ❌ USB Bridge unavailable - hiding USB chip (cable disconnected)")
            }
        }
    }
}
