#!/bin/zsh
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

ROOT="$(cd "$(dirname "$0")" && pwd)"
DEST="$ROOT/Resources/bin"
mkdir -p "$DEST" "$DEST/arm64"

YTDLP_VERSION="2026.08.19"
YTDLP_URL="https://github.com/yt-dlp/yt-dlp/releases/download/${YTDLP_VERSION}/yt-dlp_macos"
FFMPEG_ARM_URL="https://github.com/eugeneware/ffmpeg-static/releases/download/b6.1.1/ffmpeg-darwin-arm64"
FFPROBE_ARM_URL="https://github.com/eugeneware/ffmpeg-static/releases/download/b6.1.1/ffprobe-darwin-arm64"

# Production ships Apple Silicon ffmpeg/ffprobe only. Intel slices from
# eugeneware/evermeet are not a trusted dependency and must not be bundled.
rm -rf "$DEST/x86_64"

is_arm64_only() {
  local info
  info="$(/usr/bin/lipo -info "$1" 2>/dev/null || true)"
  print -- "$info" | grep -q "arm64" || return 1
  print -- "$info" | grep -q "x86_64" && return 1
  return 0
}

need_ytdlp=0
need_ffmpeg=0
[[ -x "$DEST/yt-dlp" ]] || need_ytdlp=1
[[ -x "$DEST/arm64/ffmpeg" && -x "$DEST/arm64/ffprobe" ]] || need_ffmpeg=1
if [[ -x "$DEST/ffmpeg" ]] && ! is_arm64_only "$DEST/ffmpeg"; then
  need_ffmpeg=1
fi
if [[ -x "$DEST/ffprobe" ]] && ! is_arm64_only "$DEST/ffprobe"; then
  need_ffmpeg=1
fi

if [[ "$need_ytdlp" -eq 0 && "$need_ffmpeg" -eq 0 && "${1:-}" != "--force" ]]; then
  echo "Bundled binaries already present (yt-dlp + Apple Silicon ffmpeg/ffprobe) in $DEST"
  exit 0
fi

assert_no_unwanted_libs() {
  local libs
  libs="$(otool -L "$1")"
  if print -- "$libs" | grep -E '/opt/homebrew|/usr/local|@rpath|@executable_path|@loader_path' >/dev/null; then
    echo "error: $1 has unwanted library dependencies" >&2
    print -- "$libs" >&2
    exit 1
  fi
}

assert_arch() {
  local binary="$1"
  local arch="$2"
  /usr/bin/file "$binary" | /usr/bin/grep -q "$arch" || {
    echo "error: $binary is not $arch" >&2
    /usr/bin/file "$binary" >&2
    exit 1
  }
}

assert_not_intel() {
  if /usr/bin/lipo -info "$1" 2>/dev/null | grep -q "x86_64"; then
    echo "error: $1 still contains an Intel slice" >&2
    /usr/bin/lipo -info "$1" >&2
    exit 1
  fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [[ "$need_ytdlp" -eq 1 || "${1:-}" == "--force" ]]; then
  echo "Downloading official yt-dlp_macos ${YTDLP_VERSION}…"
  curl -fL --retry 3 -o "$TMP/yt-dlp" "$YTDLP_URL"
  chmod +x "$TMP/yt-dlp"
  xattr -dr com.apple.quarantine "$TMP/yt-dlp" >/dev/null 2>&1 || true
  assert_no_unwanted_libs "$TMP/yt-dlp"
  if ! "$TMP/yt-dlp" --version >/dev/null; then
    echo "warning: yt-dlp --version failed in this environment; continuing after Mach-O checks"
  fi
  cp "$TMP/yt-dlp" "$DEST/yt-dlp"
  chmod +x "$DEST/yt-dlp"
fi

if [[ "$need_ffmpeg" -eq 1 || "${1:-}" == "--force" ]]; then
  if [[ -x "$DEST/arm64/ffmpeg" && -x "$DEST/arm64/ffprobe" && "${1:-}" != "--force" ]]; then
    echo "Reusing existing Apple Silicon ffmpeg/ffprobe; not fetching Intel binaries"
    cp "$DEST/arm64/ffmpeg" "$DEST/ffmpeg"
    cp "$DEST/arm64/ffprobe" "$DEST/ffprobe"
  else
    echo "Downloading static ffmpeg/ffprobe arm64 only…"
    curl -fL --retry 3 -o "$TMP/ffmpeg-arm64" "$FFMPEG_ARM_URL"
    curl -fL --retry 3 -o "$TMP/ffprobe-arm64" "$FFPROBE_ARM_URL"
    chmod +x "$TMP/ffmpeg-arm64" "$TMP/ffprobe-arm64"
    xattr -dr com.apple.quarantine "$TMP" >/dev/null 2>&1 || true
    assert_arch "$TMP/ffmpeg-arm64" "arm64"
    assert_arch "$TMP/ffprobe-arm64" "arm64"
    assert_not_intel "$TMP/ffmpeg-arm64"
    assert_not_intel "$TMP/ffprobe-arm64"
    assert_no_unwanted_libs "$TMP/ffmpeg-arm64"
    assert_no_unwanted_libs "$TMP/ffprobe-arm64"
    if [[ "$(uname -m)" == "arm64" ]]; then
      "$TMP/ffmpeg-arm64" -version >/dev/null
      "$TMP/ffprobe-arm64" -version >/dev/null
    fi
    cp "$TMP/ffmpeg-arm64" "$DEST/arm64/ffmpeg"
    cp "$TMP/ffprobe-arm64" "$DEST/arm64/ffprobe"
    cp "$TMP/ffmpeg-arm64" "$DEST/ffmpeg"
    cp "$TMP/ffprobe-arm64" "$DEST/ffprobe"
  fi
  chmod +x "$DEST/ffmpeg" "$DEST/ffprobe" "$DEST/arm64/ffmpeg" "$DEST/arm64/ffprobe"
fi

rm -rf "$DEST/x86_64"
chmod +x "$DEST/yt-dlp" "$DEST/ffmpeg" "$DEST/ffprobe" "$DEST/arm64/ffmpeg" "$DEST/arm64/ffprobe"
assert_not_intel "$DEST/ffmpeg"
assert_not_intel "$DEST/ffprobe"
assert_not_intel "$DEST/arm64/ffmpeg"
assert_not_intel "$DEST/arm64/ffprobe"
assert_no_unwanted_libs "$DEST/ffmpeg"
assert_no_unwanted_libs "$DEST/ffprobe"
assert_no_unwanted_libs "$DEST/yt-dlp"

echo "Installed bundled binaries to $DEST"
file "$DEST/yt-dlp" "$DEST/ffmpeg" "$DEST/ffprobe"
lipo -info "$DEST/yt-dlp" "$DEST/ffmpeg" "$DEST/ffprobe"
