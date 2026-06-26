#!/usr/bin/env bash
# Runs every check we want green before publishing or pushing a sync.
# Host-only — Windows and Linux must be covered by CI.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

cd "$(git rev-parse --show-toplevel)"

run() {
    echo
    echo "==> $*"
    "$@"
}

run "$CARGO" fmt --check
run "$CARGO" check --all-features --all-targets
run "$CARGO" clippy --all-features --all-targets -- -D warnings
run "$CARGO" test --all-features

echo
echo "Host checks passed. (Cross-platform coverage still needs CI.)"
