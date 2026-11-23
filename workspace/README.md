# iSH App Workspace

Path: `/mnt/wcopy/apps/`

## Repositories

- **AppLauncher:** Combined PWA launcher; its submodules are not maintained locally.
- **Ascendant:** Tactical LitRPG combat simulator.
- **Chronicle:** Civilization/history project.
- **Ciyan:** Mandarin reader and vocabulary app.
- **WorldGen:** Procedural terrain/world generator.
- **PWA-GoogleDrive:** Shared cloud profile/sync service.
- **iSH-Scripts:** This repository; iSH shell utilities.

## Aliases

- `syncapps`: Check and safely fast-forward all top-level repos to `origin/main`.
- `syncapp REPO`: Check and safely fast-forward one repo (e.g., `syncapp WorldGen`).
- `gamp`: Apply `*.patch`, push, delete patches only after success.

Sync blocks when tracked files have uncommitted edits or local commits would be lost. Untracked files are preserved unless they are **untracked root-level `.patch` files**, which are deleted on successful sync. Submodules are never fetched recursively.

Scripts: `iSH-Scripts/scripts/aliases/`. Register or refresh all aliases with `sh iSH-Scripts/scripts/register_aliases.sh`; definitions are stored in `~/.profile`, and an ignored snapshot is generated at `iSH-Scripts/current_aliases.txt`.

- `pwacloud`: manage the shared Google Drive profile Worker from iSH (`pwacloud help`, `pwacloud doctor`, `pwacloud setup`, `pwacloud deploy`, `pwacloud status`). See `GoogleCloud/README.md`.
