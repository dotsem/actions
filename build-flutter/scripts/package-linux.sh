#!/usr/bin/env bash
set -euo pipefail

BUILD_MODE="${BUILD_MODE:-release}"
APP_NAME="${APP_NAME:-app}"
MODE_SUFFIX="${MODE_SUFFIX:-}"

mkdir -p dist
tar -czf "dist/${APP_NAME}-linux${MODE_SUFFIX}.tar.gz" -C "build/linux/x64/${BUILD_MODE}/bundle" .
