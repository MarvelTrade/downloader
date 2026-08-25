#!/bin/zsh
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/dist/M24VKDownloader.app"
DEST="/Applications/M24VKDownloader.app"
ALIAS="$HOME/Desktop/M24VKDownloader"

if [[ ! -d "$SRC" ]]; then
  echo "error: missing $SRC" >&2
  exit 1
fi

killall M24VKDownloader 2>/dev/null || true
sleep 1
rm -rf "$DEST"
ditto "$SRC" "$DEST"
xattr -dr com.apple.quarantine "$DEST" >/dev/null 2>&1 || true
codesign --force --deep --sign - "$DEST" >/dev/null 2>&1 || true

echo "Installed $DEST"
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$DEST/Contents/Info.plist"
file "$DEST/Contents/MacOS/M24VKDownloader"
lipo -info "$DEST/Contents/MacOS/M24VKDownloader"
lipo -info "$DEST/Contents/Resources/bin/ffmpeg" "$DEST/Contents/Resources/bin/ffprobe" "$DEST/Contents/Resources/bin/yt-dlp"
if /usr/bin/lipo -info "$DEST/Contents/Resources/bin/ffmpeg" | grep -q "x86_64"; then
  echo "error: installed ffmpeg still contains Intel" >&2
  exit 1
fi
if [[ -d "$DEST/Contents/Resources/bin/x86_64" ]]; then
  echo "error: installed app still has Intel ffmpeg directory" >&2
  exit 1
fi

rm -f "$ALIAS" "$HOME/Desktop/M24VKDownloader.app" "$HOME/Desktop/M24VKDownloader.app alias" 2>/dev/null || true
osascript <<'APPLESCRIPT'
tell application "Finder"
  if exists file "M24VKDownloader" of desktop then
    delete file "M24VKDownloader" of desktop
  end if
  set src to POSIX file "/Applications/M24VKDownloader.app"
  set newAlias to make alias file to src at desktop
  set name of newAlias to "M24VKDownloader"
end tell
APPLESCRIPT

echo "==== alias ===="
ls -la "$ALIAS"
file "$ALIAS"
osascript <<'APPLESCRIPT'
tell application "Finder"
  set p to POSIX path of (original item of file "M24VKDownloader" of desktop as alias)
end tell
p
APPLESCRIPT
mdls -name kMDItemKind "$ALIAS" || true
