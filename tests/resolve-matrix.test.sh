#!/usr/bin/env bash
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
only_on linux macos

SCRIPT="$REPO_ROOT/flutter-matrix/scripts/resolve-matrix.sh"
TARGETS_JSON_FILE="$REPO_ROOT/build-flutter/targets.json"
# The script finds targets.json relative to its own action, exactly as on a runner.
ACTION_PATH="GITHUB_ACTION_PATH=$REPO_ROOT/flutter-matrix"

resolve() {
  new_case
  run "$SCRIPT" "$ACTION_PATH" "$@"
}

LINUX='[{"target":"linux","os":"ubuntu-latest"}]'
IOS='[{"target":"ios","os":"macos-latest"}]'

resolve EVENT_NAME=pull_request TARGETS_INPUT='["linux"]' PR_TARGETS_INPUT='["ios"]'
expect "targets wins over pr-targets" "$LINUX" "$(output matrix)"

resolve EVENT_NAME=push TARGETS_INPUT='["linux"]' PUSH_TARGETS_INPUT='["ios"]'
expect "targets wins over push-targets" "$LINUX" "$(output matrix)"

resolve EVENT_NAME=pull_request PR_TARGETS_INPUT='["ios"]' PUSH_TARGETS_INPUT='["linux"]'
expect "pull_request uses pr-targets" "$IOS" "$(output matrix)"

resolve EVENT_NAME=push PR_TARGETS_INPUT='["ios"]' PUSH_TARGETS_INPUT='["linux"]'
expect "push uses push-targets" "$LINUX" "$(output matrix)"

resolve EVENT_NAME=workflow_dispatch PR_TARGETS_INPUT='["ios"]' PUSH_TARGETS_INPUT='["linux"]'
expect "other events use push-targets" "$LINUX" "$(output matrix)"

resolve EVENT_NAME=pull_request PUSH_TARGETS_INPUT='["linux"]'
expect_fail "pull_request ignores push-targets" "Must provide"

resolve EVENT_NAME=push PR_TARGETS_INPUT='["linux"]'
expect_fail "push ignores pr-targets" "Must provide"

resolve EVENT_NAME=push
expect_fail "no targets" "Must provide"

for bad in '"linux"' '[]' '[1]' '["linux", null]' '{"linux":1}' 'not json'; do
  resolve EVENT_NAME=push TARGETS_INPUT="$bad"
  expect_fail "rejects targets $bad" "non-empty JSON array of strings"
done

resolve EVENT_NAME=push TARGETS_INPUT='["linux","bogus","nope"]'
expect_fail "unknown targets are listed" '["bogus","nope"]'
expect_fail "unknown target error lists allowed targets" "Allowed targets: $(jq -c 'keys_unsorted' "$TARGETS_JSON_FILE")"
expect "no matrix on failure" "" "$(output matrix)"

resolve EVENT_NAME=pull_request TARGETS_INPUT='["linux"]'
expect "pull_request defaults to debug" "debug" "$(output build-mode)"

resolve EVENT_NAME=push TARGETS_INPUT='["linux"]'
expect "push defaults to release" "release" "$(output build-mode)"

resolve EVENT_NAME=pull_request TARGETS_INPUT='["linux"]' PR_BUILD_MODE_INPUT=profile PUSH_BUILD_MODE_INPUT=debug
expect "pull_request uses pr-build-mode" "profile" "$(output build-mode)"

resolve EVENT_NAME=push TARGETS_INPUT='["linux"]' PR_BUILD_MODE_INPUT=profile PUSH_BUILD_MODE_INPUT=debug
expect "push uses push-build-mode" "debug" "$(output build-mode)"

resolve EVENT_NAME=pull_request TARGETS_INPUT='["linux"]' BUILD_MODE_INPUT=release PR_BUILD_MODE_INPUT=profile
expect "build-mode wins over pr-build-mode" "release" "$(output build-mode)"

resolve EVENT_NAME=push TARGETS_INPUT='["linux"]' BUILD_MODE_INPUT=profile PUSH_BUILD_MODE_INPUT=debug
expect "build-mode wins over push-build-mode" "profile" "$(output build-mode)"

resolve EVENT_NAME=push TARGETS_INPUT='["linux"]' BUILD_MODE_INPUT=fast
expect_fail "invalid build mode" "Unsupported build mode: fast"

ALL=$(jq -c 'keys_unsorted' "$TARGETS_JSON_FILE")
resolve EVENT_NAME=push TARGETS_INPUT="$ALL"
expect "every target maps to its targets.json runner, in input order" \
  "$(jq -c 'to_entries | map({target: .key, os: .value})' "$TARGETS_JSON_FILE")" "$(output matrix)"

resolve EVENT_NAME=push TARGETS_INPUT='["ios","linux"]'
expect "input order is kept" '[{"target":"ios","os":"macos-latest"},{"target":"linux","os":"ubuntu-latest"}]' "$(output matrix)"

finish
