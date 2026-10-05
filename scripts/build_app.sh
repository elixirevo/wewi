#!/usr/bin/env bash
set -euo pipefail
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

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

cd "$ROOT_DIR"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"
SDK_ARGS=(--sdk "$SDK_PATH" -Xlinker -platform_version -Xlinker macos -Xlinker 13.0 -Xlinker "$SDK_VERSION")

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
mkdir -p "$FRAMEWORKS_DIR"

if [[ "$ARCH" == "universal" ]]; then
  swift build -c release --arch arm64 "${SDK_ARGS[@]}"
  ARM_BIN_PATH="$(swift build -c release --arch arm64 "${SDK_ARGS[@]}" --show-bin-path)"

  # Swift Build may reuse the same output directory for different architectures.
  cp "$ARM_BIN_PATH/$APP_NAME" "$MACOS_DIR/$APP_NAME.arm64"

  swift build -c release --arch x86_64 "${SDK_ARGS[@]}"
  X86_BIN_PATH="$(swift build -c release --arch x86_64 "${SDK_ARGS[@]}" --show-bin-path)"

  lipo -create \
    "$MACOS_DIR/$APP_NAME.arm64" \
    "$X86_BIN_PATH/$APP_NAME" \
    -output "$MACOS_DIR/$APP_NAME"
  chmod +x "$MACOS_DIR/$APP_NAME"
  rm "$MACOS_DIR/$APP_NAME.arm64"
  BIN_PATH="$X86_BIN_PATH"
else
  BUILD_ARGS=(-c release "${SDK_ARGS[@]}")
  if [[ -n "$ARCH" ]]; then
    BUILD_ARGS+=(--arch "$ARCH")
  fi

  swift build "${BUILD_ARGS[@]}"
  BIN_PATH="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
  cp "$BIN_PATH/$APP_NAME" "$MACOS_DIR/$APP_NAME"
  chmod +x "$MACOS_DIR/$APP_NAME"
fi

for bundle in wewi_wewi MacAppEssentials_MacAppSettings MacAppEssentials_MacAppOnboarding MacAppEssentials_MacAppMenuBar MacAppEssentials_MacAppMainMenu; do
  test -d "$BIN_PATH/$bundle.bundle"
  ditto "$BIN_PATH/$bundle.bundle" "$RESOURCES_DIR/$bundle.bundle"
done
# Includes dependency privacy manifests when emitted by SwiftPM.
for bundle in "$BIN_PATH"/*.bundle; do
  [[ -d "$bundle" ]] || continue
  ditto "$bundle" "$RESOURCES_DIR/$(basename "$bundle")"
done
# Sentry is statically linked; SwiftPM does not copy its framework resources.
SENTRY_RESOURCES="$ROOT_DIR/.build/artifacts/sentry-cocoa/Sentry/Sentry.xcframework/macos-arm64_arm64e_x86_64/Sentry.framework/Versions/A/Resources"
test -f "$SENTRY_RESOURCES/PrivacyInfo.xcprivacy"
mkdir -p "$RESOURCES_DIR/SentryResources.bundle/Contents/Resources"
cp "$SENTRY_RESOURCES/PrivacyInfo.xcprivacy" "$RESOURCES_DIR/SentryResources.bundle/Contents/Resources/PrivacyInfo.xcprivacy"
cat > "$RESOURCES_DIR/SentryResources.bundle/Contents/Info.plist" <<'SENTRY_PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleIdentifier</key><string>com.elixirevo.wewi.SentryResources</string><key>CFBundlePackageType</key><string>BNDL</string></dict></plist>
SENTRY_PLIST
BUILD_INFO="$(xcrun vtool -show-build "$MACOS_DIR/$APP_NAME")"
printf '%s\n' "$BUILD_INFO"
# Validate every slice; deployment target and SDK must not collapse to the same value.
while read -r field value; do
  case "$field" in
    minos) [[ "$value" == "13.0" ]] || exit 1 ;;
    sdk) [[ "$value" == "$SDK_VERSION" ]] || exit 1 ;;
  esac
done < <(awk '$1 == "minos" || $1 == "sdk" { print $1, $2 }' <<< "$BUILD_INFO")
dsymutil "$MACOS_DIR/$APP_NAME" -o "$ROOT_DIR/dist/$APP_BUNDLE_NAME.app.dSYM"

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

# Compile the whole Icon Composer document, including its background, layers and
# appearance variants. A PNG-only icon generator would discard that information.
ICON_INFO_PLIST="$ROOT_DIR/dist/$APP_BUNDLE_NAME-icon.plist"
xcrun actool "$ROOT_DIR/wewi.icon" \
  --compile "$RESOURCES_DIR" \
  --platform macosx \
  --minimum-deployment-target 13.0 \
  --app-icon wewi \
  --output-partial-info-plist "$ICON_INFO_PLIST" \
  --output-format human-readable-text
# actool also emits a legacy fallback. Ship only the Icon Composer asset catalog.
rm "$RESOURCES_DIR/wewi.icns"
/usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" "$ICON_INFO_PLIST"

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
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>ko</string></array>
  <key>NSHumanReadableCopyright</key><string>© 2026 elixirevo</string>
  <key>SUEnableSystemProfiling</key><false/>
  <key>SUAutomaticallyUpdate</key><false/>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

/usr/libexec/PlistBuddy -c "Merge $ICON_INFO_PLIST" "$CONTENTS_DIR/Info.plist"

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
