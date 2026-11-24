# iSH-Scripts

Small, POSIX-shell Git workflows for the iSH app workspace at `/mnt/wcopy/apps/`.

## Set up aliases

Run `sh scripts/register_aliases.sh` from this repository (or pass its full path).
It installs/updates the four aliases in `~/.profile`, preserves other aliases, and
creates an ignored, local `current_aliases.txt` listing persistent aliases found
in that profile. The script is safe to rerun. Activate aliases in an existing
terminal with `. ~/.profile`; new iSH login shells read the profile normally.

## Commands

- `syncapps` — detects only direct-child Git repositories; checks **all** for tracked changes, fetches and verifies **all**, then safely fast-forwards each to `origin/main`.
- `syncapp REPO` — safely syncs one repository using its path relative to `/mnt/wcopy/apps/`, from any current directory.
- `gamp` — syncs the current repo first, validates existing tags, applies every patch, atomically pushes main and all new revision/version tags, then removes patches only on success.
- `tagapps` — append missing tags in the current repo; `tagapps --all` processes every top-level repo. Uses only POSIX shell, Git and standard BusyBox utilities.
- `tagapps --all --rebuild` — preview replacement of historical tags; add `--apply` to perform it. `--prune-branches` previews/deletes non-main branches (requires `--apply`); AppLauncher production is always preserved. Recovery bundles are saved in `git-ref-backups/`.

Sync refuses to overwrite staged or unstaged tracked changes (including deletions) and refuses to discard local commits or operate on branches other than `main`. Untracked files are normally preserved. If an untracked file would be overwritten by a remote change, Git refuses the fast-forward. After a successful sync, **untracked `.patch` files are preserved**; only `gamp` cleans up patches it successfully applies. The new commit SHA is printed after each update.

`syncapps` intentionally skips AppLauncher submodules and processes `iSH-Scripts` itself as a top-level repository. GitHub/Cloudflare can still initialize AppLauncher submodules during builds.

## Install

Extract the ZIP to `/mnt/wcopy/apps/iSH-Scripts/` with the `.git` directory included. Run `sh /mnt/wcopy/apps/iSH-Scripts/scripts/register_aliases.sh` and `. ~/.profile`. Optionally copy `workspace/README.md` to `/mnt/wcopy/apps/README.md`. Register the repo with `git config --global --add safe.directory /mnt/wcopy/apps/iSH-Scripts` if iSH reports dubious ownership; configure a remote and push when ready.

No changes are made by simply installing the files. Running `syncapps` or `syncapp` modifies repository checkouts when fast-forwarding is possible. Running `gamp` creates commits and pushes.

## Tests

Run `sh tests/test-sync.sh`, `sh tests/test-register-aliases.sh`, and `sh tests/test-tags.sh`. Tests use temporary shell profiles and repositories; `test-register-aliases.sh` regenerates only the ignored `current_aliases.txt` in the test checkout.

Versions are taken from historical `package.json` or `VERSION` files along first-parent main history. Each version first receives `vX.Y.Z` and `vX.Y.Z.r1`; subsequent commits with the same recorded version receive `.r2`, `.r3`, etc. Unversioned history is not invented. Normal tagging only scans new commits and never replaces remote tags. If `gamp` has applied patches but the atomic push fails, keep the patch files and use `tagapps --push-main` once the local branch is safely reconciled; do not reapply the patches.

The single historical Ascendant typo at `f785e58cc1675e63c820d57d8277d86851cbc94d` is tagged as `0.1.11`, preserving the original commit. Chronicle starts at `0.0.0`.

The one-time prepared workspace publication is outside this repository. Its shell script and manifest are not permanent aliases or Git-tracked tooling. Future `gamp` and `tagapps` work without them. Application builds may still use Python on CI; none of these local iSH commands require it.
