#!/usr/bin/env bash
# Bump the truce iteration suffix in Cargo.toml and commit.
#   0.1.1-truce.1  ->  0.1.1-truce.2
#
# For a new upstream base (e.g. upstream releases 0.1.2 and we rebase onto
# it), edit Cargo.toml manually to "0.1.2-truce.1" — that's a rare event.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Working tree dirty. Commit or stash first."
    exit 1
fi

current=$(awk -F\" '/^version = "/ { print $2; exit }' Cargo.toml)
if [[ -z "$current" ]]; then
    echo "Could not parse version from Cargo.toml"
    exit 1
fi

if ! [[ "$current" =~ ^(.+-truce\.)([0-9]+)$ ]]; then
    echo "Version '$current' doesn't match the X.Y.Z-truce.N pattern."
    echo "Edit Cargo.toml manually."
    exit 1
fi

base="${BASH_REMATCH[1]}"
counter="${BASH_REMATCH[2]}"
next="${base}$((counter + 1))"

echo "Bumping version: $current -> $next"

# Only rewrites the column-0 `version = "..."` line (the package version).
# Dependency versions appear as `windows = { version = "..." }` etc. and
# don't start with "version" at column 0, so they're untouched.
awk -v new="$next" '
    /^version = "/ && !done { sub(/"[^"]+"/, "\"" new "\""); done=1 }
    { print }
' Cargo.toml > Cargo.toml.tmp && mv Cargo.toml.tmp Cargo.toml

# Refresh Cargo.lock so the new version lands there too.
cargo check --offline --quiet 2>/dev/null || cargo check --quiet

git add Cargo.toml Cargo.lock
git commit -m "Bump version to $next"

echo "Committed. Next: scripts/release.sh"
