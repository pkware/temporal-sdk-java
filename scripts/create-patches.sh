#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$REPO_ROOT/build"
PATCHES_DIR="$REPO_ROOT/patches"

if [ ! -d "$BUILD_DIR/.git" ]; then
  echo "Error: build/ is not a git repository. Run apply-patches.sh first."
  exit 1
fi

cd "$BUILD_DIR"

# The upstream tag commit is the first (root) commit in our shallow clone
BASE_COMMIT=$(git log --format=%H --reverse | head -1)

COMMIT_COUNT=$(git rev-list --count "$BASE_COMMIT"..HEAD)
if [ "$COMMIT_COUNT" -eq 0 ]; then
  echo "No commits on top of upstream. Nothing to export."
  exit 0
fi

# Clear existing patches
rm -f "$PATCHES_DIR"/*.patch

# Export patches
git format-patch --no-numbered "$BASE_COMMIT"..HEAD -o "$PATCHES_DIR"

echo "==> Exported $COMMIT_COUNT patches to patches/"
