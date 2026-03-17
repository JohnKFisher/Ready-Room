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
VERSION_FILE="$ROOT_DIR/VERSION"
LAST_VERSION_FILE="$ROOT_DIR/LAST_BUILT_VERSION"
BUILD_NUMBER_FILE="$ROOT_DIR/BUILD_NUMBER"
PLIST_PATH="$ROOT_DIR/Sources/App/Info.plist"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$ROOT_DIR/dist"

current_version="$(tr -d '[:space:]' < "$VERSION_FILE")"
last_built_version="$(tr -d '[:space:]' < "$LAST_VERSION_FILE")"
current_build_number="$(tr -d '[:space:]' < "$BUILD_NUMBER_FILE")"

if [[ ! "$current_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "VERSION must use semantic version format major.minor.patch" >&2
  exit 1
fi

if [[ ! "$last_built_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "LAST_BUILT_VERSION must use semantic version format major.minor.patch" >&2
  exit 1
fi

if [[ ! "$current_build_number" =~ ^[0-9]+$ ]]; then
  echo "BUILD_NUMBER must be an integer" >&2
  exit 1
fi

IFS=. read -r current_major current_minor current_patch <<< "$current_version"
IFS=. read -r last_major last_minor last_patch <<< "$last_built_version"

if [[ "$current_major" != "$last_major" || "$current_minor" != "$last_minor" ]]; then
  next_version="${current_major}.${current_minor}.0"
else
  next_patch=$((current_patch + 1))
  next_version="${current_major}.${current_minor}.${next_patch}"
fi

next_build_number=$((current_build_number + 1))

printf '%s\n' "$next_version" > "$VERSION_FILE"
printf '%s\n' "$next_version" > "$LAST_VERSION_FILE"
printf '%s\n' "$next_build_number" > "$BUILD_NUMBER_FILE"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $next_version" "$PLIST_PATH"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $next_build_number" "$PLIST_PATH"

echo "Building Ready Room version $next_version ($next_build_number)"

pushd "$ROOT_DIR" >/dev/null
swift build -c release --product ReadyRoomApp
popd >/dev/null

if [[ ! -d "$ICONSET_DIR" ]]; then
  echo "Missing app icon source set at $ICONSET_DIR" >&2
  exit 1
fi

iconutil --convert icns "$ICONSET_DIR" --output "$GENERATED_ICNS"

cp "$BUILD_DIR/ReadyRoomApp" "$MACOS_DIR/Ready Room"
cp "$PLIST_PATH" "$CONTENTS_DIR/Info.plist"
cp "$GENERATED_ICNS" "$RESOURCES_DIR/AppIcon.icns"

echo "Built $APP_DIR"
