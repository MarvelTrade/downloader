import Foundation

enum DebugLog {
    private static let queue = DispatchQueue(label: "ru.m24.vkdownloader.debuglog")

    private static var logFileURL: URL {
        let logs = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Logs", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        return logs.appendingPathComponent("M24VKDownloader.log")
    }

    /// Move a log that still contains Homebrew paths so 1.2.1 starts a clean file.
    /// Does not delete the previous log.
    static func rotateLegacyHomebrewLogIfNeeded() {
        queue.sync {
            let url = logFileURL
            guard FileManager.default.fileExists(atPath: url.path),
                  let handle = try? FileHandle(forReadingFrom: url) else { return }
            defer { try? handle.close() }
            let data = (try? handle.readToEnd()) ?? Data()
            guard let text = String(data: data, encoding: .utf8),
                  text.contains("/opt/homebrew") else { return }
            let old = url.deletingLastPathComponent().appendingPathComponent("M24VKDownloader.log.old")
            try? FileManager.default.removeItem(at: old)
            do {
                try FileManager.default.moveItem(at: url, to: old)
            } catch {
                return
            }
        }
    }

    static func info(_ message: String) {
        write(level: "INFO", message: message)
    }

    static func error(_ message: String) {
        write(level: "ERROR", message: message)
    }

    static func raw(_ message: String) {
        write(level: "PROC", message: message)
    }

    private static func write(level: String, message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] [\(level)] \(message)\n"
        queue.async {
            let url = logFileURL
            guard let data = line.data(using: .utf8) else { return }
            if FileManager.default.fileExists(atPath: url.path) {
                if let handle = try? FileHandle(forWritingTo: url) {
                    defer { try? handle.close() }
                    _ = try? handle.seekToEnd()
                    try? handle.write(contentsOf: data)
                }
            } else {
                try? data.write(to: url, options: .atomic)
            }
        }
    }
}
