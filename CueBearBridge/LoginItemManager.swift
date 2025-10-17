import Foundation
import ServiceManagement
import SwiftUI

/// Manages the "Open at Login" functionality using the modern SMAppService API (macOS 13+)
@available(macOS 13.0, *)
class LoginItemManager: ObservableObject {
    @Published var isEnabled: Bool = false

    private let userDefaultsKey = "openAtLogin"

    init() {
        // Initialize state from current system status
        updateStatus()

        // Check if this is the first launch (no saved preference)
        if UserDefaults.standard.object(forKey: userDefaultsKey) == nil {
            // First launch: default to OFF
            print("Open at Login: First launch, defaulting to OFF")
            _ = disable()
            UserDefaults.standard.set(false, forKey: userDefaultsKey)
        } else {
            // Restore user preference if available
            let savedPreference = UserDefaults.standard.bool(forKey: userDefaultsKey)
            if savedPreference != isEnabled {
                // User preference doesn't match system state, sync it
                if savedPreference {
                    _ = enable()
                } else {
                    _ = disable()
                }
            }
        }
    }

    /// Updates the published status by checking the current SMAppService status
    func updateStatus() {
        let status = SMAppService.mainApp.status
        switch status {
        case .enabled:
            isEnabled = true
        case .notRegistered, .notFound, .requiresApproval:
            isEnabled = false
        @unknown default:
            isEnabled = false
        }
    }

    /// Enables "Open at Login" by registering the app with SMAppService
    /// - Returns: True if successful, false otherwise
    @discardableResult
    func enable() -> Bool {
        do {
            try SMAppService.mainApp.register()
            isEnabled = true
            UserDefaults.standard.set(true, forKey: userDefaultsKey)
            print("Open at Login: Enabled successfully")
            return true
        } catch {
            print("Open at Login: Failed to enable - \(error.localizedDescription)")
            // Update status in case the system state changed
            updateStatus()
            return false
        }
    }

    /// Disables "Open at Login" by unregistering the app from SMAppService
    /// - Returns: True if successful, false otherwise
    @discardableResult
    func disable() -> Bool {
        do {
            try SMAppService.mainApp.unregister()
            isEnabled = false
            UserDefaults.standard.set(false, forKey: userDefaultsKey)
            print("Open at Login: Disabled successfully")
            return true
        } catch {
            print("Open at Login: Failed to disable - \(error.localizedDescription)")
            // Update status in case the system state changed
            updateStatus()
            return false
        }
    }

    /// Toggles the current "Open at Login" state
    func toggle() {
        if isEnabled {
            disable()
        } else {
            enable()
        }
    }

    /// Returns a user-friendly status message
    var statusMessage: String {
        let status = SMAppService.mainApp.status
        switch status {
        case .enabled:
            return "App will open at login"
        case .notRegistered:
            return "Not registered for login"
        case .notFound:
            return "App not found"
        case .requiresApproval:
            return "Requires approval in System Settings"
        @unknown default:
            return "Unknown status"
        }
    }
}
