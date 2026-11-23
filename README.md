# iSH-Scripts

Small, POSIX-shell Git workflows for the iSH app workspace at `/mnt/wcopy/apps/`.

## Commands

- `syncapps` — detects only direct-child Git repositories; checks **all** for tracked changes, fetches and verifies **all**, then safely fast-forwards each to `origin/main`.
- `syncapp REPO` — safely syncs one repository using its path relative to `/mnt/wcopy/apps/`, from any current directory.
- `gamp` — runs `git am *.patch && git push && rm *.patch` in the current directory.

Sync refuses to overwrite staged or unstaged tracked changes (including deletions) and refuses to discard local commits or operate on branches other than `main`. Untracked files are normally preserved. If an untracked file would be overwritten by a remote change, Git refuses the fast-forward. After a successful sync, **untracked root-level `.patch` files are deleted**; tracked patches remain untouched.

`syncapps` intentionally skips AppLauncher submodules and processes `iSH-Scripts` itself as a top-level repository. GitHub/Cloudflare can still initialize AppLauncher submodules during builds.

## Install

Extract this ZIP into `/mnt/wcopy/apps/` to create `/mnt/wcopy/apps/iSH-Scripts/`, keeping the `.git` directory. Copy `workspace/README.md` to `/mnt/wcopy/apps/README.md`, then update the shell aliases in `/root/.profile` to refer to `scripts/aliases/`. The supplied ChatGPT installation block also registers this directory as globally safe and pushes `main` to the GitHub remote.

No changes are made by simply installing the files. Running `syncapps` or `syncapp` modifies repository checkouts when fast-forwarding is possible. Running `gamp` creates commits and pushes.
