#!/usr/bin/env bash
#
# Regenerates the Dart, Kotlin and Swift sides of the bridge from
# pigeons/messages.dart.
#
# The output is committed verbatim and never reformatted. scripts/verify-generated.sh
# re-runs this and diffs, so any post-processing step here would have to be
# reproduced there exactly; taking pigeon's output as-is removes that risk.

set -euo pipefail

cd "$(dirname "$0")/.."

# Prefer the pinned SDK from .fvmrc. Pigeon's output depends on the Dart version
# it runs under, so the drift check is only reproducible when everyone regenerates
# with the same one.
if command -v fvm >/dev/null 2>&1; then
  dart=(fvm dart)
else
  dart=(dart)
fi

"${dart[@]}" run pigeon --input pigeons/messages.dart
