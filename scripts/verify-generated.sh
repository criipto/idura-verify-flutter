#!/usr/bin/env bash
#
# Fails if the committed bridge does not match what pigeons/messages.dart
# generates right now.
#
# Committing generated code is only safe if it cannot silently drift from its
# schema. This is the guarantee the Expo module's codegen script gives, made cheap:
# regenerate and diff. It relies on the output never being post-processed, which is
# why scripts/generate.sh does nothing but run pigeon.

set -euo pipefail

cd "$(dirname "$0")/.."

generated=(
  lib/src/messages.g.dart
  android/src/main/kotlin/eu/idura/verify/flutter/Messages.g.kt
  ios/idura_verify/Sources/idura_verify/Messages.g.swift
)

if ! git diff --quiet -- pigeons "${generated[@]}"; then
  echo "error: uncommitted changes to the schema or its output; commit or stash first" >&2
  exit 1
fi

./scripts/generate.sh

# Scoped to what generate.sh writes. An unscoped diff reports any unrelated dirty
# file in the tree as a stale bridge, which is a confusing lie while you are in
# the middle of unrelated work.
if ! git diff --exit-code --stat -- "${generated[@]}"; then
  cat >&2 <<'MSG'

error: the committed bridge is stale.
       Run scripts/generate.sh and commit the result alongside the schema change.
MSG
  exit 1
fi

echo "generated bridge is up to date"
