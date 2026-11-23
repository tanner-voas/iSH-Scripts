#!/bin/sh
# Sync all direct child repos; never walk AppLauncher submodules.

BASE="${ISH_APPS_BASE:-/mnt/wcopy/apps}"
SCRIPT_DIR="$(CDPATH= cd "$(dirname "$0")" && pwd -P)" || exit 1
SINGLE="$SCRIPT_DIR/sync-app.sh"

[ -d "$BASE" ] || { echo "Missing apps directory: $BASE" >&2; exit 1; }

count=0
for repo in "$BASE"/*/; do
    [ -d "$repo" ] || continue
    [ -e "$repo/.git" ] || continue
    count=$((count + 1))
done

[ "$count" -gt 0 ] || { echo "No repositories found in $BASE" >&2; exit 1; }
echo "Found $count top-level repositories."

# Preflight all repos BEFORE touching any checkout.
# All fetches and ancestry checks also finish BEFORE any checkout updates.
for phase in check fetch update; do
    case "$phase" in
        check) echo "Phase 1/3: checking local changes" ;;
        fetch) echo "Phase 2/3: fetching and verifying remote history" ;;
        update) echo "Phase 3/3: fast-forwarding clean repositories" ;;
    esac
    for repo in "$BASE"/*/; do
        [ -d "$repo" ] || continue
        [ -e "$repo/.git" ] || continue
        name="${repo%/}"
        name="${name##*/}"
        if ! sh "$SINGLE" "--$phase" "$name"; then
            echo "STOPPED: $name failed $phase phase." >&2
            exit 1
        fi
    done
done

echo "All $count repositories synchronized successfully."
