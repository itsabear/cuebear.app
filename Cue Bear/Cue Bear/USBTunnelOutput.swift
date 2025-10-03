// USBTunnelOutput.swift — iPad USB sender (server-backed tcp tunnel)

import Foundation
import Network

final class USBTunnelOutput: ObservableObject {
    @Published var isReady: Bool = false

    private var server: USBTunnelServer?

    // Call start() when app launches; run a local listener that the Mac connects to via usbmux/iproxy
    func start(host: String = "127.0.0.1", port: UInt16 = 9360) {
        // Host is ignored in server mode
        stop()
        let server = USBTunnelServer(port: port)
        self.server = server
        server.start { [weak self] connected in
            self?.isReady = connected
        }
    }

    func stop() {
        server?.stop(); server = nil
        DispatchQueue.main.async { [weak self] in
            self?.isReady = false
        }
    }

    // MARK: - Send helpers

    func sendCC(channel: Int, cc: Int, value: Int, label: String, buttonID: String) {
        let payload: [String: Any] = [
            "type": "midi_cc",
            "channel": channel,
            "cc": cc,
            "value": value,
            "label": label,
            "button_id": buttonID,
            "timestamp": Date().timeIntervalSince1970
        ]
        sendJSON(payload)
    }

    func sendNote(channel: Int, note: Int, velocity: Int, label: String, buttonID: String) {
        let payload: [String: Any] = [
            "type": "midi_note",
            "channel": channel,
            "note": note,
            "velocity": velocity,
            "label": label,
            "button_id": buttonID,
            "timestamp": Date().timeIntervalSince1970
        ]
        sendJSON(payload)
    }

    // MARK: - Low level

    private func sendJSON(_ obj: [String: Any]) {
        guard let server = server, isReady else { return }
        guard let data = try? JSONSerialization.data(withJSONObject: obj) else { return }
        // newline framing is added by the server
        server.sendLine(data: data)
    }
}
public protocol EquatableBytes: Equatable {
    
}