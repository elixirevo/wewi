#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
: "${APP_PATH:?Run through tools/deploy/deploy.sh}"
: "${DSYM_PATH:?Release symbols destination is required}"
: "${ARCH:?Release architecture is required}"
APP_BUNDLE_NAME="wewi-release-$ARCH" bash "$ROOT_DIR/scripts/build_app.sh"
ditto "$ROOT_DIR/dist/wewi-release-$ARCH.app" "$APP_PATH"
ditto "$ROOT_DIR/dist/wewi-release-$ARCH.app.dSYM" "$DSYM_PATH"
