//
//  SecureLink.swift — Cue Bear wire protocol v2 (pairing + session authentication)
//
//  SHARED CODE: an identical copy of this section lives at the bottom of the Bridge's
//  ConnectionSecurity.swift. If you change one, change the other.
//
//  Protocol overview (newline-delimited JSON over TCP, Wi-Fi only):
//
//    1. Bridge → iPad   {"type":"hello","proto":2,"bridge_id":…,"name":…,"nonce":…,"pairing_required":…}
//
//    Already paired:
//    2. iPad → Bridge   {"type":"auth","device_id":…,"device_name":…,"mac":HMAC(key, bridge|device|nonce)}
//    3. Bridge → iPad   {"type":"auth_ok"}  or  {"type":"auth_failed","reason":…}  or  {"type":"busy"}
//
//    First time (numeric comparison, like Bluetooth pairing):
//    2. iPad → Bridge   {"type":"pair_start","device_id":…,"device_name":…,"commit":SHA256(devicePub‖deviceNonce)}
//    3. Bridge → iPad   {"type":"pair_key","bridge_pub":…,"nonce":…}
//    4. iPad → Bridge   {"type":"pair_reveal","device_pub":…,"nonce":…}
//       Both sides now show the same 6-digit code. The Mac asks the user to Allow.
//    5. Bridge → iPad   {"type":"pair_ok"}  or  {"type":"pair_denied","reason":…}
//    6. iPad authenticates as in "Already paired".
//
//  The iPad commits to its public key before it sees the Bridge's key, so an attacker in the
//  middle cannot search for keys that make the two codes match.
//

import Foundation
import CryptoKit

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
