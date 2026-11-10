#!/usr/bin/env bash
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
only_on linux macos windows

SCRIPT="$REPO_ROOT/setup-flutter/scripts/resolve-version.sh"
ENV_HEAD='name: app\nenvironment:\n  sdk: ^3.13.1\n'
DEPS='dependencies:\n  flutter:\n    sdk: flutter\nflutter:\n  uses-material-design: true\n'

# case <name> <expected version or FAIL> <flutter-version input> <pubspec content, empty for none>
case_() {
  new_case
  if [ -n "$4" ]; then printf '%b' "$4" > "$WORK/pubspec.yaml"; fi
  run "$SCRIPT" FLUTTER_VERSION_INPUT="$3"
  if [ "$2" = FAIL ]; then
    expect_fail "$1" "environment.flutter"
  else
    expect "$1" "$2" "$(output version)"
  fi
}

case_ "exact" "3.47.1" "" "${ENV_HEAD}  flutter: 3.47.1\n${DEPS}"
case_ "caret" "3.47.1" "" "${ENV_HEAD}  flutter: ^3.47.1\n${DEPS}"
case_ "range" "3.47.1" "" "${ENV_HEAD}  flutter: \">=3.47.1 <4.0.0\"\n${DEPS}"
case_ "inclusive upper" "3.47.1" "" "${ENV_HEAD}  flutter: '>=3.47.1 <=3.50.0'\n${DEPS}"
case_ "single quotes" "3.47.1" "" "${ENV_HEAD}  flutter: '^3.47.1'\n${DEPS}"
case_ "trailing comment" "3.47.1" "" "${ENV_HEAD}  flutter: ^3.47.1 # pinned\n${DEPS}"
case_ "crlf" "3.47.1" "" "name: app\r\nenvironment:\r\n  flutter: ^3.47.1\r\n"
case_ "pre-release" "3.48.0-0.1.pre" "" "${ENV_HEAD}  flutter: 3.48.0-0.1.pre\n${DEPS}"
case_ "flutter key outside environment ignored" "3.47.1" "" "flutter:\n  uses-material-design: true\n${ENV_HEAD}  flutter: 3.47.1\n"
case_ "input wins over pubspec" "3.40.0" "3.40.0" "${ENV_HEAD}  flutter: ^3.47.1\n"
case_ "input works without pubspec" "3.40.0" "3.40.0" ""
case_ "missing key" FAIL "" "${ENV_HEAD}${DEPS}"
case_ "upper bound only" FAIL "" "${ENV_HEAD}  flutter: <4.0.0\n"
case_ "exclusive lower" FAIL "" "${ENV_HEAD}  flutter: \">3.47.1\"\n"
case_ "any" FAIL "" "${ENV_HEAD}  flutter: any\n"
case_ "partial version" FAIL "" "${ENV_HEAD}  flutter: ^3.47\n"

new_case
run "$SCRIPT"
expect_fail "no pubspec" "pubspec.yaml not found"

new_case
printf '%b' "${ENV_HEAD}  flutter: ^3.47.1\n" > "$WORK/pubspec.yaml"
run "$SCRIPT"
expect "range logs a notice" "1" "$(grep -c '^::notice::.*lower bound 3.47.1' "$CASE_DIR/stdout")"

finish
