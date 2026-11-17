import Foundation

enum DownloadError: LocalizedError {
    case ytdlpNotFound
    case ffmpegNotFound
    case invalidURL
    case videoUnavailable
    case authRequired
    case networkError
    case sourceUnavailable
    case downloadFailed
    case diskFull
    case emptyResult
    case cancelled

    var errorDescription: String? {
        switch self {
        case .ytdlpNotFound:
            return "Не удалось найти yt-dlp"
        case .ffmpegNotFound:
            return "Не удалось найти ffmpeg"
        case .invalidURL:
            return "Ссылка не поддерживается"
        case .videoUnavailable:
            return "Видео недоступно"
        case .authRequired:
            return "Для этого видео требуется авторизация"
        case .networkError:
            return "Ошибка сети"
        case .sourceUnavailable:
            return "Источник временно не отвечает"
        case .downloadFailed:
            return "Не удалось получить видеопоток"
        case .diskFull:
            return "Недостаточно места на диске"
        case .emptyResult:
            return "Ошибка загрузки"
        case .cancelled:
            return "Загрузка отменена"
        }
    }
}
