// USB tunnel to the iPad, with event-driven USB detection
import Foundation
import Network
import Darwin // For socket functions
import AppKit // For NSWorkspace notifications

/// Runs the USB tunnel to the iPad (127.0.0.1:8077 on the Mac → port 9360 on the iPad).
/// Since v1.2.4 the tunnel runs inside the Bridge (DirectUSBRelay below); the separate
/// `iproxy` helper program is no longer used. The class keeps its old name so the rest of
/// the app doesn't need to change.
final class IProxyManager: ObservableObject {
    @Published var isRunning = false
    @Published var status: String = "Idle"
    @Published var lastError: String?
    @Published var boundLocalPort: UInt16?
    @Published var persistedUDID: String? = nil

    private let localPort: UInt16 = 8077
    private let devicePort: UInt16 = 9360
    private var usbMuxdMonitor: USBMuxdMonitor?
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var directRelay: DirectUSBRelay?

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
        Logger.shared.log("🔧 IProxyManager: Starting USB tunnel...")
        stop()
        status = "Starting..."

        let relay = DirectUSBRelay(localPort: localPort, devicePort: devicePort)
        relay.preferredUDID = persistedUDID
        do {
            try relay.start()
        } catch {
            status = "Failed to start"
            lastError = error.localizedDescription
            Logger.shared.log("🔧 IProxyManager: ❌ USB tunnel failed to start: \(error.localizedDescription)")
            throw error
        }
        directRelay = relay
        isRunning = true
        lastError = nil
        status = "Running"
        boundLocalPort = localPort
        Logger.shared.log("🔧 IProxyManager: ✅ USB tunnel running")
    }

    func stop(manual: Bool = true) {
        directRelay?.stop()
        directRelay = nil
        isRunning = false
        status = "Stopped"
        boundLocalPort = nil
        Logger.shared.log("🔧 IProxyManager: Stopped USB tunnel")
    }

    // MARK: - USB Device Detection via libusbmuxd

    private func setupUSBMuxdMonitoring() {
        Logger.shared.log("🔧 IProxyManager: Setting up libusbmuxd device monitoring")

        let monitor = USBMuxdMonitor()

        // Handle device attached
        monitor.onDeviceAttached = { [weak self] in
            Logger.shared.log("🔧 IProxyManager: 🎯 iOS device attached! Starting automatic connection...")

            // CRITICAL FIX: Only start USB tunnel if it's not already running
            // This prevents killing a working USB tunnel process when multiple attach events fire
            guard let self = self, !self.isRunning else {
                Logger.shared.log("🔧 IProxyManager: USB tunnel already running - skipping auto-start")
                return
            }

            // Automatically start USB tunnel when iOS device is detected
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [weak self] in
                // Double-check isRunning after the delay
                guard let self = self, !self.isRunning else {
                    Logger.shared.log("🔧 IProxyManager: USB tunnel already running after delay - skipping auto-start")
                    return
                }

                do {
                    try self.start()
                } catch {
                    Logger.shared.log("🔧 IProxyManager: ❌ Failed to auto-start USB tunnel: \(error)")
                }
            }
        }

        // Handle device detached
        monitor.onDeviceDetached = { [weak self] in
            Logger.shared.log("🔧 IProxyManager: 📱 iOS device detached! Stopping USB tunnel...")

            // Stop USB tunnel when iOS device is disconnected
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
        Logger.shared.log("🔧 IProxyManager: 💤 System going to sleep - stopping USB tunnel")
        stop(manual: false)
    }

    private func handleSystemWake() {
        Logger.shared.log("🔧 IProxyManager: ⏰ System woke up - restarting USB tunnel after 2s delay")

        // Wait a moment for USB subsystem to be ready after wake
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) { [weak self] in
            do {
                try self?.start()
                Logger.shared.log("🔧 IProxyManager: ✅ USB tunnel restarted successfully after wake")

                // SLEEP/WAKE FIX: Notify MacConnectionManager to reset failure counter
                // This gives Bridge fresh reconnection attempts after Mac wakes
                NotificationCenter.default.post(name: .iproxyDidRestartAfterWake, object: nil)
            } catch {
                Logger.shared.log("🔧 IProxyManager: ❌ Failed to restart USB tunnel after wake: \(error)")
                // Retry after a longer delay if first attempt fails
                DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    do {
                        try self?.start()
                        Logger.shared.log("🔧 IProxyManager: ✅ USB tunnel restarted on retry after wake")

                        // Notify on successful retry as well
                        NotificationCenter.default.post(name: .iproxyDidRestartAfterWake, object: nil)
                    } catch {
                        Logger.shared.log("🔧 IProxyManager: ❌ Failed to restart USB tunnel on retry: \(error)")
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
// MARK: - Direct USB relay (v1.2.4)
//
// Does the job the bundled `iproxy` program used to do, inside the Bridge: listens on
// 127.0.0.1:<localPort> and, for each connection, opens a tunnel to <devicePort> on the
// iPad through Apple's USB service (usbmuxd), then copies bytes both ways.
// MacConnectionManager connects to 127.0.0.1:8077 exactly as before, so nothing else changes.

final class DirectUSBRelay {
    private let localPort: UInt16
    private let devicePort: UInt16
    private let lock = NSLock()
    private var listenFD: Int32 = -1
    private var running = false
    private var openFDs = Set<Int32>()

    /// When set, only this iPad is used; otherwise the first USB-connected device.
    var preferredUDID: String?

    init(localPort: UInt16, devicePort: UInt16) {
        self.localPort = localPort
        self.devicePort = devicePort
    }

    var isRunning: Bool {
        lock.lock(); defer { lock.unlock() }
        return running
    }

    func start() throws {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw Self.posixError("socket") }

        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = CFSwapInt16HostToBig(localPort)
        addr.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))   // local only, never the network

        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else {
            let error = Self.posixError("bind 127.0.0.1:\(localPort)")
            close(fd)
            throw error
        }
        guard listen(fd, 4) == 0 else {
            let error = Self.posixError("listen")
            close(fd)
            throw error
        }

        lock.lock()
        listenFD = fd
        running = true
        lock.unlock()

        let thread = Thread { [weak self] in self?.acceptLoop(fd) }
        thread.name = "CueBear.DirectUSB.accept"
        thread.qualityOfService = .userInteractive
        thread.start()
        Logger.shared.log("🔌 DirectUSB: listening on 127.0.0.1:\(localPort) → iPad port \(devicePort)")
    }

    func stop() {
        lock.lock()
        running = false
        let fds = openFDs
        openFDs.removeAll()
        let fd = listenFD
        listenFD = -1
        lock.unlock()

        // Waking blocked reads; the pump threads close their own sockets.
        for client in fds { shutdown(client, SHUT_RDWR) }
        if fd >= 0 { close(fd) }
        Logger.shared.log("🔌 DirectUSB: stopped")
    }

    // MARK: Accept

    private func acceptLoop(_ fd: Int32) {
        while isRunning {
            // poll() so stop() is noticed within 250 ms
            var pfd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let ready = poll(&pfd, 1, 250)
            if ready <= 0 { continue }

            let client = accept(fd, nil, nil)
            if client < 0 {
                if errno == EINTR || errno == EAGAIN { continue }
                break
            }
            var yes: Int32 = 1
            setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))
            setsockopt(client, IPPROTO_TCP, TCP_NODELAY, &yes, socklen_t(MemoryLayout<Int32>.size))

            let worker = Thread { [weak self] in self?.handle(client) }
            worker.name = "CueBear.DirectUSB.connect"
            worker.qualityOfService = .userInteractive
            worker.start()
        }
    }

    // MARK: Per-connection tunnel

    private func handle(_ client: Int32) {
        guard let deviceHandle = findDeviceHandle() else {
            Logger.shared.log("🔌 DirectUSB: no iPad on USB")
            close(client)
            return
        }

        let device = usbmuxd_connect(deviceHandle, devicePort)
        guard device >= 0 else {
            // Normal while Cue Bear isn't open on the iPad yet; the Bridge retries.
            Logger.shared.log("🔌 DirectUSB: iPad not accepting on port \(devicePort) yet (\(device))")
            close(client)
            return
        }
        var yes: Int32 = 1
        setsockopt(device, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))
        // libusbmuxd can hand back a non-blocking socket; the pump threads expect blocking I/O.
        Self.setBlocking(device)
        Self.setBlocking(client)

        lock.lock()
        guard running else {
            lock.unlock()
            close(client)
            close(device)
            return
        }
        openFDs.insert(client)
        openFDs.insert(device)
        lock.unlock()

        Logger.shared.log("🔌 DirectUSB: tunnel open")
        let pair = TunnelPair(a: client, b: device) { [weak self] in
            self?.lock.lock()
            self?.openFDs.remove(client)
            self?.openFDs.remove(device)
            self?.lock.unlock()
            Logger.shared.log("🔌 DirectUSB: tunnel closed")
        }
        pair.start()
    }

    private func findDeviceHandle() -> UInt32? {
        var list: UnsafeMutablePointer<usbmuxd_device_info_t>?
        let count = usbmuxd_get_device_list(&list)
        guard count > 0, let devices = list else {
            if list != nil { usbmuxd_device_list_free(&list) }
            return nil
        }
        defer { usbmuxd_device_list_free(&list) }

        var firstUSB: UInt32?
        for index in 0..<Int(count) {
            var info = devices[index]
            guard info.conn_type.rawValue == CONNECTION_TYPE_USB.rawValue else { continue }
            let udid = withUnsafeBytes(of: &info.udid) { raw -> String in
                String(cString: raw.bindMemory(to: CChar.self).baseAddress!)
            }
            if let wanted = preferredUDID, !wanted.isEmpty {
                if udid == wanted { return info.handle }
            } else if firstUSB == nil {
                firstUSB = info.handle
            }
        }
        return firstUSB
    }

    static func setBlocking(_ fd: Int32) {
        let flags = fcntl(fd, F_GETFL, 0)
        if flags >= 0 && (flags & O_NONBLOCK) != 0 {
            _ = fcntl(fd, F_SETFL, flags & ~O_NONBLOCK)
        }
    }

    private static func posixError(_ what: String) -> NSError {
        let code = errno
        return NSError(domain: NSPOSIXErrorDomain, code: Int(code),
                       userInfo: [NSLocalizedDescriptionKey: "DirectUSB \(what) failed: \(String(cString: strerror(code)))"])
    }
}

/// Copies bytes both ways between two sockets until either side closes.
private final class TunnelPair {
    /// Waits (up to 1 s) until the socket is ready; used if a socket is non-blocking.
    static func waitUntil(_ fd: Int32, events: Int16) {
        var pfd = pollfd(fd: fd, events: events, revents: 0)
        _ = poll(&pfd, 1, 1000)
    }

    private let a: Int32
    private let b: Int32
    private let lock = NSLock()
    private var finishedPumps = 0
    private let onClose: () -> Void

    init(a: Int32, b: Int32, onClose: @escaping () -> Void) {
        self.a = a
        self.b = b
        self.onClose = onClose
    }

    func start() {
        for (from, to) in [(a, b), (b, a)] {
            let thread = Thread { [self] in self.pump(from: from, to: to) }
            thread.name = "CueBear.DirectUSB.pump"
            thread.qualityOfService = .userInteractive
            thread.start()
        }
    }

    private func pump(from source: Int32, to destination: Int32) {
        var buffer = [UInt8](repeating: 0, count: 16 * 1024)
        var reason = "closed"
        outer: while true {
            let received = buffer.withUnsafeMutableBytes { recv(source, $0.baseAddress, $0.count, 0) }
            if received < 0 {
                let code = errno
                if code == EINTR { continue }
                if code == EAGAIN || code == EWOULDBLOCK {
                    Self.waitUntil(source, events: Int16(POLLIN))
                    continue
                }
                reason = "read error \(code)"
                break
            }
            if received == 0 { reason = source == a ? "Bridge side closed" : "iPad side closed"; break }

            var offset = 0
            while offset < received {
                let sent = buffer.withUnsafeBytes {
                    send(destination, $0.baseAddress! + offset, received - offset, 0)
                }
                if sent < 0 {
                    let code = errno
                    if code == EINTR { continue }
                    if code == EAGAIN || code == EWOULDBLOCK {
                        Self.waitUntil(destination, events: Int16(POLLOUT))
                        continue
                    }
                    reason = "write error \(code)"
                    break outer
                }
                offset += sent
            }
        }
        Logger.shared.log("🔌 DirectUSB: \(reason)")

        // Wake the other direction, then whoever finishes last closes both sockets.
        shutdown(a, SHUT_RDWR)
        shutdown(b, SHUT_RDWR)
        lock.lock()
        finishedPumps += 1
        let last = finishedPumps == 2
        lock.unlock()
        if last {
            close(a)
            close(b)
            onClose()
        }
    }
}
