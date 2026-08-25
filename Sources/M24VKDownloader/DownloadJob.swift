import Foundation

enum JobStatus: String, Codable, Equatable {
    case waiting
    case fetchingInfo
    case downloading
    case merging
    case completed
    case failed
    case cancelled

    var isActive: Bool {
        self == .fetchingInfo || self == .downloading || self == .merging
    }

    var isFinished: Bool {
        self == .completed || self == .failed || self == .cancelled
    }

    var displayName: String {
        switch self {
        case .waiting: return "Ожидает"
        case .fetchingInfo: return "Получение информации"
        case .downloading: return "Скачивание"
        case .merging: return "Объединение"
        case .completed: return "Готово"
        case .failed: return "Ошибка"
        case .cancelled: return "Отменено"
        }
    }
}

struct DownloadJob: Identifiable, Codable, Equatable {
    var id: UUID
    var url: String
    var title: String?
    var status: JobStatus
    var progress: Double?
    var speed: String?
    var eta: String?
    var outputPath: String?
    var errorMessage: String?
    var createdAt: Date
    var finishedAt: Date?

    init(
        id: UUID = UUID(),
        url: String,
        title: String? = nil,
        status: JobStatus = .waiting,
        progress: Double? = nil,
        speed: String? = nil,
        eta: String? = nil,
        outputPath: String? = nil,
        errorMessage: String? = nil,
        createdAt: Date = Date(),
        finishedAt: Date? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.status = status
        self.progress = progress
        self.speed = speed
        self.eta = eta
        self.outputPath = outputPath
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.finishedAt = finishedAt
    }

    var displayTitle: String {
        if let title, !title.isEmpty { return title }
        return url
    }

    var outputURL: URL? {
        guard let outputPath else { return nil }
        return URL(fileURLWithPath: outputPath)
    }
}

struct HistoryItem: Identifiable, Codable, Equatable {
    var id: UUID
    var url: String
    var title: String
    var finishedAt: Date
    var outputPath: String?
    var status: JobStatus
    var fileSize: Int64?

    var outputURL: URL? {
        guard let outputPath else { return nil }
        return URL(fileURLWithPath: outputPath)
    }

    var fileExists: Bool {
        guard let outputPath else { return false }
        return FileManager.default.fileExists(atPath: outputPath)
    }
}

struct AppSettings: Codable, Equatable {
    var saveFolderPath: String
    var lastYTDLPCheck: Date?
}

enum Persistence {
    static func loadSettings() -> AppSettings {
        let fallback = AppSettings(
            saveFolderPath: (FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")).path,
            lastYTDLPCheck: nil
        )
        guard let data = try? Data(contentsOf: AppPaths.settingsFile),
              let settings = try? JSONDecoder.appDecoder.decode(AppSettings.self, from: data) else {
            return fallback
        }
        return settings
    }

    static func saveSettings(_ settings: AppSettings) {
        encode(settings, to: AppPaths.settingsFile)
    }

    static func loadQueue() -> [DownloadJob] {
        guard let data = try? Data(contentsOf: AppPaths.queueFile),
              var jobs = try? JSONDecoder.appDecoder.decode([DownloadJob].self, from: data) else {
            return []
        }
        for index in jobs.indices where jobs[index].status.isActive {
            jobs[index].status = .waiting
            jobs[index].progress = nil
            jobs[index].speed = nil
            jobs[index].eta = nil
            jobs[index].errorMessage = nil
        }
        return jobs
    }

    static func saveQueue(_ jobs: [DownloadJob]) {
        encode(jobs, to: AppPaths.queueFile)
    }

    static func loadHistory() -> [HistoryItem] {
        guard let data = try? Data(contentsOf: AppPaths.historyFile),
              let items = try? JSONDecoder.appDecoder.decode([HistoryItem].self, from: data) else {
            return []
        }
        return items
    }

    static func saveHistory(_ items: [HistoryItem]) {
        encode(items, to: AppPaths.historyFile)
    }

    private static func encode<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

extension JSONDecoder {
    static var appDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
