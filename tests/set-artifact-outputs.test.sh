#!/usr/bin/env bash
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
only_on linux macos windows

SCRIPT="$REPO_ROOT/build-flutter/scripts/set-artifact-outputs.sh"
VARS=(APP_NAME=my_app TARGET=android-apk MODE_SUFFIX=-debug WORKING_DIRECTORY=apps/mobile)

new_case
mkdir -p "$WORK/dist"
touch "$WORK/dist/my_app-android-debug.apk"
run "$SCRIPT" "${VARS[@]}"
expect "artifact-name" "my_app-android-apk-debug" "$(output artifact-name)"
expect "artifact-path" "apps/mobile/dist/*" "$(output artifact-path)"

new_case
mkdir -p "$WORK/dist"
touch "$WORK/dist/my_app-linux.tar.gz"
run "$SCRIPT" APP_NAME=my_app TARGET=linux MODE_SUFFIX= WORKING_DIRECTORY=.
expect "release artifact-name has no suffix" "my_app-linux" "$(output artifact-name)"

new_case
mkdir -p "$WORK/dist"
run "$SCRIPT" "${VARS[@]}"
expect_fail "empty dist" "Packaging produced no artifacts"
expect "no outputs on failure" "" "$(output artifact-name)"

new_case
run "$SCRIPT" "${VARS[@]}"
expect_fail "missing dist" "Packaging produced no artifacts"

finish
