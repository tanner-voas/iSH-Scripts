#!/bin/sh
# Runs all tests in a temporary directory without touching the actual workspace.
set -eu
ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
BASE="$TMP/apps"
mkdir -p "$BASE"
export ISH_APPS_BASE="$BASE"
export HOME="$TMP/home"
mkdir -p "$HOME"
export GIT_CONFIG_NOSYSTEM=1

init_repo() {
    name="$1"
    git init -q --bare "$TMP/$name.git"
    git clone -q "$TMP/$name.git" "$BASE/$name"
    git -C "$BASE/$name" config user.name Test
    git -C "$BASE/$name" config user.email test@example.invalid
    git -C "$BASE/$name" checkout -q -b main
    printf 'initial\n' > "$BASE/$name/tracked.txt"
    git -C "$BASE/$name" add tracked.txt
    git -C "$BASE/$name" commit -qm initial
    git -C "$BASE/$name" push -q -u origin main
    git --git-dir="$TMP/$name.git" symbolic-ref HEAD refs/heads/main
    git clone -q "$TMP/$name.git" "$TMP/${name}-upstream"
    git -C "$TMP/${name}-upstream" config user.name Test
    git -C "$TMP/${name}-upstream" config user.email test@example.invalid
}

push_update() {
    name="$1"
    file="$2"
    printf 'remote update\n' > "$TMP/${name}-upstream/$file"
    git -C "$TMP/${name}-upstream" add "$file"
    git -C "$TMP/${name}-upstream" commit -qm update
    git -C "$TMP/${name}-upstream" push -q origin main
}

init_repo Alpha
init_repo Beta
push_update Alpha another.txt
push_update Beta another.txt

# Tracked edit in Beta stops the entire batch before Alpha is updated.
printf 'changed\n' > "$BASE/Beta/tracked.txt"
old_alpha="$(git -C "$BASE/Alpha" rev-parse HEAD)"
if sh "$ROOT/scripts/aliases/sync-apps.sh" >"$TMP/out" 2>&1; then
    echo 'FAIL: dirty batch should fail' >&2
    exit 1
fi
[ "$(git -C "$BASE/Alpha" rev-parse HEAD)" = "$old_alpha" ] || exit 1
[ "$(cat "$BASE/Beta/tracked.txt")" = changed ] || exit 1

git -C "$BASE/Beta" checkout -q -- tracked.txt

# Untracked files and uncommitted patches must survive a successful sync.
printf 'keep\n' > "$BASE/Alpha/untracked.txt"
printf 'temporary patch\n' > "$BASE/Alpha/obsolete.patch"
sh "$ROOT/scripts/aliases/sync-apps.sh" >"$TMP/out" 2>&1 || {
    cat "$TMP/out"; exit 1;
}
[ -f "$BASE/Alpha/another.txt" ] || exit 1
[ -f "$BASE/Beta/another.txt" ] || exit 1
[ "$(cat "$BASE/Alpha/untracked.txt")" = keep ] || exit 1
[ "$(cat "$BASE/Alpha/obsolete.patch")" = "temporary patch" ] || exit 1

# Local commits never get discarded.
printf 'locally committed\n' > "$BASE/Alpha/local.txt"
git -C "$BASE/Alpha" add local.txt
git -C "$BASE/Alpha" commit -qm local
old_local="$(git -C "$BASE/Alpha" rev-parse HEAD)"
if sh "$ROOT/scripts/aliases/sync-app.sh" Alpha >"$TMP/out" 2>&1; then
    echo 'FAIL: local ahead commit should fail' >&2
    exit 1
fi
[ "$(git -C "$BASE/Alpha" rev-parse HEAD)" = "$old_local" ] || exit 1

# An untracked file with the same name as a remote addition cannot be clobbered.
push_update Beta conflict.txt
printf 'my untracked data\n' > "$BASE/Beta/conflict.txt"
if sh "$ROOT/scripts/aliases/sync-app.sh" Beta >"$TMP/out" 2>&1; then
    echo 'FAIL: untracked collision should fail' >&2
    exit 1
fi
[ "$(cat "$BASE/Beta/conflict.txt")" = 'my untracked data' ] || exit 1

echo 'PASS: dirty guard, preflight, untracked protection, patch preservation, local commits.'
