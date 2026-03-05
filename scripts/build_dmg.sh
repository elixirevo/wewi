#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="wewi"
APP_VERSION="${APP_VERSION:-1.0.0}"
ARCH="${1:-${ARCH:-}}"
VOL_NAME="${APP_NAME}"

if [[ -z "$ARCH" ]]; then
  echo "Usage: $0 <arm64|x86_64>"
  exit 1
fi

if [[ "$ARCH" != "arm64" && "$ARCH" != "x86_64" ]]; then
  echo "Unsupported ARCH: $ARCH (expected arm64 or x86_64)"
  exit 1
fi

DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/${APP_NAME}-${APP_VERSION}-${ARCH}.dmg"
RW_DMG_PATH="$DIST_DIR/${APP_NAME}-${APP_VERSION}-${ARCH}-rw.dmg"
TMP_DIR="$(mktemp -d /tmp/${APP_NAME}-dmg.${ARCH}.XXXXXX)"
STAGE_DIR="$TMP_DIR/stage"
BG_DIR="$STAGE_DIR/.background"
BG_IMAGE="$BG_DIR/background.png"
DEVICE_NAME=""
MOUNT_POINT=""
MOUNT_VOLUME=""

cleanup() {
  if [[ -n "$DEVICE_NAME" ]]; then
    hdiutil detach "$DEVICE_NAME" >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

ARCH="$ARCH" APP_BUNDLE_NAME="$APP_NAME" bash "$ROOT_DIR/scripts/build_app.sh"

mkdir -p "$STAGE_DIR"
cp -R "$APP_PATH" "$STAGE_DIR/$APP_NAME.app"
ln -s /Applications "$STAGE_DIR/Applications"
mkdir -p "$BG_DIR"

# Generate a simple DMG background with a directional arrow.
cat > "$TMP_DIR/generate_dmg_background.swift" <<'SWIFT'
import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count >= 2 else {
  fputs("Usage: generate_dmg_background.swift <output-path>\n", stderr)
  exit(1)
}

let outputPath = args[1]
let width = 680
let height = 420
let size = NSSize(width: width, height: height)

let image = NSImage(size: size)
image.lockFocus()

let bgRect = NSRect(origin: .zero, size: size)
NSColor(calibratedWhite: 0.965, alpha: 1.0).setFill()
bgRect.fill()

let panelRect = NSRect(x: 22, y: 22, width: size.width - 44, height: size.height - 44)
let panel = NSBezierPath(roundedRect: panelRect, xRadius: 20, yRadius: 20)
NSColor(calibratedWhite: 0.985, alpha: 0.97).setFill()
panel.fill()
NSColor(calibratedWhite: 0.86, alpha: 1.0).setStroke()
panel.lineWidth = 1.0
panel.stroke()

let labelAttr: [NSAttributedString.Key: Any] = [
  .font: NSFont.systemFont(ofSize: 24, weight: .semibold),
  .foregroundColor: NSColor(calibratedWhite: 0.30, alpha: 1.0)
]
let guide = NSString(string: "Drag wewi.app to Applications")
let guideSize = guide.size(withAttributes: labelAttr)
guide.draw(
  at: NSPoint(
    x: (size.width - guideSize.width) / 2.0,
    y: size.height - 98
  ),
  withAttributes: labelAttr
)

let arrowPath = NSBezierPath()
arrowPath.lineWidth = 14
arrowPath.lineCapStyle = .round
arrowPath.move(to: NSPoint(x: 280, y: 208))
arrowPath.line(to: NSPoint(x: 400, y: 208))

arrowPath.move(to: NSPoint(x: 380, y: 232))
arrowPath.line(to: NSPoint(x: 408, y: 208))
arrowPath.line(to: NSPoint(x: 380, y: 184))
NSColor(calibratedRed: 0.18, green: 0.48, blue: 0.92, alpha: 0.95).setStroke()
arrowPath.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
  fputs("Failed to render PNG\n", stderr)
  exit(1)
}

let outputURL = URL(fileURLWithPath: outputPath)
do {
  try png.write(to: outputURL)
} catch {
  fputs("Failed to write PNG: \(error)\n", stderr)
  exit(1)
}
SWIFT

swift "$TMP_DIR/generate_dmg_background.swift" "$BG_IMAGE"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "$VOL_NAME" \
  -srcfolder "$STAGE_DIR" \
  -fs HFS+ \
  -format UDRW \
  -ov \
  "$RW_DMG_PATH" >/dev/null

ATTACH_OUTPUT="$(
hdiutil attach \
  -readwrite \
  -noverify \
  -noautoopen \
  "$RW_DMG_PATH"
)"

DEVICE_NAME="$(printf '%s\n' "$ATTACH_OUTPUT" | awk -F '\t' '/GUID_partition_scheme/ {gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1; exit}')"
if [[ -z "$DEVICE_NAME" ]]; then
  DEVICE_NAME="$(printf '%s\n' "$ATTACH_OUTPUT" | awk -F '\t' '/Apple_HFS/ {gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1; exit}')"
fi
MOUNT_POINT="$(printf '%s\n' "$ATTACH_OUTPUT" | awk -F '\t' '/Apple_HFS/ {gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3; exit}')"
MOUNT_VOLUME="$(basename "$MOUNT_POINT")"

if [[ -z "$DEVICE_NAME" || -z "$MOUNT_POINT" || -z "$MOUNT_VOLUME" ]]; then
  echo "Failed to parse mounted DMG information."
  echo "$ATTACH_OUTPUT"
  exit 1
fi

osascript <<OSA
set mountAlias to POSIX file "${MOUNT_POINT}" as alias
set bgAlias to POSIX file "${MOUNT_POINT}/.background/background.png" as alias
tell application "Finder"
  open mountAlias
  set dmgWindow to container window of mountAlias
  set current view of dmgWindow to icon view
  set the bounds of dmgWindow to {120, 120, 800, 540}
  set opts to the icon view options of dmgWindow
  set arrangement of opts to not arranged
  set icon size of opts to 128
  set text size of opts to 13
  set background picture of opts to bgAlias
  set position of item "${APP_NAME}.app" of mountAlias to {180, 260}
  set position of item "Applications" of mountAlias to {500, 260}
  delay 1
end tell
OSA

hdiutil detach "$DEVICE_NAME" >/dev/null || hdiutil detach "$DEVICE_NAME" -force >/dev/null
DEVICE_NAME=""
hdiutil convert "$RW_DMG_PATH" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" >/dev/null
rm -f "$RW_DMG_PATH"

echo "DMG created: $DMG_PATH"
