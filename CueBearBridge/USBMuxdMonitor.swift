//
//  USBMuxdMonitor.swift
//  CueBearBridge
//
//  Monitors iOS device attach/detach events using libusbmuxd
//

import Foundation

class USBMuxdMonitor {
    private var context: usbmuxd_subscription_context_t?
    private var isMonitoring = false
    private let queue = DispatchQueue(label: "com.cuebear.usbmuxd", qos: .userInitiated)

    // Store callback as static to keep it alive
    private static let callback: @convention(c) (UnsafePointer<usbmuxd_event_t>?, UnsafeMutableRawPointer?) -> Void = { eventPtr, userData in
        guard let eventPtr = eventPtr,
              let userData = userData else { return }

        let monitor = Unmanaged<USBMuxdMonitor>.fromOpaque(userData).takeUnretainedValue()
        let event = eventPtr.pointee

        switch Int32(event.event) {
        case Int32(UE_DEVICE_ADD.rawValue):
            let udid = withUnsafeBytes(of: event.device.udid) { bytes -> String in
                let buffer = bytes.bindMemory(to: CChar.self)
                return String(cString: buffer.baseAddress!)
            }
            Logger.shared.log("📱 USBMuxdMonitor: iOS device attached (UDID: \(udid))")
            DispatchQueue.main.async {
                monitor.onDeviceAttached?()
            }

        case Int32(UE_DEVICE_REMOVE.rawValue):
            let udid = withUnsafeBytes(of: event.device.udid) { bytes -> String in
                let buffer = bytes.bindMemory(to: CChar.self)
                return String(cString: buffer.baseAddress!)
            }
            Logger.shared.log("📱 USBMuxdMonitor: iOS device detached (UDID: \(udid))")
            DispatchQueue.main.async {
                monitor.onDeviceDetached?()
            }

        case Int32(UE_DEVICE_PAIRED.rawValue):
            let udid = withUnsafeBytes(of: event.device.udid) { bytes -> String in
                let buffer = bytes.bindMemory(to: CChar.self)
                return String(cString: buffer.baseAddress!)
            }
            Logger.shared.log("📱 USBMuxdMonitor: iOS device paired (UDID: \(udid))")

        default:
            Logger.shared.log("⚠️ USBMuxdMonitor: Unknown event type: \(event.event)")
        }
    }

    var onDeviceAttached: (() -> Void)?
    var onDeviceDetached: (() -> Void)?

    deinit {
        stop()
    }

    func start() {
        guard !isMonitoring else {
            Logger.shared.log("⚠️ USBMuxdMonitor: Already monitoring")
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let strongSelf = self else { return }

            var ctx: usbmuxd_subscription_context_t?

            // Subscribe to device events using static callback
            let selfPtr = Unmanaged.passUnretained(strongSelf).toOpaque()
            let result = usbmuxd_events_subscribe(&ctx, USBMuxdMonitor.callback, selfPtr)

            if result == 0 {
                strongSelf.context = ctx
                strongSelf.isMonitoring = true
                Logger.shared.log("✅ USBMuxdMonitor: Started monitoring iOS devices")
            } else {
                Logger.shared.log("❌ USBMuxdMonitor: Failed to subscribe to events (error: \(result))")
            }
        }

        queue.async(execute: workItem)
    }

    func stop() {
        guard isMonitoring else { return }

        queue.sync {
            if let ctx = self.context {
                usbmuxd_events_unsubscribe(ctx)
                self.context = nil
                self.isMonitoring = false
                Logger.shared.log("🛑 USBMuxdMonitor: Stopped monitoring")
            }
        }
    }
}
