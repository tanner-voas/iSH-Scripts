#!/bin/sh
# Test registration without touching the user's shell profile.
set -eu
ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' 0
trap 'exit 1' 1 2 3 15

export HOME="$TMP"
export ISH_PROFILE_FILE="$TMP/.profile"

cat > "$ISH_PROFILE_FILE" <<'PROFILE'
# My existing settings
alias other='echo unchanged'
alias syncapps='sh "$HOME/old-sync-apps.sh"'
alias gamp='sh "$HOME/old-apply.sh"'
PROFILE

sh "$ROOT/scripts/register_aliases.sh" > "$TMP/install.log"
cp "$ISH_PROFILE_FILE" "$TMP/first-run"
sh "$ROOT/scripts/register_aliases.sh" >> "$TMP/install.log"
cmp "$ISH_PROFILE_FILE" "$TMP/first-run" || { echo 'FAIL: not idempotent' >&2; exit 1; }

[ "$(grep -c '^alias syncapps=' "$ISH_PROFILE_FILE")" = 1 ]
[ "$(grep -c '^alias syncapp=' "$ISH_PROFILE_FILE")" = 1 ]
[ "$(grep -c '^alias tagapps=' "$ISH_PROFILE_FILE")" = 1 ]
[ "$(grep -c '^alias gamp=' "$ISH_PROFILE_FILE")" = 1 ]
grep -Fq "alias other='echo unchanged'" "$ISH_PROFILE_FILE"
grep -Fq "$ROOT/scripts/aliases/sync-apps.sh" "$ISH_PROFILE_FILE"
grep -Fq "$ROOT/scripts/aliases/sync-app.sh" "$ISH_PROFILE_FILE"
grep -Fq "$ROOT/scripts/aliases/git-apply-push.sh" "$ISH_PROFILE_FILE"

[ -f "$ROOT/current_aliases.txt" ]
grep -Fq 'alias other=' "$ROOT/current_aliases.txt"
grep -Fq 'alias syncapps=' "$ROOT/current_aliases.txt"
git -C "$ROOT" check-ignore -q current_aliases.txt
# Confirm the registered aliases actually work after the profile is sourced.
sh -c '. "$1"; alias syncapps; alias syncapp; alias gamp' sh "$ISH_PROFILE_FILE" > "$TMP/active"
grep -Fq 'syncapps=' "$TMP/active"
grep -Fq 'syncapp=' "$TMP/active"
grep -Fq 'gamp=' "$TMP/active"

echo 'PASS: registration, idempotency, preserved aliases, snapshot, and ignore.'
