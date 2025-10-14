import Foundation
import Network

/// Minimal TCP listener the Mac connects to via iproxy (usbmux).
final class USBTunnelServer {
    private let port: UInt16
    private var listener: NWListener?
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "CueBear.USBTunnelServer")
    private var statusHandler: ((Bool) -> Void)?

    init(port: UInt16) { self.port = port }

    func start(onStatus: @escaping (Bool) -> Void) {
        statusHandler = onStatus
        stop() // ensure clean start
        do {
            let params = NWParameters.tcp
            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                debugPrint("USBTunnelServer: Invalid port number: \(port)")
                updateStatus(false)
                return
            }
            let listener = try NWListener(using: params, on: nwPort)
            self.listener = listener

            listener.newConnectionHandler = { [weak self] conn in
                self?.accept(conn)
            }
            listener.stateUpdateHandler = { [weak self] state in
                if case .failed = state { self?.updateStatus(false) }
            }
            listener.start(queue: queue)
        } catch {
            updateStatus(false)
        }
    }

    private func accept(_ conn: NWConnection) {
        connection?.cancel()
        connection = conn
        conn.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                // Don't set status to true yet - wait for handshake to complete
                debugPrint("🔌 USBTunnelServer: Connection ready, waiting for handshake...")
                self?.receive(from: conn)
            case .failed, .cancelled:
                self?.updateStatus(false)
            default:
                break
            }
        }
        conn.start(queue: queue)
    }

    private func receive(from conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, err in
            if isComplete || err != nil {
                debugPrint("🔌 USBTunnelServer: Connection closed")
                self?.updateStatus(false)
                return
            }

            // Handle incoming data (CB/2 handshake and messages)
            if let data = data, !data.isEmpty {
                self?.handleIncomingData(data, from: conn)
            }

            self?.receive(from: conn)
        }
    }

    private func handleIncomingData(_ data: Data, from conn: NWConnection) {
        guard let message = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return
        }

        // Handle CB/2 protocol handshake
        if message.hasPrefix("CB/") {
            debugPrint("🔌 USBTunnelServer: Received handshake: \(message)")

            // Parse protocol version (CB/2 auth=psk1 name=MacName)
            let parts = message.dropFirst(3).components(separatedBy: " ")
            guard let versionPart = parts.first,
                  let version = Int(versionPart) else {
                debugPrint("🔌 USBTunnelServer: Failed to parse protocol version")
                return
            }

            // Extract computer name if present
            var computerName = "Bridge"
            for part in parts.dropFirst() {
                if part.hasPrefix("name=") {
                    computerName = String(part.dropFirst(5))
                }
            }

            debugPrint("🔌 USBTunnelServer: Handshake from '\(computerName)' using CB/\(version)")

            // Send CB/2 response (OK/2 hmac=)
            let response = "OK/\(version) hmac=\n"
            guard let responseData = response.data(using: .utf8) else {
                debugPrint("🔌 USBTunnelServer: Failed to encode response")
                return
            }

            conn.send(content: responseData, completion: .contentProcessed { [weak self] error in
                if let error = error {
                    debugPrint("🔌 USBTunnelServer: ❌ Failed to send handshake response: \(error)")
                    self?.updateStatus(false)
                } else {
                    debugPrint("🔌 USBTunnelServer: ✅ Handshake complete - connection established to \(computerName)")
                    self?.updateStatus(true)
                }
            })
        }
        // Future: Handle other message types here if needed
    }

    private func updateStatus(_ connected: Bool) {
        if Thread.isMainThread {
            statusHandler?(connected)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.statusHandler?(connected)
            }
        }
    }

    func sendLine(data: Data) {
        guard let conn = connection else { return }
        var payload = data
        payload.append(0x0A) // newline-delimited JSON
        conn.send(content: payload, completion: .contentProcessed { _ in })
    }

    func stop() {
        connection?.cancel(); connection = nil
        listener?.cancel(); listener = nil
        updateStatus(false)
    }
}
