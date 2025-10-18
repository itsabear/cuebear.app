import Foundation

// Singleton helper to provide version string without blocking the main thread
struct VersionHelper {
    // Simple cached version string - no git, no blocking
    static let cachedVersionString: String = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version).\(build)"
    }()
}
