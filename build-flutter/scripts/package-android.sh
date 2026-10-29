#!/usr/bin/env bash
set -euo pipefail

BUILD_MODE="${BUILD_MODE:-release}"
APP_NAME="${APP_NAME:-app}"
MODE_SUFFIX="${MODE_SUFFIX:-}"

mkdir -p dist

if [ "$TARGET" = "android-apk" ] && [ -d "build/app/outputs/flutter-apk" ]; then
  APK_FILE=$(find build/app/outputs/flutter-apk -maxdepth 1 -name "*${BUILD_MODE}*.apk" | head -n 1)
  if [ -n "$APK_FILE" ]; then
    cp "$APK_FILE" "dist/${APP_NAME}-android${MODE_SUFFIX}.apk"
  fi
fi

if [ "$TARGET" = "android-aab" ] && [ -d "build/app/outputs/bundle" ]; then
  AAB_FILE=$(find build/app/outputs/bundle -name "*${BUILD_MODE}*.aab" | head -n 1)
  if [ -z "$AAB_FILE" ]; then
    AAB_FILE=$(find build/app/outputs/bundle -name "*.aab" | head -n 1)
  fi
  if [ -n "$AAB_FILE" ]; then
    cp "$AAB_FILE" "dist/${APP_NAME}-android${MODE_SUFFIX}.aab"
  fi
fi