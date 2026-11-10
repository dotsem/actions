#!/usr/bin/env bash
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
only_on linux macos

# ditto only exists on macOS; the stub records what would be zipped and creates the zip.
# shellcheck disable=SC2016 # expands inside the stub.
stub ditto 'touch "${!#}"'

MACOS="$REPO_ROOT/build-flutter/scripts/package-macos.sh"
IOS="$REPO_ROOT/build-flutter/scripts/package-ios.sh"
PRODUCTS=build/macos/Build/Products

new_case
mkdir -p "$WORK/$PRODUCTS/Release/my_app.app" "$WORK/$PRODUCTS/Debug/my_app.app"
run "$MACOS" BUILD_MODE=debug APP_NAME=my_app MODE_SUFFIX=-debug
expect_ok "macos exits 0"
expect_file "macos zip name" "dist/my_app-macos-debug.zip"
expect "macos zips the app of the build mode (case-insensitive)" \
  "ditto -c -k --sequesterRsrc $PRODUCTS/Debug/my_app.app dist/my_app-macos-debug.zip" "$(stub_log)"

new_case
mkdir -p "$WORK/$PRODUCTS/Release/my_app.app"
run "$MACOS" APP_NAME=my_app
expect_file "macos defaults to release without suffix" "dist/my_app-macos.zip"

new_case
mkdir -p "$WORK/$PRODUCTS/Release/my_app.app"
run "$MACOS" BUILD_MODE=profile APP_NAME=my_app MODE_SUFFIX=-profile
expect_fail "macos app for build mode missing" "macos .app bundle not found"
expect "macos does not zip on failure" "" "$(stub_log)"

new_case
run "$MACOS" BUILD_MODE=release APP_NAME=my_app MODE_SUFFIX=
expect_fail "macos without build output" "macos .app bundle not found"

new_case
mkdir -p "$WORK/build/ios/iphoneos/Runner.app"
run "$IOS" APP_NAME=my_app MODE_SUFFIX=-debug
expect_ok "ios exits 0"
expect "ios zips Runner.app as unsigned" \
  "ditto -c -k --sequesterRsrc build/ios/iphoneos/Runner.app dist/my_app-ios-unsigned-debug.zip" "$(stub_log)"

new_case
run "$IOS" APP_NAME=my_app MODE_SUFFIX=
expect_fail "ios without Runner.app" "ios Runner.app bundle not found"

finish
