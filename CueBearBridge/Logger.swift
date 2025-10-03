import Foundation
import Combine

final class Logger: ObservableObject {
    static let shared = Logger()
    @Published private(set) var lines: [String] = []
    private let queue = DispatchQueue(label: "Logger.queue")

    func log(_ s: String) {
        let line = "[\(timestamp())] " + s
        print(line)
        // Fix Issue #15: Remove double dispatch - directly dispatch to main queue
        DispatchQueue.main.async {
            self.lines.append(line)
            if self.lines.count > 2000 { self.lines.removeFirst(self.lines.count - 2000) }
        }
    }

    private func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }
}
