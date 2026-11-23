# iSH-Scripts

Small, POSIX-shell Git workflows for the iSH app workspace at `/mnt/wcopy/apps/`.

## Set up aliases

Run `sh scripts/register_aliases.sh` from this repository (or pass its full path).
It installs/updates the three aliases in `~/.profile`, preserves other aliases, and
creates an ignored, local `current_aliases.txt` listing persistent aliases found
in that profile. The script is safe to rerun. Activate aliases in an existing
terminal with `. ~/.profile`; new iSH login shells read the profile normally.

## Commands

- `syncapps` — detects only direct-child Git repositories; checks **all** for tracked changes, fetches and verifies **all**, then safely fast-forwards each to `origin/main`.
- `syncapp REPO` — safely syncs one repository using its path relative to `/mnt/wcopy/apps/`, from any current directory.
- `gamp` — runs `git am *.patch && git push && rm *.patch` in the current directory.

Sync refuses to overwrite staged or unstaged tracked changes (including deletions) and refuses to discard local commits or operate on branches other than `main`. Untracked files are normally preserved. If an untracked file would be overwritten by a remote change, Git refuses the fast-forward. After a successful sync, **untracked root-level `.patch` files are deleted**; tracked patches remain untouched.

`syncapps` intentionally skips AppLauncher submodules and processes `iSH-Scripts` itself as a top-level repository. GitHub/Cloudflare can still initialize AppLauncher submodules during builds.

## Install

Extract the ZIP to `/mnt/wcopy/apps/iSH-Scripts/` with the `.git` directory included. Run `sh /mnt/wcopy/apps/iSH-Scripts/scripts/register_aliases.sh` and `. ~/.profile`. Optionally copy `workspace/README.md` to `/mnt/wcopy/apps/README.md`. Register the repo with `git config --global --add safe.directory /mnt/wcopy/apps/iSH-Scripts` if iSH reports dubious ownership; configure a remote and push when ready.

No changes are made by simply installing the files. Running `syncapps` or `syncapp` modifies repository checkouts when fast-forwarding is possible. Running `gamp` creates commits and pushes.

## Tests

Run `sh tests/test-sync.sh` and `sh tests/test-register-aliases.sh`. Tests use temporary shell profiles and repositories; `test-register-aliases.sh` regenerates only the ignored `current_aliases.txt` in the test checkout.
