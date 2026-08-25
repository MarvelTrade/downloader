#!/bin/zsh
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:${PATH:-}"

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

chmod +x "$ROOT/fetch-binaries.sh"
"$ROOT/fetch-binaries.sh"

if [[ -d "$ROOT/Resources/bin/x86_64" ]]; then
  echo "error: Intel ffmpeg/ffprobe must not be present in the production tree" >&2
  exit 1
fi
if /usr/bin/lipo -info "$ROOT/Resources/bin/ffmpeg" 2>/dev/null | grep -q "x86_64"; then
  echo "error: bundled ffmpeg still contains an Intel slice" >&2
  exit 1
fi

echo "Building M24VKDownloader (Apple Silicon)…"
swift package --disable-sandbox clean
swift build --disable-sandbox -c release --arch arm64

BIN=""
if [[ -x "$ROOT/.build/arm64-apple-macosx/release/M24VKDownloader" ]]; then
  BIN="$ROOT/.build/arm64-apple-macosx/release/M24VKDownloader"
elif [[ -x "$ROOT/.build/release/M24VKDownloader" ]]; then
  BIN="$ROOT/.build/release/M24VKDownloader"
else
  BIN="$(find "$ROOT/.build" -type f -name M24VKDownloader -perm -111 | head -n 1)"
fi

if [[ -z "$BIN" ]]; then
  echo "error: compiled binary not found" >&2
  exit 1
fi

APP="$ROOT/dist/M24VKDownloader.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources/bin/arm64"

ICNS="$ROOT/assets/icon/M24VKDownloader.icns"
if [[ ! -f "$ICNS" ]]; then
  echo "error: missing app icon $ICNS" >&2
  exit 1
fi

cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
cp "$BIN" "$APP/Contents/MacOS/M24VKDownloader"
cp "$ICNS" "$APP/Contents/Resources/M24VKDownloader.icns"
cp "$ROOT/Resources/bin/yt-dlp" "$APP/Contents/Resources/bin/yt-dlp"
cp "$ROOT/Resources/bin/ffmpeg" "$APP/Contents/Resources/bin/ffmpeg"
cp "$ROOT/Resources/bin/ffprobe" "$APP/Contents/Resources/bin/ffprobe"
cp "$ROOT/Resources/bin/arm64/ffmpeg" "$APP/Contents/Resources/bin/arm64/ffmpeg"
cp "$ROOT/Resources/bin/arm64/ffprobe" "$APP/Contents/Resources/bin/arm64/ffprobe"
chmod +x "$APP/Contents/MacOS/M24VKDownloader" \
  "$APP/Contents/Resources/bin/yt-dlp" \
  "$APP/Contents/Resources/bin/ffmpeg" \
  "$APP/Contents/Resources/bin/ffprobe" \
  "$APP/Contents/Resources/bin/arm64/ffmpeg" \
  "$APP/Contents/Resources/bin/arm64/ffprobe"
xattr -dr com.apple.quarantine "$APP" >/dev/null 2>&1 || true
echo -n "APPL????" > "$APP/Contents/PkgInfo"

# Local development only: ad-hoc signature so the unsigned build can launch.
# Production Developer ID signing/notarization is a separate release step.
if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - \
    "$APP/Contents/Resources/bin/yt-dlp" \
    "$APP/Contents/Resources/bin/ffmpeg" \
    "$APP/Contents/Resources/bin/ffprobe" \
    "$APP/Contents/Resources/bin/arm64/ffmpeg" \
    "$APP/Contents/Resources/bin/arm64/ffprobe" \
    "$APP/Contents/MacOS/M24VKDownloader" >/dev/null 2>&1 || true
  codesign --force --sign - "$APP" >/dev/null 2>&1 || true
fi

echo "Built $APP"
ls -la "$APP/Contents/Resources/M24VKDownloader.icns"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist"
file "$APP/Contents/MacOS/M24VKDownloader"
lipo -info "$APP/Contents/MacOS/M24VKDownloader"
file "$APP/Contents/Resources/bin/ffmpeg" "$APP/Contents/Resources/bin/ffprobe" "$APP/Contents/Resources/bin/yt-dlp"
lipo -info "$APP/Contents/Resources/bin/ffmpeg" "$APP/Contents/Resources/bin/ffprobe" "$APP/Contents/Resources/bin/yt-dlp"
if [[ -d "$APP/Contents/Resources/bin/x86_64" ]]; then
  echo "error: Intel binaries were copied into the app bundle" >&2
  exit 1
fi
