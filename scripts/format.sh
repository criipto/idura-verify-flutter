#!/usr/bin/env bash
#
# Formats every hand-written Dart file. Pass --check to report instead of rewrite,
# which is what scripts/lint.sh does.
#
# Use this rather than `dart format lib`. Pigeon's output is committed verbatim so
# scripts/verify-generated.sh can diff it byte for byte, and reformatting it makes
# that check fail. `dart format` has no ignore file, so the exclusion has to live
# in the invocation — which is why it lives here once rather than in every caller.

set -euo pipefail

cd "$(dirname "$0")/.."

if command -v fvm >/dev/null 2>&1; then
  dart=(fvm dart)
else
  dart=(dart)
fi

args=()
if [[ "${1:-}" == "--check" ]]; then
  args=(--output=none --set-exit-if-changed)
fi

# --others so a file that is new but not yet staged is still formatted, since a
# missed one only surfaces later as a CI failure.
git ls-files --cached --others --exclude-standard '*.dart' |
  grep -v '\.g\.dart$' |
  xargs "${dart[@]}" format ${args[@]+"${args[@]}"}
