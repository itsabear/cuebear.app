// Minimal IProxyManager - CPU optimized version with event-driven USB detection
import Foundation
import Network
import Darwin // For socket functions
import AppKit // For NSWorkspace notifications

final class IProxyManager: ObservableObject {
    @Published var isRunning = false
    @Published var status: String = "Idle"
    @Published var lastError: String?
    @Published var boundLocalPort: UInt16?
    @Published var persistedUDID: String? = nil

    // Fix Issue #13: Use NSLock to protect process state
    private let processLock = NSLock()
    private var process: Process?
    private let devicePort: UInt16 = 9360
    private var usbDeviceObserver: NSObjectProtocol?
    private var isMonitoringUSB = false

    init() {
        setupUSBDeviceMonitoring()
    }
    
    deinit {
        stopUSBDeviceMonitoring()
    }

    func start() throws {
        Logger.shared.log("🔧 IProxyManager: Starting minimal iproxy...")
        stop()
        
        status = "Starting..."
        
        // Check if iOS device is connected before starting iproxy
        let task = Process()
        task.launchPath = "/usr/bin/which"
        task.arguments = ["idevice_id"]
        task.launch()
        task.waitUntilExit()
        
        if task.terminationStatus == 0 {
            let deviceTask = Process()
            deviceTask.launchPath = "/opt/homebrew/bin/idevice_id" // Assuming Homebrew path
            deviceTask.arguments = ["-l"]
            deviceTask.launch()
            deviceTask.waitUntilExit()
            
            if deviceTask.terminationStatus != 0 {
                status = "No iOS device connected"
                Logger.shared.log("🔧 IProxyManager: ❌ No iOS device detected - connect iPad via USB cable")
                throw NSError(domain: "IProxyManager", code: 1003, userInfo: [NSLocalizedDescriptionKey: "No iOS device connected"])
            }
        }
        
        guard let iproxyPath = findBundledIproxy(), FileManager.default.isExecutableFile(atPath: iproxyPath) else {
            status = "Missing helper"
            Logger.shared.log("🔧 IProxyManager: ❌ iproxy helper not found")
            throw NSError(domain: "IProxyManager", code: 1002, userInfo: [NSLocalizedDescriptionKey: "iproxy helper not found"])
        }

        Logger.shared.log("🔧 IProxyManager: Found iproxy at: \(iproxyPath)")
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: iproxyPath)
        proc.arguments = ["8077", "\(devicePort)"]
        
        Logger.shared.log("🔧 IProxyManager: Starting iproxy with args: \(proc.arguments ?? [])")
        
        proc.terminationHandler = { [weak self] p in
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.status = "Stopped (code: \(p.terminationStatus))"
                Logger.shared.log("🔧 IProxyManager: iproxy stopped with code \(p.terminationStatus)")
            }
        }
        
        do {
            try proc.run()
            // Fix Issue #13: Protect process access with lock
            processLock.lock()
            process = proc
            processLock.unlock()
            isRunning = true
            status = "Running"
            boundLocalPort = 8077
            Logger.shared.log("🔧 IProxyManager: ✅ iproxy started successfully")

            // Add simple port binding check (non-aggressive)
            checkPortBinding()
        } catch {
            status = "Failed to start"
            Logger.shared.log("🔧 IProxyManager: ❌ Failed to start iproxy: \(error)")
            throw error
        }
    }
    
    private func checkPortBinding() {
        // Simple, non-aggressive port check
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
            let fd = socket(AF_INET, SOCK_STREAM, 0)
            if fd >= 0 {
                defer { close(fd) }
                var addr = sockaddr_in()
                addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                addr.sin_family = sa_family_t(AF_INET)
                addr.sin_port = CFSwapInt16HostToBig(8077)
                addr.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
                
                let res = withUnsafePointer(to: &addr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
                
                DispatchQueue.main.async {
                    if res == 0 {
                        Logger.shared.log("🔧 IProxyManager: ✅ Port 8077 is listening")
                    } else {
                        Logger.shared.log("🔧 IProxyManager: ⚠️ Port 8077 not listening (normal if no device)")
                    }
                }
            }
        }
    }

    func stop(manual: Bool = true) {
        // Kill any existing iproxy processes to prevent port conflicts
        let task = Process()
        task.launchPath = "/usr/bin/pkill"
        task.arguments = ["-f", "iproxy.*8077"]
        task.launch()
        task.waitUntilExit()

        // Fix Issue #13: Protect process access with lock
        processLock.lock()
        process?.terminate()
        process = nil
        processLock.unlock()
        isRunning = false
        status = manual ? "Stopped" : "Stopped"
        boundLocalPort = nil
        Logger.shared.log("🔧 IProxyManager: Stopped iproxy")
    }

    private func findBundledIproxy() -> String? {
        // Use system iproxy from libimobiledevice
        let systemIproxy = "/usr/local/bin/iproxy"
        let homebrewIproxy = "/opt/homebrew/bin/iproxy"
        
        if FileManager.default.fileExists(atPath: systemIproxy) {
            Logger.shared.log("🔧 IProxyManager: Using system iproxy at: \(systemIproxy)")
            return systemIproxy
        } else if FileManager.default.fileExists(atPath: homebrewIproxy) {
            Logger.shared.log("🔧 IProxyManager: Using Homebrew iproxy at: \(homebrewIproxy)")
            return homebrewIproxy
        } else {
            Logger.shared.log("🔧 IProxyManager: ❌ No system iproxy found")
            return nil
        }
    }
    
    // MARK: - Event-Driven USB Device Detection
    
    private func setupUSBDeviceMonitoring() {
        Logger.shared.log("🔧 IProxyManager: Setting up event-driven USB device monitoring")
        
        // Listen for USB device mount/unmount events
        usbDeviceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleUSBDeviceMounted(notification)
        }
        
        isMonitoringUSB = true
        Logger.shared.log("🔧 IProxyManager: ✅ USB device monitoring active")
    }
    
    private func stopUSBDeviceMonitoring() {
        if let observer = usbDeviceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            usbDeviceObserver = nil
        }
        isMonitoringUSB = false
        Logger.shared.log("🔧 IProxyManager: USB device monitoring stopped")
    }
    
    private func handleUSBDeviceMounted(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let devicePath = userInfo[NSWorkspace.volumeURLUserInfoKey] as? URL else {
            return
        }
        
        Logger.shared.log("🔧 IProxyManager: USB device mounted at: \(devicePath.path)")
        
        // Check if this is an iOS device by looking for common iOS device paths
        if isiOSDevicePath(devicePath.path) {
            Logger.shared.log("🔧 IProxyManager: 🎯 iOS device detected! Starting automatic connection...")
            
            // Automatically start iproxy when iOS device is detected
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [weak self] in
                do {
                    try self?.start()
                } catch {
                    Logger.shared.log("🔧 IProxyManager: ❌ Failed to auto-start iproxy: \(error)")
                }
            }
        }
    }
    
    private func isiOSDevicePath(_ path: String) -> Bool {
        // Check for common iOS device mount points
        let iosDevicePatterns = [
            "/Volumes/iPhone",
            "/Volumes/iPad", 
            "/Volumes/iPod",
            "/Volumes/Apple iPhone",
            "/Volumes/Apple iPad"
        ]
        
        return iosDevicePatterns.contains { pattern in
            path.hasPrefix(pattern)
        }
    }
}