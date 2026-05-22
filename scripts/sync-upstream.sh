#!/usr/bin/env bash
# Rebase the truce patch stack on top of upstream RustAudio/baseview master.
#
# Branch model:
#   origin = RustAudio/baseview  (upstream, read-only)
#   truce  = truce-audio/baseview (our published fork)
#   master = the truce patch stack, rebased on top of origin/master
#
# Always rebase, never merge, so `git log origin/master..HEAD` stays a clean
# stack of named patch commits that mirror what we want to send upstream.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# --- Pre-flight ---------------------------------------------------------------

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Working tree dirty. Commit or stash first."
    exit 1
fi

current_branch=$(git symbolic-ref --short HEAD)
if [[ "$current_branch" != "master" ]]; then
    echo "Not on master (on $current_branch). Switch first."
    exit 1
fi

# --- Fetch & report -----------------------------------------------------------

echo "Fetching upstream (origin)..."
git fetch origin master

base=$(git merge-base HEAD origin/master)
new_upstream=$(git rev-list --count "$base..origin/master")
patches=$(git rev-list --count "$base..HEAD")

if [[ "$new_upstream" -eq 0 ]]; then
    echo "Already up to date with upstream. ($patches truce patches on top.)"
    exit 0
fi

echo
echo "Upstream has $new_upstream new commits since last sync:"
git log --oneline --no-decorate "$base..origin/master"
echo
echo "We have $patches truce patches to rebase:"
git log --oneline --no-decorate "$base..HEAD"
echo

read -r -p "Proceed with rebase onto origin/master? [y/N] " ans
[[ "$ans" == "y" || "$ans" == "Y" ]] || { echo "Aborted."; exit 1; }

# --- Backup + rebase ----------------------------------------------------------

backup_tag="truce-sync-backup-$(date +%Y%m%d-%H%M%S)"
git tag "$backup_tag" master
echo "Tagged backup: $backup_tag"

if ! git rebase origin/master; then
    cat <<EOF

Rebase paused with conflicts. The risky file is src/macos/window.rs
(WindowInner::close — the AAX teardown patch).

Resolve, then continue with:
  git rebase --continue
Or abort with:
  git rebase --abort   # leaves you back on $backup_tag

Once the rebase finishes, re-run:
  scripts/verify.sh
EOF
    exit 1
fi

echo
echo "Rebase clean. Running verification..."
scripts/verify.sh

cat <<EOF

Sync complete.

Review:   git log --oneline $backup_tag..HEAD
Publish:  git push truce master --force-with-lease
Cleanup:  git tag -d $backup_tag   (once you're happy)
EOF
