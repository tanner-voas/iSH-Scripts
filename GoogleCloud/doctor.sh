#!/bin/sh
set -eu
. "$(CDPATH= cd "$(dirname "$0")" && pwd -P)/common.sh"
notice 'iSH prerequisites'
for name in git python3 gh curl; do
    if command -v "$name" >/dev/null 2>&1; then
        printf '%-8s OK\n' "$name"
    else
        printf '%-8s MISSING\n' "$name"
    fi
done
[ -f "$GC_OAUTH_FILE" ] && printf 'OAuth file present: %s\n' "$GC_OAUTH_FILE" || printf 'OAuth file missing: %s\n' "$GC_OAUTH_FILE"
[ -f "$GC_KEYS_FILE" ] && echo 'Saved Worker keys file present (values hidden).' || echo 'Worker keys file not created yet.'
if command -v python3 >/dev/null 2>&1 && [ -f "$GC_OAUTH_FILE" ]; then validate_oauth; fi
if command -v gh >/dev/null 2>&1; then
    if gh auth status >/dev/null 2>&1; then echo 'GitHub CLI authenticated.'; else echo 'GitHub CLI not authenticated.'; fi
fi
notice 'Repository versions'
if command -v python3 >/dev/null 2>&1; then
    for name in PWA-GoogleDrive AppLauncher Ciyan; do
        r="$GC_APPS_BASE/$name"
        if [ -f "$r/package.json" ]; then
            printf '%s ' "$name"
            python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("version","unknown"))' "$r/package.json"
        else
            echo "$name missing at $r"
        fi
    done
fi
printf '\nUse: sh "%s/gc.sh" help\n' "$GC_DIR"
