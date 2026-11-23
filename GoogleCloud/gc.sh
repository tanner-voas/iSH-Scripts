#!/bin/sh
# Single entry point. Can be run from /mnt/wcopy/apps or any other directory.
set -eu
DIR="$(CDPATH= cd "$(dirname "$0")" && pwd -P)"
case "${1:-help}" in
    help|-h|--help)
        cat <<'EOF'
PWA GoogleCloud management (run from any directory)
  sh iSH-Scripts/GoogleCloud/gc.sh doctor          Check prerequisites and revisions
  sh iSH-Scripts/GoogleCloud/gc.sh stage-apps      Stage AppLauncher + Ciyan Git patches
  sh iSH-Scripts/GoogleCloud/gc.sh stage-worker    Stage PWA-GoogleDrive deploy-action patch
  sh iSH-Scripts/GoogleCloud/gc.sh setup           Upload Worker secrets from OAuth JSON
  sh iSH-Scripts/GoogleCloud/gc.sh deploy          Trigger Cloudflare deployment via GitHub Actions
  sh iSH-Scripts/GoogleCloud/gc.sh status          Inspect GitHub Actions + PWA endpoints
  sh iSH-Scripts/GoogleCloud/gc.sh watch           Watch the latest Worker deployment
See GoogleCloud/README.md for exact workflow and security instructions.
EOF
        ;;
    doctor) exec sh "$DIR/doctor.sh" ;;
    stage-apps) exec sh "$DIR/stage-patches.sh" apps ;;
    stage-worker) exec sh "$DIR/stage-patches.sh" worker ;;
    setup) exec sh "$DIR/setup.sh" ;;
    deploy) exec sh "$DIR/deploy.sh" ;;
    status) exec sh "$DIR/status.sh" ;;
    watch) exec sh "$DIR/deploy.sh" watch ;;
    *) echo "Unknown command: $1" >&2; exec sh "$DIR/gc.sh" help ;;
esac
