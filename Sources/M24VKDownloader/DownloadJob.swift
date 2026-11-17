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

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "resolving": self = .waiting
        case "alreadyExists": self = .completed
        case "pdfUnavailable": self = .failed
        default: self = JobStatus(rawValue: raw) ?? .failed
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
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
    var downloadThumbnail: Bool
    var fileSize: Int64?

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
        finishedAt: Date? = nil,
        downloadThumbnail: Bool = false,
        fileSize: Int64? = nil
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
        self.downloadThumbnail = downloadThumbnail
        self.fileSize = fileSize
    }

    private enum CodingKeys: String, CodingKey {
        case id, url, title, status, progress, speed, eta, outputPath, errorMessage
        case createdAt, finishedAt, downloadThumbnail, fileSize
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        url = try container.decode(String.self, forKey: .url)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        status = try container.decode(JobStatus.self, forKey: .status)
        progress = try container.decodeIfPresent(Double.self, forKey: .progress)
        speed = try container.decodeIfPresent(String.self, forKey: .speed)
        eta = try container.decodeIfPresent(String.self, forKey: .eta)
        outputPath = try container.decodeIfPresent(String.self, forKey: .outputPath)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        finishedAt = try container.decodeIfPresent(Date.self, forKey: .finishedAt)
        downloadThumbnail = try container.decodeIfPresent(Bool.self, forKey: .downloadThumbnail) ?? false
        fileSize = try container.decodeIfPresent(Int64.self, forKey: .fileSize)
    }

    var displayTitle: String {
        if let title, !title.isEmpty { return title }
        return url
    }

    var privateDisplayTitle: String {
        let candidate = displayTitle
        return candidate.localizedCaseInsensitiveContains("m24") ? "Скачанное видео" : candidate
    }

    var sourceSummary: String {
        guard let source = URLValidator.source(from: url) else { return "Источник видео" }
        return "Источник: \(source.displayName)"
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

    var privateDisplayTitle: String {
        title.localizedCaseInsensitiveContains("m24") ? "Скачанное видео" : title
    }

    var sourceSummary: String {
        guard let source = URLValidator.source(from: url) else { return "Источник видео" }
        return "Источник: \(source.displayName)"
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
        return jobs.filter { URLValidator.isSupportedVideoURL($0.url) }
    }

    static func saveQueue(_ jobs: [DownloadJob]) {
        encode(jobs, to: AppPaths.queueFile)
    }

    static func loadHistory() -> [HistoryItem] {
        guard let data = try? Data(contentsOf: AppPaths.historyFile),
              let items = try? JSONDecoder.appDecoder.decode([HistoryItem].self, from: data) else {
            return []
        }
        return items.filter { URLValidator.isSupportedVideoURL($0.url) }
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
