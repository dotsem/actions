#!/usr/bin/env bash
set -euo pipefail

TARGETS_FILE="${TARGETS_FILE:-${GITHUB_ACTION_PATH}/targets.json}"
if ! jq -e --arg t "$TARGET" 'has($t)' "$TARGETS_FILE" > /dev/null; then
  echo "::error::Unsupported build target: $TARGET. Allowed targets: $(jq -c 'keys_unsorted' "$TARGETS_FILE")"
  exit 1
fi

case "$BUILD_MODE" in
  debug|profile|release) ;;
  *)
    echo "::error::Unsupported build mode: $BUILD_MODE"
    exit 1
    ;;
esac

if [ "$BUILD_MODE" = "release" ]; then
  MODE_SUFFIX=""
else
  MODE_SUFFIX="-${BUILD_MODE}"
fi

echo "BUILD_MODE=$BUILD_MODE" >> "$GITHUB_ENV"
echo "MODE_SUFFIX=$MODE_SUFFIX" >> "$GITHUB_ENV"

if [ ! -f pubspec.yaml ]; then
  echo "::error::pubspec.yaml not found in $PWD"
  exit 1
fi

NAME=$(sed -n "s/^name:[[:space:]]*//p" pubspec.yaml | head -n 1 | tr -d '\r"'\'' ')
NAME="${NAME:-app}"

echo "APP_NAME=$NAME" >> "$GITHUB_ENV"
echo "app-name=$NAME" >> "$GITHUB_OUTPUT"
