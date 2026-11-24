# iSH App Workspace

Path: `/mnt/wcopy/apps/`

## Repositories

- **AppLauncher:** Combined PWA launcher; its submodules are not maintained locally.
- **Ascendant:** Tactical LitRPG combat simulator.
- **Chronicle:** Civilization/history project.
- **Ciyan:** Mandarin reader and vocabulary app.
- **WorldGen:** Procedural terrain/world generator.
- **PWA-GoogleDrive:** Shared cloud profile/sync service.
- **PWA-Core:** Shared offline PWA infrastructure.
- **iSH-Scripts:** This repository; iSH shell utilities.

## Aliases

- `syncapps`: Check and safely fast-forward all top-level repos to `origin/main`.
- `syncapp REPO`: Check and safely fast-forward one repo (e.g., `syncapp WorldGen`).
- `gamp`: Sync first, apply `*.patch`, atomically push main and version tags, delete patches only after success.
- `tagapps [--all]`: Append missing version tags (all top-level repositories with `--all`).

Sync blocks when tracked files have uncommitted edits or local commits would be lost. Untracked files including patch files are preserved on sync. Submodules are never fetched recursively.

Scripts: `iSH-Scripts/scripts/aliases/`. Register or refresh all aliases with `sh iSH-Scripts/scripts/register_aliases.sh`; definitions are stored in `~/.profile`, and an ignored snapshot is generated at `iSH-Scripts/current_aliases.txt`.

AppLauncher retains `production` for validated Cloudflare deployment; all other repositories use `main` only. Tags identify source commits, not deployments.
