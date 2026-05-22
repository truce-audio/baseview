#!/usr/bin/env bash
# Tag the current master as a truce release and push it.
# Crates.io publishing is a separate step — run scripts/publish.sh after this.
#
# Reads the version from Cargo.toml. Bump that first, commit, then run this.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# --- Read version straight from Cargo.toml (no extra deps) --------------------

version=$(awk -F\" '/^version = "/ { print $2; exit }' Cargo.toml)
if [[ -z "$version" ]]; then
    echo "Could not parse version from Cargo.toml"
    exit 1
fi

tag="truce-v$version"

if git rev-parse "$tag" >/dev/null 2>&1; then
    echo "Tag $tag already exists. Bump version in Cargo.toml first."
    exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Working tree dirty. Commit first."
    exit 1
fi

current_branch=$(git symbolic-ref --short HEAD)
if [[ "$current_branch" != "master" ]]; then
    echo "Not on master (on $current_branch)."
    exit 1
fi

# --- Verify -------------------------------------------------------------------

echo "Verifying..."
scripts/verify.sh

# --- Tag & push ---------------------------------------------------------------

upstream_base=$(git merge-base HEAD origin/master 2>/dev/null || echo "")
patch_summary=""
if [[ -n "$upstream_base" ]]; then
    patch_summary=$(git log --oneline --no-decorate "$upstream_base..HEAD")
fi

echo "Tagging $tag..."
git tag -a "$tag" -m "truce release $version

Rebased on upstream $(git rev-parse --short "$upstream_base" 2>/dev/null || echo unknown).

Patches:
$patch_summary"

echo "Pushing to truce remote..."
git push truce master
git push truce "$tag"

echo
echo "Released $tag."
echo "To publish to crates.io: scripts/publish.sh"
