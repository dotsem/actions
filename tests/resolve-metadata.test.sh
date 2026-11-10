#!/usr/bin/env bash
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
only_on linux macos windows

SCRIPT="$REPO_ROOT/build-flutter/scripts/resolve-metadata.sh"
ACTION_PATH="GITHUB_ACTION_PATH=$REPO_ROOT/build-flutter"

# resolve <pubspec content, empty for none> [VAR=val ...]
resolve() {
  new_case
  if [ -n "$1" ]; then printf '%b' "$1" > "$WORK/pubspec.yaml"; fi
  shift
  run "$SCRIPT" "$ACTION_PATH" "$@"
}

PUBSPEC='name: my_app\nversion: 1.0.0\n'

for target in $(jq -r 'keys_unsorted[]' "$REPO_ROOT/build-flutter/targets.json" | tr -d '\r'); do
  resolve "$PUBSPEC" TARGET="$target" BUILD_MODE=release
  expect_ok "accepts target $target"
done

resolve "$PUBSPEC" TARGET=web BUILD_MODE=release
expect_fail "rejects unknown target" "Unsupported build target: web"
expect_fail "unknown target error lists allowed targets" '"android-apk"'

resolve "$PUBSPEC" TARGET=linux BUILD_MODE=fast
expect_fail "rejects unknown build mode" "Unsupported build mode: fast"

resolve "$PUBSPEC" TARGET=linux BUILD_MODE=release
expect "release has no suffix" "" "$(env_var MODE_SUFFIX)"
expect "BUILD_MODE exported" "release" "$(env_var BUILD_MODE)"
expect "APP_NAME exported" "my_app" "$(env_var APP_NAME)"
expect "app-name output" "my_app" "$(output app-name)"

for mode in debug profile; do
  resolve "$PUBSPEC" TARGET=linux BUILD_MODE="$mode"
  expect "$mode suffix" "-$mode" "$(env_var MODE_SUFFIX)"
done

resolve 'name: "quoted_app"\n' TARGET=linux BUILD_MODE=release
expect "double-quoted name" "quoted_app" "$(output app-name)"

resolve "name: 'single_app'\n" TARGET=linux BUILD_MODE=release
expect "single-quoted name" "single_app" "$(output app-name)"

resolve 'name: crlf_app\r\nversion: 1.0.0\r\n' TARGET=linux BUILD_MODE=release
expect "crlf name" "crlf_app" "$(output app-name)"

resolve 'description: x\nflutter:\n  name: nested\nname: top_app\n' TARGET=linux BUILD_MODE=release
expect "only top-level name counts" "top_app" "$(output app-name)"

resolve 'version: 1.0.0\n' TARGET=linux BUILD_MODE=release
expect "missing name falls back to app" "app" "$(output app-name)"

resolve "" TARGET=linux BUILD_MODE=release
expect_fail "missing pubspec" "pubspec.yaml not found"

finish
