#!/bin/sh
# Stage exact audited patches without changing Git history. User runs gamp.
set -eu
. "$(CDPATH= cd "$(dirname "$0")" && pwd -P)/common.sh"
require git git
require python3 python3
stage() {
    name=$1; version=$2; target=$3; patch=$4
    repo_on_main "$name"
    r="$GC_APPS_BASE/$name"
    found=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("version",""))' "$r/package.json")
    [ "$found" = "$version" ] || die "$name is v$found, expected v$version for $patch. Nothing staged."
    if find "$r" -maxdepth 1 -name '*.patch' -print | grep -q .; then
        die "$r already has root-level *.patch files; do not mix patches with gamp."
    fi
    [ -f "$GC_DIR/patches/$patch" ] || die "Missing bundled patch $patch"
    cp "$GC_DIR/patches/$patch" "$r/$patch"
    printf 'Staged: %s/%s\n' "$r" "$patch"
    printf 'Next: cd "%s" && gamp\n' "$r"
}
case "${1:-}" in
    apps)
        # Stage both before applying either. The user then applies AppLauncher FIRST.
        for name in AppLauncher Ciyan; do repo_on_main "$name"; done
        stage AppLauncher 0.1.6 0.1.7 AppLauncher_v0.1.7_Profiles.patch
        stage Ciyan 0.9.6 0.9.7 Ciyan_v0.9.7_Profiles.patch
        echo 'Apply AppLauncher first, then Ciyan. Follow GoogleCloud/README.md.'
        ;;
    worker)
        stage PWA-GoogleDrive 0.1.2 0.1.3 PWA-GoogleDrive_v0.1.3_iSH_Deployment.patch
        ;;
    *) die 'Usage: gc.sh stage-apps OR gc.sh stage-worker' ;;
esac
