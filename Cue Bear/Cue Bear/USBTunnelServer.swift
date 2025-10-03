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
                self?.updateStatus(true)
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
        conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] _, _, isComplete, err in
            if isComplete || err != nil { self?.updateStatus(false); return }
            self?.receive(from: conn)
        }
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
