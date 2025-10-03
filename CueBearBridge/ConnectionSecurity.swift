import Foundation
import Network
import CryptoKit

/// Phase 1 Security Manager for Cue Bear Bridge
/// Provides essential security measures without breaking existing functionality
/// - Connection rate limiting
/// - Message rate limiting
/// - Input validation and sanitization
/// - Device fingerprinting
final class ConnectionSecurity {
    static let shared = ConnectionSecurity()

    // Fix Issue #14: Use serial queue for thread-safe access to shared state
    private let stateQueue = DispatchQueue(label: "com.cuebear.security.state", qos: .userInitiated)

    // MARK: - Connection Rate Limiting
    private var connectionAttempts: [String: [Date]] = [:]
    private let maxAttemptsPerMinute = 20  // Increased for connection loops
    private let rateLimitWindow: TimeInterval = 60.0 // 1 minute

    // MARK: - Message Rate Limiting
    private var messageCounts: [String: Int] = [:]
    private var lastResetTime: [String: Date] = [:]
    private let maxMessagesPerSecond = 100
    private let messageRateWindow: TimeInterval = 1.0 // 1 second

    // MARK: - Device Tracking
    private var knownDevices: Set<String> = []
    private let maxKnownDevices = 10

    private init() {
        Logger.shared.log("🔒 ConnectionSecurity: Initialized with Phase 1 security measures")
    }
    
    // MARK: - Connection Validation
    
    /// Validates if a connection attempt should be allowed
    /// - Parameter endpoint: The network endpoint attempting to connect
    /// - Returns: true if connection should be allowed, false if rate limited
    func validateConnection(from endpoint: NWEndpoint) -> Bool {
        return stateQueue.sync {
            let deviceId = generateDeviceId(from: endpoint)
            let now = Date()

            // Get existing attempts for this device
            let attempts = connectionAttempts[deviceId] ?? []

            // Filter attempts within the rate limit window
            let recentAttempts = attempts.filter { now.timeIntervalSince($0) < rateLimitWindow }

            // Check if rate limit exceeded
            if recentAttempts.count >= maxAttemptsPerMinute {
                Logger.shared.log("🔒 ConnectionSecurity: Rate limit exceeded for device: \(deviceId)")
                return false
            }

            // Update attempts
            connectionAttempts[deviceId] = recentAttempts + [now]

            // Track known devices
            if knownDevices.count < maxKnownDevices {
                knownDevices.insert(deviceId)
            }

            Logger.shared.log("🔒 ConnectionSecurity: Connection allowed for device: \(deviceId)")
            return true
        }
    }
    
    /// Clears rate limiting for a specific device (useful for manual reconnection)
    func clearRateLimit(for endpoint: NWEndpoint) {
        stateQueue.sync {
            let deviceId = generateDeviceId(from: endpoint)
            connectionAttempts.removeValue(forKey: deviceId)
            Logger.shared.log("🔒 ConnectionSecurity: Rate limit cleared for device: \(deviceId)")
        }
    }
    
    // MARK: - Message Rate Limiting
    
    /// Validates if a message should be allowed based on rate limiting
    /// - Parameter deviceId: The device sending the message
    /// - Returns: true if message should be allowed, false if rate limited
    func validateMessageRate(for deviceId: String) -> Bool {
        return stateQueue.sync {
            let now = Date()

            // Check if we need to reset the counter for this device
            if let lastReset = lastResetTime[deviceId] {
                if now.timeIntervalSince(lastReset) >= messageRateWindow {
                    // Reset counter
                    messageCounts[deviceId] = 0
                    lastResetTime[deviceId] = now
                }
            } else {
                // First message from this device
                lastResetTime[deviceId] = now
                messageCounts[deviceId] = 0
            }

            // Check current count
            let currentCount = messageCounts[deviceId] ?? 0
            if currentCount >= maxMessagesPerSecond {
                Logger.shared.log("🔒 ConnectionSecurity: Message rate limit exceeded for device: \(deviceId)")
                return false
            }

            // Increment counter
            messageCounts[deviceId] = currentCount + 1

            return true
        }
    }
    
    // MARK: - Input Validation and Sanitization
    
    /// Validates and sanitizes MIDI messages
    /// - Parameter json: The JSON message to validate
    /// - Returns: Sanitized JSON if valid, nil if invalid
    func validateAndSanitizeMIDIMessage(_ json: [String: Any]) -> [String: Any]? {
        guard let type = json["type"] as? String else {
            Logger.shared.log("🔒 ConnectionSecurity: Invalid message - missing type")
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
        case "handshake", "handshake_response":
            return validateHandshake(json)
        default:
            Logger.shared.log("🔒 ConnectionSecurity: Unknown message type: \(type)")
            return nil
        }
    }
    
    private func validateMIDICC(_ json: [String: Any]) -> [String: Any]? {
        guard let channel = json["channel"] as? Int, (1...16).contains(channel),
              let cc = json["cc"] as? Int, (0...127).contains(cc),
              let value = json["value"] as? Int, (0...127).contains(value) else {
            Logger.shared.log("🔒 ConnectionSecurity: Invalid MIDI CC message")
            return nil
        }
        
        // Return sanitized message
        return [
            "type": "midi_cc",
            "channel": channel,
            "cc": cc,
            "value": value
        ]
    }
    
    private func validateMIDINote(_ json: [String: Any]) -> [String: Any]? {
        guard let channel = json["channel"] as? Int, (1...16).contains(channel),
              let note = json["note"] as? Int, (0...127).contains(note),
              let velocity = json["velocity"] as? Int, (0...127).contains(velocity) else {
            Logger.shared.log("🔒 ConnectionSecurity: Invalid MIDI Note message")
            return nil
        }
        
        // Return sanitized message
        return [
            "type": "midi_note",
            "channel": channel,
            "note": note,
            "velocity": velocity
        ]
    }
    
    private func validateMIDIInput(_ json: [String: Any]) -> [String: Any]? {
        guard let midi = json["midi"] as? [Int], midi.count >= 3 else {
            Logger.shared.log("🔒 ConnectionSecurity: Invalid MIDI input - missing or invalid midi array")
            return nil
        }
        
        // Validate MIDI message format: [status, data1, data2, ...]
        let status = midi[0]
        let data1 = midi[1]
        let data2 = midi[2]
        
        // Validate status byte (should be 176-191 for CC messages)
        guard (176...191).contains(status) else {
            Logger.shared.log("🔒 ConnectionSecurity: Invalid MIDI status byte: \(status)")
            return nil
        }
        
        // Validate data bytes (0-127)
        guard (0...127).contains(data1) && (0...127).contains(data2) else {
            Logger.shared.log("🔒 ConnectionSecurity: Invalid MIDI data bytes: \(data1), \(data2)")
            return nil
        }
        
        // Return sanitized message
        return [
            "type": "midi_input",
            "midi": midi
        ]
    }
    
    private func validateBatchMessage(_ json: [String: Any]) -> [String: Any]? {
        guard let messages = json["messages"] as? [String] else {
            Logger.shared.log("🔒 ConnectionSecurity: Invalid batch message - missing messages array")
            return nil
        }
        
        // Limit batch size to prevent abuse
        if messages.count > 50 {
            Logger.shared.log("🔒 ConnectionSecurity: Batch message too large: \(messages.count) messages")
            return nil
        }
        
        // Validate each message in the batch
        var validMessages: [String] = []
        for messageString in messages {
            guard let messageData = messageString.data(using: .utf8),
                  let messageJson = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any],
                  let sanitized = validateAndSanitizeMIDIMessage(messageJson),
                  let sanitizedData = try? JSONSerialization.data(withJSONObject: sanitized),
                  let sanitizedString = String(data: sanitizedData, encoding: .utf8) else {
                Logger.shared.log("🔒 ConnectionSecurity: Invalid message in batch, skipping")
                continue
            }
            validMessages.append(sanitizedString)
        }
        
        return [
            "type": "batch",
            "messages": validMessages
        ]
    }
    
    private func validateHandshake(_ json: [String: Any]) -> [String: Any]? {
        // Basic handshake validation - just check that type field exists
        guard json["type"] is String else {
            return nil
        }
        
        // Allow handshake messages through with minimal validation
        return json
    }
    
    // MARK: - Device Management
    
    private func generateDeviceId(from endpoint: NWEndpoint) -> String {
        let endpointString = "\(endpoint)"
        let data = endpointString.data(using: .utf8) ?? Data()
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Removes old connection attempts to prevent memory leaks
    func cleanupOldData() {
        stateQueue.sync {
            let now = Date()

            // Clean up old connection attempts
            for (deviceId, attempts) in connectionAttempts {
                let recentAttempts = attempts.filter { now.timeIntervalSince($0) < rateLimitWindow * 2 }
                if recentAttempts.isEmpty {
                    connectionAttempts.removeValue(forKey: deviceId)
                } else {
                    connectionAttempts[deviceId] = recentAttempts
                }
            }

            // Clean up old message counters
            for (deviceId, lastReset) in lastResetTime {
                if now.timeIntervalSince(lastReset) > messageRateWindow * 2 {
                    messageCounts.removeValue(forKey: deviceId)
                    lastResetTime.removeValue(forKey: deviceId)
                }
            }
        }
    }
    
    // MARK: - Security Statistics
    
    func getSecurityStats() -> [String: Any] {
        return stateQueue.sync {
            return [
                "knownDevices": knownDevices.count,
                "activeConnections": connectionAttempts.count,
                "activeMessageCounters": messageCounts.count
            ]
        }
    }
}
