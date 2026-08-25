import Foundation

enum AppPaths {
    static let appVersion = "1.3.0"

    static var supportDirectory: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("M24VKDownloader", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var managedBinDirectory: URL {
        let url = supportDirectory.appendingPathComponent("bin", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var managedYTDLP: URL {
        managedBinDirectory.appendingPathComponent("yt-dlp")
    }

    static var settingsFile: URL {
        supportDirectory.appendingPathComponent("settings.json")
    }

    static var historyFile: URL {
        supportDirectory.appendingPathComponent("history.json")
    }

    static var queueFile: URL {
        supportDirectory.appendingPathComponent("queue.json")
    }

    static var tempRoot: URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("M24VKDownloader", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func bundledBinDirectory() -> URL? {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("bin", isDirectory: true),
           FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        let fallback = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/bin", isDirectory: true)
        if FileManager.default.fileExists(atPath: fallback.path) {
            return fallback
        }
        return nil
    }

    static func bundledExecutable(named name: String) -> URL? {
        if let directory = bundledBinDirectory() {
            let archURL = directory
                .appendingPathComponent(HostArchitecture.machine, isDirectory: true)
                .appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: archURL.path) {
                return archURL
            }
        }
        if let url = Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "bin"),
           FileManager.default.isExecutableFile(atPath: url.path) {
            return url
        }
        if let url = Bundle.main.url(
            forResource: name,
            withExtension: nil,
            subdirectory: "bin/\(HostArchitecture.machine)"
        ), FileManager.default.isExecutableFile(atPath: url.path) {
            return url
        }
        if let directory = bundledBinDirectory() {
            let url = directory.appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return url
            }
        }
        return nil
    }
}
