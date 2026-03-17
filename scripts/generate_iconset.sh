#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MASTER_SOURCE="${1:-$ROOT_DIR/design/app-icon/final/AppIcon-master.png}"
ICONSET_DIR="$ROOT_DIR/Sources/App/Resources/AppIcon.iconset"

if [[ ! -f "$MASTER_SOURCE" ]]; then
  echo "Missing master icon source: $MASTER_SOURCE" >&2
  exit 1
fi

mkdir -p "$(dirname "$ICONSET_DIR")"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

render_size() {
  local pixels="$1"
  local output_name="$2"
  sips -s format png -z "$pixels" "$pixels" "$MASTER_SOURCE" --out "$ICONSET_DIR/$output_name" >/dev/null
}

render_size 16 icon_16x16.png
render_size 32 icon_16x16@2x.png
render_size 32 icon_32x32.png
render_size 64 icon_32x32@2x.png
render_size 128 icon_128x128.png
render_size 256 icon_128x128@2x.png
render_size 256 icon_256x256.png
render_size 512 icon_256x256@2x.png
render_size 512 icon_512x512.png
render_size 1024 icon_512x512@2x.png

echo "Generated $ICONSET_DIR from $MASTER_SOURCE"
