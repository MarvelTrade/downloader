import Foundation

struct ProgressSnapshot: Sendable, Equatable {
    var percent: Double?
    var speed: String?
    var eta: String?
}

enum ProgressParser {
    static func parse(_ chunk: String) -> ProgressSnapshot? {
        let lines = chunk.components(separatedBy: .newlines)
        var latest: ProgressSnapshot?

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if let snapshot = parseTemplateLine(line) ?? parseClassicLine(line) {
                latest = snapshot
            }
        }
        return latest
    }

    static func status(from chunk: String) -> String? {
        let lower = chunk.lowercased()
        if lower.contains("[merger]") || lower.contains("merging formats") {
            return "Объединение видео и аудио…"
        }
        if lower.contains("[fixup") || lower.contains("remux") || lower.contains("converting") {
            return "Сохранение MP4…"
        }
        if lower.contains("[download]") || lower.contains("download:") {
            return "Загрузка видео…"
        }
        if lower.contains("[info]") && lower.contains("extract") {
            return "Получение информации о видео…"
        }
        return nil
    }

    static func extractedFilePath(from chunk: String) -> String? {
        for rawLine in chunk.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("FILEPATH:") {
                let path = String(line.dropFirst("FILEPATH:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !path.isEmpty {
                    return path
                }
            }
            if let range = line.range(of: "Merging formats into \"") {
                let rest = line[range.upperBound...]
                if let end = rest.firstIndex(of: "\"") {
                    return String(rest[..<end])
                }
            }
        }
        return nil
    }

    private static func parseTemplateLine(_ line: String) -> ProgressSnapshot? {
        var payload = line
        if payload.lowercased().hasPrefix("download:") {
            payload = String(payload.dropFirst("download:".count))
        }
        let parts = payload.split(separator: "|", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard parts.count >= 3 else { return nil }

        let percent = parsePercent(parts[0])
        let speed = displayOrNil(parts[1])
        let eta = displayOrNil(parts[2])
        if percent == nil && speed == nil && eta == nil {
            return nil
        }
        return ProgressSnapshot(percent: percent, speed: speed, eta: eta)
    }

    private static func parseClassicLine(_ line: String) -> ProgressSnapshot? {
        guard line.contains("[download]") || line.contains("%") else { return nil }

        let percent = parsePercent(line)
        let speed = firstMatch(in: line, pattern: #"at\s+([0-9.]+\s*[KMGT]?i?B/s)"#)
            ?? firstMatch(in: line, pattern: #"([0-9.]+\s*[KMGT]?i?B/s)"#)
        let eta = firstMatch(in: line, pattern: #"ETA\s+([0-9:]+)"#)

        if percent == nil && speed == nil && eta == nil {
            return nil
        }
        return ProgressSnapshot(percent: percent, speed: speed, eta: eta)
    }

    private static func parsePercent(_ text: String) -> Double? {
        guard let raw = firstMatch(in: text, pattern: #"([0-9]+(?:\.[0-9]+)?)\s*%"#),
              let value = Double(raw) else {
            return nil
        }
        return min(max(value / 100.0, 0), 1)
    }

    private static func displayOrNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let lower = trimmed.lowercased()
        if lower == "na" || lower == "n/a" || lower == "unknown" || lower == "none" {
            return nil
        }
        return trimmed
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges >= 2,
              let swiftRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[swiftRange])
    }
}
