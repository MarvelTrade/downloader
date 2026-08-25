import SwiftUI

struct ContentView: View {
    @StateObject private var model = AppViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            urlBar
            queueList
            footer
        }
        .padding(20)
        .frame(minWidth: 720, minHeight: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $model.showingHistory) {
            HistoryView(model: model)
        }
        .sheet(isPresented: $model.showingSettings) {
            SettingsView(model: model)
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("M24 VK Downloader")
                    .font(.title2.weight(.semibold))
                Text("Очередь загрузок VK в MP4")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("История") { model.showingHistory = true }
                .accessibilityLabel("История")
            Button("Настройки") { model.showingSettings = true }
                .accessibilityLabel("Настройки")
        }
    }

    private var urlBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ссылка на видео VK")
                .font(.headline)
            HStack(spacing: 8) {
                TextField("https://vk.com/video…", text: $model.urlText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Ссылка на видео VK")
                    .onSubmit { model.addToQueue() }
                Button("Вставить") { model.pasteFromClipboard() }
                    .accessibilityLabel("Вставить")
                Button("Добавить в очередь") { model.addToQueue() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.canAddToQueue)
                    .accessibilityLabel("Добавить в очередь")
            }
            if let error = model.urlError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var queueList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Очередь")
                .font(.headline)
            if model.jobs.isEmpty {
                Text("Очередь пуста. Добавьте ссылку VK.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
                    .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(model.jobs) { job in
                            QueueRow(
                                job: job,
                                onCancel: { model.cancelJob(job) },
                                onRemove: { model.removeFromQueue(job) },
                                onReveal: {
                                    if let url = job.outputURL {
                                        model.reveal(url: url)
                                    }
                                }
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 220)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Папка сохранения")
                .font(.headline)
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.secondary)
                Text(model.displayedFolder)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .help(model.saveFolder.path)
                Spacer()
                Button("Выбрать папку") { model.chooseFolder() }
                Button("Очистить завершённые") { model.clearFinished() }
                    .disabled(!model.jobs.contains(where: { $0.status.isFinished }))
            }
            .padding(10)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private struct QueueRow: View {
    let job: DownloadJob
    let onCancel: () -> Void
    let onRemove: () -> Void
    let onReveal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(job.displayTitle)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                Text(job.status.displayName)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(statusColor)
            }
            Text(job.url)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            if job.status.isActive || (job.progress ?? 0) > 0 {
                ProgressView(value: job.progress ?? 0)
                HStack {
                    if let progress = job.progress {
                        Text("\(Int((progress * 100).rounded()))%")
                            .font(.caption.monospacedDigit())
                    }
                    Spacer()
                    if let speed = job.speed {
                        Text(speed).font(.caption).foregroundStyle(.secondary)
                    }
                    if let eta = job.eta, job.status.isActive {
                        Text("осталось \(eta)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            if let error = job.errorMessage, job.status == .failed {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            HStack {
                if job.status.isActive {
                    Button("Отменить", action: onCancel)
                        .accessibilityLabel("Отменить")
                }
                if job.status == .waiting {
                    Button("Удалить из очереди", action: onRemove)
                }
                if job.status == .completed, job.outputURL != nil {
                    Button("Показать в Finder", action: onReveal)
                }
                Spacer()
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var statusColor: Color {
        switch job.status {
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .secondary
        case .waiting: return .orange
        default: return .blue
        }
    }
}
