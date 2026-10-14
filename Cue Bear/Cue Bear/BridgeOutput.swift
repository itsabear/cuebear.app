// BridgeOutput.swift — iPad client to Mac Bridge over Wi-Fi
// - Browses Bonjour (_cuebear._tcp)
// - Connects and sends newline-delimited JSON
// - v1.2.1: pairs with the Bridge and authenticates every connection (see SecureLink.swift)
// - Helpers: sendCC / sendNote / sendTransport
//
// v1.2.1 changes
// - All state lives on the main thread. Network callbacks hop to main before touching it.
//   (Timers used to be created on a background queue with no run loop, so the 30 s
//   reconnect timer never fired and a dropped link stayed down.)
// - Reconnects after 0.5, 1, 2, 4, then every 8 s instead of never / every 30 s.
// - Detects a dead Bridge within ~6 s using the Bridge's 2 s heartbeat.
// - Incoming data is split into lines, so merged or split TCP reads no longer lose messages.
// - MIDI is sent immediately instead of waiting for a 10 ms batch timer.
// - Still works with older Bridges (1.2.3 and earlier), without pairing.

import Foundation
import Network
import UIKit
import CryptoKit
import Security

final class BridgeOutput: ObservableObject {
    struct Item: Identifiable {
        let id = UUID()
        let name: String
        let endpoint: NWEndpoint
    }

    enum ConnectionQuality {
        case excellent, good, fair, poor, disconnected
    }

    /// What the pairing overlay shows. nil = no overlay.
    struct PairingPrompt: Identifiable, Equatable {
        enum Stage: Equatable {
            case contacting
            case confirmOnMac(code: String)
            case declined
            case busy(otherDevice: String)
            case failed(message: String)
        }
        let id = UUID()
        let bridgeName: String
        var stage: Stage
    }

    @Published var discovered: [Item] = []
    @Published var isConnected: Bool = false
    @Published var isConnecting: Bool = false
    @Published var current: Item? = nil
    @Published var connectionQuality: ConnectionQuality = .disconnected
    @Published var pairingPrompt: PairingPrompt? = nil
    /// True when the link is paired and authenticated.
    @Published private(set) var isSecure: Bool = false
    /// True when connected to a Bridge older than 1.2.1 (no pairing support).
    @Published private(set) var bridgeNeedsUpdate: Bool = false

    // v1.0.8: Internal (not private) so ConnectionCoordinator can check if connection is suspended
    internal var connection: NWConnection?
    // v1.0.8: Track if WiFi was actually suspended (for proper resume detection)
    internal var isSuspended: Bool = false

    private enum LinkState {
        case idle, waitingForHello, authenticating, pairing, authenticated, legacy
    }

    private var linkState: LinkState = .idle
    private var lineBuffer = LineBuffer()
    private var connectionGeneration = 0
    private let queue = DispatchQueue(label: "CueBear.BridgeOutput", qos: .userInteractive)
    private var browser: NWBrowser?
    private var discoveryRefreshTimer: Timer?
    private var heartbeatTimer: Timer?
    private var helloTimeout: DispatchWorkItem?
    private var reconnectWork: DispatchWorkItem?
    private var reconnectAttempt = 0
    private var userInitiatedDisconnect = false
    private var lastReceived = Date.distantPast
    private var lastSuccessfulMessage = Date.distantPast
    private var backgroundSupportConfigured = false
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    // Session / pairing state for the current connection
    private var bridgeID: String?
    private var bridgeName: String = "Mac"
    private var sessionNonce: String?
    private var pairingPrivateKey: Curve25519.KeyAgreement.PrivateKey?
    private var pairingNonce: Data?
    private var pendingLinkKey: SymmetricKey?

    private let helloWait: TimeInterval = 2.5          // older Bridges never send hello
    private let heartbeatInterval: TimeInterval = 2.0
    private let staleAfter: TimeInterval = 6.0         // 1.2.1 Bridges send a heartbeat every 2 s
    private let reconnectDelays: [TimeInterval] = [0.5, 1, 2, 4, 8]

    init() {
        // Tokens from the old (never-completed) pairing scheme are no longer used.
        UserDefaults.standard.removeObject(forKey: "BridgePairToken")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        heartbeatTimer?.invalidate()
        discoveryRefreshTimer?.invalidate()
        connection?.cancel()
        browser?.cancel()
    }

    // MARK: - Discovery

    func start() {
        setupBackgroundTaskSupport()
        startBrowsing()
        startDiscoveryRefreshTimer()
    }

    private func startBrowsing() {
        browser?.cancel()
        let params = NWParameters.tcp
        let bonjour = NWBrowser.Descriptor.bonjour(type: "_cuebear._tcp.", domain: nil)
        let newBrowser = NWBrowser(for: bonjour, using: params)
        browser = newBrowser

        newBrowser.stateUpdateHandler = { state in
            debugPrint("BridgeOutput: Browser state changed to: \(state)")
        }
        newBrowser.browseResultsChangedHandler = { [weak self] results, _ in
            let items: [Item] = results.compactMap { result in
                guard case let .service(name: name, type: _, domain: _, interface: _) = result.endpoint else {
                    return nil
                }
                let cleanName = name.hasSuffix(".local") ? String(name.dropLast(6)) : name
                return Item(name: cleanName, endpoint: result.endpoint)
            }
            DispatchQueue.main.async {
                self?.discovered = items.sorted { $0.name < $1.name }
            }
        }
        newBrowser.start(queue: queue)
    }

    private func startDiscoveryRefreshTimer() {
        discoveryRefreshTimer?.invalidate()
        // Restart browsing every 30 s while disconnected, to catch Bridge apps that start later
        discoveryRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.isConnected else { return }
            self.restartBrowsing()
        }
    }

    private func restartBrowsing() {
        browser?.cancel()
        browser = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startBrowsing()
        }
    }

    func restartDiscovery() {
        debugPrint("BridgeOutput: Manually restarting discovery")
        restartBrowsing()
    }

    func stop() {
        disconnect()
        browser?.cancel()
        browser = nil
        discoveryRefreshTimer?.invalidate()
        discoveryRefreshTimer = nil
        discovered.removeAll()
    }

    // MARK: - Connect / disconnect

    func connect(to item: Item) {
        debugPrint("BridgeOutput: connect(to: \(item.name))")
        tearDownConnection()
        cancelReconnect()
        userInitiatedDisconnect = false
        isSuspended = false
        current = item
        isConnecting = true
        bridgeName = item.name

        // TCP keepalive: detect dead sockets even when nothing is being sent
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 10
        tcp.keepaliveInterval = 5
        tcp.keepaliveCount = 3
        let params = NWParameters(tls: nil, tcp: tcp)
        let conn = NWConnection(to: item.endpoint, using: params)

        connectionGeneration += 1
        let generation = connectionGeneration
        connection = conn

        conn.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                self?.handleConnectionState(state, generation: generation)
            }
        }
        conn.start(queue: queue)
    }

    /// Manual disconnect: stays disconnected until connect(to:) is called again.
    func disconnect() {
        userInitiatedDisconnect = true
        cancelReconnect()
        tearDownConnection()
        isSuspended = false
        current = nil
    }

    /// Closes the socket and resets per-connection state. Keeps `current` and `isSuspended`.
    private func tearDownConnection() {
        connectionGeneration += 1
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        linkState = .idle
        lineBuffer.reset()
        helloTimeout?.cancel()
        helloTimeout = nil
        stopHeartbeat()
        sessionNonce = nil
        pairingPrivateKey = nil
        pairingNonce = nil
        pendingLinkKey = nil
        isConnected = false
        isConnecting = false
        isSecure = false
        connectionQuality = .disconnected
    }

    private func handleConnectionState(_ state: NWConnection.State, generation: Int) {
        guard generation == connectionGeneration, let conn = connection else { return }

        switch state {
        case .ready:
            debugPrint("BridgeOutput: TCP connected to \(bridgeName)")
            linkState = .waitingForHello
            lastReceived = Date()
            receive(on: conn, generation: generation)

            let timeout = DispatchWorkItem { [weak self] in
                guard let self = self, generation == self.connectionGeneration,
                      self.linkState == .waitingForHello else { return }
                self.enterLegacyMode()
            }
            helloTimeout = timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + helloWait, execute: timeout)

        case .failed(let error):
            debugPrint("BridgeOutput: Connection failed: \(error)")
            handleLinkLost()

        case .waiting(let error):
            // The Bridge can't be reached right now (Mac asleep, Wi-Fi changed…).
            debugPrint("BridgeOutput: Connection waiting: \(error)")
            handleLinkLost()

        case .cancelled:
            handleLinkLost()

        default:
            break
        }
    }

    private func handleLinkLost() {
        let wasSuspended = isSuspended
        tearDownConnection()
        guard !userInitiatedDisconnect, current != nil else { return }
        if wasSuspended {
            // USB is active. resume() reconnects Wi-Fi when USB goes away.
            isSuspended = true
            return
        }
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        guard let item = current, !userInitiatedDisconnect else { return }
        cancelReconnect()
        let delay = reconnectDelays[min(reconnectAttempt, reconnectDelays.count - 1)]
        reconnectAttempt += 1
        debugPrint("BridgeOutput: Reconnecting to \(item.name) in \(delay)s (attempt \(reconnectAttempt))")

        let work = DispatchWorkItem { [weak self] in
            guard let self = self, !self.userInitiatedDisconnect, self.connection == nil, !self.isSuspended else { return }
            // Prefer a freshly discovered entry with the same name (the Bridge may have restarted).
            let target = self.discovered.first { $0.name == item.name } ?? item
            self.connect(to: target)
        }
        reconnectWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func cancelReconnect() {
        reconnectWork?.cancel()
        reconnectWork = nil
    }

    // MARK: - USB priority (called by ConnectionCoordinator)

    // v1.0.8: Suspend Wi-Fi temporarily (USB takes priority) without destroying it.
    func suspend() {
        debugPrint("BridgeOutput: Suspending Wi-Fi (USB taking priority)")
        isSuspended = true
        cancelReconnect()
        // UI shows disconnected; heartbeats keep the socket alive for a quick resume.
        isConnected = false
        isConnecting = false
    }

    // v1.0.8: Resume Wi-Fi after USB disconnects.
    func resume() {
        guard isSuspended else {
            debugPrint("BridgeOutput: Wi-Fi was not suspended - nothing to resume")
            return
        }
        isSuspended = false

        if connection != nil, linkState == .authenticated || linkState == .legacy {
            lastSuccessfulMessage = Date()
            isConnected = true
            connectionQuality = .excellent
            debugPrint("BridgeOutput: Wi-Fi resumed")
        } else if let item = current {
            debugPrint("BridgeOutput: Wi-Fi link was lost while suspended - reconnecting")
            reconnectAttempt = 0
            connect(to: item)
        }
    }

    // MARK: - Receiving

    private func receive(on conn: NWConnection, generation: Int) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            DispatchQueue.main.async {
                guard let self = self, generation == self.connectionGeneration else { return }

                if let data = data, !data.isEmpty {
                    self.lastReceived = Date()
                    for line in self.lineBuffer.append(data) {
                        self.handleLine(line)
                        if generation != self.connectionGeneration { return }
                    }
                }

                if let error = error {
                    // A receive timeout is not fatal; keep listening.
                    if case .posix(let code) = error, code == .ETIMEDOUT {
                        self.receive(on: conn, generation: generation)
                        return
                    }
                    debugPrint("BridgeOutput: Receive error: \(error)")
                    self.handleLinkLost()
                    return
                }
                if isComplete {
                    self.handleLinkLost()
                    return
                }
                self.receive(on: conn, generation: generation)
            }
        }
    }

    private func handleLine(_ line: Data) {
        guard let json = SecureLink.decode(line), let type = json["type"] as? String else { return }

        switch type {
        case SecureLink.MessageType.hello:
            handleHello(json)

        case SecureLink.MessageType.authOK:
            debugPrint("BridgeOutput: Paired link authenticated")
            linkState = .authenticated
            switch pairingPrompt?.stage {
            case .some(.contacting), .some(.confirmOnMac(_)):
                pairingPrompt = nil
            default:
                break
            }
            markConnected(secure: true)

        case SecureLink.MessageType.authFailed:
            let reason = json["reason"] as? String ?? "unknown"
            debugPrint("BridgeOutput: Authentication failed (\(reason)) - pairing again")
            if let id = bridgeID { BridgeKeyStore.delete(for: id) }
            startPairing()

        case SecureLink.MessageType.busy:
            let other = json["device_name"] as? String ?? "another iPad"
            pairingPrompt = PairingPrompt(bridgeName: bridgeName, stage: .busy(otherDevice: other))
            stopTrying()

        case SecureLink.MessageType.pairKey:
            handlePairKey(json)

        case SecureLink.MessageType.pairOK:
            guard let key = pendingLinkKey, let id = bridgeID else { return }
            BridgeKeyStore.save(key, for: id)
            pendingLinkKey = nil
            debugPrint("BridgeOutput: Paired with \(bridgeName)")
            sendAuth(key: key)

        case SecureLink.MessageType.pairDenied:
            let reason = json["reason"] as? String ?? "declined"
            pairingPrompt = PairingPrompt(bridgeName: bridgeName,
                                          stage: reason == "busy" ? .busy(otherDevice: "another iPad") : .declined)
            stopTrying()

        case SecureLink.MessageType.authRequired:
            // We are in compatibility mode but this Bridge wants pairing: start over.
            if linkState == .legacy {
                debugPrint("BridgeOutput: Bridge requires pairing - reconnecting")
                handleLinkLost()
            }

        case SecureLink.MessageType.heartbeat:
            break   // lastReceived is already updated

        case "midi_input":
            handleMIDIInputFromDAW(json)

        default:
            break
        }
    }

    // MARK: - Authentication and pairing

    private func handleHello(_ json: [String: Any]) {
        guard linkState == .waitingForHello else { return }
        helloTimeout?.cancel()
        helloTimeout = nil

        guard let id = json["bridge_id"] as? String, !id.isEmpty,
              let nonce = json["nonce"] as? String, !nonce.isEmpty else {
            enterLegacyMode()
            return
        }
        bridgeID = id
        sessionNonce = nonce
        if let name = json["name"] as? String, !name.isEmpty {
            bridgeName = name
        }
        bridgeNeedsUpdate = false

        if let key = BridgeKeyStore.key(for: id) {
            sendAuth(key: key)
        } else {
            startPairing()
        }
    }

    private func sendAuth(key: SymmetricKey) {
        guard let id = bridgeID, let nonce = sessionNonce else { return }
        linkState = .authenticating
        let mac = SecureLink.authMAC(key: key, bridgeID: id, deviceID: Self.deviceID, sessionNonce: nonce)
        sendControl([
            "type": SecureLink.MessageType.auth,
            "proto": SecureLink.protocolVersion,
            "device_id": Self.deviceID,
            "device_name": UIDevice.current.name,
            "mac": mac
        ])
    }

    private func startPairing() {
        linkState = .pairing
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        let nonce = SecureLink.randomBytes(16)
        pairingPrivateKey = privateKey
        pairingNonce = nonce
        pendingLinkKey = nil

        pairingPrompt = PairingPrompt(bridgeName: bridgeName, stage: .contacting)
        sendControl([
            "type": SecureLink.MessageType.pairStart,
            "device_id": Self.deviceID,
            "device_name": UIDevice.current.name,
            "commit": SecureLink.commitment(publicKey: privateKey.publicKey.rawRepresentation, nonce: nonce)
        ])
    }

    private func handlePairKey(_ json: [String: Any]) {
        guard linkState == .pairing,
              let privateKey = pairingPrivateKey,
              let deviceNonce = pairingNonce,
              let pubString = json["bridge_pub"] as? String,
              let bridgePublicKey = Data(base64Encoded: pubString), bridgePublicKey.count == 32,
              let nonceString = json["nonce"] as? String,
              let bridgeNonce = Data(base64Encoded: nonceString), bridgeNonce.count == 16 else {
            return
        }

        do {
            pendingLinkKey = try SecureLink.deriveLinkKey(privateKey: privateKey,
                                                          peerPublicKey: bridgePublicKey,
                                                          deviceNonce: deviceNonce,
                                                          bridgeNonce: bridgeNonce)
        } catch {
            pairingPrompt = PairingPrompt(bridgeName: bridgeName,
                                          stage: .failed(message: "The Bridge sent an invalid key. Try again."))
            stopTrying()
            return
        }

        let devicePublicKey = privateKey.publicKey.rawRepresentation
        sendControl([
            "type": SecureLink.MessageType.pairReveal,
            "device_pub": devicePublicKey.base64EncodedString(),
            "nonce": deviceNonce.base64EncodedString()
        ])

        let code = SecureLink.comparisonCode(bridgePublicKey: bridgePublicKey,
                                             devicePublicKey: devicePublicKey,
                                             deviceNonce: deviceNonce,
                                             bridgeNonce: bridgeNonce)
        pairingPrompt = PairingPrompt(bridgeName: bridgeName, stage: .confirmOnMac(code: code))
    }

    /// Older Bridge (no hello): connect without pairing, as before.
    private func enterLegacyMode() {
        debugPrint("BridgeOutput: Bridge did not send hello - using compatibility mode (update the Bridge to pair)")
        linkState = .legacy
        bridgeNeedsUpdate = true
        markConnected(secure: false)
    }

    private func markConnected(secure: Bool) {
        cancelReconnect()
        reconnectAttempt = 0
        isSecure = secure
        isConnecting = false
        lastSuccessfulMessage = Date()
        lastReceived = Date()
        connectionQuality = .excellent
        startHeartbeat()
        // While USB has priority, stay quiet in the UI; resume() will flip this.
        if !isSuspended {
            isConnected = true
        }
    }

    /// Stop after a final answer from the Bridge (declined, busy).
    private func stopTrying() {
        userInitiatedDisconnect = true
        cancelReconnect()
        tearDownConnection()
    }

    // Called by the pairing overlay
    func cancelPairing() {
        pairingPrompt = nil
        disconnect()
    }

    func dismissPairingPrompt() {
        pairingPrompt = nil
    }

    /// Removes every stored Bridge key. The next connection pairs again.
    func forgetPairedBridges() {
        BridgeKeyStore.deleteAll()
    }

    // MARK: - Heartbeat and health

    private func startHeartbeat() {
        stopHeartbeat()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            self?.heartbeatTick()
        }
    }

    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    private func heartbeatTick() {
        guard connection != nil, linkState == .authenticated || linkState == .legacy else { return }

        // Paired Bridges send a heartbeat every 2 s; silence means the link is gone.
        if linkState == .authenticated, Date().timeIntervalSince(lastReceived) > staleAfter {
            debugPrint("BridgeOutput: No data from Bridge for \(Int(staleAfter))s - reconnecting")
            handleLinkLost()
            return
        }

        sendControl([
            "type": SecureLink.MessageType.heartbeat,
            "timestamp": Date().timeIntervalSince1970
        ])
        updateConnectionQuality()
    }

    func checkConnectionHealth() {
        if connection == nil, !isConnected, !userInitiatedDisconnect, !isSuspended, let item = current {
            debugPrint("BridgeOutput: Health check - reconnecting to \(item.name)")
            reconnectAttempt = 0
            connect(to: item)
        }
    }

    private func updateConnectionQuality() {
        guard isConnected else {
            connectionQuality = .disconnected
            return
        }
        let silence = Date().timeIntervalSince(lastReceived)
        if linkState == .legacy {
            connectionQuality = .good   // older Bridges don't send heartbeats, so we can't measure
        } else if silence < 3 {
            connectionQuality = .excellent
        } else if silence < 4 {
            connectionQuality = .good
        } else if silence < 5 {
            connectionQuality = .fair
        } else {
            connectionQuality = .poor
        }
    }

    // MARK: - Send helpers

    func sendCC(channel: Int, cc: Int, value: Int, label: String, buttonID: String) {
        sendMIDIPayload([
            "type": "midi_cc",
            "channel": channel,
            "cc": cc,
            "value": value,
            "label": label,
            "button_id": buttonID
        ])
    }

    func sendNote(channel: Int, note: Int, velocity: Int, label: String, buttonID: String) {
        sendMIDIPayload([
            "type": "midi_note",
            "channel": channel,
            "note": note,
            "velocity": velocity,
            "label": label,
            "button_id": buttonID
        ])
    }

    func sendTransport(action: String) {
        sendMIDIPayload([
            "type": "transport",
            "action": action,
            "timestamp": Date().timeIntervalSince1970
        ])
    }

    func sendMIDIImmediate(channel: Int, cc: Int, value: Int, label: String, buttonID: String) {
        sendCC(channel: channel, cc: cc, value: value, label: label, buttonID: buttonID)
    }

    // MARK: - Low-level IO

    /// MIDI only goes out on an authenticated (or compatibility-mode) link.
    private func sendMIDIPayload(_ object: [String: Any]) {
        guard linkState == .authenticated || linkState == .legacy else {
            debugPrint("BridgeOutput: Not connected - dropping MIDI message")
            return
        }
        sendControl(object)
        lastSuccessfulMessage = Date()
    }

    private func sendControl(_ object: [String: Any]) {
        guard let conn = connection, let data = SecureLink.encodeLine(object) else { return }
        conn.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                debugPrint("BridgeOutput: Send failed: \(error)")
            }
        })
    }

    // MARK: - MIDI from the DAW

    private func handleMIDIInputFromDAW(_ json: [String: Any]) {
        guard let midiBytes = json["midi"] as? [Int], midiBytes.count >= 3 else {
            debugPrint("BridgeOutput: Invalid MIDI input data")
            return
        }

        let statusByte = midiBytes[0]
        let data1 = midiBytes[1]
        let data2 = midiBytes[2]
        let messageType = statusByte & 0xF0
        let channel = (statusByte & 0x0F) + 1 // Convert to 1-based channel

        switch messageType {
        case 0xB0: // Control Change (CC)
            NotificationCenter.default.post(
                name: Notification.Name("cbMIDIInputFromDAW"),
                object: nil,
                userInfo: ["type": "cc", "channel": channel, "cc": data1, "value": data2]
            )
        case 0x90: // Note On
            NotificationCenter.default.post(
                name: Notification.Name("cbMIDIInputFromDAW"),
                object: nil,
                userInfo: ["type": "note", "channel": channel, "note": data1, "velocity": data2]
            )
        default:
            break
        }
    }

    // MARK: - Background

    private func setupBackgroundTaskSupport() {
        guard !backgroundSupportConfigured else { return }
        backgroundSupportConfigured = true
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground),
                                               name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    @objc private func appDidEnterBackground() {
        // iOS allows roughly 30 s of background time before suspending the app.
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "CueBearWiFiConnection") { [weak self] in
            self?.endBackgroundTask()
        }
    }

    @objc private func appWillEnterForeground() {
        endBackgroundTask()
        DispatchQueue.main.async { [weak self] in
            self?.checkWiFiConnectionAfterWake()
        }
    }

    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }

    private func checkWiFiConnectionAfterWake() {
        if connection != nil {
            if linkState == .authenticated, Date().timeIntervalSince(lastReceived) > staleAfter {
                debugPrint("BridgeOutput: Link went stale while in background - reconnecting")
                reconnectAttempt = 0
                handleLinkLost()
            } else {
                sendControl(["type": SecureLink.MessageType.heartbeat, "timestamp": Date().timeIntervalSince1970])
            }
        } else {
            checkConnectionHealth()
        }
    }

    // MARK: - Identity

    /// A random ID for this iPad, created once. Not the hardware identifier.
    static var deviceID: String {
        let key = "CueBearDeviceID"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: key)
        return created
    }
}

// MARK: - Keychain storage for Bridge link keys

enum BridgeKeyStore {
    private static let service = "com.studiobear.cuebear.bridge-link-key"

    private static func baseQuery(for bridgeID: String) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: bridgeID
        ]
    }

    static func key(for bridgeID: String) -> SymmetricKey? {
        var query = baseQuery(for: bridgeID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data, data.count == 32 else {
            return nil
        }
        return SymmetricKey(data: data)
    }

    static func save(_ key: SymmetricKey, for bridgeID: String) {
        delete(for: bridgeID)
        var query = baseQuery(for: bridgeID)
        query[kSecValueData as String] = SecureLink.keyData(key)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            debugPrint("BridgeKeyStore: failed to save key (\(status))")
        }
    }

    static func delete(for bridgeID: String) {
        SecItemDelete(baseQuery(for: bridgeID) as CFDictionary)
    }

    static func deleteAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }
}
