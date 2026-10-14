import SwiftUI
import Combine
import Foundation
import Network
import CoreMIDI
import CryptoKit
import AppKit
import SystemConfiguration

// Helper to provide version string without blocking
struct VersionHelper {
    static let cachedVersionString: String = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version).\(build)"
    }()
}

// AppDelegate for handling app lifecycle events
class AppDelegate: NSObject, NSApplicationDelegate {
    var bridgeApp: BridgeApp?

    func applicationWillTerminate(_ notification: Notification) {
        // Ensure iproxy is properly stopped when app quits
        Logger.shared.log("App: applicationWillTerminate - stopping iproxy")
        bridgeApp?.iproxy.stop(manual: false)
    }
}

@main
struct CueBearBridgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var app = BridgeApp()
    @StateObject private var onboardingManager = OnboardingManager()

    var body: some Scene {
        MenuBarExtra("Cue Bear Bridge", image: "BearPawIcon") {
            MenuBarView()
                .environmentObject(app)
                .environmentObject(onboardingManager)
                .onAppear {
                    // Connect AppDelegate to BridgeApp for cleanup
                    appDelegate.bridgeApp = app
                }
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
    @EnvironmentObject var onboardingManager: OnboardingManager

    var body: some View {
        VStack(spacing: 8) {
            // Header
            VStack(alignment: .leading, spacing: 2) {
                Text("Cue Bear Bridge")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text(VersionHelper.cachedVersionString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
            }
            .padding(.vertical, 4)

            // v1.2.1: Pairing / security
            Divider()
            SecuritySection(server: app.wifiServer)

            // Experimental: run the USB tunnel inside the Bridge (no iproxy helper)
            Divider()
            DirectUSBToggle(app: app)

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

            // Getting Started Menu Item
            Divider()

            Button(action: {
                onboardingManager.showOnboarding()
            }) {
                HStack {
                    Text("Getting Started")
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 2)
            }
            .buttonStyle(PlainButtonStyle())
            .background(Color.clear)

            // Quit Menu Item
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
                .padding(.top, 2)
                .padding(.bottom, 6)
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
        .frame(width: 220)
        .background(Color(NSColor.controlBackgroundColor))
    }

}

/// Experimental switch between the classic iproxy helper and the built-in USB relay.
struct DirectUSBToggle: View {
    let app: BridgeApp
    @AppStorage(IProxyManager.directUSBDefaultsKey) private var useDirectUSB = true

    var body: some View {
        HStack {
            Text("Direct USB (beta)")
                .font(.system(size: 13))
                .foregroundColor(.primary)
            Spacer()
            Toggle("", isOn: $useDirectUSB)
                .toggleStyle(SwitchToggleStyle())
                .labelsHidden()
                .onChange(of: useDirectUSB) { enabled in
                    Logger.shared.log("🔧 USB engine switched to \(enabled ? "direct" : "classic iproxy") - restarting USB")
                    try? app.iproxy.start()
                }
        }
        .help("Runs the USB connection inside the Bridge instead of the separate iproxy helper. Turn off to go back to the classic connection.")
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

/// v1.2.1: shows who is connected, whether the link is paired, and pairing controls.
struct SecuritySection: View {
    @ObservedObject var server: WifiServer

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: lockSymbol)
                    .font(.system(size: 10))
                    .foregroundColor(server.isConnected && !server.connectionIsSecure ? .orange : .secondary)
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
            }

            HStack {
                Text("Require pairing")
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { server.requirePairing },
                    set: { server.setRequirePairing($0) }
                ))
                .toggleStyle(SwitchToggleStyle())
                .labelsHidden()
            }
            .help("When on, only iPads you have approved on this Mac can send MIDI over Wi-Fi.")

            if server.pairedDeviceCount > 0 {
                Button(action: { server.forgetPairedDevices() }) {
                    HStack {
                        Text("Forget Paired iPads (\(server.pairedDeviceCount))")
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private var lockSymbol: String {
        if server.isConnected && !server.connectionIsSecure { return "lock.open.fill" }
        return "lock.fill"
    }

    private var statusText: String {
        if server.isConnected {
            if server.connectionIsSecure {
                return "Paired: \(server.connectedDeviceName ?? "iPad")"
            }
            return "Unpaired iPad connected (older app)"
        }
        switch server.pairedDeviceCount {
        case 0: return "No iPads paired yet"
        case 1: return "1 paired iPad"
        default: return "\(server.pairedDeviceCount) paired iPads"
        }
    }
}

// MARK: - WiFi Server (v1.2.1)
//
// Changes from 1.2.0:
// - Every connection must authenticate (or pair) before it can send MIDI. Older iPad apps
//   are still accepted until the first iPad pairs, or until "Require pairing" is turned on.
// - A new connection can no longer knock off a paired iPad that is still alive.
// - Incoming data is split into lines, so merged or split TCP reads no longer lose messages.
// - Heartbeats are actually sent and checked. (Timers were created on a background queue
//   with no run loop, so they never fired.) A dead iPad is detected within ~6 s.

/// One TCP connection from an iPad. Only touched on WifiServer.queue.
private final class ClientSession {
    let id = UUID()
    let connection: NWConnection
    var buffer = LineBuffer()
    let sessionNonce = SecureLink.randomToken()
    var lastHeard = Date()
    var deviceID: String?
    var deviceName: String?
    var isAuthenticated = false
    var authRequiredSent = false
    var isClosed = false

    // Pairing in progress on this connection
    var pairDeviceID: String?
    var pairDeviceName: String?
    var pairCommitment: String?
    var pairBridgeKey: Curve25519.KeyAgreement.PrivateKey?
    var pairBridgeNonce: Data?
    var pairStartedAt: Date?
    var awaitingUserApproval = false

    init(connection: NWConnection) {
        self.connection = connection
    }
}

class WifiServer: ObservableObject {
    @Published private(set) var status: String = "Stopped"
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var connectedDeviceName: String?
    @Published private(set) var connectionIsSecure: Bool = false
    @Published private(set) var pairedDeviceCount: Int = PairedDeviceStore.shared.deviceCount
    @Published private(set) var requirePairing: Bool = PairedDeviceStore.shared.requirePairing

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "WifiServer", qos: .userInteractive)
    private var midi: MIDIManager?
    private var usbConnectionManager: MacConnectionManager?
    private var midiObserver: NSObjectProtocol?
    private var port: UInt16 = 8078
    private var bridgeDisplayName = "Mac"

    // Everything below is only touched on `queue`.
    private var running = false
    private var sessions: [UUID: ClientSession] = [:]
    private var activeSessionID: UUID?
    private var pairingSessionID: UUID?
    private var housekeepingTimer: DispatchSourceTimer?
    private var housekeepingTicks = 0

    private let store = PairedDeviceStore.shared
    private let maxSessions = 8
    private let authenticatedStaleAfter: TimeInterval = 6      // 1.2.1 iPads send a heartbeat every 2 s
    private let legacyStaleAfter: TimeInterval = 45            // older iPads send one every 15 s
    private let unauthenticatedTimeout: TimeInterval = 20
    private let pairingTimeout: TimeInterval = 120

    deinit {
        if let observer = midiObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        housekeepingTimer?.cancel()
        listener?.cancel()
        for session in sessions.values {
            session.connection.cancel()
        }
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
        print("WiFi Server: \(message)")
    }

    // MARK: - Start / stop

    func start() {
        // Computer name without a DNS lookup (Host.current() can block for seconds).
        if let cfName = SCDynamicStoreCopyComputerName(nil, nil) {
            let name = cfName as String
            if !name.isEmpty { bridgeDisplayName = name }
        }
        status = "Starting..."
        queue.async { [weak self] in
            guard let self = self, !self.running else { return }
            self.running = true
            self.log("Starting WiFi server on port \(self.port)...")
            self.setupListener()
            self.startHousekeeping()
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.shutdown()
        }
    }

    private func shutdown() {
        log("Stopping WiFi server")
        running = false
        housekeepingTimer?.cancel()
        housekeepingTimer = nil
        listener?.cancel()
        listener = nil
        for session in Array(sessions.values) {
            close(session)
        }
        activeSessionID = nil
        pairingSessionID = nil
        DispatchQueue.main.async {
            self.status = "Stopped"
            self.isConnected = false
            self.connectedDeviceName = nil
            self.connectionIsSecure = false
        }
    }

    private func setStatus(_ value: String) {
        DispatchQueue.main.async {
            self.status = value
        }
    }

    private func setupListener() {
        guard running else { return }
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        if let tcp = parameters.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options {
            tcp.noDelay = true
        }

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            log("Invalid port: \(port)")
            running = false
            setStatus("Failed")
            return
        }

        do {
            let newListener = try NWListener(using: parameters, on: nwPort)
            newListener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            newListener.stateUpdateHandler = { [weak self] state in
                self?.handleListenerState(state)
            }
            listener = newListener
            newListener.start(queue: queue)
        } catch {
            log("Failed to create listener: \(error.localizedDescription)")
            setStatus("Failed")
            retryListenerLater()
        }
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            log("WiFi server listening on port \(port)")
            if activeSessionID == nil {
                setStatus("Listening")
            }
        case .failed(let error):
            log("WiFi server failed: \(error.localizedDescription)")
            listener?.cancel()
            listener = nil
            setStatus("Failed")
            retryListenerLater()
        default:
            break
        }
    }

    private func retryListenerLater() {
        queue.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self, self.running, self.listener == nil else { return }
            self.setupListener()
        }
    }

    // MARK: - Connections

    private var activeSession: ClientSession? {
        guard let id = activeSessionID else { return nil }
        return sessions[id]
    }

    private func accept(_ connection: NWConnection) {
        guard running else {
            connection.cancel()
            return
        }
        guard ConnectionSecurity.shared.validateConnection(from: connection.endpoint) else {
            log("Rejecting connection from \(connection.endpoint): too many attempts")
            connection.cancel()
            return
        }
        guard sessions.count < maxSessions else {
            log("Rejecting connection from \(connection.endpoint): too many open connections")
            connection.cancel()
            return
        }

        let session = ClientSession(connection: connection)
        sessions[session.id] = session
        log("New connection from \(connection.endpoint)")

        connection.stateUpdateHandler = { [weak self, weak session] state in
            guard let self = self, let session = session else { return }
            switch state {
            case .ready:
                self.sendHello(to: session)
                self.receive(on: session)
            case .failed(let error):
                self.log("Connection failed: \(error.localizedDescription)")
                self.close(session)
            case .cancelled:
                self.close(session)
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    private func sendHello(to session: ClientSession) {
        send([
            "type": SecureLink.MessageType.hello,
            "proto": SecureLink.protocolVersion,
            "bridge_id": store.bridgeID,
            "name": bridgeDisplayName,
            "nonce": session.sessionNonce,
            "pairing_required": store.requirePairing
        ], to: session)
    }

    private func send(_ object: [String: Any], to session: ClientSession) {
        guard !session.isClosed, let data = SecureLink.encodeLine(object) else { return }
        session.connection.send(content: data, completion: .contentProcessed { _ in })
    }

    private func receive(on session: ClientSession) {
        session.connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self, weak session] data, _, isComplete, error in
            guard let self = self, let session = session, !session.isClosed else { return }
            if let data = data, !data.isEmpty {
                session.lastHeard = Date()
                for line in session.buffer.append(data) {
                    self.handleLine(line, from: session)
                    if session.isClosed { return }
                }
            }
            if isComplete || error != nil {
                self.close(session)
                return
            }
            self.receive(on: session)
        }
    }

    private func close(_ session: ClientSession) {
        guard !session.isClosed else { return }
        session.isClosed = true
        session.connection.stateUpdateHandler = nil
        session.connection.cancel()
        sessions.removeValue(forKey: session.id)
        if pairingSessionID == session.id {
            pairingSessionID = nil
        }
        if activeSessionID == session.id {
            activeSessionID = nil
            let stillRunning = running
            DispatchQueue.main.async {
                self.isConnected = false
                self.connectedDeviceName = nil
                self.connectionIsSecure = false
                self.status = stillRunning ? "Listening" : "Stopped"
            }
            log("iPad disconnected")
        }
    }

    private func isAlive(_ session: ClientSession) -> Bool {
        let limit = session.isAuthenticated ? authenticatedStaleAfter : legacyStaleAfter
        return Date().timeIntervalSince(session.lastHeard) < limit
    }

    private func makeActive(_ session: ClientSession) {
        if let previous = activeSession, previous.id != session.id {
            log("Replacing previous iPad connection")
            close(previous)
        }
        activeSessionID = session.id
        let name = session.deviceName ?? "iPad"
        let secure = session.isAuthenticated
        DispatchQueue.main.async {
            self.status = "Connected"
            self.isConnected = true
            self.connectedDeviceName = name
            self.connectionIsSecure = secure
        }
        log("Active iPad: \(name) (\(secure ? "paired" : "unpaired, older app"))")
    }

    /// Decides whether MIDI from this connection may reach the DAW.
    private func admitMIDI(from session: ClientSession) -> Bool {
        if session.isAuthenticated {
            return activeSessionID == session.id
        }

        // Unpaired client: an iPad running Cue Bear 1.2.0 or older.
        if store.requirePairing {
            if !session.authRequiredSent {
                session.authRequiredSent = true
                send(["type": SecureLink.MessageType.authRequired], to: session)
                log("Ignoring MIDI from an unpaired iPad (pairing is required)")
            }
            return false
        }
        if activeSessionID != session.id {
            if let active = activeSession, active.isAuthenticated, isAlive(active) {
                return false   // never let an unpaired device take over from a paired one
            }
            makeActive(session)
        }
        return true
    }

    // MARK: - Messages

    private func handleLine(_ line: Data, from session: ClientSession) {
        guard ConnectionSecurity.shared.validateMessageRate(for: session.id.uuidString) else { return }

        // Legacy text format: "midi_cc channel=1 cc=7 value=100"
        if line.first != UInt8(ascii: "{") {
            guard let text = String(data: line, encoding: .utf8) else { return }
            if text.hasPrefix("midi_cc") || text.hasPrefix("midi_note") {
                guard admitMIDI(from: session) else { return }
                if text.hasPrefix("midi_cc") {
                    processMIDICC(text)
                } else {
                    processMIDINote(text)
                }
            }
            return
        }

        guard let json = SecureLink.decode(line), let type = json["type"] as? String else {
            log("Dropping unreadable message")
            return
        }

        switch type {
        case SecureLink.MessageType.heartbeat:
            return  // lastHeard was already updated

        case SecureLink.MessageType.auth:
            handleAuth(json, from: session)

        case SecureLink.MessageType.pairStart:
            handlePairStart(json, from: session)

        case SecureLink.MessageType.pairReveal:
            handlePairReveal(json, from: session)

        case "pair_request", "switch_to_wifi", "transport":
            return  // sent by older iPad apps; nothing to do

        case "midi_cc", "midi_note", "batch":
            guard admitMIDI(from: session) else { return }
            guard let sanitized = ConnectionSecurity.shared.validateAndSanitizeMIDIMessage(json) else { return }
            if type == "batch" {
                for messageString in (sanitized["messages"] as? [String]) ?? [] {
                    if let data = messageString.data(using: .utf8), let message = SecureLink.decode(data) {
                        processMIDIMessage(message)
                    }
                }
            } else {
                processMIDIMessage(sanitized)
            }

        default:
            log("Ignoring message type: \(type)")
        }
    }

    // MARK: - Authentication

    private func handleAuth(_ json: [String: Any], from session: ClientSession) {
        guard let deviceID = json["device_id"] as? String, !deviceID.isEmpty, deviceID.count <= 128,
              let mac = json["mac"] as? String, mac.count <= 128 else {
            send(["type": SecureLink.MessageType.authFailed, "reason": "malformed"], to: session)
            return
        }
        guard let device = store.device(id: deviceID) else {
            send(["type": SecureLink.MessageType.authFailed, "reason": "unknown_device"], to: session)
            return
        }
        let key = SymmetricKey(data: device.key)
        guard SecureLink.verifyAuthMAC(mac, key: key, bridgeID: store.bridgeID,
                                       deviceID: deviceID, sessionNonce: session.sessionNonce) else {
            log("Authentication failed for \(device.name)")
            send(["type": SecureLink.MessageType.authFailed, "reason": "bad_mac"], to: session)
            return
        }

        session.isAuthenticated = true
        session.deviceID = deviceID
        if let name = json["device_name"] as? String, !name.isEmpty {
            session.deviceName = String(name.prefix(64))
        } else {
            session.deviceName = device.name
        }

        // A different paired iPad that is still alive keeps the link.
        if let active = activeSession, active.id != session.id, active.isAuthenticated,
           active.deviceID != deviceID, isAlive(active) {
            log("Refusing \(session.deviceName ?? "iPad"): \(active.deviceName ?? "another iPad") is connected")
            send(["type": SecureLink.MessageType.busy, "device_name": active.deviceName ?? "another iPad"], to: session)
            queue.asyncAfter(deadline: .now() + 0.5) { [weak self, weak session] in
                guard let self = self, let session = session else { return }
                self.close(session)
            }
            return
        }

        makeActive(session)
        send(["type": SecureLink.MessageType.authOK], to: session)
    }

    // MARK: - Pairing

    private func handlePairStart(_ json: [String: Any], from session: ClientSession) {
        guard let deviceID = json["device_id"] as? String, !deviceID.isEmpty, deviceID.count <= 128,
              let commit = json["commit"] as? String, !commit.isEmpty, commit.count <= 128 else {
            return
        }
        if let otherID = pairingSessionID, otherID != session.id, let other = sessions[otherID], !other.isClosed {
            send(["type": SecureLink.MessageType.pairDenied, "reason": "busy"], to: session)
            return
        }

        let name = String(((json["device_name"] as? String) ?? "iPad").prefix(64))
        let bridgeKey = Curve25519.KeyAgreement.PrivateKey()
        let bridgeNonce = SecureLink.randomBytes(16)

        session.pairDeviceID = deviceID
        session.pairDeviceName = name
        session.pairCommitment = commit
        session.pairBridgeKey = bridgeKey
        session.pairBridgeNonce = bridgeNonce
        session.pairStartedAt = Date()
        session.awaitingUserApproval = false
        pairingSessionID = session.id

        log("Pairing requested by \(name)")
        send([
            "type": SecureLink.MessageType.pairKey,
            "bridge_pub": bridgeKey.publicKey.rawRepresentation.base64EncodedString(),
            "nonce": bridgeNonce.base64EncodedString()
        ], to: session)
    }

    private func handlePairReveal(_ json: [String: Any], from session: ClientSession) {
        guard pairingSessionID == session.id, !session.awaitingUserApproval,
              let deviceID = session.pairDeviceID,
              let commit = session.pairCommitment,
              let bridgeKey = session.pairBridgeKey,
              let bridgeNonce = session.pairBridgeNonce,
              let publicKeyString = json["device_pub"] as? String,
              let devicePublicKey = Data(base64Encoded: publicKeyString), devicePublicKey.count == 32,
              let nonceString = json["nonce"] as? String,
              let deviceNonce = Data(base64Encoded: nonceString), deviceNonce.count == 16 else {
            return
        }

        guard SecureLink.commitment(publicKey: devicePublicKey, nonce: deviceNonce) == commit else {
            log("Pairing rejected: commitment mismatch")
            send(["type": SecureLink.MessageType.pairDenied, "reason": "commitment_mismatch"], to: session)
            endPairing(on: session)
            return
        }

        let linkKey: SymmetricKey
        do {
            linkKey = try SecureLink.deriveLinkKey(privateKey: bridgeKey, peerPublicKey: devicePublicKey,
                                                   deviceNonce: deviceNonce, bridgeNonce: bridgeNonce)
        } catch {
            send(["type": SecureLink.MessageType.pairDenied, "reason": "bad_key"], to: session)
            endPairing(on: session)
            return
        }

        let code = SecureLink.comparisonCode(bridgePublicKey: bridgeKey.publicKey.rawRepresentation,
                                             devicePublicKey: devicePublicKey,
                                             deviceNonce: deviceNonce, bridgeNonce: bridgeNonce)
        session.awaitingUserApproval = true
        let deviceName = session.pairDeviceName ?? "iPad"
        let sessionID = session.id

        DispatchQueue.main.async { [weak self] in
            let allowed = WifiServer.askUserToApprovePairing(deviceName: deviceName, code: code)
            self?.queue.async { [weak self] in
                self?.finishPairing(sessionID: sessionID, allowed: allowed,
                                    deviceID: deviceID, deviceName: deviceName, key: linkKey)
            }
        }
    }

    private func finishPairing(sessionID: UUID, allowed: Bool, deviceID: String, deviceName: String, key: SymmetricKey) {
        guard let session = sessions[sessionID], !session.isClosed else {
            if pairingSessionID == sessionID { pairingSessionID = nil }
            log("Pairing answered after the iPad disconnected; ignoring")
            return
        }
        endPairing(on: session)

        if allowed {
            store.add(id: deviceID, name: deviceName, key: key)
            publishStoreState()
            log("Paired with \(deviceName)")
            send(["type": SecureLink.MessageType.pairOK], to: session)
            // The iPad now authenticates on this same connection.
        } else {
            log("Pairing declined for \(deviceName)")
            send(["type": SecureLink.MessageType.pairDenied, "reason": "declined"], to: session)
        }
    }

    private func endPairing(on session: ClientSession) {
        session.pairDeviceID = nil
        session.pairDeviceName = nil
        session.pairCommitment = nil
        session.pairBridgeKey = nil
        session.pairBridgeNonce = nil
        session.pairStartedAt = nil
        session.awaitingUserApproval = false
        if pairingSessionID == session.id {
            pairingSessionID = nil
        }
    }

    /// Shows the pairing approval alert. Main thread only.
    private static func askUserToApprovePairing(deviceName: String, code: String) -> Bool {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Allow “\(deviceName)” to control this Mac?"
        alert.informativeText = "Cue Bear on the iPad is showing a pairing code. Only click Allow if it matches the code below.\n\nOnce paired, this iPad connects automatically, and other devices on the network can't send MIDI to this Mac."

        let codeLabel = NSTextField(labelWithString: SecureLink.formattedCode(code))
        codeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 34, weight: .semibold)
        codeLabel.alignment = .center
        codeLabel.frame = NSRect(x: 0, y: 0, width: 260, height: 44)
        alert.accessoryView = codeLabel

        alert.addButton(withTitle: "Allow")
        alert.addButton(withTitle: "Don't Allow")
        return alert.runModal() == .alertFirstButtonReturn
    }

    // MARK: - Pairing settings (called from the menu bar)

    func setRequirePairing(_ value: Bool) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.store.setRequirePairing(value)
            self.publishStoreState()
            if value, let active = self.activeSession, !active.isAuthenticated {
                self.log("Pairing now required; disconnecting unpaired iPad")
                self.close(active)
            }
        }
    }

    func forgetPairedDevices() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.store.forgetAll()
            self.publishStoreState()
            for session in Array(self.sessions.values) {
                self.close(session)
            }
        }
    }

    private func publishStoreState() {
        let count = store.deviceCount
        let required = store.requirePairing
        DispatchQueue.main.async {
            self.pairedDeviceCount = count
            self.requirePairing = required
        }
    }

    // MARK: - Housekeeping (heartbeats, dead connections)

    private func startHousekeeping() {
        housekeepingTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 2.0, repeating: 2.0, leeway: .milliseconds(200))
        timer.setEventHandler { [weak self] in
            self?.housekeeping()
        }
        housekeepingTimer = timer
        timer.resume()
    }

    private func housekeeping() {
        let now = Date()

        if let active = activeSession {
            if isAlive(active) {
                send(["type": SecureLink.MessageType.heartbeat, "source": "wifi_bridge"], to: active)
            } else {
                log("iPad stopped responding; closing connection")
                close(active)
            }
        }

        for session in Array(sessions.values) where session.id != activeSessionID {
            if let startedAt = session.pairStartedAt {
                if now.timeIntervalSince(startedAt) > pairingTimeout {
                    close(session)
                }
            } else if now.timeIntervalSince(session.lastHeard) > unauthenticatedTimeout {
                close(session)
            }
        }

        housekeepingTicks += 1
        if housekeepingTicks % 30 == 0 {
            ConnectionSecurity.shared.cleanupOldData()
        }
    }

    // MARK: - MIDI out (to the DAW)

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

        sendMIDICC(channel: channel, cc: min(cc, 127), value: min(value, 127))
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

        sendMIDINote(channel: channel, note: min(note, 127), velocity: min(velocity, 127))
    }

    private func processMIDIMessage(_ midiObj: [String: Any]) {
        guard let type = midiObj["type"] as? String else { return }

        switch type {
        case "heartbeat":
            return

        case "midi_cc":
            if let channel = midiObj["channel"] as? Int, (1...16).contains(channel),
               let cc = midiObj["cc"] as? Int, (0...127).contains(cc),
               let value = midiObj["value"] as? Int, (0...127).contains(value) {
                // Convert 1-based iPad channel to 0-based MIDI channel
                sendMIDICC(channel: UInt8(channel - 1), cc: UInt8(cc), value: UInt8(value))
            } else {
                log("Invalid MIDI CC parameters")
            }

        case "midi_note":
            if let channel = midiObj["channel"] as? Int, (1...16).contains(channel),
               let note = midiObj["note"] as? Int, (0...127).contains(note),
               let velocity = midiObj["velocity"] as? Int, (0...127).contains(velocity) {
                sendMIDINote(channel: UInt8(channel - 1), note: UInt8(note), velocity: UInt8(velocity))
            } else {
                log("Invalid MIDI Note parameters")
            }

        default:
            log("Unknown MIDI message type: \(type)")
        }
    }

    private func sendMIDICC(channel: UInt8, cc: UInt8, value: UInt8) {
        sendMIDI(status: 0xB0 | (channel & 0x0F), data1: cc, data2: value)
    }

    private func sendMIDINote(channel: UInt8, note: UInt8, velocity: UInt8) {
        sendMIDI(status: 0x90 | (channel & 0x0F), data1: note, data2: velocity)
    }

    private func sendMIDI(status: UInt8, data1: UInt8, data2: UInt8) {
        guard let midi = midi else {
            log("MIDI manager not available")
            return
        }
        guard midi.source != 0 else {
            log("MIDI source not initialized (source=0)")
            return
        }

        var packet = MIDIPacket()
        packet.timeStamp = 0
        packet.length = 3
        packet.data.0 = status
        packet.data.1 = data1
        packet.data.2 = data2

        var list = MIDIPacketList(numPackets: 1, packet: packet)
        let result = MIDIReceived(midi.source, &list)
        if result != noErr {
            log("Failed to send MIDI: error=\(result)")
        }
    }

    // MARK: - MIDI in (from the DAW, back to the iPad)

    private func forwardMIDIToIPad(_ midiData: Data) {
        // Only MIDI that comes from the DAW (virtual MIDI destination) is forwarded.
        // MIDI from the iPad is never echoed back, which prevents feedback loops.
        guard let message = makeMIDIInputLine(from: midiData) else { return }
        queue.async { [weak self] in
            guard let self = self, let active = self.activeSession else { return }
            active.connection.send(content: message, completion: .contentProcessed { _ in })
        }
        usbConnectionManager?.sendMIDIToIPad(String(decoding: message, as: UTF8.self))
    }

    /// Wraps a DAW MIDI event in the "midi_input" format the iPad expects.
    private func makeMIDIInputLine(from midiData: Data) -> Data? {
        guard let midiDict = (try? JSONSerialization.jsonObject(with: midiData)) as? [String: Any] else {
            log("Failed to parse MIDI data for iPad forwarding")
            return nil
        }
        let channel = max(0, min(15, midiDict["channel"] as? Int ?? 0))   // 0-based from the DAW
        let bytes: [Int]
        switch (midiDict["type"] as? String) ?? "" {
        case "midi_note":
            // v1.2.1: notes were previously sent to the iPad as CC 0.
            let note = max(0, min(127, midiDict["note"] as? Int ?? 0))
            let velocity = max(0, min(127, midiDict["velocity"] as? Int ?? 0))
            bytes = [0x90 | channel, note, velocity]
        case "midi_cc":
            let cc = max(0, min(127, midiDict["cc"] as? Int ?? 0))
            let value = max(0, min(127, midiDict["value"] as? Int ?? 0))
            bytes = [0xB0 | channel, cc, value]
        default:
            return nil
        }

        return SecureLink.encodeLine([
            "type": "midi_input",
            "midi": bytes
        ])
    }

    func testMIDITransmission() {
        log("Testing MIDI transmission through WiFi server...")
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
        if let cfName = SCDynamicStoreCopyComputerName(nil, nil) {
            let name = cfName as String
            if !name.isEmpty { return name }
        }
        return "Mac"
    }

    func publish(port: Int) {
        self.port = port
        stop()

        let displayName = getDisplayName()
        netService = NetService(domain: "local.", type: "_cuebear._tcp.", name: displayName, port: Int32(port))
        netService?.delegate = self
        netService?.publish()

        status = "Publishing..."
        print("Bonjour: Publishing service '_cuebear._tcp.' as '\(displayName)' on port \(port)")
    }

    func stop() {
        netService?.stop()
        netService = nil
        isPublished = false
        status = "Stopped"
        print("Bonjour: Service stopped")
    }
}

extension BridgeBonjour: NetServiceDelegate {
    func netServiceDidPublish(_ sender: NetService) {
        DispatchQueue.main.async {
            self.isPublished = true
            self.status = "Published"
        }
        print("Bonjour: Service published successfully on port \(sender.port)")
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        DispatchQueue.main.async {
            self.isPublished = false
            self.status = "Failed"
        }
        print("Bonjour: Failed to publish service: \(errorDict)")
    }

    func netServiceDidStop(_ sender: NetService) {
        DispatchQueue.main.async {
            self.isPublished = false
            self.status = "Stopped"
        }
        print("Bonjour: Service stopped")
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
    private var conn: MacConnectionManager!  // Changed from lazy var to fix bridgeApp weak reference
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

        // Initialize conn AFTER self is fully initialized (not lazy!)
        self.conn = MacConnectionManager(iproxyManager: iproxy)

        // Set up the reference after initialization
        conn.setBridgeApp(self)

        // CRITICAL: Set up Combine subscriptions BEFORE starting anything
        // This ensures UI updates are captured from the very first status change
        setupSubscriptions()

        // Start the bridge immediately when created
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.start()
        }
    }

    deinit {
        midiActivityTimer?.invalidate()
        print("BridgeApp: deinit - resources cleaned up")
    }

    private func setupSubscriptions() {
        // Monitor iproxy status
        iproxy.$status.receive(on: DispatchQueue.main).sink { [weak self] s in
            self?.iproxyStatus = "iproxy: " + s
            self?.isRunning = s.contains("Running")
        }.store(in: &cancellables)

        // Monitor iproxy bound port and trigger connection attempts
        iproxy.$boundLocalPort.receive(on: DispatchQueue.main).sink { [weak self] p in
            self?.localPort = p
            // The retry logic handles cases where iPad isn't ready yet
            if let _ = p, self?.iproxy.isRunning == true {
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.conn.waitAndConnect()
                }
            }
        }.store(in: &cancellables)

        // Monitor USB connection status
        conn.$connectionStatus.receive(on: DispatchQueue.main).sink { [weak self] s in
            self?.usbStatus = s
            self?.isConnected = s.contains("Connected")
        }.store(in: &cancellables)

        // Monitor WiFi status
        wifiServer.$status.receive(on: DispatchQueue.main).sink { [weak self] s in
            self?.wifiStatus = "WiFi: " + s
        }.store(in: &cancellables)
    }

    func triggerMIDIActivity() {
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.1)) {
                self.midiActivity = true
            }

            // Reset activity after 200ms (like a preamp LED)
            self.midiActivityTimer?.invalidate()
            self.midiActivityTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        self?.midiActivity = false
                    }
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

            // Always advertise WiFi via Bonjour - let the iPad choose which connection to use
            self.bonjour.publish(port: 8078)
        }

        do {
            try iproxy.start()

            // The USB connection happens automatically when:
            // 1. An iOS device attaches (USBMuxdMonitor → IProxyManager starts iproxy → waitAndConnect)
            // 2. System wake events (handled by IProxyManager sleep/wake monitoring)

            status = "Running"
        } catch {
            status = "Error: \(error.localizedDescription)"
        }
    }

    func stop() {
        print("BridgeApp: Stopping all services...")

        conn.stop()
        iproxy.stop()
        wifiServer.stop()
        bonjour.stop()

        midi.cleanup()

        status = "Stopped"
        isRunning = false
        isConnected = false
        midiReady = false
    }

    func testWiFiMIDI() {
        // Test sending MIDI CC through WiFi server
        wifiServer.testMIDITransmission()
    }
}
