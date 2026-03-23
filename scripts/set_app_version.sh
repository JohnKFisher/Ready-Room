#!/bin/zsh
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <version> <build-number>" >&2
  echo "Example: $0 0.2.16 36" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="$ROOT_DIR/VERSION"
LAST_VERSION_FILE="$ROOT_DIR/LAST_BUILT_VERSION"
BUILD_NUMBER_FILE="$ROOT_DIR/BUILD_NUMBER"
PLIST_PATH="$ROOT_DIR/Sources/App/Info.plist"

next_version="$1"
next_build_number="$2"

if [[ ! "$next_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must use semantic version format major.minor.patch" >&2
  exit 1
fi

if [[ ! "$next_build_number" =~ ^[0-9]+$ ]]; then
  echo "Build number must be an integer" >&2
  exit 1
fi

printf '%s\n' "$next_version" > "$VERSION_FILE"
printf '%s\n' "$next_version" > "$LAST_VERSION_FILE"
printf '%s\n' "$next_build_number" > "$BUILD_NUMBER_FILE"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $next_version" "$PLIST_PATH"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $next_build_number" "$PLIST_PATH"

echo "Updated tracked app version metadata to $next_version ($next_build_number)"
