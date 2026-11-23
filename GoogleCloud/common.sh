#!/bin/sh
# Shared settings for iSH-Scripts/GoogleCloud. Do not put credentials here.
set -eu
GC_DIR="$(CDPATH= cd "$(dirname "$0")" && pwd -P)"
GC_APPS_BASE="${ISH_APPS_BASE:-/mnt/wcopy/apps}"
GC_REPO='tanner-voas/PWA-GoogleDrive'
GC_OAUTH_FILE="${GC_OAUTH_FILE:-/mnt/wcopy/PWAProfiles.client_secrets.apps.googleusercontent.com.json}"
GC_KEYS_FILE="${GC_KEYS_FILE:-/mnt/wcopy/PWAProfiles.worker-keys.json}"
GC_APP_URL='https://applauncher.tannervoas.workers.dev'
GC_CIYAN_URL='https://ciyan.tannervoas.workers.dev'
GC_EXPECTED_REDIRECT_1="$GC_APP_URL/_profiles/v1/auth/callback"
GC_EXPECTED_REDIRECT_2="$GC_CIYAN_URL/_profiles/v1/auth/callback"
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
notice() { printf '\n== %s ==\n' "$*"; }
require() { command -v "$1" >/dev/null 2>&1 || die "Missing $1. Run: apk add $2 (or install it via your iSH package repositories)."; }
auth() { gh auth status >/dev/null 2>&1 || die 'GitHub CLI is not authenticated. Run: gh auth login --hostname github.com --git-protocol https --web'; }
repo_on_main() {
    name=$1
    r="$GC_APPS_BASE/$name"
    [ -e "$r/.git" ] || die "Missing Git repository: $r"
    [ "$(git -C "$r" branch --show-current)" = main ] || die "$name is not on main"
    [ -z "$(git -C "$r" status --porcelain --untracked-files=no)" ] || die "$name has tracked changes or pending Git operations. Resolve them first."
}
validate_oauth() {
    [ -f "$GC_OAUTH_FILE" ] || die "OAuth JSON not found: $GC_OAUTH_FILE"
    python3 - "$GC_OAUTH_FILE" "$GC_EXPECTED_REDIRECT_1" "$GC_EXPECTED_REDIRECT_2" <<'PY'
import json,sys
p,one,two=sys.argv[1:]
try:
 data=json.load(open(p,encoding='utf-8'))['web']
 assert isinstance(data['client_id'],str) and data['client_id'].strip()
 assert isinstance(data['client_secret'],str) and data['client_secret'].strip()
 redirects=data['redirect_uris']
 assert one in redirects and two in redirects
except (OSError,ValueError,KeyError,AssertionError,TypeError):
 sys.exit('ERROR: Invalid Google OAuth JSON, missing credentials, or incorrect redirect URIs. Check Google Cloud Clients.')
print('OAuth JSON validated; both deployment redirect URIs are present. (Credential values hidden.)')
PY
}
