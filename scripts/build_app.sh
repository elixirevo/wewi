#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="wewi"
APP_VERSION="${APP_VERSION:-1.0.2}"
APP_BUILD="${APP_BUILD:-3}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
ARCH="${ARCH:-}"
APP_BUNDLE_NAME="${APP_BUNDLE_NAME:-$APP_NAME}"
APP_DIR="$ROOT_DIR/dist/$APP_BUNDLE_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-https://github.com/elixirevo/wewi/releases/latest/download/appcast.xml}"
SPARKLE_ENABLE_AUTOMATIC_CHECKS="${SPARKLE_ENABLE_AUTOMATIC_CHECKS:-true}"
SPARKLE_PUBLIC_ED_KEY_FILE="${SPARKLE_PUBLIC_ED_KEY_FILE:-$ROOT_DIR/sparkle-public-key.txt}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}"

if [[ -z "$SPARKLE_PUBLIC_ED_KEY" && -f "$SPARKLE_PUBLIC_ED_KEY_FILE" ]]; then
  SPARKLE_PUBLIC_ED_KEY="$(tr -d '[:space:]' < "$SPARKLE_PUBLIC_ED_KEY_FILE")"
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
mkdir -p "$FRAMEWORKS_DIR"

if [[ "$ARCH" == "universal" ]]; then
  swift build -c release --arch arm64
  ARM_BIN_PATH="$(swift build -c release --arch arm64 --show-bin-path)"

  swift build -c release --arch x86_64
  X86_BIN_PATH="$(swift build -c release --arch x86_64 --show-bin-path)"

  lipo -create \
    "$ARM_BIN_PATH/$APP_NAME" \
    "$X86_BIN_PATH/$APP_NAME" \
    -output "$MACOS_DIR/$APP_NAME"
  chmod +x "$MACOS_DIR/$APP_NAME"
else
  BUILD_ARGS=(-c release)
  if [[ -n "$ARCH" ]]; then
    BUILD_ARGS+=(--arch "$ARCH")
  fi

  swift build "${BUILD_ARGS[@]}"
  BIN_PATH="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
  cp "$BIN_PATH/$APP_NAME" "$MACOS_DIR/$APP_NAME"
  chmod +x "$MACOS_DIR/$APP_NAME"
fi

if ! otool -l "$MACOS_DIR/$APP_NAME" | grep -q "@executable_path/../Frameworks"; then
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/$APP_NAME"
fi

SPARKLE_FRAMEWORK_SOURCE="${SPARKLE_FRAMEWORK_SOURCE:-}"
if [[ -z "$SPARKLE_FRAMEWORK_SOURCE" ]]; then
  SPARKLE_FRAMEWORK_SOURCE="$(find "$ROOT_DIR/.build" -path "*/Sparkle.framework" -type d | sort | head -n 1)"
fi

if [[ -z "$SPARKLE_FRAMEWORK_SOURCE" || ! -d "$SPARKLE_FRAMEWORK_SOURCE" ]]; then
  echo "Sparkle.framework was not found under .build."
  echo "Run 'swift build' after Package.swift resolves Sparkle, or set SPARKLE_FRAMEWORK_SOURCE."
  exit 1
fi

ditto "$SPARKLE_FRAMEWORK_SOURCE" "$FRAMEWORKS_DIR/Sparkle.framework"

cp "$ROOT_DIR/menubar-icon.png" "$RESOURCES_DIR/menubar-icon.png"

ICON_SOURCE_DIR="$ROOT_DIR/wewi_icons"
ICONSET_DIR="$RESOURCES_DIR/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"

cp "$ICON_SOURCE_DIR/wewi-iOS-Default-16x16@1x.png" "$ICONSET_DIR/icon_16x16.png"
cp "$ICON_SOURCE_DIR/wewi-iOS-Default-16x16@2x.png" "$ICONSET_DIR/icon_16x16@2x.png"
cp "$ICON_SOURCE_DIR/wewi-iOS-Default-32x32@1x.png" "$ICONSET_DIR/icon_32x32.png"
cp "$ICON_SOURCE_DIR/wewi-iOS-Default-32x32@2x.png" "$ICONSET_DIR/icon_32x32@2x.png"
cp "$ICON_SOURCE_DIR/wewi-iOS-Default-128x128@1x.png" "$ICONSET_DIR/icon_128x128.png"
cp "$ICON_SOURCE_DIR/wewi-iOS-Default-128x128@2x.png" "$ICONSET_DIR/icon_128x128@2x.png"
cp "$ICON_SOURCE_DIR/wewi-iOS-Default-256x256@1x.png" "$ICONSET_DIR/icon_256x256.png"
cp "$ICON_SOURCE_DIR/wewi-iOS-Default-256x256@2x.png" "$ICONSET_DIR/icon_256x256@2x.png"
cp "$ICON_SOURCE_DIR/wewi-iOS-Default-512x512@1x.png" "$ICONSET_DIR/icon_512x512.png"
cp "$ICON_SOURCE_DIR/wewi-iOS-Default-1024x1024@1x.png" "$ICONSET_DIR/icon_512x512@2x.png"

iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
cp "$ICON_SOURCE_DIR/wewi-iOS-Default-1024x1024@1x.png" "$RESOURCES_DIR/AppIcon.png"
rm -rf "$ICONSET_DIR"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>wewi</string>
  <key>CFBundleDisplayName</key>
  <string>wewi</string>
  <key>CFBundleIdentifier</key>
  <string>com.elixirevo.wewi</string>
  <key>CFBundleVersion</key>
  <string>${APP_BUILD}</string>
  <key>CFBundleShortVersionString</key>
  <string>${APP_VERSION}</string>
  <key>CFBundleExecutable</key>
  <string>wewi</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon.icns</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

/usr/libexec/PlistBuddy -c "Add :SUFeedURL string $SPARKLE_FEED_URL" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Add :SUEnableAutomaticChecks bool $SPARKLE_ENABLE_AUTOMATIC_CHECKS" "$CONTENTS_DIR/Info.plist"

if [[ -n "$SPARKLE_PUBLIC_ED_KEY" ]]; then
  /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $SPARKLE_PUBLIC_ED_KEY" "$CONTENTS_DIR/Info.plist"
else
  echo "Warning: Sparkle public key not set. Run 'make sparkle-keys' before release builds."
fi

codesign_path() {
  local path="$1"
  shift

  if [[ ! -e "$path" ]]; then
    return
  fi

  if [[ "$SIGN_IDENTITY" == "-" ]]; then
    codesign --force --sign - "$@" "$path"
  else
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$@" "$path"
  fi
}

SPARKLE_FRAMEWORK="$FRAMEWORKS_DIR/Sparkle.framework"
SPARKLE_FRAMEWORK_VERSION_DIR="$SPARKLE_FRAMEWORK/Versions/B"
if [[ ! -d "$SPARKLE_FRAMEWORK_VERSION_DIR" ]]; then
  SPARKLE_FRAMEWORK_VERSION_DIR="$SPARKLE_FRAMEWORK/Versions/Current"
fi

if [[ "$SIGN_IDENTITY" == "-" ]]; then
  echo "Signing app with ad-hoc identity (-)."
else
  echo "Signing app with identity: $SIGN_IDENTITY"
fi

codesign_path "$SPARKLE_FRAMEWORK_VERSION_DIR/XPCServices/Installer.xpc"
codesign_path "$SPARKLE_FRAMEWORK_VERSION_DIR/XPCServices/Downloader.xpc" --preserve-metadata=entitlements
codesign_path "$SPARKLE_FRAMEWORK_VERSION_DIR/Autoupdate"
codesign_path "$SPARKLE_FRAMEWORK_VERSION_DIR/Updater.app"
codesign_path "$SPARKLE_FRAMEWORK"
codesign_path "$APP_DIR"

codesign --verify --deep --strict --verbose=2 "$APP_DIR"

echo "App bundle created: $APP_DIR"
