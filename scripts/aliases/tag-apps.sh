#!/bin/sh
# tagapps [--all] [options]; default: current top-level repository.
set -eu
BASE=$(CDPATH= cd "${ISH_APPS_BASE:-/mnt/wcopy/apps}" && pwd -P)
DIR=$(CDPATH= cd "$(dirname "$0")/.." && pwd -P)
if [ "${1:-}" = --all ]; then
    shift
    for repo in "$BASE"/*/; do
        [ -e "$repo/.git" ] || continue
        sh "$DIR/tag-versions.sh" --repo "$repo" "$@"
    done
else
    repo=$(pwd -P)
    [ "$(dirname "$repo")" = "$BASE" ] && [ -e "$repo/.git" ] || { echo 'Run inside a top-level app repo, or use tagapps --all.' >&2; exit 2; }
    sh "$DIR/tag-versions.sh" --repo "$repo" "$@"
fi
