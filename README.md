# Загрузчик видео для macOS

Быстрое нативное приложение для Apple Silicon (macOS 14+) на базе `yt-dlp` и `ffmpeg`: скачивает видео и аудио по ссылке без рекламы, браузерных расширений и лишних сервисов.

**Автор:** [Антон Белый](https://github.com/MarvelTrade)

## Поддерживаемые площадки

- **YouTube** (`youtube.com`, `youtu.be`)
- **VK Видео** (`vk.com`, `vk.ru`, `vkvideo.ru`)
- **Instagram Reels** (`instagram.com`)
- **TikTok** (`tiktok.com`)
- **RuTube** (`rutube.ru`)
- **Одноклассники** (`ok.ru`)

## Возможности

- Очередь загрузок с живым прогресс-баром и отменой.
- Автоматическое обновление встроенного `yt-dlp` прямо из настроек.
- История скачанных видео и быстрый переход в Finder.
- Полностью нативная сборка под Apple Silicon (`arm64`).

## Сборка

```bash
chmod +x build.sh
./build.sh
```
