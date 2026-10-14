import Foundation

class Logger {
    static let shared = Logger()

    private init() {}

    func log(_ message: String) {
        #if DEBUG
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        print("[\(timestamp)] \(message)")
        #endif
    }
}

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

