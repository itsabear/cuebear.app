import Foundation
import Network
import CryptoKit

/// Security Manager for Cue Bear Bridge
/// - Connection rate limiting (per remote host)
/// - Message rate limiting
/// - Input validation and sanitization for MIDI messages
/// v1.2.1: pairing and session authentication live in WifiServer + PairedDeviceStore below.
final class ConnectionSecurity {
    static let shared = ConnectionSecurity()

    // Serial queue for thread-safe access to shared state
    private let stateQueue = DispatchQueue(label: "com.cuebear.security.state", qos: .userInitiated)

    // MARK: - Connection Rate Limiting
    private var connectionAttempts: [String: [Date]] = [:]
    private let maxAttemptsPerMinute = 30
    private let rateLimitWindow: TimeInterval = 60.0

    // MARK: - Message Rate Limiting
    private var messageCounts: [String: Int] = [:]
    private var lastResetTime: [String: Date] = [:]
    private let maxMessagesPerSecond = 400   // fast fader sweeps send ~120 msg/s per fader
    private let messageRateWindow: TimeInterval = 1.0

    private init() {
        Logger.shared.log("ConnectionSecurity: initialized")
    }

    // MARK: - Connection Validation

    /// Returns false if this host has opened too many connections in the last minute.
    func validateConnection(from endpoint: NWEndpoint) -> Bool {
        return stateQueue.sync {
            let hostId = hostIdentifier(for: endpoint)
            let now = Date()
            let recent = (connectionAttempts[hostId] ?? []).filter { now.timeIntervalSince($0) < rateLimitWindow }
            if recent.count >= maxAttemptsPerMinute {
                Logger.shared.log("ConnectionSecurity: connection rate limit exceeded for \(hostId)")
                connectionAttempts[hostId] = recent
                return false
            }
            connectionAttempts[hostId] = recent + [now]
            return true
        }
    }

    /// Clears rate limiting for a specific host (useful for manual reconnection)
    func clearRateLimit(for endpoint: NWEndpoint) {
        stateQueue.sync {
            _ = connectionAttempts.removeValue(forKey: hostIdentifier(for: endpoint))
        }
    }

    // MARK: - Message Rate Limiting

    func validateMessageRate(for deviceId: String) -> Bool {
        return stateQueue.sync {
            let now = Date()
            if let lastReset = lastResetTime[deviceId] {
                if now.timeIntervalSince(lastReset) >= messageRateWindow {
                    messageCounts[deviceId] = 0
                    lastResetTime[deviceId] = now
                }
            } else {
                lastResetTime[deviceId] = now
                messageCounts[deviceId] = 0
            }
            let currentCount = messageCounts[deviceId] ?? 0
            if currentCount >= maxMessagesPerSecond {
                if currentCount == maxMessagesPerSecond {
                    Logger.shared.log("ConnectionSecurity: message rate limit exceeded for \(deviceId)")
                }
                messageCounts[deviceId] = currentCount + 1
                return false
            }
            messageCounts[deviceId] = currentCount + 1
            return true
        }
    }

    // MARK: - Input Validation and Sanitization

    /// Validates and sanitizes a message. Returns nil for anything that is not allowed.
    func validateAndSanitizeMIDIMessage(_ json: [String: Any]) -> [String: Any]? {
        guard let type = json["type"] as? String else {
            Logger.shared.log("ConnectionSecurity: invalid message - missing type")
            return nil
        }

        switch type {
        case "midi_cc":
            return validateMIDICC(json)
        case "midi_note":
            return validateMIDINote(json)
        case "midi_input":
            return validateMIDIInput(json)
        case "batch":
            return validateBatchMessage(json)
        case "heartbeat":
            // v1.2.1: heartbeats were rejected here before, so the Bridge never saw them.
            return ["type": "heartbeat"]
        case "handshake", "handshake_response":
            return validateHandshake(json)
        case "switch_to_wifi":
            return ["type": "switch_to_wifi"]
        case "pair_request":
            // Sent by Cue Bear 1.0.x–1.2.0 iPads. Never answered; kept so it is not logged as unknown.
            return ["type": "pair_request"]
        default:
            Logger.shared.log("ConnectionSecurity: unknown message type: \(type)")
            return nil
        }
    }

    private func validateMIDICC(_ json: [String: Any]) -> [String: Any]? {
        guard let channel = json["channel"] as? Int, (1...16).contains(channel),
              let cc = json["cc"] as? Int, (0...127).contains(cc),
              let value = json["value"] as? Int, (0...127).contains(value) else {
            Logger.shared.log("ConnectionSecurity: invalid MIDI CC message")
            return nil
        }
        return ["type": "midi_cc", "channel": channel, "cc": cc, "value": value]
    }

    private func validateMIDINote(_ json: [String: Any]) -> [String: Any]? {
        guard let channel = json["channel"] as? Int, (1...16).contains(channel),
              let note = json["note"] as? Int, (0...127).contains(note),
              let velocity = json["velocity"] as? Int, (0...127).contains(velocity) else {
            Logger.shared.log("ConnectionSecurity: invalid MIDI Note message")
            return nil
        }
        return ["type": "midi_note", "channel": channel, "note": note, "velocity": velocity]
    }

    private func validateMIDIInput(_ json: [String: Any]) -> [String: Any]? {
        guard let midi = json["midi"] as? [Int], midi.count >= 3 else {
            Logger.shared.log("ConnectionSecurity: invalid MIDI input - missing or invalid midi array")
            return nil
        }
        let status = midi[0], data1 = midi[1], data2 = midi[2]
        guard (176...191).contains(status) else {
            Logger.shared.log("ConnectionSecurity: invalid MIDI status byte: \(status)")
            return nil
        }
        guard (0...127).contains(data1) && (0...127).contains(data2) else {
            Logger.shared.log("ConnectionSecurity: invalid MIDI data bytes: \(data1), \(data2)")
            return nil
        }
        return ["type": "midi_input", "midi": [status, data1, data2]]
    }

    private func validateBatchMessage(_ json: [String: Any]) -> [String: Any]? {
        guard let messages = json["messages"] as? [String] else {
            Logger.shared.log("ConnectionSecurity: invalid batch message - missing messages array")
            return nil
        }
        if messages.count > 50 {
            Logger.shared.log("ConnectionSecurity: batch message too large: \(messages.count) messages")
            return nil
        }
        var validMessages: [String] = []
        for messageString in messages {
            let trimmed = messageString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let messageData = trimmed.data(using: .utf8),
                  let messageJson = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any],
                  let innerType = messageJson["type"] as? String,
                  innerType == "midi_cc" || innerType == "midi_note",   // no nested batches or control messages
                  let sanitized = validateAndSanitizeMIDIMessage(messageJson),
                  let sanitizedData = try? JSONSerialization.data(withJSONObject: sanitized),
                  let sanitizedString = String(data: sanitizedData, encoding: .utf8) else {
                Logger.shared.log("ConnectionSecurity: invalid message in batch, skipping")
                continue
            }
            validMessages.append(sanitizedString)
        }
        return ["type": "batch", "messages": validMessages]
    }

    private func validateHandshake(_ json: [String: Any]) -> [String: Any]? {
        guard let type = json["type"] as? String else { return nil }
        return ["type": type]
    }

    // MARK: - Host identity

    /// Rate limits apply per remote host. (Before v1.2.1 the port was included,
    /// so every connection counted as a new device and the limit never applied.)
    private func hostIdentifier(for endpoint: NWEndpoint) -> String {
        if case let .hostPort(host, _) = endpoint {
            return "\(host)"
        }
        return "\(endpoint)"
    }

    /// Removes old connection attempts to prevent memory growth
    func cleanupOldData() {
        stateQueue.sync {
            let now = Date()
            for (hostId, attempts) in connectionAttempts {
                let recent = attempts.filter { now.timeIntervalSince($0) < rateLimitWindow * 2 }
                if recent.isEmpty {
                    connectionAttempts.removeValue(forKey: hostId)
                } else {
                    connectionAttempts[hostId] = recent
                }
            }
            for (deviceId, lastReset) in lastResetTime where now.timeIntervalSince(lastReset) > messageRateWindow * 2 {
                messageCounts.removeValue(forKey: deviceId)
                lastResetTime.removeValue(forKey: deviceId)
            }
        }
    }

    func getSecurityStats() -> [String: Any] {
        return stateQueue.sync {
            return [
                "trackedHosts": connectionAttempts.count,
                "activeMessageCounters": messageCounts.count
            ]
        }
    }
}

// MARK: - Paired devices (v1.2.1)

/// iPads that completed pairing with this Bridge, plus this Bridge's own identity.
/// Stored in ~/Library/Application Support/CueBearBridge/paired-devices.json with owner-only permissions.
final class PairedDeviceStore {
    static let shared = PairedDeviceStore()

    struct Device: Codable {
        let id: String
        var name: String
        let key: Data
        let pairedAt: Date
    }

    private struct FileFormat: Codable {
        var bridgeID: String
        /// nil = automatic: required as soon as at least one iPad has paired.
        var requirePairing: Bool?
        var devices: [Device]
    }

    private let lock = NSLock()
    private var state: FileFormat
    private let fileURL: URL

    private init() {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("CueBearBridge", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        fileURL = dir.appendingPathComponent("paired-devices.json")

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(FileFormat.self, from: data) {
            state = decoded
        } else {
            state = FileFormat(bridgeID: UUID().uuidString, requirePairing: nil, devices: [])
            persist()
        }
    }

    var bridgeID: String {
        lock.lock(); defer { lock.unlock() }
        return state.bridgeID
    }

    var deviceCount: Int {
        lock.lock(); defer { lock.unlock() }
        return state.devices.count
    }

    /// Whether unpaired (older) iPad apps may send MIDI.
    /// Automatic mode: allowed until the first iPad pairs, so people who update the Bridge
    /// before the iPad app keep working. After that, pairing is required.
    var requirePairing: Bool {
        lock.lock(); defer { lock.unlock() }
        return state.requirePairing ?? !state.devices.isEmpty
    }

    func setRequirePairing(_ value: Bool) {
        lock.lock()
        state.requirePairing = value
        lock.unlock()
        persist()
    }

    func device(id: String) -> Device? {
        lock.lock(); defer { lock.unlock() }
        return state.devices.first { $0.id == id }
    }

    func add(id: String, name: String, key: SymmetricKey) {
        lock.lock()
        state.devices.removeAll { $0.id == id }
        state.devices.append(Device(id: id, name: name, key: SecureLink.keyData(key), pairedAt: Date()))
        lock.unlock()
        persist()
    }

    func forgetAll() {
        lock.lock()
        state.devices.removeAll()
        state.requirePairing = nil
        lock.unlock()
        persist()
    }

    private func persist() {
        lock.lock()
        let snapshot = state
        lock.unlock()
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        do {
            try data.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch {
            Logger.shared.log("PairedDeviceStore: failed to save: \(error.localizedDescription)")
        }
    }
}

// MARK: - Shared protocol (keep identical to the iPad's SecureLink.swift)

enum SecureLink {
    static let protocolVersion = 2

    enum MessageType {
        static let hello = "hello"
        static let auth = "auth"
        static let authOK = "auth_ok"
        static let authFailed = "auth_failed"
        static let authRequired = "auth_required"
        static let busy = "busy"
        static let pairStart = "pair_start"
        static let pairKey = "pair_key"
        static let pairReveal = "pair_reveal"
        static let pairOK = "pair_ok"
        static let pairDenied = "pair_denied"
        static let heartbeat = "heartbeat"
    }

    // MARK: - Framing

    /// Encodes a JSON object as one newline-terminated line.
    static func encodeLine(_ object: [String: Any]) -> Data? {
        guard JSONSerialization.isValidJSONObject(object),
              var data = try? JSONSerialization.data(withJSONObject: object) else { return nil }
        data.append(0x0A)
        return data
    }

    /// Decodes one line (without its newline) into a JSON object.
    static func decode(_ line: Data) -> [String: Any]? {
        return (try? JSONSerialization.jsonObject(with: line)) as? [String: Any]
    }

    // MARK: - Randomness

    static func randomBytes(_ count: Int) -> Data {
        var generator = SystemRandomNumberGenerator()
        return Data((0..<count).map { _ in UInt8.random(in: UInt8.min...UInt8.max, using: &generator) })
    }

    static func randomToken(byteCount: Int = 16) -> String {
        return randomBytes(byteCount).base64EncodedString()
    }

    // MARK: - Pairing

    /// The iPad's commitment to its public key and nonce.
    static func commitment(publicKey: Data, nonce: Data) -> String {
        return Data(SHA256.hash(data: publicKey + nonce)).base64EncodedString()
    }

    /// The 6-digit code both screens show during pairing.
    static func comparisonCode(bridgePublicKey: Data, devicePublicKey: Data,
                               deviceNonce: Data, bridgeNonce: Data) -> String {
        let input = Data("cuebear-code-v1".utf8) + bridgePublicKey + devicePublicKey + deviceNonce + bridgeNonce
        let bytes = Array(SHA256.hash(data: input))
        let value = ((UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])) % 1_000_000
        let digits = String(value)
        return String(repeating: "0", count: max(0, 6 - digits.count)) + digits
    }

    /// "482913" → "482 913"
    static func formattedCode(_ code: String) -> String {
        guard code.count == 6 else { return code }
        return String(code.prefix(3)) + " " + String(code.suffix(3))
    }

    /// The long-term link key both sides derive after pairing.
    static func deriveLinkKey(privateKey: Curve25519.KeyAgreement.PrivateKey,
                              peerPublicKey: Data,
                              deviceNonce: Data,
                              bridgeNonce: Data) throws -> SymmetricKey {
        let peer = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerPublicKey)
        let secret = try privateKey.sharedSecretFromKeyAgreement(with: peer)
        return secret.hkdfDerivedSymmetricKey(using: SHA256.self,
                                              salt: deviceNonce + bridgeNonce,
                                              sharedInfo: Data("cuebear-link-key-v1".utf8),
                                              outputByteCount: 32)
    }

    // MARK: - Session authentication

    private static func authPayload(bridgeID: String, deviceID: String, sessionNonce: String) -> Data {
        return Data("cuebear-auth-v1|\(bridgeID)|\(deviceID)|\(sessionNonce)".utf8)
    }

    static func authMAC(key: SymmetricKey, bridgeID: String, deviceID: String, sessionNonce: String) -> String {
        let mac = HMAC<SHA256>.authenticationCode(for: authPayload(bridgeID: bridgeID, deviceID: deviceID, sessionNonce: sessionNonce),
                                                  using: key)
        return Data(mac).base64EncodedString()
    }

    /// Constant-time check of an auth MAC.
    static func verifyAuthMAC(_ macBase64: String, key: SymmetricKey,
                              bridgeID: String, deviceID: String, sessionNonce: String) -> Bool {
        guard let mac = Data(base64Encoded: macBase64) else { return false }
        return HMAC<SHA256>.isValidAuthenticationCode(mac,
                                                      authenticating: authPayload(bridgeID: bridgeID, deviceID: deviceID, sessionNonce: sessionNonce),
                                                      using: key)
    }

    static func keyData(_ key: SymmetricKey) -> Data {
        return key.withUnsafeBytes { Data($0) }
    }
}

/// Turns a TCP byte stream into complete lines. TCP can merge several messages into one
/// read or split one message across two reads; parsing raw reads loses messages.
struct LineBuffer {
    private var buffer = Data()
    let maxBufferedBytes: Int

    init(maxBufferedBytes: Int = 256 * 1024) {
        self.maxBufferedBytes = maxBufferedBytes
    }

    /// Adds bytes and returns every complete line, without the trailing "\n" or "\r\n".
    mutating func append(_ data: Data) -> [Data] {
        buffer.append(data)
        var lines: [Data] = []
        while let newline = buffer.firstIndex(of: 0x0A) {
            var line = Data(buffer[buffer.startIndex..<newline])
            if line.last == 0x0D { line.removeLast() }
            buffer.removeSubrange(buffer.startIndex...newline)
            if !line.isEmpty { lines.append(line) }
        }
        // A peer that never sends a newline must not grow memory forever.
        if buffer.count > maxBufferedBytes { buffer.removeAll() }
        return lines
    }

    mutating func reset() {
        buffer.removeAll()
    }
}
