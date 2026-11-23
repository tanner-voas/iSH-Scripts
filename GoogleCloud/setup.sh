#!/bin/sh
# Upload GitHub Actions secrets without disclosing values in source control or terminal output.
set -eu
. "$(CDPATH= cd "$(dirname "$0")" && pwd -P)/common.sh"
require gh github-cli
require python3 python3
require git git
auth
validate_oauth
[ -f "$GC_APPS_BASE/PWA-GoogleDrive/.github/workflows/deploy-worker.yml" ] || die 'Apply PWA-GoogleDrive v0.1.3 deploy-action patch before setup.'
notice 'Checking GitHub repository access'
gh repo view "$GC_REPO" --json nameWithOwner --jq .nameWithOwner >/dev/null || die 'GitHub repository cannot be accessed with your gh account.'
notice 'Uploading Google OAuth values directly from the local JSON'
# Pipeline outputs go ONLY to gh secret set. Credential values never enter argv or logs.
python3 -c 'import json,sys;sys.stdout.write(json.load(open(sys.argv[1]))["web"]["client_id"])' "$GC_OAUTH_FILE" | gh secret set GOOGLE_CLIENT_ID -R "$GC_REPO"
python3 -c 'import json,sys;sys.stdout.write(json.load(open(sys.argv[1]))["web"]["client_secret"])' "$GC_OAUTH_FILE" | gh secret set GOOGLE_CLIENT_SECRET -R "$GC_REPO"
notice 'Preserving persistent keys for encrypted cloud sessions'
# Critical: if the key file was lost after initial setup, never generate replacement keys
# over existing GitHub secrets. That would invalidate all stored encrypted refresh tokens.
if [ ! -e "$GC_KEYS_FILE" ]; then
    EXISTING=$(gh secret list -R "$GC_REPO" --json name --jq '.[].name') || die "Cannot check whether encryption keys already exist on GitHub; refusing to generate new keys."
    if printf '%s\n' "$EXISTING" | grep -Eq '^(VAULT_KEY|SESSION_SIGNING_KEY)$'; then
        die "Existing keys found on GitHub but $GC_KEYS_FILE is missing. Recover the original keys before retrying; refusing rotation."
    fi
fi
python3 - "$GC_KEYS_FILE" <<'PY'
import sys,json,os,secrets,base64,stat
path=sys.argv[1]
if not os.path.isfile(path):
    def key(n):return base64.urlsafe_b64encode(secrets.token_bytes(n)).decode().rstrip('=')
    data={'SESSION_SIGNING_KEY':key(48),'VAULT_KEY':key(32)}
    fd=os.open(path,os.O_CREAT|os.O_EXCL|os.O_WRONLY,0o600)
    with os.fdopen(fd,'w') as fp:
        json.dump(data,fp)
        fp.write('\n')
    print('Created fresh Worker keys file. Make an encrypted backup of this file.')
else:
    data=json.load(open(path))
    def size(k):
        s=data.get(k)
        return len(base64.urlsafe_b64decode(s+'='*((-len(s))%4))) if isinstance(s,str) else 0
    assert size('SESSION_SIGNING_KEY')==48 and size('VAULT_KEY')==32,'Invalid existing key lengths'
    if stat.S_IMODE(os.stat(path).st_mode)&0o077:
        raise SystemExit('ERROR: Existing keys file is too permissive. Run chmod 600 on it.')
    print('Reusing existing Worker keys (no rotation).')
PY
python3 -c 'import json,sys;sys.stdout.write(json.load(open(sys.argv[1]))["SESSION_SIGNING_KEY"])' "$GC_KEYS_FILE" | gh secret set SESSION_SIGNING_KEY -R "$GC_REPO"
python3 -c 'import json,sys;sys.stdout.write(json.load(open(sys.argv[1]))["VAULT_KEY"])' "$GC_KEYS_FILE" | gh secret set VAULT_KEY -R "$GC_REPO"
notice 'Cloudflare account and limited API token'
printf 'Enter Cloudflare Account ID (32 hexadecimal characters): '
IFS= read -r ACCOUNT_ID
case "$ACCOUNT_ID" in
    *[!0123456789abcdefABCDEF]*|'') die 'Cloudflare Account ID must contain only hex characters.' ;;
esac
[ "${#ACCOUNT_ID}" -eq 32 ] || die 'Cloudflare Account ID must be exactly 32 characters.'
printf '%s' "$ACCOUNT_ID" | gh secret set CLOUDFLARE_ACCOUNT_ID -R "$GC_REPO"
unset ACCOUNT_ID
[ -r /dev/tty ] || die 'An interactive terminal is required to enter the Cloudflare API token.'
printf 'Paste the Cloudflare API token (input hidden), then press Enter: ' > /dev/tty
OLD_TTY=$(stty -g </dev/tty) || die 'Cannot disable terminal echo.'
trap 'stty "$OLD_TTY" </dev/tty 2>/dev/null || : ' 0 1 2 3 15
stty -echo </dev/tty
IFS= read -r CF_TOKEN </dev/tty || die 'Cannot read Cloudflare token.'
stty "$OLD_TTY" </dev/tty
trap - 0 1 2 3 15
printf '\n' > /dev/tty
[ -n "$CF_TOKEN" ] || die 'Empty Cloudflare API token.'
printf '%s' "$CF_TOKEN" | gh secret set CLOUDFLARE_API_TOKEN -R "$GC_REPO"
unset CF_TOKEN
notice 'Setup complete'
printf 'Encrypted GitHub Actions secrets installed. Local key backup: %s\n' "$GC_KEYS_FILE"
echo 'Now run: sh iSH-Scripts/GoogleCloud/gc.sh deploy'
echo 'IMPORTANT: Back up the keys file securely. Never commit or share it.'
