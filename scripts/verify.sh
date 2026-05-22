#!/usr/bin/env bash
# Runs every check we want green before publishing or pushing a sync.
# Host-only — Windows and Linux must be covered by CI.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

run() {
    echo
    echo "==> $*"
    "$@"
}

run cargo fmt --check
run cargo check --all-features --all-targets
run cargo clippy --all-features --all-targets -- -D warnings
run cargo test --all-features

echo
echo "Host checks passed. (Cross-platform coverage still needs CI.)"
