#!/bin/sh
set -eu
. "$(CDPATH= cd "$(dirname "$0")" && pwd -P)/common.sh"
notice 'GitHub Actions deployment status'
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    gh run list -R "$GC_REPO" --workflow deploy-worker.yml --limit 5 || :
else
    echo 'GitHub CLI unavailable or not authenticated.'
fi
notice 'PWA same-origin profile endpoints'
if command -v curl >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
    for url in "$GC_APP_URL" "$GC_CIYAN_URL"; do
        printf '\n%s\n' "$url"
        # Nonauthenticated /status returns {connected:false} on a working service.
        TMP=$(mktemp)
        HTTP=$(curl --silent --show-error --max-time 20 -o "$TMP" -w '%{http_code}' "$url/_profiles/v1/status") || HTTP='network-error'
        printf 'HTTP %s: ' "$HTTP"
        if [ "$HTTP" = 200 ]; then
            python3 - "$TMP" <<'PY' || true
import json,sys
try:
 data=json.load(open(sys.argv[1]))
 print('Profile API responding (not signed in).' if data.get('connected') is False else 'Unexpected status response; inspect deployment.')
except (ValueError,OSError): print('Non-JSON response; check route and Worker binding.')
PY
        else
            echo 'Not ready or unreachable; inspect app deployment/service binding.'
        fi
        rm -f "$TMP"
    done
else
    echo 'curl/python3 unavailable.'
fi
