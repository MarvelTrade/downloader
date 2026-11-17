import SwiftUI

struct AboutView: View {
    @State private var ytdlpVersion = "—"
    @State private var ffmpegVersion = "—"

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 42))
                .foregroundStyle(.blue)
            Text("Загрузчик \(AppPaths.appVersion)")
                .font(.title2.weight(.semibold))
            Text(HostArchitecture.displayName)
                .font(.body)
                .foregroundStyle(.secondary)
            Text("Автор: Антон Белый")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                labeled("yt-dlp", ytdlpVersion)
                labeled("ffmpeg", ffmpegVersion)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
        }
        .padding(24)
        .frame(width: 420)
        .onAppear(perform: loadVersions)
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
    }

    private func loadVersions() {
        do {
            let binaries = try BinaryLocator.locate()
            ytdlpVersion = BinaryLocator.version(of: binaries.ytdlp)
            ffmpegVersion = compactFFmpegVersion(
                BinaryLocator.version(of: binaries.ffmpeg, arguments: ["-version"])
            )
        } catch {
            ytdlpVersion = "недоступен"
            ffmpegVersion = "недоступен"
        }
    }

    private func compactFFmpegVersion(_ raw: String) -> String {
        let line = raw.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? raw
        if let range = line.range(of: #"ffmpeg version ([^\s]+)"#, options: .regularExpression) {
            let matched = String(line[range])
            if let version = matched.split(separator: " ").last {
                return String(version)
            }
        }
        return line
    }
}
