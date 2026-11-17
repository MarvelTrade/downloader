# M24VKDownloader release notes

## 1.6.0

- Добавлены отдельные разделы «Библиотека» и «Моя библиотека» с сохраняемым wishlist.
- Добавлен официальный поиск Project Gutenberg (легальный EPUB), Open Library и Google Books (метаданные).
- Добавлены confidence-сопоставление, безопасная обработка неоднозначных результатов и ISBN-дедупликация.
- Добавлен импорт локальных PDF, EPUB и FB2 без копирования файлов, каталог библиотеки и статус будущей индексации.
- Существующие очереди видео и Flibusta сохранены без изменения форматов и сетевых сценариев.

## 1.4.0

- Added public video downloads from YouTube (including Shorts), Instagram, TikTok, OK.ru, RuTube, and M24.ru
- Kept the existing VK / VK Video download pipeline and MP4 output behavior
- Added source detection, source labels, and clearer authentication/network/source errors
- YouTube downloads prefer H.264 video and AAC audio when those formats are available
- Instagram downloads never create a separate thumbnail or metadata sidecar
- Optional JPG thumbnail downloads remain available for other supported sources

## 1.3.0 (in progress)

- Custom macOS app icon (original artwork; no third-party trademarks)
- Version bump to 1.3.0 (Apple Silicon / arm64)
- Production Developer ID signing — **blocked**: no valid `Developer ID Application` identity on this Mac
- Hardened Runtime / Apple notarization / stapled DMG — **not started** until Developer ID + notary credentials are available

## 1.2.1

- Apple Silicon production build (`arm64`)
- Bundled official standalone `yt-dlp`
- Bundled Apple Silicon `ffmpeg` / `ffprobe` (no Intel production slice)
- No Homebrew dependency for downloads
- No user Python dependency for downloads
- yt-dlp updater skips download when already current
# 1.5.0

- Добавлена поддержка каталогов, тегов, авторов, серий и отдельных книг Flibusta.
- Каталог раскрывается в последовательную очередь PDF-книг с защитой от дублей и циклической пагинации.
- Добавлены состояния «Уже скачано» и «PDF недоступен», размеры файлов и сводка по книжной очереди.
- PDF скачивается потоково, проверяется по HTTP-ответу и сигнатуре файла; EPUB/FB2 не подменяют отсутствующий PDF.
