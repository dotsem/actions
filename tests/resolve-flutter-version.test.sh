#!/usr/bin/env bash
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/setup-flutter/scripts/resolve-version.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
FAILED=0

# expect <name> <expected version or FAIL> <flutter-version input> <pubspec content>
expect() {
  rm -f "$TMP/pubspec.yaml"
  if [ -n "$4" ]; then printf '%b' "$4" > "$TMP/pubspec.yaml"; fi
  : > "$TMP/out"
  local got
  if FLUTTER_VERSION_INPUT="$3" PUBSPEC="$TMP/pubspec.yaml" GITHUB_OUTPUT="$TMP/out" bash "$SCRIPT" > /dev/null; then
    got=$(sed -n 's/^version=//p' "$TMP/out")
  else
    got=FAIL
  fi
  if [ "$got" = "$2" ]; then
    echo "ok   $1"
  else
    echo "FAIL $1: expected '$2', got '$got'"
    FAILED=1
  fi
}

ENV_HEAD='name: app\nenvironment:\n  sdk: ^3.13.1\n'
DEPS='dependencies:\n  flutter:\n    sdk: flutter\nflutter:\n  uses-material-design: true\n'

expect "exact" "3.47.1" "" "${ENV_HEAD}  flutter: 3.47.1\n${DEPS}"
expect "caret" "3.47.1" "" "${ENV_HEAD}  flutter: ^3.47.1\n${DEPS}"
expect "range" "3.47.1" "" "${ENV_HEAD}  flutter: \">=3.47.1 <4.0.0\"\n${DEPS}"
expect "single quotes" "3.47.1" "" "${ENV_HEAD}  flutter: '^3.47.1'\n${DEPS}"
expect "trailing comment" "3.47.1" "" "${ENV_HEAD}  flutter: ^3.47.1 # pinned\n${DEPS}"
expect "crlf" "3.47.1" "" "name: app\r\nenvironment:\r\n  flutter: ^3.47.1\r\n"
expect "pre-release" "3.48.0-0.1.pre" "" "${ENV_HEAD}  flutter: 3.48.0-0.1.pre\n${DEPS}"
expect "input wins" "3.40.0" "3.40.0" "${ENV_HEAD}  flutter: ^3.47.1\n"
expect "missing key" "FAIL" "" "${ENV_HEAD}${DEPS}"
expect "upper bound only" "FAIL" "" "${ENV_HEAD}  flutter: <4.0.0\n"
expect "exclusive lower" "FAIL" "" "${ENV_HEAD}  flutter: \">3.47.1\"\n"
expect "any" "FAIL" "" "${ENV_HEAD}  flutter: any\n"
expect "partial version" "FAIL" "" "${ENV_HEAD}  flutter: ^3.47\n"
expect "no pubspec" "FAIL" "" ""

exit "$FAILED"
