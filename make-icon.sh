#!/bin/zsh
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

ROOT="$(cd "$(dirname "$0")" && pwd)"
MASTER="$ROOT/assets/icon/M24VKDownloader-icon-master-1024.png"
OUT_ICNS="$ROOT/assets/icon/M24VKDownloader.icns"

if [[ ! -f "$MASTER" ]]; then
  echo "error: missing $MASTER" >&2
  exit 1
fi

# iconutil is sensitive to workspace xattrs; build the iconset in /tmp.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp "$MASTER" "$WORK/master.png"
python3 - <<PY
from PIL import Image
img = Image.open("$WORK/master.png").convert("RGBA")
img.save("$WORK/master.png")
PY

ICONSET="$WORK/M24VKDownloader.iconset"
mkdir -p "$ICONSET"
for spec in \
  "16:icon_16x16.png" \
  "32:icon_16x16@2x.png" \
  "32:icon_32x32.png" \
  "64:icon_32x32@2x.png" \
  "128:icon_128x128.png" \
  "256:icon_128x128@2x.png" \
  "256:icon_256x256.png" \
  "512:icon_256x256@2x.png" \
  "512:icon_512x512.png" \
  "1024:icon_512x512@2x.png"
do
  px="${spec%%:*}"
  name="${spec#*:}"
  sips -z "$px" "$px" "$WORK/master.png" --out "$ICONSET/$name" >/dev/null
done
find "$ICONSET" -exec xattr -c {} \; 2>/dev/null || true
iconutil -c icns "$ICONSET" -o "$WORK/M24VKDownloader.icns"

rm -rf "$ROOT/assets/icon/M24VKDownloader.iconset"
mkdir -p "$ROOT/assets/icon"
ditto "$ICONSET" "$ROOT/assets/icon/M24VKDownloader.iconset"
cp "$WORK/M24VKDownloader.icns" "$OUT_ICNS"
mkdir -p "$ROOT/Resources"
cp "$OUT_ICNS" "$ROOT/Resources/M24VKDownloader.icns"
file "$OUT_ICNS"
echo "Wrote $OUT_ICNS"
