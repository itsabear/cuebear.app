//
//  SecureLinkTests.swift — Cue Bear
//  v1.2.1: tests for message framing and pairing / authentication.
//
//  NOTE: the "Cue BearTests" target currently compiles no files (its Sources phase is empty).
//  In Xcode, select this file (and CueListTests.swift) → File Inspector → Target Membership →
//  tick "Cue BearTests". Then run with ⌘U.
//

import XCTest
import CryptoKit
@testable import Cue_Bear

final class SecureLinkTests: XCTestCase {

    // MARK: - LineBuffer

    func testTwoMessagesInOneReadAreBothDelivered() {
        var buffer = LineBuffer()
        let lines = buffer.append(Data("{\"a\":1}\n{\"b\":2}\n".utf8))
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(String(decoding: lines[0], as: UTF8.self), "{\"a\":1}")
        XCTAssertEqual(String(decoding: lines[1], as: UTF8.self), "{\"b\":2}")
    }

    func testMessageSplitAcrossReadsIsReassembled() {
        var buffer = LineBuffer()
        XCTAssertTrue(buffer.append(Data("{\"type\":\"mid".utf8)).isEmpty)
        let lines = buffer.append(Data("i_cc\"}\n{\"x\"".utf8))
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(SecureLink.decode(lines[0])?["type"] as? String, "midi_cc")
        let rest = buffer.append(Data(":1}\n".utf8))
        XCTAssertEqual(rest.count, 1)
    }

    func testCRLFAndBlankLinesAreHandled() {
        var buffer = LineBuffer()
        let lines = buffer.append(Data("one\r\n\n\ntwo\n".utf8))
        XCTAssertEqual(lines.map { String(decoding: $0, as: UTF8.self) }, ["one", "two"])
    }

    func testRunawayInputIsDiscarded() {
        var buffer = LineBuffer(maxBufferedBytes: 16)
        XCTAssertTrue(buffer.append(Data(repeating: 0x41, count: 64)).isEmpty)
        let lines = buffer.append(Data("ok\n".utf8))
        XCTAssertEqual(lines.map { String(decoding: $0, as: UTF8.self) }, ["ok"])
    }

    func testEncodeLineEndsWithNewlineAndRoundTrips() throws {
        let data = try XCTUnwrap(SecureLink.encodeLine(["type": "heartbeat", "n": 3]))
        XCTAssertEqual(data.last, 0x0A)
        let decoded = try XCTUnwrap(SecureLink.decode(data.dropLast()))
        XCTAssertEqual(decoded["type"] as? String, "heartbeat")
        XCTAssertEqual(decoded["n"] as? Int, 3)
    }

    // MARK: - Pairing

    /// Runs the full pairing exchange in-process, the way the iPad and the Bridge do it.
    func testPairingGivesBothSidesTheSameCodeAndKey() throws {
        // iPad
        let deviceKey = Curve25519.KeyAgreement.PrivateKey()
        let deviceNonce = SecureLink.randomBytes(16)
        let commit = SecureLink.commitment(publicKey: deviceKey.publicKey.rawRepresentation, nonce: deviceNonce)

        // Bridge
        let bridgeKey = Curve25519.KeyAgreement.PrivateKey()
        let bridgeNonce = SecureLink.randomBytes(16)

        // Bridge checks the reveal against the commitment
        XCTAssertEqual(SecureLink.commitment(publicKey: deviceKey.publicKey.rawRepresentation, nonce: deviceNonce), commit)

        let codeOnIPad = SecureLink.comparisonCode(bridgePublicKey: bridgeKey.publicKey.rawRepresentation,
                                                   devicePublicKey: deviceKey.publicKey.rawRepresentation,
                                                   deviceNonce: deviceNonce, bridgeNonce: bridgeNonce)
        let codeOnMac = SecureLink.comparisonCode(bridgePublicKey: bridgeKey.publicKey.rawRepresentation,
                                                  devicePublicKey: deviceKey.publicKey.rawRepresentation,
                                                  deviceNonce: deviceNonce, bridgeNonce: bridgeNonce)
        XCTAssertEqual(codeOnIPad, codeOnMac)
        XCTAssertEqual(codeOnIPad.count, 6)
        XCTAssertTrue(codeOnIPad.allSatisfy { $0.isNumber })

        let keyOnIPad = try SecureLink.deriveLinkKey(privateKey: deviceKey,
                                                     peerPublicKey: bridgeKey.publicKey.rawRepresentation,
                                                     deviceNonce: deviceNonce, bridgeNonce: bridgeNonce)
        let keyOnMac = try SecureLink.deriveLinkKey(privateKey: bridgeKey,
                                                    peerPublicKey: deviceKey.publicKey.rawRepresentation,
                                                    deviceNonce: deviceNonce, bridgeNonce: bridgeNonce)
        XCTAssertEqual(SecureLink.keyData(keyOnIPad), SecureLink.keyData(keyOnMac))
    }

    func testSwappedKeyFailsTheCommitment() {
        let realKey = Curve25519.KeyAgreement.PrivateKey()
        let attackerKey = Curve25519.KeyAgreement.PrivateKey()
        let nonce = SecureLink.randomBytes(16)
        let commit = SecureLink.commitment(publicKey: realKey.publicKey.rawRepresentation, nonce: nonce)
        XCTAssertNotEqual(SecureLink.commitment(publicKey: attackerKey.publicKey.rawRepresentation, nonce: nonce), commit)
    }

    func testFormattedCode() {
        XCTAssertEqual(SecureLink.formattedCode("042913"), "042 913")
        XCTAssertEqual(SecureLink.formattedCode("12"), "12")
    }

    // MARK: - Session authentication

    func testAuthMACVerifiesOnlyForTheSameSession() {
        let key = SymmetricKey(size: .bits256)
        let mac = SecureLink.authMAC(key: key, bridgeID: "bridge", deviceID: "ipad", sessionNonce: "nonce-1")

        XCTAssertTrue(SecureLink.verifyAuthMAC(mac, key: key, bridgeID: "bridge", deviceID: "ipad", sessionNonce: "nonce-1"))
        // Replayed on a new connection (different nonce)
        XCTAssertFalse(SecureLink.verifyAuthMAC(mac, key: key, bridgeID: "bridge", deviceID: "ipad", sessionNonce: "nonce-2"))
        // Claimed by another device
        XCTAssertFalse(SecureLink.verifyAuthMAC(mac, key: key, bridgeID: "bridge", deviceID: "other", sessionNonce: "nonce-1"))
        // Wrong key
        XCTAssertFalse(SecureLink.verifyAuthMAC(mac, key: SymmetricKey(size: .bits256), bridgeID: "bridge", deviceID: "ipad", sessionNonce: "nonce-1"))
        // Garbage
        XCTAssertFalse(SecureLink.verifyAuthMAC("not base64!", key: key, bridgeID: "bridge", deviceID: "ipad", sessionNonce: "nonce-1"))
    }
}
