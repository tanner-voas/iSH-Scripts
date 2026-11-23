#!/bin/sh
set -eu
. "$(CDPATH= cd "$(dirname "$0")" && pwd -P)/common.sh"
require gh github-cli
auth
WORKFLOW=deploy-worker.yml
if [ "${1:-}" = watch ]; then
    notice 'Watching latest Cloudflare Worker deployment'
    RUN_ID=$(gh run list -R "$GC_REPO" --workflow "$WORKFLOW" --limit 1 --json databaseId --jq '.[0].databaseId')
    [ -n "$RUN_ID" ] && [ "$RUN_ID" != null ] || die 'No Worker deployment run exists yet.'
    exec gh run watch "$RUN_ID" -R "$GC_REPO" --exit-status
fi
notice 'Checking required GitHub Actions secrets'
NAMES=$(gh secret list -R "$GC_REPO" --json name --jq '.[].name') || die 'Cannot list repository secrets.'
for key in CLOUDFLARE_API_TOKEN CLOUDFLARE_ACCOUNT_ID GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET SESSION_SIGNING_KEY VAULT_KEY; do
    printf '%s\n' "$NAMES" | grep -qx "$key" || die "Missing Actions secret $key in $GC_REPO. Run gc.sh setup."
done
notice 'Dispatching Wrangler deployment on GitHub Linux runner'
gh workflow run "$WORKFLOW" -R "$GC_REPO" --ref main
printf 'Triggered. Check: https://github.com/%s/actions/workflows/%s\n' "$GC_REPO" "$WORKFLOW"
echo 'To follow: sh iSH-Scripts/GoogleCloud/gc.sh watch'
