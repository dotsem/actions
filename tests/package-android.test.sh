#!/usr/bin/env bash
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
only_on linux macos

SCRIPT="$REPO_ROOT/build-flutter/scripts/package-android.sh"
APK_DIR=build/app/outputs/flutter-apk
AAB_DIR=build/app/outputs/bundle

# put <relative path> writes a file whose content is its own path, so copies can be traced.
put() {
  mkdir -p "$WORK/$(dirname "$1")"
  echo "$1" > "$WORK/$1"
}

new_case
put "$APK_DIR/app-release.apk"
put "$APK_DIR/app-debug.apk"
run "$SCRIPT" TARGET=android-apk BUILD_MODE=debug APP_NAME=my_app MODE_SUFFIX=-debug
expect_ok "apk exits 0"
expect_file "apk named with suffix" "dist/my_app-android-debug.apk"
expect "apk matching build mode is picked" "$APK_DIR/app-debug.apk" "$(cat "$WORK/dist/my_app-android-debug.apk")"

new_case
put "$APK_DIR/app-release.apk"
run "$SCRIPT" TARGET=android-apk BUILD_MODE=release APP_NAME=my_app MODE_SUFFIX=
expect_file "release apk has no suffix" "dist/my_app-android.apk"

new_case
put "$APK_DIR/app-release.apk"
run "$SCRIPT" TARGET=android-apk BUILD_MODE=profile APP_NAME=my_app MODE_SUFFIX=-profile
expect "apk of another mode is never used" "" "$(ls "$WORK/dist")"

new_case
put "$AAB_DIR/release/app-release.aab"
put "$AAB_DIR/profile/app-profile.aab"
run "$SCRIPT" TARGET=android-aab BUILD_MODE=profile APP_NAME=my_app MODE_SUFFIX=-profile
expect "aab matching build mode is picked" "$AAB_DIR/profile/app-profile.aab" "$(cat "$WORK/dist/my_app-android-profile.aab")"

new_case
put "$AAB_DIR/release/app-release.aab"
run "$SCRIPT" TARGET=android-aab BUILD_MODE=debug APP_NAME=my_app MODE_SUFFIX=-debug
expect "aab falls back to any bundle" "$AAB_DIR/release/app-release.aab" "$(cat "$WORK/dist/my_app-android-debug.aab")"

new_case
put "$APK_DIR/app-release.apk"
run "$SCRIPT" TARGET=android-aab BUILD_MODE=release APP_NAME=my_app MODE_SUFFIX=
expect "aab target ignores apk output" "" "$(ls "$WORK/dist")"

# No build output is not an error here: set-artifact-outputs.sh fails on the empty dist/ instead.
new_case
run "$SCRIPT" TARGET=android-apk BUILD_MODE=release APP_NAME=my_app MODE_SUFFIX=
expect_ok "missing build output exits 0"
expect "missing build output leaves dist empty" "" "$(ls "$WORK/dist")"

finish
