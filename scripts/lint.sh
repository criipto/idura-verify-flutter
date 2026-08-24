#!/usr/bin/env bash
#
# Every static check that needs no device, in one place so CI and humans run the
# same thing.
#
# Generated files are excluded throughout. Pigeon's output is committed verbatim
# so scripts/verify-generated.sh can diff it byte for byte, which means it must
# not be reformatted to satisfy a linter. Kotlin is excluded via .editorconfig,
# Swift via .swiftlint.yml, and Dart via scripts/format.sh.

set -euo pipefail

cd "$(dirname "$0")/.."

if command -v fvm >/dev/null 2>&1; then
  flutter=(fvm flutter)
else
  flutter=(flutter)
fi

status=0

echo "==> dart format"
./scripts/format.sh --check || status=1

echo "==> flutter analyze"
"${flutter[@]}" analyze --fatal-infos || status=1

echo "==> ktlint"
if command -v ktlint >/dev/null 2>&1; then
  ktlint 'android/**/*.kt' 'example/android/**/*.kt' || status=1
else
  echo "ktlint not installed, skipping (see DEVELOPING.md)"
fi

echo "==> swiftlint"
if command -v swiftlint >/dev/null 2>&1; then
  swiftlint lint --strict --quiet || status=1
else
  echo "swiftlint not installed, skipping (see DEVELOPING.md)"
fi

exit "$status"
