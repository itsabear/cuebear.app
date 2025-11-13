//
//  CrashReporter.swift
//  Cue Bear
//
//  Crash detection and reporting utility
//

import Foundation
import UIKit

/// Utility for detecting crashes and collecting diagnostic information
class CrashReporter {
    static let shared = CrashReporter()

    private let crashDetectedKey = "CueBear_CrashDetected"
    private let lastCrashLogKey = "CueBear_LastCrashLog"
    private let appVersionKey = "CueBear_LastAppVersion"

    private init() {}

    /// Call this when app launches successfully to clear crash flag
    func markAppLaunched() {
        // Clear the crash flag since we launched successfully
        UserDefaults.standard.set(false, forKey: crashDetectedKey)

        // Store current app version
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            UserDefaults.standard.set("\(version) (\(build))", forKey: appVersionKey)
        }
    }

    /// Call this at the very start of app launch to detect if previous session crashed
    func checkForCrash() -> Bool {
        return UserDefaults.standard.bool(forKey: crashDetectedKey)
    }

    /// Mark that a crash occurred (call this in crash handlers)
    func markCrashOccurred() {
        UserDefaults.standard.set(true, forKey: crashDetectedKey)

        // Capture crash log information
        let crashInfo = collectDiagnosticInfo()
        UserDefaults.standard.set(crashInfo, forKey: lastCrashLogKey)
    }

    /// Get the last crash log (if available)
    func getLastCrashLog() -> String? {
        return UserDefaults.standard.string(forKey: lastCrashLogKey)
    }

    /// Clear stored crash information
    func clearCrashLog() {
        UserDefaults.standard.removeObject(forKey: lastCrashLogKey)
        UserDefaults.standard.set(false, forKey: crashDetectedKey)
    }

    /// Collect diagnostic information for bug reports
    func collectDiagnosticInfo() -> String {
        var info = "Cue Bear Bug Report\n"
        info += "==================\n\n"

        // App version
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            info += "App Version: \(version) (\(build))\n"
        }

        // Device info
        let device = UIDevice.current
        info += "Device: \(device.model)\n"
        info += "iOS Version: \(device.systemVersion)\n"
        info += "Device Name: \(device.name)\n"

        // System info
        let processInfo = ProcessInfo.processInfo
        info += "OS Version: \(processInfo.operatingSystemVersionString)\n"
        info += "Physical Memory: \(ByteCountFormatter.string(fromByteCount: Int64(processInfo.physicalMemory), countStyle: .memory))\n"

        // Memory usage
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let usedMemory = taskInfo.resident_size
            info += "App Memory Usage: \(ByteCountFormatter.string(fromByteCount: Int64(usedMemory), countStyle: .memory))\n"
        }

        // Date/time
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        info += "Report Date: \(formatter.string(from: Date()))\n"

        info += "\n"

        return info
    }

    /// Generate email body for bug report
    func generateBugReportEmail(userComments: String) -> String {
        var email = collectDiagnosticInfo()

        if !userComments.isEmpty {
            email += "User Comments:\n"
            email += "==============\n"
            email += userComments
            email += "\n\n"
        }

        // Include crash log if available
        if let crashLog = getLastCrashLog() {
            email += "Previous Crash Information:\n"
            email += "===========================\n"
            email += crashLog
            email += "\n"
        }

        return email
    }
}

// MARK: - Crash Handler Setup
extension CrashReporter {
    /// Setup crash detection handlers
    func setupCrashHandlers() {
        // NSException handler
        NSSetUncaughtExceptionHandler { exception in
            var crashLog = "Uncaught Exception:\n"
            crashLog += "Name: \(exception.name.rawValue)\n"
            crashLog += "Reason: \(exception.reason ?? "Unknown")\n"
            crashLog += "Call Stack:\n"
            crashLog += exception.callStackSymbols.joined(separator: "\n")

            UserDefaults.standard.set(crashLog, forKey: "CueBear_LastCrashLog")
            UserDefaults.standard.set(true, forKey: "CueBear_CrashDetected")
            UserDefaults.standard.synchronize()
        }

        // Signal handler (for crashes like SIGSEGV, SIGABRT, etc.)
        signal(SIGABRT, handleSignal)
        signal(SIGILL, handleSignal)
        signal(SIGSEGV, handleSignal)
        signal(SIGFPE, handleSignal)
        signal(SIGBUS, handleSignal)
        signal(SIGPIPE, handleSignal)
    }
}

// Signal handler function
private func handleSignal(_ sig: Int32) {
    var crashLog = "Signal Crash:\n"
    crashLog += "Signal: \(sig)\n"
    crashLog += "Signal Name: \(signalName(sig))\n"

    // Get call stack
    crashLog += "Call Stack:\n"
    crashLog += Thread.callStackSymbols.joined(separator: "\n")

    UserDefaults.standard.set(crashLog, forKey: "CueBear_LastCrashLog")
    UserDefaults.standard.set(true, forKey: "CueBear_CrashDetected")
    UserDefaults.standard.synchronize()

    // Re-raise signal to allow system to handle it
    Darwin.signal(sig, SIG_DFL)
    raise(sig)
}

private func signalName(_ signal: Int32) -> String {
    switch signal {
    case SIGABRT: return "SIGABRT (Abort)"
    case SIGILL: return "SIGILL (Illegal Instruction)"
    case SIGSEGV: return "SIGSEGV (Segmentation Fault)"
    case SIGFPE: return "SIGFPE (Floating Point Exception)"
    case SIGBUS: return "SIGBUS (Bus Error)"
    case SIGPIPE: return "SIGPIPE (Broken Pipe)"
    default: return "Unknown Signal (\(signal))"
    }
}
