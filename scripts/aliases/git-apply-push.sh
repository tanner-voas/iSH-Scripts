#!/bin/sh
# Synchronize first, apply every patch in order, publish main + tags together.
# Preserve patch files on every failure. Never silently discard local commits.
set -eu
DIR=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
BASE=$(CDPATH= cd "${ISH_APPS_BASE:-/mnt/wcopy/apps}" && pwd -P)
repo=$(pwd -P)
[ "$(dirname "$repo")" = "$BASE" ] && [ -e "$repo/.git" ] || { echo 'Run gamp in a top-level app repo.' >&2; exit 2; }
sh "$DIR/sync-app.sh" "${repo##*/}"
set -- ./*.patch
[ -f "$1" ] || { echo 'No patch files found.' >&2; exit 1; }
# First validate tag state so legacy tags do not strand newly applied patches.
# The initial cleanup patches can be installed with documented git am/push.
sh "$DIR/../tag-versions.sh" --repo "$repo"
git am "$@"
# --push-main generates a revision tag for EACH new commit and publishes the
# complete set atomically with main. If rejected, patches and commits remain.
sh "$DIR/../tag-versions.sh" --repo "$repo" --push-main
rm -f -- "$@"
