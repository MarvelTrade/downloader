import Foundation

enum ErrorMapper {
    static func map(exitCode: Int32, stdout: String, stderr: String) -> DownloadError {
        let combined = (stdout + "\n" + stderr).lowercased()
        let technical = usefulTechnicalLines(from: stdout + "\n" + stderr)
        if !technical.isEmpty {
            DebugLog.error("Mapped process failure (exit \(exitCode)): \(technical)")
        } else {
            DebugLog.error("Mapped process failure (exit \(exitCode)) with no useful technical lines")
        }

        if combined.contains("no space left")
            || combined.contains("enospc")
            || combined.contains("disk quota exceeded")
            || combined.contains("not enough space") {
            return .diskFull
        }

        if looksLikeAuthRequired(combined) {
            return .vkAuthRequired
        }

        if looksLikeInvalidURL(combined) {
            return .invalidURL
        }

        if looksLikeUnavailable(combined) {
            return .videoUnavailable
        }

        return .downloadFailed
    }

    static func usefulTechnicalLines(from text: String) -> String {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                guard !line.isEmpty else { return false }
                let lower = line.lowercased()
                if lower.contains("notopensslwarning") { return false }
                if lower.contains("urllib3") { return false }
                if lower.contains("warnings.warn") { return false }
                return lower.contains("error")
                    || lower.contains("unable")
                    || lower.contains("denied")
                    || lower.contains("private")
                    || lower.contains("login")
                    || lower.contains("auth")
                    || lower.contains("unavailable")
                    || lower.contains("unsupported")
                    || lower.contains("no space")
            }
            .joined(separator: " | ")
    }

    private static func looksLikeAuthRequired(_ text: String) -> Bool {
        text.contains("login required")
            || text.contains("sign in")
            || text.contains("authorization required")
            || text.contains("auth required")
            || text.contains("only available for registered")
            || text.contains("please log in")
            || text.contains("cookies") && text.contains("vk")
            || text.contains("captcha")
            || text.contains("access denied") && text.contains("login")
    }

    private static func looksLikeInvalidURL(_ text: String) -> Bool {
        text.contains("unsupported url")
            || text.contains("is not a valid url")
            || text.contains("invalid url")
            || text.contains("unable to extract") && text.contains("webpage") && text.contains("malformed")
    }

    private static func looksLikeUnavailable(_ text: String) -> Bool {
        text.contains("video unavailable")
            || text.contains("video is unavailable")
            || text.contains("this video has been removed")
            || text.contains("private video")
            || text.contains("is not available")
            || text.contains("unable to download webpage")
            || text.contains("http error 404")
            || text.contains("http error 410")
            || text.contains("unable to extract")
    }
}
