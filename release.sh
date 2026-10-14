#!/usr/bin/env bash
set -e

# Usage helper
if [ -z "$1" ]; then
    echo "Usage: ./release.sh <version> [commit_message]"
    echo "Example: ./release.sh 1.3.1 \"Add 3-way row selection and self-pinning\""
    exit 1
fi

VERSION="$1"
# Ensure version string doesn't duplicate the 'v' prefix
RAW_VER="${VERSION#v}"
TAG="v${RAW_VER}"
MSG="${2:-Release ${TAG}}"

echo "==> Preparing release ${TAG}..."

# 1. Verify working directory is clean or has uncommitted changes
if ! git diff-index --quiet HEAD -- || [ -n "$(git status --porcelain)" ]; then
    echo "==> Staging and committing local changes..."
    git add .
    git commit -m "${MSG}"
else
    echo "==> Working directory clean. Proceeding to tag..."
fi

# 2. Check if the tag already exists locally or remotely
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "Error: Tag ${TAG} already exists locally."
    exit 1
fi

if git ls-remote --tags origin | grep -q "refs/tags/${TAG}$"; then
    echo "Error: Tag ${TAG} already exists on remote origin."
    exit 1
fi

# 3. Push branch commits to main
echo "==> Pushing commits to origin/main..."
git push origin main

# 4. Create annotated Git tag
echo "==> Creating annotated tag ${TAG}..."
git tag -a "${TAG}" -m "${MSG}"

# 5. Push the tag to trigger BigWigs packager
echo "==> Pushing ${TAG} to GitHub..."
git push origin "${TAG}"

echo "--------------------------------------------------------"
echo "Success! ${TAG} pushed."
echo "GitHub Actions is now running your BigWigs release workflow:"
echo "https://github.com/foxfair/forever-threat-meter/actions"
echo "--------------------------------------------------------"
