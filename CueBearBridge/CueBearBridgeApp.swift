import SwiftUI
import Combine
import Foundation
import Network
import CoreMIDI

@main
struct CueBearBridgeApp: App {
    @StateObject private var app = BridgeApp()
    
    var body: some Scene {
        MenuBarExtra("Cue Bear Bridge", image: "BearPawIcon") {
            MenuBarView()
                .environmentObject(app)
        }
        .menuBarExtraStyle(.window)
        
        // Keep the window for debugging/logs
        WindowGroup("Bridge Logs") {
            ContentView()
                .environmentObject(app)
        }
        .windowStyle(.titleBar)
        .defaultPosition(.topTrailing)
    }
}

struct MenuBarView: View {
    @EnvironmentObject var app: BridgeApp
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Text("Cue Bear Bridge")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            Divider()
            
            // Status Indicators
            VStack(spacing: 6) {
                // USB Connection Status
                HStack {
                    Circle()
                        .fill(app.isConnected ? .green : (app.usbStatus.contains("Looking for") ? .blue : .yellow))
                        .frame(width: 8, height: 8)
                    Text("USB")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(app.isConnected ? "Connected" : (app.usbStatus.contains("Looking for") ? "Looking for Cue Bear" : "Disconnected"))
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                
                // WiFi Status
                HStack {
                    Circle()
                        .fill(app.wifiStatus.contains("Connected") ? .green : (app.wifiStatus.contains("Listening") ? .blue : .orange))
                        .frame(width: 8, height: 8)
                    Text("WiFi")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(app.wifiStatus.contains("Connected") ? "Connected" : (app.wifiStatus.contains("Listening") ? "Listening" : "Idle"))
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                
                // MIDI Activity Indicator (like a preamp input LED)
                HStack {
                    Circle()
                        .fill(app.midiActivity ? .green : .gray)
                        .frame(width: 8, height: 8)
                        .scaleEffect(app.midiActivity ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: app.midiActivity)
                    Text("MIDI")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(app.midiActivity ? "Active" : "Ready")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
            }
            .padding(.vertical, 4)
            
            // Settings Section
            Divider()

            // Open at Login Toggle - iOS Settings style
            if #available(macOS 13.0, *) {
                HStack {
                    Text("Open at Login")
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { app.loginItemManager.isEnabled },
                        set: { newValue in
                            if newValue {
                                app.loginItemManager.enable()
                            } else {
                                app.loginItemManager.disable()
                            }
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle())
                    .labelsHidden()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            // Quit Menu Item - Simple text only
            Divider()

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack {
                    Text("Quit")
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(PlainButtonStyle())
            .background(Color.clear)
            
            // Creator credit
            HStack {
                Text("Created by Omri Behr")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .frame(width: 200)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - WiFi Server
class WifiServer: ObservableObject {
    @Published private(set) var status: String = "Stopped"
    @Published private(set) var isConnected: Bool = false

    private var listener: NWListener?
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "WifiServer", qos: .utility)
    private var midi: MIDIManager?
    private var usbConnectionManager: MacConnectionManager?
    private var heartbeatTimer: Timer?
    private var midiObserver: NSObjectProtocol?

    private var port: UInt16 = 8078

    private enum State {
        case stopped, starting, listening, connected
    }

    // Fix Issue #16: Use NSLock to protect state enum access
    private let stateLock = NSLock()
    private var state: State = .stopped

    deinit {
        if let observer = midiObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        heartbeatTimer?.invalidate()
        stop()
        log("WiFi server deinit - all resources cleaned up")
    }

    func setMidiRouter(_ midi: MIDIManager) {
        self.midi = midi
        log("Setting MIDI router, source value: \(midi.source)")
        midi.onIncomingMIDI = { [weak self] midiData in
            self?.forwardMIDIToIPad(midiData)
        }

        // Listen for MIDI messages forwarded from USB connection
        midiObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ForwardMIDIToWiFiServer"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let midiObj = notification.object as? [String: Any] {
                self?.processMIDIMessage(midiObj)
            }
        }
    }
    
    func setUSBConnectionManager(_ usbManager: MacConnectionManager) {
        self.usbConnectionManager = usbManager
    }
    
    func setPort(_ port: UInt16) {
        self.port = port
    }
    
    private func log(_ message: String) {
        print("📡 WiFi Server: \(message)")
    }
    
    func start() {
        // Fix Issue #16: Protect state access with lock
        stateLock.lock()
        let currentState = state
        if currentState == .stopped {
            state = .starting
        }
        stateLock.unlock()

        guard currentState == .stopped else { return }
        stop()

        log("Starting WiFi server on port \(port)...")
        status = "Starting..."

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.setupListener()
        }
    }

    func stop() {
        log("Stopping WiFi server")
        stopHeartbeat()
        connection?.cancel()
        connection = nil
        listener?.cancel()
        listener = nil
        // Fix Issue #16: Protect state access with lock
        stateLock.lock()
        state = .stopped
        stateLock.unlock()
        status = "Stopped"
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
    
    private func setupListener() {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            log("Invalid port: \(port)")
            // Fix Issue #16: Protect state access with lock
            stateLock.lock()
            state = .stopped
            stateLock.unlock()
            status = "Failed"
            return
        }

        do {
            listener = try NWListener(using: parameters, on: nwPort)
            listener?.newConnectionHandler = { [weak self] connection in
                self?.acceptConnection(connection)
            }

            listener?.stateUpdateHandler = { [weak self] nwState in
                guard let self = self else { return }
                switch nwState {
                case .ready:
                    self.log("WiFi server listening on port \(self.port)")
                    // Fix Issue #16: Protect state access with lock
                    self.stateLock.lock()
                    self.state = .listening
                    self.stateLock.unlock()
                    DispatchQueue.main.async {
                        self.status = "Listening"
                    }
                case .failed(let error):
                    self.log("WiFi server failed: \(error.localizedDescription)")
                    // Fix Issue #16: Protect state access with lock
                    self.stateLock.lock()
                    self.state = .stopped
                    self.stateLock.unlock()
                    DispatchQueue.main.async {
                        self.status = "Failed"
                    }
                case .cancelled:
                    self.log("WiFi server cancelled")
                    // Fix Issue #16: Protect state access with lock
                    self.stateLock.lock()
                    self.state = .stopped
                    self.stateLock.unlock()
                    DispatchQueue.main.async {
                        self.status = "Stopped"
                    }
                default: break
                }
            }

            listener?.start(queue: queue)
        } catch {
            log("Failed to create listener: \(error.localizedDescription)")
            // Fix Issue #16: Protect state access with lock
            stateLock.lock()
            state = .stopped
            stateLock.unlock()
            status = "Failed"
        }
    }
    
    private func acceptConnection(_ conn: NWConnection) {
        log("New WiFi connection received")

        // SECURITY: Validate connection before accepting
        guard let remoteEndpoint = conn.currentPath?.remoteEndpoint else {
            log("🔒 WiFi: Cannot determine remote endpoint, rejecting")
            conn.cancel()
            return
        }

        guard ConnectionSecurity.shared.validateConnection(from: remoteEndpoint) else {
            log("🔒 WiFi: Connection validation failed, rejecting")
            conn.cancel()
            return
        }

        connection?.cancel()
        connection = conn
        
        conn.stateUpdateHandler = { [weak self] nwState in
            guard let self = self else { return }
            switch nwState {
            case .ready:
                self.log("WiFi connection established")
                // Fix Issue #16: Protect state access with lock
                self.stateLock.lock()
                self.state = .connected
                self.stateLock.unlock()
                DispatchQueue.main.async {
                    self.status = "Connected"
                    self.isConnected = true
                }
                self.startReceiving(conn)
                self.startHeartbeat()
            case .failed(let error):
                self.log("WiFi connection failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.status = "Connection failed"
                    self.isConnected = false
                }
            case .cancelled:
                self.log("WiFi connection cancelled")
                self.stopHeartbeat()
                DispatchQueue.main.async {
                    self.status = "Connection cancelled"
                    self.isConnected = false
                }
            default: break
            }
        }
        
        conn.start(queue: queue)
    }
    
    private func startReceiving(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.processReceivedData(data)
            }
            
            if isComplete {
                self?.log("WiFi connection closed")
                self?.stopHeartbeat()
                DispatchQueue.main.async {
                    self?.isConnected = false
                    self?.status = "Disconnected"
                }
            } else if let error = error {
                self?.log("WiFi receive error: \(error.localizedDescription)")
            } else {
                self?.startReceiving(conn)
            }
        }
    }
    
    private func processReceivedData(_ data: Data) {
        // SECURITY: Rate limit messages
        guard ConnectionSecurity.shared.validateMessageRate(for: "wifi_connection") else {
            log("🔒 WiFi: Message rate limit exceeded, dropping message")
            return
        }

        guard let message = String(data: data, encoding: .utf8) else { return }
        log("Received WiFi message: \(message)")

        // Handle legacy text-based MIDI messages (for backward compatibility)
        if message.hasPrefix("midi_cc") {
            processMIDICC(message)
        } else if message.hasPrefix("midi_note") {
            processMIDINote(message)
        } else if message.contains("\"type\":\"batch\"") || message.contains("\"type\":") {
            // SECURITY: Validate JSON messages through security layer
            guard let jsonData = message.data(using: .utf8),
                  let jsonObj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let sanitized = ConnectionSecurity.shared.validateAndSanitizeMIDIMessage(jsonObj) else {
                log("🔒 WiFi: Invalid message rejected by security validation")
                return
            }

            // Process sanitized message
            if let type = sanitized["type"] as? String {
                if type == "batch" {
                    processBatchMessage(message, sanitized: sanitized)
                } else {
                    processMIDIMessage(sanitized)
                }
            }
        } else {
            log("Unknown message type: \(message)")
        }
    }
    
    private func processMIDICC(_ message: String) {
        let components = message.components(separatedBy: " ")
        guard components.count >= 4 else { return }
        
        var channel: UInt8 = 0, cc: UInt8 = 0, value: UInt8 = 0
        
        for component in components[1...] {
            let parts = component.components(separatedBy: "=")
            if parts.count == 2 {
                switch parts[0] {
                case "channel": channel = UInt8(parts[1]) ?? 0
                case "cc": cc = UInt8(parts[1]) ?? 0
                case "value": value = UInt8(parts[1]) ?? 0
                default: break
                }
            }
        }
        
        sendMIDICC(channel: channel, cc: cc, value: value)
    }
    
    private func processMIDINote(_ message: String) {
        let components = message.components(separatedBy: " ")
        guard components.count >= 4 else { return }
        
        var channel: UInt8 = 0, note: UInt8 = 0, velocity: UInt8 = 0
        
        for component in components[1...] {
            let parts = component.components(separatedBy: "=")
            if parts.count == 2 {
                switch parts[0] {
                case "channel": channel = UInt8(parts[1]) ?? 0
                case "note": note = UInt8(parts[1]) ?? 0
                case "velocity": velocity = UInt8(parts[1]) ?? 0
                default: break
                }
            }
        }
        
        sendMIDINote(channel: channel, note: note, velocity: velocity)
    }
    
    private func processMIDIMessage(_ midiObj: [String: Any]) {
        guard let type = midiObj["type"] as? String else { return }

        switch type {
        case "midi_cc":
            if let channel = midiObj["channel"] as? Int,
               let cc = midiObj["cc"] as? Int,
               let value = midiObj["value"] as? Int {
                // Convert 1-based iPad channel to 0-based MIDI channel
                let midiChannel = UInt8(max(0, channel - 1))
                log("✅ Processing WiFi MIDI CC: iPad ch=\(channel) -> MIDI ch=\(midiChannel) cc=\(cc) val=\(value)")
                sendMIDICC(channel: midiChannel, cc: UInt8(cc), value: UInt8(value))
            } else {
                log("❌ Missing MIDI CC parameters")
            }

        case "midi_note":
            if let channel = midiObj["channel"] as? Int,
               let note = midiObj["note"] as? Int,
               let velocity = midiObj["velocity"] as? Int {
                // Convert 1-based iPad channel to 0-based MIDI channel
                let midiChannel = UInt8(max(0, channel - 1))
                log("✅ Processing WiFi MIDI Note: iPad ch=\(channel) -> MIDI ch=\(midiChannel) note=\(note) vel=\(velocity)")
                sendMIDINote(channel: midiChannel, note: UInt8(note), velocity: UInt8(velocity))
            } else {
                log("❌ Missing MIDI Note parameters")
            }

        default:
            log("❌ Unknown MIDI message type: \(type)")
        }
    }
    
    private func processBatchMessage(_ message: String, sanitized: [String: Any]) {
        log("Processing batch message")

        // SECURITY: Use pre-sanitized batch data from ConnectionSecurity
        // The sanitized parameter already has validated messages
        guard let messages = sanitized["messages"] as? [String] else {
            log("❌ Invalid batch structure in sanitized message")
            return
        }

        log("Found \(messages.count) validated messages in batch")

        for messageString in messages {
            // Remove any trailing newline characters
            let cleanMessage = messageString.trimmingCharacters(in: .whitespacesAndNewlines)

            log("Processing individual message: \(cleanMessage)")

            // Parse the individual message JSON (already validated by ConnectionSecurity)
            if let messageData = cleanMessage.data(using: .utf8),
               let messageDict = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any] {

                // Process the validated message
                processMIDIMessage(messageDict)
            } else {
                log("❌ Failed to parse individual message JSON: \(cleanMessage)")
            }
        }
    }
    
    private func sendMIDICC(channel: UInt8, cc: UInt8, value: UInt8) {
        guard let midi = midi else { 
            log("❌ MIDI manager not available")
            return 
        }
        
        // Check if MIDI source is valid
        log("🔍 Checking MIDI source: \(midi.source)")
        if midi.source == 0 {
            log("❌ MIDI source not initialized (source=0)")
            return
        }
        
        var packet = MIDIPacket()
        packet.timeStamp = 0
        packet.length = 3
        packet.data.0 = 0xB0 | (channel & 0x0F)
        packet.data.1 = cc
        packet.data.2 = value
        
        var list = MIDIPacketList(numPackets: 1, packet: packet)
        let result = MIDIReceived(midi.source, &list)
        
        if result == noErr {
            log("✅ MIDI CC sent successfully: ch=\(channel) cc=\(cc) val=\(value)")
        } else {
            log("❌ Failed to send MIDI CC: error=\(result)")
        }
    }
    
    private func sendMIDINote(channel: UInt8, note: UInt8, velocity: UInt8) {
        guard let midi = midi else { 
            log("❌ MIDI manager not available")
            return 
        }
        
        // Check if MIDI source is valid
        log("🔍 Checking MIDI source: \(midi.source)")
        if midi.source == 0 {
            log("❌ MIDI source not initialized (source=0)")
            return
        }
        
        var packet = MIDIPacket()
        packet.timeStamp = 0
        packet.length = 3
        packet.data.0 = 0x90 | (channel & 0x0F)
        packet.data.1 = note
        packet.data.2 = velocity
        
        var list = MIDIPacketList(numPackets: 1, packet: packet)
        let result = MIDIReceived(midi.source, &list)
        
        if result == noErr {
            log("✅ MIDI Note sent successfully: ch=\(channel) note=\(note) vel=\(velocity)")
        } else {
            log("❌ Failed to send MIDI Note: error=\(result)")
        }
    }
    
    private func forwardMIDIToIPad(_ midiData: Data) {
        // Only forward MIDI that comes from DAW (virtual MIDI destination)
        // Do NOT forward MIDI that comes from iPad (USB/WiFi connections)
        // This prevents MIDI feedback loops
        log("📤 Forwarding DAW MIDI to iPad (not iPad-originated MIDI)")
        forwardMIDIToWiFi(midiData)
        forwardMIDIToUSB(midiData)
    }
    
    private func forwardMIDIToWiFi(_ midiData: Data) {
        guard let connection = connection else { return }
        
        // Parse the MIDI data and convert channel from 0-based to 1-based
        do {
            if let midiDict = try JSONSerialization.jsonObject(with: midiData) as? [String: Any] {
                var convertedDict = midiDict
                
                // Convert MIDI channel from 0-based to 1-based for iPad
                if let channel = midiDict["channel"] as? Int {
                    convertedDict["channel"] = channel + 1
                    log("Converting MIDI channel: DAW ch=\(channel) -> iPad ch=\(channel + 1)")
                }
                
                // Wrap the MIDI message in the format expected by iPad ConnectionManager
                let channel = Int(convertedDict["channel"] as? Int ?? 0) - 1 // Convert back to 0-based for raw MIDI
                let cc = convertedDict["cc"] as? Int ?? 0
                let value = convertedDict["value"] as? Int ?? 0
                let statusByte = 0xB0 | channel // Control Change status byte with channel
                
                let wrappedMessage: [String: Any] = [
                    "type": "midi_input",
                    "midi": [statusByte, cc, value]
                ]
                
                let wrappedData = try JSONSerialization.data(withJSONObject: wrappedMessage)
                let jsonString = String(data: wrappedData, encoding: .utf8) ?? ""
                let message = jsonString + "\n"
                
                connection.send(content: message.data(using: .utf8), completion: .contentProcessed { error in
                    if let error = error {
                        self.log("Failed to send MIDI to iPad via WiFi: \(error.localizedDescription)")
                    } else {
                        self.log("Sent MIDI to iPad via WiFi: \(jsonString)")
                    }
                })
            } else {
                log("Failed to parse MIDI data for iPad forwarding")
            }
        } catch {
            log("Error processing MIDI data for iPad: \(error.localizedDescription)")
        }
    }
    
    private func forwardMIDIToUSB(_ midiData: Data) {
        // Send MIDI to iPad via USB connection
        do {
            if let midiDict = try JSONSerialization.jsonObject(with: midiData) as? [String: Any] {
                var convertedDict = midiDict
                
                // Convert MIDI channel from 0-based to 1-based for iPad
                if let channel = midiDict["channel"] as? Int {
                    convertedDict["channel"] = channel + 1
                    log("Converting MIDI channel for USB: DAW ch=\(channel) -> iPad ch=\(channel + 1)")
                }
                
                // Wrap the MIDI message in the format expected by iPad ConnectionManager
                let channel = Int(convertedDict["channel"] as? Int ?? 0) - 1 // Convert back to 0-based for raw MIDI
                let cc = convertedDict["cc"] as? Int ?? 0
                let value = convertedDict["value"] as? Int ?? 0
                let statusByte = 0xB0 | channel // Control Change status byte with channel
                
                let wrappedMessage: [String: Any] = [
                    "type": "midi_input",
                    "midi": [statusByte, cc, value]
                ]
                
                let wrappedData = try JSONSerialization.data(withJSONObject: wrappedMessage)
                let jsonString = String(data: wrappedData, encoding: .utf8) ?? ""
                let message = jsonString + "\n"
                
                // Send via USB connection
                usbConnectionManager?.sendMIDIToIPad(message)
                
            } else {
                log("Failed to parse MIDI data for USB forwarding")
            }
        } catch {
            log("Error processing MIDI data for USB: \(error.localizedDescription)")
        }
    }
    
    func testMIDITransmission() {
        log("🧪 Testing MIDI transmission through WiFi server...")
        sendMIDICC(channel: 0, cc: 1, value: 64) // ModWheel on channel 1
    }
}

// MARK: - Bonjour Service Publisher
class BridgeBonjour: NSObject, ObservableObject {
    @Published private(set) var isPublished: Bool = false
    @Published private(set) var status: String = "Stopped"
    
    private var netService: NetService?
    private var port: Int = 8078
    
    // Helper function to get user-friendly display name
    private func getDisplayName() -> String {
        let computerName = Host.current().name ?? "Mac" // Use .name to avoid duplication
        return computerName
    }
    
    func publish(port: Int) {
        self.port = port
        stop()
        
        let displayName = getDisplayName()
        netService = NetService(domain: "local.", type: "_cuebear._tcp.", name: displayName, port: Int32(port))
        netService?.delegate = self
        netService?.publish()
        
        status = "Publishing..."
        print("📡 Bonjour: Publishing service '_cuebear._tcp.' as '\(displayName)' on port \(port)")
    }
    
    func stop() {
        netService?.stop()
        netService = nil
        isPublished = false
        status = "Stopped"
        print("📡 Bonjour: Service stopped")
    }
}

extension BridgeBonjour: NetServiceDelegate {
    func netServiceDidPublish(_ sender: NetService) {
        DispatchQueue.main.async {
            self.isPublished = true
            self.status = "Published"
        }
        print("📡 Bonjour: Service published successfully on port \(sender.port)")
    }
    
    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        DispatchQueue.main.async {
            self.isPublished = false
            self.status = "Failed"
        }
        print("📡 Bonjour: Failed to publish service: \(errorDict)")
    }
    
    func netServiceDidStop(_ sender: NetService) {
        DispatchQueue.main.async {
            self.isPublished = false
            self.status = "Stopped"
        }
        print("📡 Bonjour: Service stopped")
    }
}

// MARK: - Bridge App
final class BridgeApp: ObservableObject {
    @Published var status: String = "Idle"
    @Published var usbStatus: String = "USB: idle"
    @Published var iproxyStatus: String = "iproxy: idle"
    @Published var wifiStatus: String = "WiFi: idle"
    @Published var localPort: UInt16?
    @Published var isRunning: Bool = false
    @Published var isConnected: Bool = false
    @Published var midiReady: Bool = false
    @Published var midiActivity: Bool = false

    let iproxy = IProxyManager()
    lazy var conn = MacConnectionManager(iproxyManager: iproxy)
    let midi = MIDIManager()
    let wifiServer = WifiServer()
    let bonjour = BridgeBonjour()
    let loginItemManager: LoginItemManager

    private var cancellables: Set<AnyCancellable> = []
    private var midiActivityTimer: Timer?
    
    init() {
        // Initialize login item manager
        if #available(macOS 13.0, *) {
            self.loginItemManager = LoginItemManager()
        } else {
            fatalError("macOS 13.0 or later is required")
        }

        // Set up the reference after initialization
        conn.setBridgeApp(self)

        // Start the bridge immediately when created
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.start()
        }
    }

    deinit {
        midiActivityTimer?.invalidate()
        print("🔗 BridgeApp: deinit - resources cleaned up")
    }
    
    func triggerMIDIActivity() {
        DispatchQueue.main.async {
            self.midiActivity = true
            
            // Reset activity after 200ms (like a preamp LED)
            self.midiActivityTimer?.invalidate()
            self.midiActivityTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
                DispatchQueue.main.async {
                    self.midiActivity = false
                }
            }
        }
    }

    func start() {
        guard status != "Running" else { return }
        status = "Starting…"
        
        // Setup MIDI
        midi.createVirtualSourceIfNeeded()
        midi.createVirtualDestinationIfNeeded()
        midiReady = true
        
        // Small delay to ensure MIDI source is fully initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Setup WiFi
            self.wifiServer.setMidiRouter(self.midi)
            self.wifiServer.setUSBConnectionManager(self.conn)
            self.wifiServer.setPort(8078)
            self.wifiServer.start()
            self.bonjour.publish(port: 8078)
        }

            do {
                try iproxy.start()
            iproxy.$status.receive(on: DispatchQueue.main).sink { [weak self] s in
                self?.iproxyStatus = "iproxy: " + s
                self?.isRunning = s.contains("Running")
            }.store(in: &cancellables)
            iproxy.$boundLocalPort.receive(on: DispatchQueue.main).sink { [weak self] p in
                self?.localPort = p
                if let _ = p, self?.iproxy.isRunning == true {
                    self?.conn.waitAndConnect()
                }
            }.store(in: &cancellables)
            conn.$connectionStatus.receive(on: DispatchQueue.main).sink { [weak self] s in
                self?.usbStatus = s
                self?.isConnected = s.contains("Connected")
            }.store(in: &cancellables)
            
            // Monitor WiFi status
            wifiServer.$status.receive(on: DispatchQueue.main).sink { [weak self] s in
                self?.wifiStatus = "WiFi: " + s
            }.store(in: &cancellables)
            
            status = "Running"
        } catch {
            status = "Error: \(error.localizedDescription)"
        }
    }

    func stop() {
        print("🔗 BridgeApp: Stopping all services...")
        
        // Stop all services
        conn.stop()
        iproxy.stop()
        wifiServer.stop()
        bonjour.stop()
        
        // Clean up MIDI devices
        print("🔗 BridgeApp: Cleaning up MIDI devices...")
        midi.cleanup()
        
        status = "Stopped"
        isRunning = false
        isConnected = false
        midiReady = false
        
        print("🔗 BridgeApp: All services stopped and MIDI devices cleaned up")
    }
    
    func testWiFiMIDI() {
        // Test sending MIDI CC through WiFi server
        wifiServer.testMIDITransmission()
    }
}

// MARK: - WiFi Server Heartbeat Extension

extension WifiServer {
    // MARK: - Heartbeat for Connection Stability
    
    private func startHeartbeat() {
        log("Starting WiFi heartbeat")
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }
    
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        log("Stopped WiFi heartbeat")
    }
    
    private func sendHeartbeat() {
        guard let connection = connection else { return }
        
        let heartbeat: [String: Any] = [
            "type": "heartbeat",
            "source": "wifi_bridge",
            "timestamp": Int(Date().timeIntervalSince1970)
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: heartbeat) else { return }
        let framed = data + Data([0x0A])
        
        connection.send(content: framed, completion: .contentProcessed { error in
            if let error = error {
                print("📡 WiFi Server: Heartbeat send error: \(error)")
            }
        })
    }
}
