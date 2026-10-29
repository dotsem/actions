#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${APP_NAME:-app}"
MODE_SUFFIX="${MODE_SUFFIX:-}"

mkdir -p dist

if [ ! -d "build/ios/iphoneos/Runner.app" ]; then
  echo "::error::ios Runner.app bundle not found"
  exit 1
fi

ditto -c -k --sequesterRsrc "build/ios/iphoneos/Runner.app" "dist/${APP_NAME}-ios-unsigned${MODE_SUFFIX}.zip"
