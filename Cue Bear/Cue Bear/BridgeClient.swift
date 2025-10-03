import Foundation
import Network
import Combine

struct DiscoveredBridge: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let endpoint: NWEndpoint
}

final class BridgeClient: ObservableObject {
    enum Status: CustomStringConvertible {
        case disconnected
        case connecting(String)
        case connected(String)

        var description: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .connecting(let s): return "Connecting to \(s)…"
            case .connected(let s): return "Connected: \(s)"
            }
        }
    }

    @Published var status: Status = .disconnected
    @Published var discovered: [DiscoveredBridge] = []

    private var connection: NWConnection?
    private var browser: NWBrowser?

    // MARK: - Bonjour discovery (_cuebear._tcp)
    func startBrowsing() {
        let params = NWParameters.tcp
        let browser = NWBrowser(for: .bonjour(type: "_cuebear._tcp", domain: nil), using: params)
        self.browser = browser

        browser.stateUpdateHandler = { _ in }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let items = results.map { result -> DiscoveredBridge in
                switch result.endpoint {
                case let .service(name: name, type: _, domain: _, interface: _):
                    return DiscoveredBridge(name: name, endpoint: result.endpoint)
                default:
                    return DiscoveredBridge(name: "Bridge", endpoint: result.endpoint)
                }
            }
            DispatchQueue.main.async { [weak self] in
                self?.discovered = items
            }
        }
        browser.start(queue: .main)
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        discovered = []
    }

    // MARK: - Connect / Send
    func connect(to endpoint: NWEndpoint, label: String) {
        disconnect()
        status = .connecting(label)
        let conn = NWConnection(to: endpoint, using: .tcp)
        connection = conn
        conn.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async { [weak self] in
                switch state {
                case .ready:
                    self?.status = .connected(label)
                case .failed, .cancelled:
                    self?.status = .disconnected
                case .waiting(let err):
                    self?.status = .connecting("Waiting: \(err.localizedDescription)")
                default: break
                }
            }
        }
        conn.start(queue: .main)
    }

    func connect(host: String, port: UInt16) {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }
        let endpoint = NWEndpoint.hostPort(host: .name(host, nil), port: nwPort)
        connect(to: endpoint, label: "\(host):\(port)")
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        status = .disconnected
    }

    func sendJSON<T: Encodable>(_ object: T) {
        guard case .connected = status, let conn = connection else { return }
        do {
            let data = try JSONEncoder().encode(object)
            var payload = data
            payload.append(0x0A) // newline framing
            conn.send(content: payload, completion: .contentProcessed { _ in })
        } catch {
            // Silently ignore for starter
        }
    }
}

