import AppKit
import Combine
import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published var urlText = ""
    @Published var jobs: [DownloadJob] = []
    @Published var history: [HistoryItem] = []
    @Published var saveFolder: URL
    @Published var urlError: String?
    @Published var ytdlpVersion = "—"
    @Published var ffmpegVersion = "—"
    @Published var ytdlpPathText = "—"
    @Published var ffmpegPathText = "—"
    @Published var ytdlpSourceText = "—"
    @Published var ffmpegSourceText = "—"
    @Published var updateMessage: String?
    @Published var isCheckingUpdate = false
    @Published var showingHistory = false
    @Published var showingSettings = false

    private var settings: AppSettings
    private var currentSession: CancellableSession?
    private var processingTask: Task<Void, Never>?
    private var isProcessing = false

    var displayedFolder: String {
        let path = saveFolder.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    var canAddToQueue: Bool {
        !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var activeJobID: UUID? {
        jobs.first(where: { $0.status.isActive })?.id
    }

    init() {
        settings = Persistence.loadSettings()
        saveFolder = URL(fileURLWithPath: settings.saveFolderPath)
        jobs = Persistence.loadQueue()
        history = Persistence.loadHistory()
        startProcessorIfNeeded()
        Task {
            refreshBinaryInfo()
            await maybeAutoUpdateYTDLP()
        }
    }

    func pasteFromClipboard() {
        let pasted = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        urlText = pasted
        urlError = pasted.isEmpty ? "Буфер обмена пуст." : nil
    }

    func addToQueue() {
        let raw = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        guard URLValidator.isVKVideoURL(raw), let normalized = URLValidator.normalizedURL(from: raw) else {
            urlError = DownloadError.invalidURL.localizedDescription
            return
        }
        urlError = nil
        let job = DownloadJob(url: normalized.absoluteString)
        jobs.append(job)
        persistQueue()
        urlText = ""
        DebugLog.info("Queued \(normalized.absoluteString)")
        startProcessorIfNeeded()
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Выбрать"
        panel.message = "Выберите папку для сохранения видео"
        panel.directoryURL = saveFolder
        if panel.runModal() == .OK, let url = panel.url {
            saveFolder = url
            settings.saveFolderPath = url.path
            Persistence.saveSettings(settings)
        }
    }

    func cancelJob(_ job: DownloadJob) {
        if job.status.isActive {
            DebugLog.info("Cancelling active job \(job.id)")
            currentSession?.cancel()
            updateJob(id: job.id) { item in
                item.status = .cancelled
                item.finishedAt = Date()
                item.speed = nil
                item.eta = nil
            }
            appendHistory(for: job.id, output: nil, size: nil, status: .cancelled)
        }
    }

    func removeFromQueue(_ job: DownloadJob) {
        guard job.status == .waiting else { return }
        jobs.removeAll { $0.id == job.id }
        persistQueue()
    }

    func clearFinished() {
        jobs.removeAll { $0.status.isFinished }
        persistQueue()
    }

    func reveal(url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    func clearHistory() {
        history.removeAll()
        Persistence.saveHistory(history)
    }

    func checkForYTDLPUpdates(force: Bool) {
        guard !isCheckingUpdate else { return }
        isCheckingUpdate = true
        updateMessage = "Проверка обновлений yt-dlp…"
        Task {
            let current = ytdlpVersion
            let result = await YTDLPUpdater.checkAndUpdate(currentVersion: current, force: force)
            settings.lastYTDLPCheck = Date()
            Persistence.saveSettings(settings)
            switch result {
            case .upToDate(let version):
                updateMessage = "yt-dlp уже актуален: \(version)"
            case .updated(let from, let to):
                updateMessage = "yt-dlp обновлён: \(from) → \(to)"
            case .failed(let message):
                updateMessage = "Не удалось проверить обновление: \(message)"
            }
            refreshBinaryInfo()
            isCheckingUpdate = false
        }
    }

    private func startProcessorIfNeeded() {
        guard processingTask == nil else { return }
        processingTask = Task { await processQueue() }
    }

    private func processQueue() async {
        while !Task.isCancelled {
            guard let job = jobs.first(where: { $0.status == .waiting }) else {
                processingTask = nil
                return
            }
            await run(job: job)
        }
        processingTask = nil
    }

    private func run(job: DownloadJob) async {
        let session = CancellableSession()
        currentSession = session
        updateJob(id: job.id) { item in
            item.status = .fetchingInfo
            item.errorMessage = nil
            item.progress = nil
            item.speed = nil
            item.eta = nil
        }

        do {
            let binaries = try BinaryLocator.locate()
            refreshBinaryInfo(with: binaries)
            DebugLog.info("Starting download job \(job.id) using yt-dlp=\(binaries.ytdlp.path) ffmpeg=\(binaries.ffmpeg.path)")
            let output = try await DownloadService.download(
                videoURL: job.url,
                destinationFolder: saveFolder,
                binaries: binaries,
                session: session
            ) { [weak self] event in
                Task { @MainActor in
                    self?.handle(event, jobID: job.id)
                }
            }
            let size = (try? FileManager.default.attributesOfItem(atPath: output.path)[.size] as? NSNumber)?.int64Value
            updateJob(id: job.id) { item in
                item.status = .completed
                item.outputPath = output.path
                item.progress = 1
                item.finishedAt = Date()
                item.speed = nil
                item.eta = nil
            }
            appendHistory(for: job.id, output: output, size: size, status: .completed)
            DebugLog.info("Job \(job.id) finished: \(output.path)")
        } catch is CancellationError {
            markCancelled(job.id)
        } catch let error as DownloadError where error == .cancelled {
            markCancelled(job.id)
        } catch {
            if session.isCancelled {
                markCancelled(job.id)
            } else {
                let message = (error as? LocalizedError)?.errorDescription ?? DownloadError.downloadFailed.localizedDescription
                DebugLog.error("Job \(job.id) failed: \(message)")
                updateJob(id: job.id) { item in
                    item.status = .failed
                    item.errorMessage = message
                    item.finishedAt = Date()
                }
                appendHistory(for: job.id, output: nil, size: nil, status: .failed)
            }
        }

        currentSession = nil
    }

    private func markCancelled(_ id: UUID) {
        var alreadyCancelled = false
        updateJob(id: id) { item in
            alreadyCancelled = item.status == .cancelled
            if !alreadyCancelled {
                item.status = .cancelled
                item.finishedAt = Date()
            }
            item.speed = nil
            item.eta = nil
        }
        if !alreadyCancelled {
            appendHistory(for: id, output: nil, size: nil, status: .cancelled)
        }
        DebugLog.info("Job \(id) cancelled")
    }

    private func handle(_ event: DownloadEvent, jobID: UUID) {
        switch event {
        case .status:
            break
        case .phase(let phase):
            updateJob(id: jobID) { item in
                if item.status.isActive || item.status == .waiting {
                    item.status = phase
                }
            }
        case .title(let title):
            updateJob(id: jobID) { item in
                item.title = title
            }
        case .progress(let snapshot):
            updateJob(id: jobID) { item in
                if let percent = snapshot.percent { item.progress = percent }
                if let speed = snapshot.speed { item.speed = speed }
                if let eta = snapshot.eta { item.eta = eta }
            }
        case .log(let chunk):
            DebugLog.raw(chunk)
        }
    }

    private func updateJob(id: UUID, mutate: (inout DownloadJob) -> Void) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        mutate(&jobs[index])
        persistQueue()
    }

    private func appendHistory(for jobID: UUID, output: URL?, size: Int64?, status: JobStatus) {
        guard let job = jobs.first(where: { $0.id == jobID }) else { return }
        let item = HistoryItem(
            id: UUID(),
            url: job.url,
            title: job.displayTitle,
            finishedAt: Date(),
            outputPath: output?.path ?? job.outputPath,
            status: status,
            fileSize: size
        )
        history.insert(item, at: 0)
        if history.count > 200 {
            history = Array(history.prefix(200))
        }
        Persistence.saveHistory(history)
    }

    private func persistQueue() {
        Persistence.saveQueue(jobs)
    }

    func refreshBinaryInfo(with binaries: BinaryLocator.Paths? = nil) {
        do {
            let located = try binaries ?? BinaryLocator.locate()
            ytdlpPathText = located.ytdlp.path
            ffmpegPathText = located.ffmpeg.path
            ytdlpSourceText = sourceLabel(located.ytdlpSource)
            ffmpegSourceText = sourceLabel(located.ffmpegSource)
            ytdlpVersion = BinaryLocator.version(of: located.ytdlp)
            ffmpegVersion = BinaryLocator.version(of: located.ffmpeg, arguments: ["-version"])
            DebugLog.info("Resolved binaries: yt-dlp \(ytdlpVersion) at \(located.ytdlp.path) [\(located.ytdlpSource.rawValue)]")
            DebugLog.info("Resolved binaries: ffmpeg \(ffmpegVersion) at \(located.ffmpeg.path) [\(located.ffmpegSource.rawValue)]")
        } catch {
            ytdlpPathText = error.localizedDescription
            ffmpegPathText = error.localizedDescription
        }
    }

    private func sourceLabel(_ source: BinaryLocator.BinarySource) -> String {
        switch source {
        case .managed: return "управляемая копия"
        case .bundled: return "встроенная"
        case .systemFallback: return "системный fallback"
        }
    }

    private func maybeAutoUpdateYTDLP() async {
        let last = settings.lastYTDLPCheck
        if let last, Date().timeIntervalSince(last) < 24 * 60 * 60 {
            return
        }
        checkForYTDLPUpdates(force: false)
    }
}

extension DownloadError: Equatable {}
