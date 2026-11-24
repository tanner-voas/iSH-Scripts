#!/bin/sh
set -eu
ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd -P)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export ISH_APPS_BASE="$TMP/apps"
export GIT_CONFIG_NOSYSTEM=1
export HOME="$TMP/home"
mkdir -p "$HOME" "$ISH_APPS_BASE"
git init -q --bare --initial-branch=main "$TMP/remote.git"
git clone -q "$TMP/remote.git" "$ISH_APPS_BASE/AppLauncher"
cd "$ISH_APPS_BASE/AppLauncher"
git config user.name Test; git config user.email test@example.invalid
printf '0.1.0\n' > VERSION; git add VERSION; git commit -qm first
one=$(git rev-parse HEAD)
echo x > content; git add content; git commit -qm second
two=$(git rev-parse HEAD)
printf '0.1.1\n' > VERSION; git commit -qam new-version
three=$(git rev-parse HEAD)
git tag -a legacy -m old "$one"; git tag v0.1.0 "$two"; git branch old "$one"; git branch production "$three"
git push -q origin main old production --tags
call(){ sh "$ROOT/scripts/tag-versions.sh" "$@"; }
call --rebuild --prune-branches > "$TMP/plan"
git show-ref --verify refs/tags/legacy >/dev/null
call --rebuild --prune-branches --apply --backup-dir "$TMP/backups"
[ "$(git rev-parse v0.1.0)" = "$one" ]
[ "$(git rev-parse v0.1.0.r1)" = "$one" ]
[ "$(git rev-parse v0.1.0.r2)" = "$two" ]
[ "$(git rev-parse v0.1.1)" = "$three" ]
[ "$(git rev-parse v0.1.1.r1)" = "$three" ]
[ "$(git branch --format='%(refname:short)' | tr '\n' ' ')" = "main production " ]
[ "$(git ls-remote --heads origin | wc -l)" -eq 2 ]
[ "$(git tag | wc -l)" -eq 5 ]
[ "$(find "$TMP/backups" -name '*.bundle' | wc -l)" -eq 1 ]
git bundle list-heads "$TMP/backups/"*.bundle | grep -q refs/heads/production
call > "$TMP/incremental"; grep -q 'scanned 0 commits' "$TMP/incremental"
# Simulate two mailed patches and one upstream commit before gamp.
git clone -q "$TMP/remote.git" "$TMP/author"
git -C "$TMP/author" config user.name Author; git -C "$TMP/author" config user.email author@example.invalid
echo remote > "$TMP/author/upstream"; git -C "$TMP/author" add upstream; git -C "$TMP/author" commit -qm upstream; git -C "$TMP/author" push -q origin main
up=$(git -C "$TMP/author" rev-parse HEAD)
echo patch1 > "$TMP/author/patch1"; git -C "$TMP/author" add patch1; git -C "$TMP/author" commit -qm patch1
printf '0.1.2\n' > "$TMP/author/VERSION"; git -C "$TMP/author" commit -qam patch2
git -C "$TMP/author" format-patch -2 -o "$PWD" >/dev/null
sh "$ROOT/scripts/aliases/git-apply-push.sh"
[ "$(git rev-parse v0.1.1.r2)" = "$up" ]
[ "$(git rev-parse v0.1.1.r3)" = "$(git rev-parse HEAD^)" ]
[ "$(git rev-parse v0.1.2.r1)" = "$(git rev-parse HEAD)" ]
[ "$(git rev-parse v0.1.2)" = "$(git rev-parse HEAD)" ]
[ ! -e 0001-patch1.patch ]
call > "$TMP/incremental"; grep -q 'scanned 0 commits' "$TMP/incremental"
echo 'PASS: rebuild, production preservation, recovery bundle, efficient incremental tags, gamp sync + multi-patch tags.'
