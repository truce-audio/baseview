# Shared helpers for the release scripts. Sourced, not executed.
#
# Picks which cargo drives the build. On the Windows dev box the native
# toolchain is `cargo.exe` (reached from Git Bash / WSL); the Linux
# `cargo` available there can't build the `cfg(windows)` code these
# checks have to cover, so the fork's Windows patches would go unverified.
# Prefer `cargo.exe` when it's on PATH, fall back to plain `cargo`
# elsewhere, and let the caller force either with `CARGO=...`.
if [[ -z "${CARGO:-}" ]]; then
    if command -v cargo.exe >/dev/null 2>&1; then
        CARGO=cargo.exe
    else
        CARGO=cargo
    fi
fi
export CARGO
