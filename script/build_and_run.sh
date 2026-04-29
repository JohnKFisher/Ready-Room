#!/bin/zsh
set -euo pipefail

MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Ready Room"
PRODUCT_NAME="ReadyRoomApp"
BUNDLE_ID="com.jkfisher.readyroom"
MIN_SYSTEM_VERSION="15.0"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
PLIST_TEMPLATE="$ROOT_DIR/Sources/App/Info.plist"
ICONSET_DIR="$ROOT_DIR/Sources/App/Resources/AppIcon.iconset"
ICNS_PATH="$APP_RESOURCES/AppIcon.icns"

usage() {
  echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
}

kill_existing() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  pkill -x "$PRODUCT_NAME" >/dev/null 2>&1 || true
}

stage_app() {
  pushd "$ROOT_DIR" >/dev/null
  swift build --product "$PRODUCT_NAME"
  local build_binary
  build_binary="$(swift build --product "$PRODUCT_NAME" --show-bin-path)/$PRODUCT_NAME"
  popd >/dev/null

  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_MACOS" "$APP_RESOURCES"
  cp "$build_binary" "$APP_BINARY"
  chmod +x "$APP_BINARY"

  cp "$PLIST_TEMPLATE" "$INFO_PLIST"
  /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $APP_NAME" "$INFO_PLIST"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$INFO_PLIST"
  /usr/libexec/PlistBuddy -c "Set :LSMinimumSystemVersion $MIN_SYSTEM_VERSION" "$INFO_PLIST"
  /usr/libexec/PlistBuddy -c "Add :NSPrincipalClass string NSApplication" "$INFO_PLIST" >/dev/null 2>&1 || \
    /usr/libexec/PlistBuddy -c "Set :NSPrincipalClass NSApplication" "$INFO_PLIST"

  if [[ -d "$ICONSET_DIR" ]]; then
    iconutil --convert icns "$ICONSET_DIR" --output "$ICNS_PATH"
  fi
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

kill_existing
stage_app

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    usage
    exit 2
    ;;
esac
