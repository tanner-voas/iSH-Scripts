#!/bin/sh
# Safely sync one existing repository to origin/main.
# Usage: sync-app.sh [--check|--fetch|--update] RELATIVE_REPO_PATH

BASE="${ISH_APPS_BASE:-/mnt/wcopy/apps}"
MODE=all

case "${1:-}" in
    --check|--fetch|--update)
        MODE="${1#--}"
        shift
        ;;
esac

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
    echo "Usage: syncapp REPO (relative to $BASE)" >&2
    exit 2
fi

case "$1" in
    /*) echo "Error: use a relative repository path." >&2; exit 2 ;;
esac

BASE="$(cd "$BASE" 2>/dev/null && pwd -P)" || {
    echo "Error: app workspace is missing: $BASE" >&2
    exit 1
}

repo="$(cd "$BASE/$1" 2>/dev/null && pwd -P)" || {
    echo "Error: directory not found: $1" >&2
    exit 1
}

case "$repo" in
    "$BASE"/*) ;;
    *) echo "Error: repository must be inside $BASE" >&2; exit 1 ;;
esac

if [ ! -e "$repo/.git" ]; then
    echo "Error: not an independent Git checkout: ${repo#"$BASE"/}" >&2
    exit 1
fi

name="${repo#"$BASE"/}"

# Mark safe before invoking Git inside a potentially differently owned checkout.
if ! git config --global --get-all safe.directory 2>/dev/null | grep -Fxq "$repo"; then
    git config --global --add safe.directory "$repo" || exit 1
fi

check_local() {
    branch="$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null)" || {
        echo "REFUSED $name: detached HEAD; expected main." >&2
        return 1
    }
    if [ "$branch" != main ]; then
        echo "REFUSED $name: checked-out branch is $branch, not main." >&2
        return 1
    fi

    # Include staged, unstaged, deleted, renamed and submodule tracked changes.
    # Intentionally ignore untracked files; Git fast-forward won't clobber them.
    changes="$(git -C "$repo" status --porcelain --untracked-files=no)" || return 1
    if [ -n "$changes" ]; then
        echo "REFUSED $name: tracked files have local changes:" >&2
        printf '%s\n' "$changes" >&2
        return 1
    fi
}

check_remote() {
    if ! git -C "$repo" show-ref --quiet --verify refs/remotes/origin/main; then
        echo "REFUSED $name: no origin/main reference; check your remote." >&2
        return 1
    fi
    # Don't throw away commits local to main or diverged from origin/main.
    if ! git -C "$repo" merge-base --is-ancestor HEAD refs/remotes/origin/main; then
        echo "REFUSED $name: local main has commits not contained in origin/main." >&2
        return 1
    fi
}

fetch_remote() {
    echo "Fetching $name..."
    git -C "$repo" -c fetch.recurseSubmodules=false fetch --all || return 1
    check_remote
}

update_remote() {
    check_local || return 1
    check_remote || return 1
    echo "Updating $name..."
    # Safe replacement for reset --hard: reaches the same remote commit if
    # fast-forwardable, but refuses untracked filename collisions.
    git -C "$repo" -c submodule.recurse=false merge --ff-only refs/remotes/origin/main || return 1

    # Never remove or alter unapplied .patch files. They may contain user work.
    # `gamp` is responsible for deleting only the patches it actually applied.
    echo "UPDATED $name: $(git -C "$repo" rev-parse --short=12 HEAD)"
    echo "SUCCESS: $name"
}

case "$MODE" in
    check) check_local ;;
    fetch) check_local && fetch_remote ;;
    update) update_remote ;;
    all) check_local && fetch_remote && update_remote ;;
esac
