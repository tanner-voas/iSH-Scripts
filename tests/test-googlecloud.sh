#!/bin/sh
# Offline tests: no Google/Cloudflare credentials or network calls.
set -eu
ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd -P)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' 0
trap 'exit 1' 1 2 3 15
mkdir -p "$TMP/apps" "$TMP/data"
export ISH_APPS_BASE="$TMP/apps"
export GC_OAUTH_FILE="$TMP/data/oauth.json"
export GC_KEYS_FILE="$TMP/data/keys.json"
cat > "$GC_OAUTH_FILE" <<'EOF'
{"web":{"client_id":"not-a-real-id","client_secret":"not-a-real-secret","redirect_uris":["https://applauncher.tannervoas.workers.dev/_profiles/v1/auth/callback","https://ciyan.tannervoas.workers.dev/_profiles/v1/auth/callback"]}}
EOF
for pair in 'AppLauncher 0.1.6' 'Ciyan 0.9.6' 'PWA-GoogleDrive 0.1.2'; do
    set -- $pair
    mkdir "$TMP/apps/$1"
    git -C "$TMP/apps/$1" init -q
    git -C "$TMP/apps/$1" checkout -qb main
    printf '{"version":"%s"}\n' "$2" > "$TMP/apps/$1/package.json"
    git -C "$TMP/apps/$1" add package.json
    git -C "$TMP/apps/$1" -c user.name=Test -c user.email=test@example.invalid commit -qm init
done
OUT=$(sh "$ROOT/GoogleCloud/gc.sh" doctor)
printf '%s\n' "$OUT" | grep -q 'OAuth JSON validated'
if printf '%s\n' "$OUT" | grep -q 'not-a-real-secret'; then echo 'Credential unexpectedly printed' >&2; exit 1; fi
sh "$ROOT/GoogleCloud/gc.sh" stage-apps >/dev/null
[ -f "$TMP/apps/Ciyan/Ciyan_v0.9.7_Profiles.patch" ]
[ -f "$TMP/apps/AppLauncher/AppLauncher_v0.1.7_Profiles.patch" ]
if sh "$ROOT/GoogleCloud/gc.sh" stage-apps >/dev/null 2>&1; then
    echo 'FAIL: duplicate patch staging must be refused' >&2; exit 1
fi
sh "$ROOT/GoogleCloud/gc.sh" stage-worker >/dev/null
[ -f "$TMP/apps/PWA-GoogleDrive/PWA-GoogleDrive_v0.1.3_iSH_Deployment.patch" ]
if sh "$ROOT/GoogleCloud/gc.sh" stage-worker >/dev/null 2>&1; then
    echo 'FAIL: duplicate shared patch staging must be refused' >&2; exit 1
fi
# Simulate GitHub already having encryption secrets while local keys are gone.
# Setup must refuse to regenerate keys even when the OAuth JSON is valid.
mkdir -p "$TMP/fake-bin" "$TMP/apps/PWA-GoogleDrive/.github/workflows"
touch "$TMP/apps/PWA-GoogleDrive/.github/workflows/deploy-worker.yml"
cat > "$TMP/fake-bin/gh" <<'FAKE'
#!/bin/sh
case "$1 $2" in
    'auth status') exit 0 ;;
    'repo view') exit 0 ;;
    'secret set') cat >/dev/null; exit 0 ;;
    'secret list') printf 'SESSION_SIGNING_KEY\nVAULT_KEY\n'; exit 0 ;;
esac
exit 1
FAKE
chmod +x "$TMP/fake-bin/gh"
if PATH="$TMP/fake-bin:$PATH" sh "$ROOT/GoogleCloud/gc.sh" setup >"$TMP/setup-out" 2>&1; then
    echo 'FAIL: missing local keys with remote keys must stop setup' >&2; exit 1
fi
grep -q 'Recover the original keys' "$TMP/setup-out"
[ ! -e "$GC_KEYS_FILE" ]
printf 'PASS: OAuth validation, safe patch staging, and refusal to rotate lost encryption keys.\n' 
