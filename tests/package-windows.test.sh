#!/usr/bin/env bash
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
only_on linux macos windows
if ! command -v pwsh > /dev/null; then
  echo "skip $(basename "$0"): pwsh not installed (it is on every GitHub runner)"
  exit 0
fi

SCRIPT="$REPO_ROOT/build-flutter/scripts/package-windows.ps1"
RUNNER=build/windows/x64/runner

new_case
mkdir -p "$WORK/$RUNNER/Release" "$WORK/$RUNNER/Debug/data"
echo release > "$WORK/$RUNNER/Release/my_app.exe"
echo debug > "$WORK/$RUNNER/Debug/my_app.exe"
touch "$WORK/$RUNNER/Debug/data/app.so"
run "$SCRIPT" BUILD_MODE=debug APP_NAME=my_app MODE_SUFFIX=-debug
expect_ok "windows exits 0"
expect_file "windows zip name" "dist/my_app-windows-debug.zip"
# shellcheck disable=SC2016 # $_ is PowerShell, not bash.
expect "windows zips the runner dir of the build mode (case-insensitive)" "data/app.so my_app.exe" \
  "$(cd "$WORK" && pwsh -NoProfile -Command '[IO.Compression.ZipFile]::OpenRead("dist/my_app-windows-debug.zip").Entries.FullName -replace "\\","/" | Where-Object { $_ -notlike "*/" } | Sort-Object' | tr -d '\r' | tr '\n' ' ' | sed 's/ $//')"

new_case
mkdir -p "$WORK/$RUNNER/Release"
echo release > "$WORK/$RUNNER/Release/my_app.exe"
run "$SCRIPT" APP_NAME=my_app
expect_file "windows defaults to release without suffix" "dist/my_app-windows.zip"

new_case
mkdir -p "$WORK/$RUNNER/Release"
run "$SCRIPT" BUILD_MODE=profile APP_NAME=my_app MODE_SUFFIX=-profile
expect_fail "windows runner dir for build mode missing"

finish
