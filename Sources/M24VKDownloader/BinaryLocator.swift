import Foundation

enum BinaryLocator {
    struct Paths: Sendable {
        let ytdlp: URL
        let ffmpeg: URL
        let ffprobe: URL?
        let ytdlpSource: BinarySource
        let ffmpegSource: BinarySource

        var extraPATHDirectories: [String] {
            Array(Set([
                ytdlp.deletingLastPathComponent().path,
                ffmpeg.deletingLastPathComponent().path,
                ffprobe?.deletingLastPathComponent().path
            ].compactMap { $0 }))
        }
    }

    enum BinarySource: String, Sendable {
        case managed
        case bundled
        case systemFallback
    }

    static func locate() throws -> Paths {
        let ytdlp = try locateYTDLP()
        let ffmpeg = try locateFFmpeg()
        let ffprobe = locateFFProbe(near: ffmpeg.url)

        DebugLog.info("Using yt-dlp (\(ytdlp.source.rawValue)) at \(ytdlp.url.path)")
        DebugLog.info("Using ffmpeg (\(ffmpeg.source.rawValue)) at \(ffmpeg.url.path)")
        if let ffprobe {
            DebugLog.info("Using ffprobe at \(ffprobe.path)")
        }

        if ytdlp.source == .systemFallback {
            DebugLog.info("yt-dlp is using a development/system fallback, not a bundled binary")
        }
        if ffmpeg.source == .systemFallback {
            DebugLog.info("ffmpeg is using a development/system fallback, not a bundled binary")
        }

        return Paths(
            ytdlp: ytdlp.url,
            ffmpeg: ffmpeg.url,
            ffprobe: ffprobe,
            ytdlpSource: ytdlp.source,
            ffmpegSource: ffmpeg.source
        )
    }

    static func version(of executable: URL, arguments: [String] = ["--version"]) -> String {
        if isStandaloneMachO(executable), !HostArchitecture.supportsCurrentArchitecture(executable) {
            DebugLog.error("Refusing to run incompatible binary \(executable.path) arch=\(HostArchitecture.machOArchitectures(in: executable)) current=\(HostArchitecture.machine)")
            return "неизвестно"
        }
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = isolatedEnvironment(extraPATH: [executable.deletingLastPathComponent().path])
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return "неизвестно"
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let raw = String(data: data, encoding: .utf8) ?? ""
        let line = raw.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return line.isEmpty ? "неизвестно" : line
    }

    static func isolatedEnvironment(extraPATH: [String] = []) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let systemPATH = "/usr/bin:/bin:/usr/sbin:/sbin"
        let merged = (extraPATH + [systemPATH]).joined(separator: ":")
        environment["PATH"] = merged
        environment["PYTHONUNBUFFERED"] = "1"
        environment["NO_COLOR"] = "1"
        environment["LANG"] = environment["LANG"] ?? "en_US.UTF-8"
        return environment
    }

    private static func locateYTDLP() throws -> (url: URL, source: BinarySource) {
        if let managed = usableStandalone(at: AppPaths.managedYTDLP) {
            return (managed, .managed)
        }
        if let bundled = AppPaths.bundledExecutable(named: "yt-dlp"), let usable = usableStandalone(at: bundled) {
            return (usable, .bundled)
        }
        if let system = systemExecutable(named: "yt-dlp") {
            if isStandaloneMachO(system), !HostArchitecture.supportsCurrentArchitecture(system) {
                DebugLog.info("Skipping system yt-dlp at \(system.path): incompatible architecture")
            } else {
                DebugLog.info("Falling back to system yt-dlp at \(system.path)")
                return (system, .systemFallback)
            }
        }
        DebugLog.error("yt-dlp was not found in managed, bundled, or system locations")
        throw DownloadError.ytdlpNotFound
    }

    private static func locateFFmpeg() throws -> (url: URL, source: BinarySource) {
        if let bundled = AppPaths.bundledExecutable(named: "ffmpeg"), let usable = usableStandalone(at: bundled) {
            return (usable, .bundled)
        }
        if let system = systemExecutable(named: "ffmpeg") {
            if isStandaloneMachO(system), !HostArchitecture.supportsCurrentArchitecture(system) {
                DebugLog.info("Skipping system ffmpeg at \(system.path): incompatible architecture")
            } else {
                DebugLog.info("Falling back to system ffmpeg at \(system.path)")
                return (system, .systemFallback)
            }
        }
        DebugLog.error("ffmpeg was not found in bundled or system locations")
        throw DownloadError.ffmpegNotFound
    }

    private static func locateFFProbe(near ffmpeg: URL) -> URL? {
        let sibling = ffmpeg.deletingLastPathComponent().appendingPathComponent("ffprobe")
        if let usable = usableStandalone(at: sibling) {
            return usable
        }
        if let bundled = AppPaths.bundledExecutable(named: "ffprobe"), let usable = usableStandalone(at: bundled) {
            return usable
        }
        if let system = systemExecutable(named: "ffprobe") {
            if isStandaloneMachO(system), !HostArchitecture.supportsCurrentArchitecture(system) {
                return nil
            }
            return system
        }
        return nil
    }

    private static func usableStandalone(at url: URL) -> URL? {
        guard FileManager.default.isExecutableFile(atPath: url.path), isStandaloneMachO(url) else {
            return nil
        }
        guard HostArchitecture.supportsCurrentArchitecture(url) else {
            DebugLog.info("Skipping \(url.path): incompatible architecture \(HostArchitecture.machOArchitectures(in: url)) current=\(HostArchitecture.machine)")
            return nil
        }
        return url
    }

    static func isStandaloneMachO(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let prefix = try? handle.read(upToCount: 4), prefix.count == 4 else { return false }
        if prefix == Data("# !".utf8) || prefix.starts(with: Data("#!".utf8)) {
            return false
        }
        let bytes = [UInt8](prefix)
        let fatBE: [UInt8] = [0xCA, 0xFE, 0xBA, 0xBE]
        let fat64: [UInt8] = [0xCA, 0xFE, 0xBA, 0xBF]
        let macho32LE: [UInt8] = [0xCE, 0xFA, 0xED, 0xFE]
        let macho64LE: [UInt8] = [0xCF, 0xFA, 0xED, 0xFE]
        let macho32BE: [UInt8] = [0xFE, 0xED, 0xFA, 0xCE]
        let macho64BE: [UInt8] = [0xFE, 0xED, 0xFA, 0xCF]
        return bytes == fatBE || bytes == fat64
            || bytes == macho32LE || bytes == macho64LE
            || bytes == macho32BE || bytes == macho64BE
    }

    private static func systemExecutable(named name: String) -> URL? {
        var candidates: [String] = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)"
        ]
        let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for directory in pathEnv.split(separator: ":") {
            candidates.append("\(directory)/\(name)")
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        candidates.append(contentsOf: [
            "\(home)/.local/bin/\(name)",
            "/opt/homebrew/opt/\(name)/bin/\(name)",
            "/usr/local/opt/\(name)/bin/\(name)"
        ])
        let pythonRoot = "\(home)/Library/Python"
        if let versions = try? FileManager.default.contentsOfDirectory(atPath: pythonRoot) {
            for version in versions {
                candidates.append("\(pythonRoot)/\(version)/bin/\(name)")
            }
        }

        var seen = Set<String>()
        for candidate in candidates {
            let path = URL(fileURLWithPath: candidate).standardizedFileURL.path
            guard seen.insert(path).inserted else { continue }
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }
}
