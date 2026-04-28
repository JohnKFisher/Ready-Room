#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="Ready Room"
PACKAGING_TMP_ROOT="${TMPDIR:-/tmp}/ready-room-release-packaging"
PACKAGE_DIR="$PACKAGING_TMP_ROOT/package"
APP_DIR="$PACKAGE_DIR/$APP_NAME.app"
DIST_APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$ROOT_DIR/Sources/App/Resources/AppIcon.iconset"
PLIST_TEMPLATE_PATH="$ROOT_DIR/Sources/App/Info.plist"
VERSION_FILE="$ROOT_DIR/VERSION"
LAST_VERSION_FILE="$ROOT_DIR/LAST_BUILT_VERSION"
BUILD_NUMBER_FILE="$ROOT_DIR/BUILD_NUMBER"
GENERATED_DIR="$ROOT_DIR/.build/release-packaging"
GENERATED_PLIST="$GENERATED_DIR/ReadyRoom-Info.plist"
GENERATED_ICNS="$GENERATED_DIR/AppIcon.icns"
ARM64_SCRATCH="$ROOT_DIR/.build/release-arm64"
X86_64_SCRATCH="$ROOT_DIR/.build/release-x86_64"
ARM64_TRIPLE="arm64-apple-macosx15.0"
X86_64_TRIPLE="x86_64-apple-macosx15.0"
DMG_STAGE_DIR="$PACKAGING_TMP_ROOT/dmg-stage"

read_trimmed_file() {
  tr -d '[:space:]' < "$1"
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$PLIST_TEMPLATE_PATH"
}

current_version="$(read_trimmed_file "$VERSION_FILE")"
last_built_version="$(read_trimmed_file "$LAST_VERSION_FILE")"
current_build_number="$(read_trimmed_file "$BUILD_NUMBER_FILE")"
plist_version="$(plist_value CFBundleShortVersionString)"
plist_build_number="$(plist_value CFBundleVersion)"

if [[ ! "$current_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "VERSION must use semantic version format major.minor.patch" >&2
  exit 1
fi

if [[ ! "$current_build_number" =~ ^[0-9]+$ ]]; then
  echo "BUILD_NUMBER must be an integer" >&2
  exit 1
fi

if [[ "$last_built_version" != "$current_version" ]]; then
  echo "LAST_BUILT_VERSION ($last_built_version) must match VERSION ($current_version)" >&2
  exit 1
fi

if [[ "$plist_version" != "$current_version" ]]; then
  echo "Info.plist CFBundleShortVersionString ($plist_version) must match VERSION ($current_version)" >&2
  exit 1
fi

if [[ "$plist_build_number" != "$current_build_number" ]]; then
  echo "Info.plist CFBundleVersion ($plist_build_number) must match BUILD_NUMBER ($current_build_number)" >&2
  exit 1
fi

if [[ ! -d "$ICONSET_DIR" ]]; then
  echo "Missing app icon source set at $ICONSET_DIR" >&2
  exit 1
fi

DMG_PATH="$DIST_DIR/Ready-Room-v$current_version-$current_build_number-universal.dmg"

echo "Building Ready Room universal DMG version $current_version ($current_build_number)"

rm -rf "$PACKAGING_TMP_ROOT" "$DIST_APP_DIR" "$DMG_PATH"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$GENERATED_DIR" "$DIST_DIR"

build_slice() {
  local triple="$1"
  local scratch_path="$2"
  local bin_path

  swift build -c release --product ReadyRoomApp --triple "$triple" --scratch-path "$scratch_path" >&2
  bin_path="$(swift build -c release --product ReadyRoomApp --triple "$triple" --scratch-path "$scratch_path" --show-bin-path)"
  printf '%s/ReadyRoomApp\n' "$bin_path"
}

arm64_binary="$(build_slice "$ARM64_TRIPLE" "$ARM64_SCRATCH")"
x86_64_binary="$(build_slice "$X86_64_TRIPLE" "$X86_64_SCRATCH")"

cp "$PLIST_TEMPLATE_PATH" "$GENERATED_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $current_version" "$GENERATED_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $current_build_number" "$GENERATED_PLIST"

iconutil --convert icns "$ICONSET_DIR" --output "$GENERATED_ICNS"
lipo -create "$arm64_binary" "$x86_64_binary" -output "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

archs="$(lipo -archs "$MACOS_DIR/$APP_NAME")"
if [[ "$archs" != *"arm64"* || "$archs" != *"x86_64"* ]]; then
  echo "Universal executable is missing an expected architecture: $archs" >&2
  exit 1
fi

cp "$GENERATED_PLIST" "$CONTENTS_DIR/Info.plist"
cp "$GENERATED_ICNS" "$RESOURCES_DIR/AppIcon.icns"

xattr -cr "$APP_DIR"
codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

mkdir -p "$DMG_STAGE_DIR"
ditto --noextattr --noqtn "$APP_DIR" "$DMG_STAGE_DIR/$APP_NAME.app"
xattr -cr "$DMG_STAGE_DIR"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGE_DIR" -format UDZO "$DMG_PATH"
hdiutil verify "$DMG_PATH"
xattr -cr "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "Built $DMG_PATH"
