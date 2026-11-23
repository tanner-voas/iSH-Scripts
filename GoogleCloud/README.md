# GoogleCloud — iSH-first PWA profile deployment

Run from `/mnt/wcopy/apps` (or any directory):

```sh
sh /mnt/wcopy/apps/iSH-Scripts/GoogleCloud/gc.sh help
```

You **do not need Node or Wrangler in iSH**. `deploy-worker.yml` runs Wrangler on GitHub Actions, using the Cloudflare API token stored in encrypted GitHub Actions secrets.

## Prerequisites

Run `apk add git python3 curl github-cli` in iSH if needed. Alpine package availability depends on your configured repositories; do not switch iSH to an incompatible Alpine release merely to install one package. `gh` is the GitHub CLI (on Alpine its package name is `github-cli`). To authenticate, run:

```sh
gh auth login --hostname github.com --git-protocol https --web
gh auth status
```

You have already created the Google Cloud `PWA Profiles` project, enabled Google Drive API, configured scopes and test user, and created the OAuth Web client with these authorized redirect URIs:

- `https://applauncher.tannervoas.workers.dev/_profiles/v1/auth/callback`
- `https://ciyan.tannervoas.workers.dev/_profiles/v1/auth/callback`

Place the **unmodified downloaded OAuth JSON** at `/mnt/wcopy/PWAProfiles.client_secrets.apps.googleusercontent.com.json`. Do **not** move it inside `/mnt/wcopy/apps`. Verify that its `web.redirect_uris` contain both URLs.

## Exact first-time workflow

**1. Apply this iSH-Scripts patch** (`gamp`), then run `sh iSH-Scripts/scripts/register_aliases.sh` and `. ~/.profile` if you want the optional `pwacloud` alias. The script also works without an alias.

**2. Protect your Ciyan progress:** export a full JSON backup from the existing Ciyan v0.9.6 and confirm it's saved in Files before upgrading. The initial Default local database is preserved, but keep an independent backup until a real Google restore succeeds.

**3. Apply the app patches FIRST.** From `/mnt/wcopy/apps`:

```sh
sh iSH-Scripts/GoogleCloud/gc.sh doctor
sh iSH-Scripts/GoogleCloud/gc.sh stage-apps
cd /mnt/wcopy/apps/AppLauncher && gamp
cd /mnt/wcopy/apps/Ciyan && gamp
cd /mnt/wcopy/apps
```

The bundler only copies the exact, previously tested v0.1.7 AppLauncher and v0.9.7 Ciyan mailbox patches into each repository; it does not silently commit them. Applying AppLauncher first installs its coordinator, so when Ciyan updates AppLauncher it does so in the correct order. If `gamp` fails, stop and inspect; **never force-push**. Ensure that the `APP_LAUNCHER_DISPATCH_TOKEN` secret is configured in Ciyan's GitHub Actions and the `DISPATCH_TOKEN` secret exists in PWA-GoogleDrive.

**4. Add the deployment workflow to PWA-GoogleDrive** v0.1.2:

```sh
sh iSH-Scripts/GoogleCloud/gc.sh stage-worker
cd /mnt/wcopy/apps/PWA-GoogleDrive && gamp
cd /mnt/wcopy/apps
```

This applies v0.1.3. Pushing triggers the existing PWA-GoogleDrive → Ciyan → AppLauncher dependency update chain, but **does not automatically deploy Cloudflare** before secrets are configured.

**5. Create one Cloudflare API token in the Cloudflare website:** Cloudflare Dashboard → My Profile → API Tokens → Create Token → **Edit Cloudflare Workers** template, restrict it to your existing account. Copy the token once. Also get the 32-character **Cloudflare Account ID** from the Workers & Pages dashboard. The Worker must live in the **same account** as `applauncher` and `ciyan`. A token with insufficient Worker edit/Durable Object deployment permissions will yield a Wrangler 403 and may require adjusting its permissions.

**6. Upload secrets directly from your iSH terminal:**

```sh
sh iSH-Scripts/GoogleCloud/gc.sh setup
```

The script validates the OAuth JSON and its two redirects, uploads `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` into encrypted GitHub repository secrets without displaying them, then creates and reuses long-lived `SESSION_SIGNING_KEY` and `VAULT_KEY` in `/mnt/wcopy/PWAProfiles.worker-keys.json` (`chmod 600`). It asks for the Cloudflare Account ID and API token; the token input is hidden, and the token is stored only as an encrypted GitHub Actions secret. **Keep a secure copy of the local Worker keys file** in a password manager/encrypted vault. If you lose that file after setup, the script refuses to rotate keys accidentally. Losing or rotating `VAULT_KEY` makes previously encrypted Google refresh tokens unreadable. The OAuth JSON and key file must never be committed, attached to GitHub issues, or shared in a chat.

The six GitHub Actions secrets in `tanner-voas/PWA-GoogleDrive` are:

- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`
- `SESSION_SIGNING_KEY`
- `VAULT_KEY`
- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_API_TOKEN`

Plus the existing `DISPATCH_TOKEN` for cross-repository dependency notifications. **Do not reuse `DISPATCH_TOKEN` for Cloudflare deployment.**

**7. Deploy the authentication Worker remotely:**

```sh
sh iSH-Scripts/GoogleCloud/gc.sh deploy
sh iSH-Scripts/GoogleCloud/gc.sh watch
```

`watch` waits for the latest GitHub Actions run and returns failure if it fails. Once deployed, the Worker will be named `pwa-profiles-api` and use its `ACCOUNTS` Durable Object. If Cloudflare rejects the migration or secret upload, inspect the workflow logs; no app data is overwritten by a failed deployment.

**8. Check AppLauncher/Ciyan integration.** Their new v0.1.7/v0.9.7 patches configure a **`PROFILES` service binding** to `pwa-profiles-api` and change the Workers to use an assets binding. GitHub Actions updating a submodule pointer doesn't automatically mean a deployed app was rebuilt. Confirm AppLauncher and Ciyan Cloudflare Builds each built the latest `main`, with `git submodule update --init --recursive` or the build scripts' equivalent, including the `shared/google-drive` submodule. If needed, redeploy the two apps from their Cloudflare pages **after the profile Worker is live**. Their build/Worker settings must not override the repository `wrangler.jsonc` service binding. Workers must be in the same Cloudflare account.

**9. Verify the endpoints from iSH:**

```sh
sh iSH-Scripts/GoogleCloud/gc.sh status
```

An unauthenticated call to `/_profiles/v1/status` on **both** app hosts should produce HTTP 200 with `{"connected":false}`. A 404, HTML response, or 503 indicates an old app deployment or missing `PROFILES` binding. This check doesn't access your Google Drive, it only verifies the gateway route. To test cloud sync, open the profile button in AppLauncher, connect to Google, create a disposable profile, open Ciyan through AppLauncher, save a small change, verify a version in Drive, and confirm recovery before using it as your only backup.

## Everyday commands

```sh
sh iSH-Scripts/GoogleCloud/gc.sh doctor
sh iSH-Scripts/GoogleCloud/gc.sh deploy
sh iSH-Scripts/GoogleCloud/gc.sh status
sh iSH-Scripts/GoogleCloud/gc.sh watch
```

Run `setup` again only if you need to re-upload unchanged credentials or change a Cloudflare token. It does **not** rotate existing key files; it refuses to create new keys over existing GitHub key secrets when the local keys file is missing.

## Things that require a website or interactive authentication

- Google Cloud OAuth client and Drive API: **already done**, nothing further needed now. Testing-mode Google refresh tokens may expire after seven days; eventually change the OAuth publishing status to Production for long-lived authorization.
- Cloudflare dashboard: create API token (once) and find Account ID (once). The scripts can't mint your account's Cloudflare API token from scratch without an existing credential.
- GitHub (or `gh auth login` on iSH): authenticate GitHub CLI (once). Repository secrets can then be set from iSH automatically. Ensure Ciyan's `APP_LAUNCHER_DISPATCH_TOKEN` is present and GitHub Actions can write commits for dependency update workflows.

## Failure and safety rules

- Never publish the OAuth JSON, Cloudflare API token, `VAULT_KEY`, or `SESSION_SIGNING_KEY`.
- Never use `git reset --hard` or force-push to fix a failed `gamp`.
- No credentials are stored inside this Git repository, any mailbox patch, or the Cloudflare Worker source.
- A browser-only PWA does not run forever in the background on iOS. Cloud saves happen while the PWA is active or on its next resume; keep your manual backup until you've tested cloud restoration.
