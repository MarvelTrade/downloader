import Foundation

enum DownloadError: LocalizedError {
    case ytdlpNotFound
    case ffmpegNotFound
    case invalidURL
    case videoUnavailable
    case vkAuthRequired
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
            return "Некорректная ссылка"
        case .videoUnavailable:
            return "Видео недоступно"
        case .vkAuthRequired:
            return "Для этого видео требуется авторизация VK"
        case .downloadFailed:
            return "Ошибка загрузки"
        case .diskFull:
            return "Недостаточно места на диске"
        case .emptyResult:
            return "Ошибка загрузки"
        case .cancelled:
            return "Загрузка отменена"
        }
    }
}
