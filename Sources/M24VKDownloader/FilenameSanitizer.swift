import Foundation

enum FilenameSanitizer {
    static func sanitize(_ rawTitle: String) -> String {
        var name = rawTitle
            .replacingOccurrences(of: "\0", with: "")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")

        let disallowed = CharacterSet.newlines
            .union(.controlCharacters)
            .union(CharacterSet(charactersIn: "%"))
        name = name.components(separatedBy: disallowed).joined(separator: " ")

        while name.contains("  ") {
            name = name.replacingOccurrences(of: "  ", with: " ")
        }

        name = name.trimmingCharacters(in: .whitespacesAndNewlines)

        while name.hasSuffix(".") {
            name.removeLast()
        }
        while name.hasPrefix(".") {
            name.removeFirst()
        }

        name = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if name.isEmpty || name == "." || name == ".." {
            name = "VK Video"
        }

        if name.count > 180 {
            name = String(name.prefix(180)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return name
    }

    static func uniqueFileURL(in folder: URL, baseName: String, ext: String) -> URL {
        var candidate = folder.appendingPathComponent("\(baseName).\(ext)")
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(baseName) (\(index)).\(ext)")
            index += 1
        }
        return candidate
    }
}
