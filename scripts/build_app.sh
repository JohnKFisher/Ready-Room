#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_DIR="$ROOT_DIR/dist/Ready Room.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$ROOT_DIR/Sources/App/Resources/AppIcon.iconset"
GENERATED_ICNS="$ROOT_DIR/.build/AppIcon.icns"
GENERATED_PLIST="$ROOT_DIR/.build/ReadyRoom-Info.plist"
VERSION_FILE="$ROOT_DIR/VERSION"
BUILD_NUMBER_FILE="$ROOT_DIR/BUILD_NUMBER"
PLIST_TEMPLATE_PATH="$ROOT_DIR/Sources/App/Info.plist"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$ROOT_DIR/dist"

current_version="$(tr -d '[:space:]' < "$VERSION_FILE")"
current_build_number="$(tr -d '[:space:]' < "$BUILD_NUMBER_FILE")"

if [[ ! "$current_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "VERSION must use semantic version format major.minor.patch" >&2
  exit 1
fi

if [[ ! "$current_build_number" =~ ^[0-9]+$ ]]; then
  echo "BUILD_NUMBER must be an integer" >&2
  exit 1
fi

cp "$PLIST_TEMPLATE_PATH" "$GENERATED_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $current_version" "$GENERATED_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $current_build_number" "$GENERATED_PLIST"

echo "Building Ready Room version $current_version ($current_build_number)"

pushd "$ROOT_DIR" >/dev/null
swift build -c release --product ReadyRoomApp
popd >/dev/null

if [[ ! -d "$ICONSET_DIR" ]]; then
  echo "Missing app icon source set at $ICONSET_DIR" >&2
  exit 1
fi

iconutil --convert icns "$ICONSET_DIR" --output "$GENERATED_ICNS"

cp "$BUILD_DIR/ReadyRoomApp" "$MACOS_DIR/Ready Room"
cp "$GENERATED_PLIST" "$CONTENTS_DIR/Info.plist"
cp "$GENERATED_ICNS" "$RESOURCES_DIR/AppIcon.icns"

echo "Built $APP_DIR"
