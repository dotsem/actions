#!/usr/bin/env bash
set -euo pipefail

if [ ! -d "dist" ] || [ -z "$(ls -A dist 2>/dev/null)" ]; then
  echo "::error::Packaging produced no artifacts in dist/"
  exit 1
fi
echo "artifact-name=${APP_NAME}-${TARGET}${MODE_SUFFIX}" >> "$GITHUB_OUTPUT"
echo "artifact-path=${WORKING_DIRECTORY}/dist/*" >> "$GITHUB_OUTPUT"
