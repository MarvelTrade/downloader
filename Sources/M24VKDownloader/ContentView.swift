import SwiftUI

struct DownloaderView: View {
    @ObservedObject var model: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                downloadCard
                queueSection
                folderCard
            }
            .padding(24)
        }
    }

    private var downloadCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) { downloadHeading; Spacer(); thumbnailToggle }
                VStack(alignment: .leading, spacing: 8) { downloadHeading; thumbnailToggle }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { linkField; downloadButton }
                VStack(alignment: .leading, spacing: 10) { linkField; downloadButton }
            }

            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("YouTube · Shorts · Instagram · TikTok · VK · OK · RuTube · новостные сайты")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let error = model.urlError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .background(Color.accentColor.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.accentColor.opacity(0.14), lineWidth: 1)
        }
    }

    private var downloadHeading: some View {
        VStack(alignment: .leading, spacing: 3) {
                    Text("Скачать по ссылке")
                        .font(.title3.weight(.semibold))
                    Text("Вставьте ссылку на видео")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
        }
    }

    private var thumbnailToggle: some View {
        Toggle("Обложка JPG", isOn: $model.downloadThumbnail)
            .toggleStyle(.switch)
            .controlSize(.small)
            .help("Для видео, если источник предоставляет обложку")
    }

    private var linkField: some View {
        HStack(spacing: 8) {
                    Image(systemName: "link")
                        .foregroundStyle(.secondary)
                    TextField("https://…", text: $model.urlText)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .onSubmit { model.addToQueue() }
                        .accessibilityLabel("Ссылка на видео")
                    Button { model.pasteFromClipboard() } label: {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Вставить из буфера обмена")
                    .accessibilityLabel("Вставить")
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(.background, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.65), lineWidth: 1)
        }
    }

    private var downloadButton: some View {
        Button { model.addToQueue() } label: {
                    Label("Скачать", systemImage: "arrow.down")
                        .fontWeight(.semibold)
                        .frame(minWidth: 102)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!model.canAddToQueue)
                .keyboardShortcut(.return, modifiers: .command)
                .accessibilityLabel("Добавить в очередь")
    }

    private var queueSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Очередь")
                    .font(.title3.weight(.semibold))
                Text("\(model.jobs.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
                Spacer()
                Button("Очистить завершённые") { model.clearFinished() }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .disabled(!model.jobs.contains(where: { $0.status.isFinished }))
            }

            if model.jobs.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("Очередь пока пуста")
                        .font(.headline)
                    Text("Добавьте ссылку — загрузка начнётся автоматически")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 190)
                .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(model.jobs) { job in
                            QueueRow(
                                job: job,
                                onCancel: { model.cancelJob(job) },
                                onRemove: { model.removeFromQueue(job) },
                                onReveal: {
                                    if let url = job.outputURL { model.reveal(url: url) }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 1)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var folderCard: some View {
        ViewThatFits(in: .horizontal) {
          HStack(spacing: 12) { folderInfo; Spacer(); folderButtons }
          VStack(alignment: .leading, spacing: 10) { folderInfo; folderButtons }
        }
        .padding(14)
        .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var folderInfo: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.1))
                Image(systemName: "folder.fill")
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("Папка сохранения")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(model.displayedFolder)
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .help(model.saveFolder.path)
            }
        }
    }

    private var folderButtons: some View {
        HStack(spacing: 8) {
            Button("Открыть") { model.openSaveFolder() }
                .buttonStyle(.bordered)
            Button("Изменить…") { model.chooseFolder() }
                .buttonStyle(.bordered)
        }
    }
}

private struct QueueRow: View {
    let job: DownloadJob
    let onCancel: () -> Void
    let onRemove: () -> Void
    let onReveal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                sourceIcon
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.privateDisplayTitle)
                        .font(.headline)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(job.sourceSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 12)
                Text(job.status.displayName)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.12), in: Capsule())
                    .foregroundStyle(statusColor)
                    .fixedSize()
            }

            HStack(spacing: 12) {
                if let source = URLValidator.source(from: job.url) {
                    Text(source.displayName)
                }
                if job.downloadThumbnail,
                   case .video(let videoSource) = URLValidator.source(from: job.url),
                   videoSource != .instagram {
                    Label("с обложкой", systemImage: "photo")
                }
                if let size = job.fileSize, size > 0 {
                    Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if job.status.isActive || (job.progress ?? 0) > 0 {
                ProgressView(value: job.progress ?? 0)
                    .tint(statusColor)
                HStack {
                    if let progress = job.progress {
                        Text("\(Int((progress * 100).rounded()))%")
                            .font(.caption.monospacedDigit())
                    } else {
                        Text(job.status.displayName)
                            .font(.caption)
                    }
                    Spacer()
                    if let speed = job.speed { Text(speed) }
                    if let eta = job.eta, job.status.isActive { Text("осталось \(eta)") }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let message = job.errorMessage, job.status == .failed {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(job.status == .failed ? Color.red : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if job.status.isActive || job.status == .waiting || job.outputURL != nil {
                HStack {
                    if job.status.isActive {
                        Button("Отменить", action: onCancel)
                    }
                    if job.status == .waiting {
                        Button("Удалить", action: onRemove)
                    }
                    if job.status == .completed, job.outputURL != nil {
                        Button("Показать в Finder", action: onReveal)
                    }
                    Spacer()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
        }
    }

    private var sourceIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(statusColor.opacity(0.1))
            Image(systemName: "play.rectangle.fill")
                .foregroundStyle(statusColor)
        }
        .frame(width: 34, height: 34)
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
