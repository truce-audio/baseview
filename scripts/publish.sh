#!/usr/bin/env bash
# Publishes baseview-truce to crates.io.
# Run AFTER scripts/release.sh has tagged and pushed the current version —
# this script refuses to publish state that isn't tagged, so the git tag
# and the crates.io version always agree.
#
# Assumes `cargo login` has been run, or CARGO_REGISTRY_TOKEN is set.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

crate="baseview-truce"

# --- Read version from Cargo.toml --------------------------------------------

version=$(awk -F\" '/^version = "/ { print $2; exit }' Cargo.toml)
if [[ -z "$version" ]]; then
    echo "Could not parse version from Cargo.toml"
    exit 1
fi

tag="v$version"

# --- Pre-flight --------------------------------------------------------------

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Working tree dirty. Commit first."
    exit 1
fi

if ! git rev-parse "$tag" >/dev/null 2>&1; then
    echo "No tag $tag exists. Run scripts/release.sh first."
    exit 1
fi

if [[ "$(git rev-parse HEAD)" != "$(git rev-parse "$tag^{commit}")" ]]; then
    echo "HEAD does not match $tag. Check out the tagged commit before publishing."
    exit 1
fi

if curl -sfo /dev/null "https://crates.io/api/v1/crates/$crate/$version"; then
    echo "$crate $version is already on crates.io. Nothing to do."
    echo "  https://crates.io/crates/$crate/$version"
    exit 0
fi

# --- Verify ------------------------------------------------------------------

echo "Verifying..."
scripts/verify.sh

# --- Dry run -----------------------------------------------------------------

echo
echo "==> cargo publish --dry-run -p $crate"
cargo publish --dry-run -p "$crate"

echo
echo "Dry run succeeded for $crate $version."
read -r -p "Publish for real to crates.io? [y/N] " ans
[[ "$ans" == "y" || "$ans" == "Y" ]] || { echo "Aborted."; exit 0; }

# --- Publish -----------------------------------------------------------------

cargo publish -p "$crate"

echo
echo "Published $crate $version."
echo "  https://crates.io/crates/$crate/$version"
