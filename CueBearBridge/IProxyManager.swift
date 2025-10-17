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
    private var usbMuxdMonitor: USBMuxdMonitor?
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var consecutiveRestartFailures = 0
    private let maxConsecutiveRestarts = 3

    init() {
        setupUSBMuxdMonitoring()
        setupSleepWakeMonitoring()
    }

    deinit {
        stop(manual: false)
        stopUSBMuxdMonitoring()
        stopSleepWakeMonitoring()
    }

    func start() throws {
        Logger.shared.log("🔧 IProxyManager: Starting minimal iproxy...")
        stop()

        status = "Starting..."

        // Let bundled iproxy handle device detection - it will fail gracefully if no device is connected
        // The bundled iproxy doesn't need external tools like idevice_id to detect iOS devices
        // Removing this check fixes auto-start issues when idevice_id is not installed

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
                guard let self = self else { return }
                self.isRunning = false
                let exitCode = p.terminationStatus
                self.status = "Stopped (code: \(exitCode))"
                Logger.shared.log("🔧 IProxyManager: iproxy stopped with code \(exitCode)")

                // Auto-restart iproxy if it crashed unexpectedly (non-zero exit code)
                // Don't restart if:
                // - Manually stopped (exit code 15 = SIGTERM)
                // - No device connected (exit code 9 = SIGKILL from immediate failure)
                // - Already hit max consecutive restart attempts
                if exitCode != 0 && exitCode != 15 && exitCode != 9 {
                    if self.consecutiveRestartFailures >= self.maxConsecutiveRestarts {
                        Logger.shared.log("🔧 IProxyManager: ❌ Max restart attempts (\(self.maxConsecutiveRestarts)) reached - stopping auto-restart")
                        self.consecutiveRestartFailures = 0
                        return
                    }

                    self.consecutiveRestartFailures += 1
                    let delay: TimeInterval = Double(self.consecutiveRestartFailures) * 2.0 // Exponential backoff: 2s, 4s, 6s
                    Logger.shared.log("🔧 IProxyManager: ⚠️ iproxy crashed unexpectedly - auto-restarting in \(Int(delay))s (attempt \(self.consecutiveRestartFailures)/\(self.maxConsecutiveRestarts))...")

                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                        do {
                            try self?.start()
                            Logger.shared.log("🔧 IProxyManager: ✅ iproxy auto-restarted successfully after crash")
                        } catch {
                            Logger.shared.log("🔧 IProxyManager: ❌ Failed to auto-restart iproxy: \(error)")
                        }
                    }
                } else if exitCode == 9 {
                    Logger.shared.log("🔧 IProxyManager: ℹ️ iproxy stopped (exit code 9) - likely no device connected. Not auto-restarting.")
                    self.consecutiveRestartFailures = 0
                }
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
            consecutiveRestartFailures = 0 // Reset failure counter on successful start
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
        // Priority 1: Check for bundled iproxy in app bundle (self-contained distribution)
        if let bundlePath = Bundle.main.executablePath {
            let appBundlePath = (bundlePath as NSString).deletingLastPathComponent
            let bundledIproxy = (appBundlePath as NSString).appendingPathComponent("iproxy")

            if FileManager.default.fileExists(atPath: bundledIproxy) {
                Logger.shared.log("🔧 IProxyManager: Using bundled iproxy at: \(bundledIproxy)")
                return bundledIproxy
            }
        }

        // Priority 2: Check system paths (fallback for development)
        let systemIproxy = "/usr/local/bin/iproxy"
        let homebrewIproxy = "/opt/homebrew/bin/iproxy"

        if FileManager.default.fileExists(atPath: systemIproxy) {
            Logger.shared.log("🔧 IProxyManager: Using system iproxy at: \(systemIproxy)")
            return systemIproxy
        } else if FileManager.default.fileExists(atPath: homebrewIproxy) {
            Logger.shared.log("🔧 IProxyManager: Using Homebrew iproxy at: \(homebrewIproxy)")
            return homebrewIproxy
        } else {
            Logger.shared.log("🔧 IProxyManager: ❌ No iproxy found (checked bundled, system, and Homebrew paths)")
            return nil
        }
    }
    
    // MARK: - USB Device Detection via libusbmuxd

    private func setupUSBMuxdMonitoring() {
        Logger.shared.log("🔧 IProxyManager: Setting up libusbmuxd device monitoring")

        let monitor = USBMuxdMonitor()

        // Handle device attached
        monitor.onDeviceAttached = { [weak self] in
            Logger.shared.log("🔧 IProxyManager: 🎯 iOS device attached! Starting automatic connection...")

            // Automatically start iproxy when iOS device is detected
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [weak self] in
                do {
                    try self?.start()
                } catch {
                    Logger.shared.log("🔧 IProxyManager: ❌ Failed to auto-start iproxy: \(error)")
                }
            }
        }

        // Handle device detached
        monitor.onDeviceDetached = { [weak self] in
            Logger.shared.log("🔧 IProxyManager: 📱 iOS device detached! Stopping iproxy...")

            // Stop iproxy when iOS device is disconnected
            self?.stop(manual: false)

            // Notify connection manager about disconnect
            NotificationCenter.default.post(name: .iosDeviceDisconnected, object: nil)
        }

        self.usbMuxdMonitor = monitor
        monitor.start()

        Logger.shared.log("🔧 IProxyManager: ✅ libusbmuxd device monitoring active")
    }

    private func stopUSBMuxdMonitoring() {
        usbMuxdMonitor?.stop()
        usbMuxdMonitor = nil
        Logger.shared.log("🔧 IProxyManager: libusbmuxd monitoring stopped")
    }

    // MARK: - Sleep/Wake Monitoring for Auto-Restart

    private func setupSleepWakeMonitoring() {
        Logger.shared.log("🔧 IProxyManager: Setting up sleep/wake monitoring for auto-restart")

        // Listen for system sleep notification
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSystemSleep()
        }

        // Listen for system wake notification
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSystemWake()
        }

        Logger.shared.log("🔧 IProxyManager: ✅ Sleep/wake monitoring active")
    }

    private func stopSleepWakeMonitoring() {
        if let observer = sleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            sleepObserver = nil
        }
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            wakeObserver = nil
        }
        Logger.shared.log("🔧 IProxyManager: Sleep/wake monitoring stopped")
    }

    private func handleSystemSleep() {
        Logger.shared.log("🔧 IProxyManager: 💤 System going to sleep - stopping iproxy")
        stop(manual: false)
    }

    private func handleSystemWake() {
        Logger.shared.log("🔧 IProxyManager: ⏰ System woke up - restarting iproxy after 2s delay")

        // Wait a moment for USB subsystem to be ready after wake
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) { [weak self] in
            do {
                try self?.start()
                Logger.shared.log("🔧 IProxyManager: ✅ iproxy restarted successfully after wake")

                // SLEEP/WAKE FIX: Notify MacConnectionManager to reset failure counter
                // This gives Bridge fresh reconnection attempts after Mac wakes
                NotificationCenter.default.post(name: .iproxyDidRestartAfterWake, object: nil)
            } catch {
                Logger.shared.log("🔧 IProxyManager: ❌ Failed to restart iproxy after wake: \(error)")
                // Retry after a longer delay if first attempt fails
                DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    do {
                        try self?.start()
                        Logger.shared.log("🔧 IProxyManager: ✅ iproxy restarted on retry after wake")

                        // Notify on successful retry as well
                        NotificationCenter.default.post(name: .iproxyDidRestartAfterWake, object: nil)
                    } catch {
                        Logger.shared.log("🔧 IProxyManager: ❌ Failed to restart iproxy on retry: \(error)")
                    }
                }
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let iosDeviceDisconnected = Notification.Name("iosDeviceDisconnected")
    static let iproxyDidRestartAfterWake = Notification.Name("iproxyDidRestartAfterWake")
}