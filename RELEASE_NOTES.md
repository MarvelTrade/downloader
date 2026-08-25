# M24VKDownloader release notes

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
