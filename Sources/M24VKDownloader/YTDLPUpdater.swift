import Foundation

enum YTDLPUpdater {
    enum Result: Sendable {
        case upToDate(String)
        case updated(from: String, to: String)
        case failed(String)
    }

    private static let latestPageURL = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest")!
    private static let latestBinaryURL = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos")!
    private static let userAgent = "M24VKDownloader/1.2.1"

    static func checkAndUpdate(currentVersion: String, force: Bool) async -> Result {
        do {
            let current = normalizeVersion(currentVersion)
            let latest = try await fetchLatestOfficialVersion()

            DebugLog.info("yt-dlp update check without GitHub API: current=\(current) latest=\(latest) force=\(force)")

            if compareVersions(current, latest) != .orderedAscending {
                DebugLog.info("yt-dlp already current; not downloading")
                return .upToDate(latest)
            }

            let staged = try await stageOfficialBinary(from: officialBinaryURL(for: latest))

            let destination = AppPaths.managedYTDLP
            if FileManager.default.fileExists(atPath: destination.path) {
                _ = try FileManager.default.replaceItemAt(destination, withItemAt: staged.url)
            } else {
                try FileManager.default.moveItem(at: staged.url, to: destination)
            }
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
            return .updated(from: current, to: staged.version)
        } catch {
            DebugLog.error("yt-dlp update failed: \(error.localizedDescription)")
            return .failed(error.localizedDescription)
        }
    }

    private struct StagedBinary {
        let url: URL
        let version: String
    }

    private static func stageOfficialBinary(from url: URL) async throws -> StagedBinary {
        try FileManager.default.createDirectory(at: AppPaths.managedBinDirectory, withIntermediateDirectories: true)
        let tempURL = AppPaths.managedBinDirectory.appendingPathComponent("yt-dlp.download.\(UUID().uuidString)")
        try await download(from: url, to: tempURL)

        let attrs = try FileManager.default.attributesOfItem(atPath: tempURL.path)
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        guard size > 1_000_000 else {
            try? FileManager.default.removeItem(at: tempURL)
            throw updaterError("Загруженный файл yt-dlp слишком маленький")
        }
        guard BinaryLocator.isStandaloneMachO(tempURL) else {
            try? FileManager.default.removeItem(at: tempURL)
            throw updaterError("Загруженный yt-dlp не является автономным бинарником")
        }
        guard HostArchitecture.supportsCurrentArchitecture(tempURL) else {
            try? FileManager.default.removeItem(at: tempURL)
            throw updaterError("Загруженный yt-dlp не подходит для этой архитектуры")
        }

        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempURL.path)
        let downloadedVersion = BinaryLocator.version(of: tempURL)
        guard downloadedVersion != "неизвестно", !downloadedVersion.isEmpty else {
            try? FileManager.default.removeItem(at: tempURL)
            throw updaterError("Загруженный yt-dlp не запускается")
        }
        DebugLog.info("Downloaded yt-dlp reports version \(downloadedVersion)")
        return StagedBinary(url: tempURL, version: normalizeVersion(downloadedVersion))
    }

    private static func fetchLatestOfficialVersion() async throws -> String {
        var request = URLRequest(url: latestPageURL)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.httpMethod = "GET"
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse {
            DebugLog.info("yt-dlp releases/latest HTTP \(http.statusCode) finalURL=\(http.url?.absoluteString ?? "nil")")
        }
        if let tag = versionFromRedirect(response.url) {
            return tag
        }
        if let html = String(data: data, encoding: .utf8), let tag = versionFromHTML(html) {
            return tag
        }
        throw updaterError("Не удалось определить официальную версию yt-dlp")
    }

    private static func versionFromRedirect(_ url: URL?) -> String? {
        guard let url else { return nil }
        let parts = url.pathComponents
        if let tagIndex = parts.firstIndex(of: "tag"), parts.indices.contains(tagIndex + 1) {
            let tag = normalizeVersion(parts[tagIndex + 1])
            if tag != "latest", !tag.isEmpty {
                return tag
            }
        }
        let last = normalizeVersion(url.lastPathComponent)
        if last != "latest", last.contains(".") {
            return last
        }
        return nil
    }

    private static func versionFromHTML(_ html: String) -> String? {
        let pattern = #"yt-dlp/yt-dlp/releases/tag/([0-9]{4}\.[0-9]{2}\.[0-9]{2}[^"'/\s]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              let tagRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        return normalizeVersion(String(html[tagRange]))
    }

    private static func officialBinaryURL(for tag: String) -> URL {
        URL(string: "https://github.com/yt-dlp/yt-dlp/releases/download/\(tag)/yt-dlp_macos") ?? latestBinaryURL
    }

    private static func download(from url: URL, to destination: URL) async throws {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (temp, response) = try await URLSession.shared.download(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw updaterError("Ошибка загрузки yt-dlp (\(http.statusCode))")
        }
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temp, to: destination)
    }

    private static func updaterError(_ message: String) -> NSError {
        NSError(domain: "YTDLPUpdater", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    static func normalizeVersion(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ".dev", with: "")
            .replacingOccurrences(of: "v", with: "", options: [.anchored])
    }

    static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        lhs.compare(rhs, options: [.numeric, .caseInsensitive])
    }
}
