// Minimal IProxyManager - CPU optimized version
import Foundation

final class IProxyManager: ObservableObject {
    @Published var isRunning = false
    @Published var status: String = "Idle"
    @Published var lastError: String?
    @Published var boundLocalPort: UInt16?
    @Published var persistedUDID: String? = nil

    private var process: Process?
    private let devicePort: UInt16 = 9360

    func start() throws {
        Logger.shared.log("🔧 IProxyManager: Starting minimal iproxy...")
        stop()
        
        status = "Starting..."
        
        guard let iproxyPath = findBundledIproxy(), FileManager.default.isExecutableFile(atPath: iproxyPath) else {
            status = "Missing helper"
            throw NSError(domain: "IProxyManager", code: 1002, userInfo: [NSLocalizedDescriptionKey: "iproxy helper not found"])
        }
        
        Logger.shared.log("🔧 IProxyManager: Found iproxy at: \(iproxyPath)")
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: iproxyPath)
        proc.arguments = ["8077", "\(devicePort)"]
        
        proc.terminationHandler = { [weak self] p in
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.status = "Stopped (code: \(p.terminationStatus))"
                Logger.shared.log("🔧 IProxyManager: iproxy stopped with code \(p.terminationStatus)")
            }
        }
        
        do {
            try proc.run()
            process = proc
            isRunning = true
            status = "Running"
            boundLocalPort = 8077
            Logger.shared.log("🔧 IProxyManager: ✅ iproxy started successfully")
        } catch {
            status = "Failed to start"
            throw error
        }
    }

    func stop(manual: Bool = true) {
        process?.terminate()
        process = nil
        isRunning = false
        status = manual ? "Stopped" : "Stopped"
        boundLocalPort = nil
    }
    
    private func findBundledIproxy() -> String? {
        let bundle = Bundle.main
        let iproxyPath = bundle.path(forResource: "iproxy", ofType: nil, inDirectory: "Contents/MacOS")
        return iproxyPath
    }
}
