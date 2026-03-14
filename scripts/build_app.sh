#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_DIR="$ROOT_DIR/dist/Ready Room.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$ROOT_DIR/dist"

pushd "$ROOT_DIR" >/dev/null
swift build -c release --product ReadyRoomApp
popd >/dev/null

cp "$BUILD_DIR/ReadyRoomApp" "$MACOS_DIR/Ready Room"
cp "$ROOT_DIR/Sources/App/Info.plist" "$CONTENTS_DIR/Info.plist"

echo "Built $APP_DIR"
