#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$REPO_ROOT/build"
PATCHES_DIR="$REPO_ROOT/patches"
OVERLAY_DIR="$REPO_ROOT/overlay"
UPSTREAM_REPO="https://github.com/temporalio/sdk-java.git"

TAG="${1:-$(cat "$REPO_ROOT/.upstream-version")}"

if [ -z "$TAG" ]; then
  echo "Error: No tag specified and .upstream-version is empty"
  exit 1
fi

echo "==> Target upstream tag: $TAG"

# If build/ exists, check its state
if [ -d "$BUILD_DIR/.git" ]; then
  cd "$BUILD_DIR"

  # Check for uncommitted changes
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Error: build/ has uncommitted changes. Commit or stash them first."
    exit 1
  fi

  # Check if we're already at the right state
  CURRENT_BASE=$(git log --format=%H --reverse | head -1)
  CURRENT_TAG=$(git describe --tags "$CURRENT_BASE" 2>/dev/null || echo "unknown")
  PATCH_COUNT=$(find "$PATCHES_DIR" -name '*.patch' 2>/dev/null | wc -l | tr -d ' ')
  COMMIT_COUNT=$(git rev-list --count "$CURRENT_BASE"..HEAD)

  if [ "$CURRENT_TAG" = "$TAG" ] && [ "$PATCH_COUNT" = "$COMMIT_COUNT" ]; then
    echo "==> build/ already at $TAG with $PATCH_COUNT patches applied. Nothing to do."
    exit 0
  fi

  echo "Error: build/ exists at $CURRENT_TAG but target is $TAG."
  echo "       Export patches first (./scripts/create-patches.sh) then 'rm -rf build' manually."
  exit 1
fi

# Clone upstream at target tag
echo "==> Cloning temporalio/sdk-java at $TAG..."
git clone --depth=1 --branch "$TAG" "$UPSTREAM_REPO" "$BUILD_DIR"

# Apply patches
cd "$BUILD_DIR"
PATCH_FILES=("$PATCHES_DIR"/*.patch)
if [ -e "${PATCH_FILES[0]}" ]; then
  echo "==> Applying patches..."
  # Ensure git identity exists for git am (CI runners may not have one)
  git config user.name >/dev/null 2>&1 || git config user.name "temporal-sdk-pkware"
  git config user.email >/dev/null 2>&1 || git config user.email "temporal-sdk-pkware@pkware.com"

  if ! git am "${PATCH_FILES[@]}"; then
    echo ""
    echo "Error: Patch apply failed. Resolve conflicts in build/, then:"
    echo "  cd build && git am --continue"
    echo "  cd .. && ./scripts/create-patches.sh"
    exit 1
  fi
  echo "==> Applied ${#PATCH_FILES[@]} patches."
else
  echo "==> No patches to apply."
fi

# Copy overlay files (not tracked by git — these are build-time config, not patches)
if [ -d "$OVERLAY_DIR" ] && [ "$(ls -A "$OVERLAY_DIR")" ]; then
  echo "==> Copying overlay files..."
  cp -R "$OVERLAY_DIR"/* "$BUILD_DIR"/

  # Prevent overlay files from being accidentally committed as patches
  cd "$BUILD_DIR"
  for f in $(cd "$OVERLAY_DIR" && find . -type f | sed 's|^\./||'); do
    if ! git check-ignore -q "$f" 2>/dev/null; then
      echo "$f" >> .git/info/exclude
    fi
  done
fi

echo ""
echo "==> Done. build/ is ready at $TAG with patches applied."
echo "    cd build && ./gradlew build"
