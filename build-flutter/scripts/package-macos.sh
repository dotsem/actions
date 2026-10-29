#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${APP_NAME:-app}"
BUILD_MODE="${BUILD_MODE:-release}"
MODE_SUFFIX="${MODE_SUFFIX:-}"

mkdir -p dist

APP_PATH=""
if [ -d "build/macos/Build/Products" ]; then
  APP_PATH=$(find "build/macos/Build/Products" -maxdepth 2 -ipath "*${BUILD_MODE}*/*.app" | head -n 1)
fi

if [ -z "$APP_PATH" ]; then
  echo "::error::macos .app bundle not found"
  exit 1
fi

ditto -c -k --sequesterRsrc "$APP_PATH" "dist/${APP_NAME}-macos${MODE_SUFFIX}.zip"
