#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="wewi"
APP_VERSION="${APP_VERSION:-1.0.2}"
ARCH="${1:-${ARCH:-universal}}"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-elixirevo/wewi}"
RELEASE_TAG="${RELEASE_TAG:-v$APP_VERSION}"
DIST_DIR="$ROOT_DIR/dist"
DMG_PATH="$DIST_DIR/${APP_NAME}-${APP_VERSION}-${ARCH}.dmg"
APPCAST_ARCHIVE_DIR="${APPCAST_ARCHIVE_DIR:-$DIST_DIR/appcast}"
SPARKLE_GENERATE_APPCAST="${SPARKLE_GENERATE_APPCAST:-}"
SPARKLE_DOWNLOAD_URL_PREFIX="${SPARKLE_DOWNLOAD_URL_PREFIX:-https://github.com/$GITHUB_REPOSITORY/releases/download/$RELEASE_TAG/}"
SPARKLE_PRODUCT_LINK="${SPARKLE_PRODUCT_LINK:-https://github.com/$GITHUB_REPOSITORY}"
SPARKLE_MAXIMUM_VERSIONS="${SPARKLE_MAXIMUM_VERSIONS:-1}"
SPARKLE_MAXIMUM_DELTAS="${SPARKLE_MAXIMUM_DELTAS:-0}"
SKIP_DMG_BUILD="${SKIP_DMG_BUILD:-0}"

find_sparkle_tool() {
  local tool_name="$1"
  find "$ROOT_DIR/.build" -type f -name "$tool_name" | sort | head -n 1
}

if [[ "$ARCH" != "arm64" && "$ARCH" != "x86_64" && "$ARCH" != "universal" ]]; then
  echo "Unsupported ARCH: $ARCH (expected arm64, x86_64, or universal)"
  exit 1
fi

if [[ -z "$SPARKLE_GENERATE_APPCAST" ]]; then
  SPARKLE_GENERATE_APPCAST="$(find_sparkle_tool generate_appcast)"
fi

if [[ -z "$SPARKLE_GENERATE_APPCAST" || ! -x "$SPARKLE_GENERATE_APPCAST" ]]; then
  echo "Sparkle generate_appcast was not found. Resolving package first..."
  swift build
  SPARKLE_GENERATE_APPCAST="$(find_sparkle_tool generate_appcast)"
fi

if [[ -z "$SPARKLE_GENERATE_APPCAST" || ! -x "$SPARKLE_GENERATE_APPCAST" ]]; then
  echo "Unable to find Sparkle generate_appcast under .build."
  echo "Set SPARKLE_GENERATE_APPCAST=/path/to/generate_appcast and retry."
  exit 1
fi

if [[ "$SKIP_DMG_BUILD" == "1" ]]; then
  if [[ ! -f "$DMG_PATH" ]]; then
    echo "DMG not found: $DMG_PATH"
    echo "Build, sign, notarize, and staple the DMG before using SKIP_DMG_BUILD=1."
    exit 1
  fi
else
  bash "$ROOT_DIR/scripts/build_dmg.sh" "$ARCH"
fi

mkdir -p "$APPCAST_ARCHIVE_DIR"
cp "$DMG_PATH" "$APPCAST_ARCHIVE_DIR/"

"$SPARKLE_GENERATE_APPCAST" \
  --download-url-prefix "$SPARKLE_DOWNLOAD_URL_PREFIX" \
  --link "$SPARKLE_PRODUCT_LINK" \
  --maximum-versions "$SPARKLE_MAXIMUM_VERSIONS" \
  --maximum-deltas "$SPARKLE_MAXIMUM_DELTAS" \
  "$APPCAST_ARCHIVE_DIR"

echo "Appcast created: $APPCAST_ARCHIVE_DIR/appcast.xml"
echo "Upload these files to GitHub Release $RELEASE_TAG:"
echo "  $DMG_PATH"
echo "  $APPCAST_ARCHIVE_DIR/appcast.xml"
