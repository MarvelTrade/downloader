import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Настройки")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Закрыть") { dismiss() }
            }

            GroupBox("Версии") {
                VStack(alignment: .leading, spacing: 8) {
                    labeled("M24VKDownloader", AppPaths.appVersion)
                    labeled("Архитектура", HostArchitecture.displayName)
                    labeled("yt-dlp", model.ytdlpVersion)
                    labeled("ffmpeg", firstLine(model.ffmpegVersion))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Бинарники") {
                VStack(alignment: .leading, spacing: 8) {
                    labeled("yt-dlp", "\(model.ytdlpSourceText)\n\(model.ytdlpPathText)")
                    labeled("ffmpeg", "\(model.ffmpegSourceText)\n\(model.ffmpegPathText)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button(model.isCheckingUpdate ? "Проверка…" : "Проверить обновления") {
                    model.checkForYTDLPUpdates(force: true)
                }
                .disabled(model.isCheckingUpdate)
                Spacer()
            }

            if let message = model.updateMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Text("Обновлённый yt-dlp сохраняется в Application Support. Встроенная копия в приложении не изменяется.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(20)
        .frame(width: 560, height: 420)
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).textSelection(.enabled)
        }
    }

    private func firstLine(_ value: String) -> String {
        value.components(separatedBy: .newlines).first(where: { !$0.isEmpty }) ?? value
    }
}
