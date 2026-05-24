import Foundation
import os

enum MonitorLogger {
    static let subsystem = "com.deepseek.monitor"
    static let store = Logger(subsystem: subsystem, category: "store")
    static let client = Logger(subsystem: subsystem, category: "client")
    static let login = Logger(subsystem: subsystem, category: "login")

    static func file(_ category: String, _ message: String) {
        FileLogWriter.shared.append(category: category, message: message)
    }
}

private final class FileLogWriter: @unchecked Sendable {
    static let shared = FileLogWriter()

    private let queue = DispatchQueue(label: "com.deepseek.monitor.file-log")
    private let fileURL: URL
    private let formatter: ISO8601DateFormatter

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        fileURL = base
            .appendingPathComponent("DeepSeekMonitor", isDirectory: true)
            .appendingPathComponent("monitor.log", isDirectory: false)
        formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func append(category: String, message: String) {
        let line = "\(formatter.string(from: Date())) [\(category)] \(message)\n"
        queue.async {
            do {
                let folderURL = self.fileURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: self.fileURL.path) {
                    let handle = try FileHandle(forWritingTo: self.fileURL)
                    try handle.seekToEnd()
                    if let data = line.data(using: .utf8) {
                        try handle.write(contentsOf: data)
                    }
                    try handle.close()
                } else {
                    try line.write(to: self.fileURL, atomically: true, encoding: .utf8)
                }
            } catch {
                self.storeFallback(line)
            }
        }
    }

    private func storeFallback(_ line: String) {
        NSLog("%@", line)
    }
}
