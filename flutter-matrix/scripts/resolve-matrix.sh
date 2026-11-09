#!/usr/bin/env bash
# Resolves the Flutter build matrix and build mode for the current event.
# Single source of truth for valid targets and runner mapping: build-flutter/targets.json
set -euo pipefail

TARGETS_FILE="${TARGETS_FILE:-${GITHUB_ACTION_PATH}/../build-flutter/targets.json}"

TARGETS_JSON="${TARGETS_INPUT:-}"
BUILD_MODE="${BUILD_MODE_INPUT:-}"

if [ "${EVENT_NAME:-}" = "pull_request" ]; then
  TARGETS_JSON="${TARGETS_JSON:-${PR_TARGETS_INPUT:-}}"
  BUILD_MODE="${BUILD_MODE:-${PR_BUILD_MODE_INPUT:-}}"
  BUILD_MODE="${BUILD_MODE:-debug}"
else
  TARGETS_JSON="${TARGETS_JSON:-${PUSH_TARGETS_INPUT:-}}"
  BUILD_MODE="${BUILD_MODE:-${PUSH_BUILD_MODE_INPUT:-}}"
  BUILD_MODE="${BUILD_MODE:-release}"
fi

if [ -z "$TARGETS_JSON" ]; then
  echo "::error::Must provide either 'targets' or 'pr-targets' and 'push-targets'"
  exit 1
fi

if ! echo "$TARGETS_JSON" | jq -e 'type == "array" and length > 0 and all(type == "string")' > /dev/null 2>&1; then
  echo "::error::Targets must be a non-empty JSON array of strings, got: $TARGETS_JSON"
  exit 1
fi

case "$BUILD_MODE" in
  debug|profile|release) ;;
  *)
    echo "::error::Unsupported build mode: $BUILD_MODE"
    exit 1
    ;;
esac

INVALID=$(echo "$TARGETS_JSON" | jq -c --slurpfile valid "$TARGETS_FILE" '[.[] | select(. as $t | $valid[0] | has($t) | not)]')
if [ "$INVALID" != "[]" ]; then
  echo "::error::Unsupported target(s) found: $INVALID. Allowed targets: $(jq -c 'keys_unsorted' "$TARGETS_FILE")"
  exit 1
fi

MATRIX=$(echo "$TARGETS_JSON" | jq -c --slurpfile valid "$TARGETS_FILE" '[.[] | {target: ., os: $valid[0][.]}]')

echo "build-mode=$BUILD_MODE" >> "$GITHUB_OUTPUT"
echo "matrix=$MATRIX" >> "$GITHUB_OUTPUT"
