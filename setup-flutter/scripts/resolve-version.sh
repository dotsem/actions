#!/usr/bin/env bash
# Resolves the Flutter SDK version to install: the flutter-version input, or environment.flutter from pubspec.yaml.
# subosito/flutter-action only matches exact versions, so ranges are reduced to their lower bound here.
set -euo pipefail

VERSION="${FLUTTER_VERSION_INPUT:-}"
PUBSPEC="${PUBSPEC:-pubspec.yaml}"

if [ -z "$VERSION" ]; then
  if [ ! -f "$PUBSPEC" ]; then
    echo "::error::$PUBSPEC not found. Pass flutter-version or set working-directory"
    exit 1
  fi

  # Windows runners check out with CRLF, hence the \r strip.
  CONSTRAINT=$(awk '
    { sub(/\r$/, "") }
    /^environment:/ { in_env = 1; next }
    in_env && /^[^[:space:]#]/ { in_env = 0 }
    in_env && /^[[:space:]]+flutter:/ {
      sub(/^[[:space:]]+flutter:[[:space:]]*/, "")
      sub(/[[:space:]]+#.*$/, "")
      print
      exit
    }
  ' "$PUBSPEC")
  CONSTRAINT="${CONSTRAINT//[\"\']/}"

  # ponytail: a range installs its lower bound, not the newest matching release. Pin an exact version to build what you ship.
  SEMVER='[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?'
  RANGE="^(\^|>=)?[[:space:]]*(${SEMVER})([[:space:]]+<=?[[:space:]]*${SEMVER})?$"
  if [[ ! "$CONSTRAINT" =~ $RANGE ]]; then
    echo "::error::Unsupported environment.flutter '${CONSTRAINT}' in $PUBSPEC. Allowed: 3.47.1, ^3.47.1, '>=3.47.1 <4.0.0', or pass flutter-version"
    exit 1
  fi
  VERSION="${BASH_REMATCH[2]}"

  if [ "$VERSION" != "$CONSTRAINT" ]; then
    echo "::notice::Resolved environment.flutter '${CONSTRAINT}' to its lower bound ${VERSION}"
  fi
fi

echo "version=$VERSION" >> "$GITHUB_OUTPUT"
