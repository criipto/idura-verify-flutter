#!/usr/bin/env bash
#
# Bumps the package version, commits it on master and tags it, ready to push.
#
# Usage: scripts/bump-version.sh --patch | --minor | --major
#
# Nothing is pushed. Pushing the tag is what publishes to pub.dev, so that step
# stays a deliberate one — see DEVELOPING.md, "Releasing".

set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") --patch | --minor | --major

Bumps the version in pubspec.yaml, commits it on master and creates the tag
v<version>. Nothing is pushed.

Flags (exactly one is required):
  --patch   Bump PATCH (X.Y.Z -> X.Y.Z+1)
  --minor   Bump MINOR (X.Y.Z -> X.Y+1.0)
  --major   Bump MAJOR (X.Y.Z -> X+1.0.0)
EOF
}

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 1
fi

case "$1" in
  -h|--help) usage; exit 0 ;;
  --patch|--minor|--major) BUMP="${1#--}" ;;
  *)
    echo "Error: expected exactly one of --patch, --minor, --major (got '$1')." >&2
    usage >&2
    exit 1
    ;;
esac

cd "$(dirname "$0")/.."

PUBSPEC="pubspec.yaml"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Error: working tree is not clean. Commit or stash changes first." >&2
  git status --short >&2
  exit 1
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" != "master" ]]; then
  echo "Error: must be on master (currently on '$BRANCH')." >&2
  exit 1
fi

echo "Fetching origin..."
git fetch --quiet --tags origin master

if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/master)" ]]; then
  echo "Error: local master is not in sync with origin/master." >&2
  exit 1
fi

current_version() {
  sed -nE 's/^version: ([^[:space:]]+)[[:space:]]*$/\1/p' "$PUBSPEC"
}

CURRENT="$(current_version)"
if [[ ! "$CURRENT" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "Error: version '$CURRENT' in $PUBSPEC is not plain MAJOR.MINOR.PATCH; bump it by hand." >&2
  exit 1
fi
MAJOR="${BASH_REMATCH[1]}"
MINOR="${BASH_REMATCH[2]}"
PATCH="${BASH_REMATCH[3]}"

case "$BUMP" in
  patch) PATCH=$((PATCH + 1)) ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
esac
VERSION="$MAJOR.$MINOR.$PATCH"
TAG="v$VERSION"

# The fetch above brought origin's tags in, so this covers both.
if git rev-parse --verify --quiet "refs/tags/$TAG" >/dev/null; then
  echo "Error: tag '$TAG' already exists." >&2
  exit 1
fi

echo "Bumping version: $CURRENT -> $VERSION ($BUMP)"
# -i.bak rather than -i, so the same invocation works with BSD and GNU sed.
sed -i.bak -E "s/^version: .*/version: $VERSION/" "$PUBSPEC"
rm "$PUBSPEC.bak"

if [[ "$(current_version)" != "$VERSION" ]]; then
  echo "Error: failed to update the version in $PUBSPEC." >&2
  git checkout -- "$PUBSPEC"
  exit 1
fi

git add "$PUBSPEC"
git commit --quiet -m "Release $VERSION

pub.dev only accepts a release whose tag matches the version in pubspec.yaml."
git tag -a "$TAG" -m "Release $VERSION"

cat <<EOF

Committed and tagged $TAG. Nothing has been pushed. To release:

  git push --atomic origin master $TAG

Pushing the tag starts the publish to pub.dev. Then write the release notes,
which are the package's changelog:

  gh release create $TAG --verify-tag --generate-notes --draft

and edit the draft on GitHub before publishing it.
EOF
