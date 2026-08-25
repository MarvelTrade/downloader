import Foundation

enum URLValidator {
    static func normalizedURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        if let url = URL(string: "https://\(trimmed)") {
            return url
        }
        return nil
    }

    static func isVKVideoURL(_ raw: String) -> Bool {
        guard let url = normalizedURL(from: raw),
              let host = url.host?.lowercased() else {
            return false
        }

        let allowedHosts = [
            "vk.com",
            "vk.ru",
            "vkvideo.ru",
            "vk.cc"
        ]

        return allowedHosts.contains { allowed in
            host == allowed || host.hasSuffix("." + allowed)
        }
    }
}
