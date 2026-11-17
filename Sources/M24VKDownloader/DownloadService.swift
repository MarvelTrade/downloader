import Foundation

enum DownloadEvent: Sendable {
    case status(String)
    case phase(JobStatus)
    case title(String)
    case progress(ProgressSnapshot)
    case fileSize(Int64)
    case log(String)
}

enum DownloadService {
    static func download(
        videoURL: String,
        destinationFolder: URL,
        binaries: BinaryLocator.Paths,
        session: CancellableSession,
        downloadThumbnail: Bool,
        onEvent: @escaping @Sendable (DownloadEvent) -> Void
    ) async throws -> URL {
        guard let source = URLValidator.videoSource(from: videoURL),
              let normalized = URLValidator.normalizedURL(from: videoURL) else {
            throw DownloadError.invalidURL
        }

        DebugLog.info("Detected source \(source.displayName) for \(normalized.absoluteString)")

        try session.throwIfCancelled()
        try ensureFolderIsWritable(destinationFolder)
        try checkDiskSpace(at: destinationFolder)

        let tempDirectory = AppPaths.tempRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        onEvent(.phase(.fetchingInfo))
        onEvent(.status("Получение информации о видео…"))
        var effectiveVideoURL = normalized.absoluteString
        var referer: String?
        let title: String
        do {
            title = try await fetchTitle(
                videoURL: normalized.absoluteString,
                binaries: binaries,
                workingDirectory: tempDirectory,
                session: session,
                source: source,
                onEvent: onEvent
            )
        } catch {
            guard source == .ok || source == .m24 else { throw error }
            let resolved = try await resolveDirectVideo(from: normalized, source: source)
            effectiveVideoURL = resolved.mediaURL.absoluteString
            referer = normalized.absoluteString
            title = resolved.title ?? source.fallbackTitle
            DebugLog.info("Using direct media fallback for \(source.displayName): \(resolved.mediaURL.absoluteString)")
        }
        try session.throwIfCancelled()
        onEvent(.title(title))

        let safeTitle = FilenameSanitizer.sanitize(title)
        let tempOutput = FilenameSanitizer.uniqueFileURL(in: tempDirectory, baseName: safeTitle, ext: "mp4")
        DebugLog.info("Temporary output path: \(tempOutput.path)")

        onEvent(.phase(.downloading))
        onEvent(.status("Загрузка видео…"))
        let downloadedURL = try await runYTDLPDownload(
            videoURL: effectiveVideoURL,
            outputURL: tempOutput,
            binaries: binaries,
            session: session,
            source: source,
            referer: referer,
            downloadThumbnail: downloadThumbnail && source != .instagram,
            onEvent: onEvent
        )
        try session.throwIfCancelled()

        onEvent(.phase(.merging))
        onEvent(.status("Сохранение MP4…"))
        let remuxedURL = try await remuxToMP4IfNeeded(
            downloadedURL,
            ffmpeg: binaries.ffmpeg,
            extraPATH: binaries.extraPATHDirectories,
            session: session
        )

        let finalURL = FilenameSanitizer.uniqueFileURL(
            in: destinationFolder,
            baseName: remuxedURL.deletingPathExtension().lastPathComponent,
            ext: remuxedURL.pathExtension.isEmpty ? "mp4" : remuxedURL.pathExtension
        )
        if FileManager.default.fileExists(atPath: finalURL.path) {
            try FileManager.default.removeItem(at: finalURL)
        }
        try FileManager.default.moveItem(at: remuxedURL, to: finalURL)

        if downloadThumbnail, source != .instagram,
           let thumbnailURL = newestThumbnailFile(in: tempDirectory) {
            let finalThumbnailURL = finalURL
                .deletingPathExtension()
                .appendingPathExtension("jpg")
            if FileManager.default.fileExists(atPath: finalThumbnailURL.path) {
                try FileManager.default.removeItem(at: finalThumbnailURL)
            }
            try FileManager.default.moveItem(at: thumbnailURL, to: finalThumbnailURL)
            DebugLog.info("Moved thumbnail to \(finalThumbnailURL.path)")
        }
        DebugLog.info("Moved finished file to \(finalURL.path)")
        onEvent(.status("Готово"))
        return finalURL
    }

    private static func fetchTitle(
        videoURL: String,
        binaries: BinaryLocator.Paths,
        workingDirectory: URL,
        session: CancellableSession,
        source: VideoSource,
        onEvent: @escaping @Sendable (DownloadEvent) -> Void
    ) async throws -> String {
        let arguments = [
            "--ignore-config",
            "--no-playlist",
            "--skip-download",
            "--no-color",
            "--ffmpeg-location", binaries.ffmpeg.path,
            "--print", "%(title)s",
            videoURL
        ]

        let result = try await ProcessRunner.run(
            executable: binaries.ytdlp,
            arguments: arguments,
            extraPATH: binaries.extraPATHDirectories,
            currentDirectory: workingDirectory,
            session: session,
            onStdout: { chunk in onEvent(.log(chunk)) },
            onStderr: { chunk in onEvent(.log(chunk)) }
        )

        if result.exitCode != 0 {
            throw ErrorMapper.map(exitCode: result.exitCode, stdout: result.stdout, stderr: result.stderr)
        }

        let title = result.stdout
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && $0.uppercased() != "NA" }

        if let title, !title.isEmpty {
            return title
        }

        DebugLog.error("yt-dlp returned empty title; using fallback name")
        return source.fallbackTitle
    }

    private static func runYTDLPDownload(
        videoURL: String,
        outputURL: URL,
        binaries: BinaryLocator.Paths,
        session: CancellableSession,
        source: VideoSource,
        referer: String?,
        downloadThumbnail: Bool,
        onEvent: @escaping @Sendable (DownloadEvent) -> Void
    ) async throws -> URL {
        var arguments = [
            "--ignore-config",
            "--no-playlist",
            "--no-color",
            "--newline",
            "--progress",
            "--progress-template", "download:%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s",
            "-f", formatSelector(for: source),
            "--merge-output-format", "mp4",
            "--ffmpeg-location", binaries.ffmpeg.path,
            "-o", outputURL.path,
            "--print", "after_move:FILEPATH:%(filepath)s"
        ]

        if downloadThumbnail {
            arguments.append(contentsOf: ["--write-thumbnail", "--convert-thumbnails", "jpg"])
        }
        if let referer {
            arguments.append(contentsOf: [
                "--referer", referer,
                "--user-agent", "Mozilla/5.0 (Macintosh; Apple Silicon Mac OS X) AppleWebKit/605.1.15 Safari/605.1.15"
            ])
        }
        arguments.append(videoURL)

        let detectedPath = StringBox()

        let result = try await ProcessRunner.run(
            executable: binaries.ytdlp,
            arguments: arguments,
            extraPATH: binaries.extraPATHDirectories,
            currentDirectory: outputURL.deletingLastPathComponent(),
            session: session,
            onStdout: { chunk in
                onEvent(.log(chunk))
                handleProgressChunk(chunk, detectedPath: detectedPath, onEvent: onEvent)
            },
            onStderr: { chunk in
                onEvent(.log(chunk))
                handleProgressChunk(chunk, detectedPath: detectedPath, onEvent: onEvent)
            }
        )

        if result.exitCode != 0 {
            throw ErrorMapper.map(exitCode: result.exitCode, stdout: result.stdout, stderr: result.stderr)
        }

        if detectedPath.get() == nil,
           let path = ProgressParser.extractedFilePath(from: result.stdout + "\n" + result.stderr) {
            detectedPath.set(path)
        }

        if let path = detectedPath.get() {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        if FileManager.default.fileExists(atPath: outputURL.path) {
            return outputURL
        }

        if let fallback = newestVideoFile(
            in: outputURL.deletingLastPathComponent(),
            matching: outputURL.deletingPathExtension().lastPathComponent
        ) {
            return fallback
        }

        throw DownloadError.emptyResult
    }

    private static func formatSelector(for source: VideoSource) -> String {
        if source == .youtube {
            return "bestvideo[vcodec^=avc1]+bestaudio[acodec^=mp4a]/bestvideo[vcodec^=avc1]+bestaudio/best[ext=mp4]/bestvideo+bestaudio/best"
        }
        return "bestvideo+bestaudio/best"
    }

    private struct DirectVideo {
        let mediaURL: URL
        let title: String?
    }

    private static func resolveDirectVideo(from pageURL: URL, source: VideoSource) async throws -> DirectVideo {
        var request = URLRequest(url: pageURL)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Apple Silicon Mac OS X) AppleWebKit/605.1.15 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            DebugLog.error("Direct fallback network error for \(source.displayName): \(error.localizedDescription)")
            throw DownloadError.networkError
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            DebugLog.error("Direct fallback HTTP \(http.statusCode) for \(source.displayName)")
            throw http.statusCode == 401 || http.statusCode == 403
                ? DownloadError.authRequired
                : DownloadError.sourceUnavailable
        }

        guard let rawHTML = String(data: data, encoding: .utf8) else {
            throw DownloadError.downloadFailed
        }
        let html = decodeEmbeddedHTML(rawHTML)
        guard let mediaURL = firstMediaURL(in: html) else {
            DebugLog.error("Direct fallback found no MP4/HLS URL for \(source.displayName)")
            throw DownloadError.downloadFailed
        }

        return DirectVideo(mediaURL: mediaURL, title: pageTitle(in: html))
    }

    private static func decodeEmbeddedHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#34;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "\\u0026", with: "&")
            .replacingOccurrences(of: "\\/", with: "/")
    }

    private static func firstMediaURL(in html: String) -> URL? {
        let pattern = #"https?://[^\"'<>\\s]+?\.(?:mp4|m3u8)(?:\?[^\"'<>\\s]+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let fullRange = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, range: fullRange)
        let candidates = matches.compactMap { match -> URL? in
            guard let range = Range(match.range, in: html) else { return nil }
            return URL(string: String(html[range]))
        }
        return candidates.first(where: { $0.pathExtension.lowercased() == "mp4" }) ?? candidates.first
    }

    private static func pageTitle(in html: String) -> String? {
        let patterns = [
            #"<meta[^>]+property=[\"']og:title[\"'][^>]+content=[\"']([^\"']+)[\"']"#,
            #"<meta[^>]+content=[\"']([^\"']+)[\"'][^>]+property=[\"']og:title[\"']"#,
            #"<title[^>]*>([^<]+)</title>"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let match = regex.firstMatch(
                    in: html,
                    range: NSRange(html.startIndex..<html.endIndex, in: html)
                  ),
                  match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: html) else {
                continue
            }
            let title = String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty { return title }
        }
        return nil
    }

    private static func handleProgressChunk(
        _ chunk: String,
        detectedPath: StringBox,
        onEvent: @escaping @Sendable (DownloadEvent) -> Void
    ) {
        if let status = ProgressParser.status(from: chunk) {
            onEvent(.status(status))
            let lower = chunk.lowercased()
            if lower.contains("[merger]") || lower.contains("merging formats") || lower.contains("fixup") {
                onEvent(.phase(.merging))
            } else if lower.contains("[download]") || lower.contains("download:") {
                onEvent(.phase(.downloading))
            }
        }
        if let progress = ProgressParser.parse(chunk) {
            onEvent(.progress(progress))
        }
        if let path = ProgressParser.extractedFilePath(from: chunk) {
            detectedPath.set(path)
        }
    }

    private static func remuxToMP4IfNeeded(
        _ inputURL: URL,
        ffmpeg: URL,
        extraPATH: [String],
        session: CancellableSession
    ) async throws -> URL {
        let ext = inputURL.pathExtension.lowercased()
        if ext == "mp4" {
            return inputURL
        }

        let folder = inputURL.deletingLastPathComponent()
        let baseName = inputURL.deletingPathExtension().lastPathComponent
        let mp4URL = FilenameSanitizer.uniqueFileURL(in: folder, baseName: baseName, ext: "mp4")
        DebugLog.info("Attempting remux to MP4 without re-encoding: \(inputURL.path) -> \(mp4URL.path)")

        let result = try await ProcessRunner.run(
            executable: ffmpeg,
            arguments: [
                "-y",
                "-i", inputURL.path,
                "-c", "copy",
                "-map", "0",
                "-movflags", "+faststart",
                mp4URL.path
            ],
            extraPATH: extraPATH,
            currentDirectory: folder,
            session: session
        )

        if result.exitCode == 0, FileManager.default.fileExists(atPath: mp4URL.path) {
            try? FileManager.default.removeItem(at: inputURL)
            return mp4URL
        }

        DebugLog.error("ffmpeg remux exited with \(result.exitCode); keeping original file")
        return inputURL
    }

    private static func newestVideoFile(in folder: URL, matching baseName: String) -> URL? {
        let allowed = Set(["mp4", "mkv", "webm", "mov", "m4a"])
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return items
            .filter { allowed.contains($0.pathExtension.lowercased()) }
            .filter { $0.deletingPathExtension().lastPathComponent.hasPrefix(baseName) }
            .sorted { lhs, rhs in
                let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return l > r
            }
            .first
    }

    private static func newestThumbnailFile(in folder: URL) -> URL? {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return items
            .filter { ["jpg", "jpeg", "png", "webp"].contains($0.pathExtension.lowercased()) }
            .sorted { lhs, rhs in
                let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return l > r
            }
            .first
    }

    private static func ensureFolderIsWritable(_ folder: URL) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw DownloadError.downloadFailed
        }
        if !FileManager.default.isWritableFile(atPath: folder.path) {
            throw DownloadError.downloadFailed
        }
    }

    private static func checkDiskSpace(at folder: URL) throws {
        let values = try folder.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        if let capacity = values.volumeAvailableCapacityForImportantUsage, capacity < 10_000_000 {
            throw DownloadError.diskFull
        }
    }
}

private final class StringBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: String?

    func set(_ newValue: String) {
        lock.lock()
        value = newValue
        lock.unlock()
    }

    func get() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}
