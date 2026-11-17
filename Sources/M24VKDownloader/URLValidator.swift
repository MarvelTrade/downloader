import Foundation

enum VideoSource: String, CaseIterable, Sendable {
    case youtube
    case instagram
    case tiktok
    case vk
    case ok
    case rutube
    case m24

    var displayName: String {
        switch self {
        case .youtube: return "YouTube"
        case .instagram: return "Instagram"
        case .tiktok: return "TikTok"
        case .vk: return "VK"
        case .ok: return "Одноклассники"
        case .rutube: return "RuTube"
        case .m24: return "Новостной сайт"
        }
    }

    var fallbackTitle: String {
        "Видео \(displayName)"
    }
}

enum DownloadSource: Equatable, Sendable {
    case video(VideoSource)

    var displayName: String {
        switch self {
        case .video(let source): return source.displayName
        }
    }
}

enum URLValidator {
    private static let domainsBySource: [(VideoSource, [String])] = [
        (.youtube, ["youtube.com", "youtu.be"]),
        (.instagram, ["instagram.com"]),
        (.tiktok, ["tiktok.com"]),
        (.vk, ["vk.com", "vk.ru", "vkvideo.ru", "vk.cc"]),
        (.ok, ["ok.ru"]),
        (.rutube, ["rutube.ru"]),
        (.m24, ["m24.ru"])
    ]

    static func normalizedURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let candidate = URL(string: trimmed)?.scheme == nil ? "https://\(trimmed)" : trimmed
        guard let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              url.host != nil else {
            return nil
        }
        return url
    }

    static func videoSource(from raw: String) -> VideoSource? {
        guard let url = normalizedURL(from: raw),
              let host = url.host?.lowercased() else {
            return nil
        }

        return domainsBySource.first { _, domains in
            domains.contains { domain in
                host == domain || host.hasSuffix("." + domain)
            }
        }?.0
    }

    static func source(from raw: String) -> DownloadSource? {
        videoSource(from: raw).map(DownloadSource.video)
    }

    static func isSupportedVideoURL(_ raw: String) -> Bool {
        videoSource(from: raw) != nil
    }

    static func isVKVideoURL(_ raw: String) -> Bool {
        videoSource(from: raw) == .vk
    }
}
