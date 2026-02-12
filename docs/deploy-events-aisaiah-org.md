# Deploy to events.aisaiah.org (prod) and events-dev.aisaiah.org (dev) via GitHub → Cloudflare Pages

## Flow

1. **Push to GitHub** (`dev` or `main` branch)
2. **GitHub Actions** builds Flutter web with branch-specific ENV
3. **Cloudflare Pages** deploys to the matching project

## Branch → Environment

| Branch | ENV | Cloudflare project | Custom domain | Firestore |
|--------|-----|--------------------|---------------|-----------|
| **dev** | dev | event-hub-dev | events-dev.aisaiah.org | event-hub-dev |
| **main** | prod | event-hub | events.aisaiah.org, rsvp.aisaiah.org | event-hub-prod |

Safety: Dev never deploys to prod. Prod never uses ENV=dev. Environment is determined by branch only.

## URLs

| Domain | Environment | Notes |
|--------|-------------|-------|
| **events-dev.aisaiah.org** | Dev | Dev deployment |
| **events.aisaiah.org** | Prod | Full events site |
| **rsvp.aisaiah.org** | Prod | Short RSVP link (no redirects) |

## 1. One-time setup

### Create Cloudflare Pages projects

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/) → **Workers & Pages** → **Create** → **Pages** → **Direct Upload**.
2. Projects:
   - **event-hub** (for main/prod branch) — you may already have this
   - **event-hub-dev** (for dev branch) — create for dev deployments

### Get API token and Account ID

1. **Account ID:** Cloudflare Dashboard → Overview (right sidebar, or URL).
2. **API Token:** [Create Token](https://dash.cloudflare.com/profile/api-tokens) → **Create Custom Token**:
   - Permissions: **Account** → **Cloudflare Pages** → **Edit**

### Add GitHub secrets

In your repo: **Settings** → **Secrets and variables** → **Actions** → **New repository secret**:

| Secret | Value |
|--------|-------|
| `CLOUDFLARE_API_TOKEN` | Your Cloudflare API token |
| `CLOUDFLARE_ACCOUNT_ID` | Your Cloudflare Account ID |

### Add Firebase authorized domains

1. [Firebase Console](https://console.firebase.google.com/) → **aisaiah-event-hub** → **Authentication** → **Settings** → **Authorized domains**.
2. Add **events.aisaiah.org**, **rsvp.aisaiah.org**, and **events-dev.aisaiah.org**.

### Add custom domains in Cloudflare

- **event-hub** (prod) → **events.aisaiah.org** and **rsvp.aisaiah.org**
- **event-hub-dev** → **events-dev.aisaiah.org**

## 2. Required build commands

ENV must be set via `--dart-define`. The app fails fast if ENV is undefined.

**DEV:**
```bash
flutter build web --release --dart-define=ENV=dev
```

**PROD:**
```bash
flutter build web --release --dart-define=ENV=prod
```

**Local run (dev):**
```bash
flutter run -d chrome --dart-define=ENV=dev
```

On startup, the app logs `Running in ENV: dev` or `Running in ENV: prod` to the console.

## 3. Deploy

### Dev (push to dev)

```bash
git checkout dev
git add .
git commit -m "Your changes"
git push origin dev
```

Deploys to events-dev.aisaiah.org, uses event-hub-dev Firestore.

### Prod (push to main)

```bash
git checkout main
git merge dev  # or your workflow
git push origin main
```

Deploys to events.aisaiah.org and rsvp.aisaiah.org, uses event-hub-prod Firestore.

### Manual trigger

Repo → **Actions** → **Deploy** → **Run workflow**. Select branch (dev or main) to deploy.

## 4. Troubleshooting deploy errors

### Build failures

| Step | Error | Fix |
|------|-------|-----|
| **Install dependencies** | `Bad state: No element` or SDK version mismatch | The workflow uses Flutter 3.38.7 (Dart 3.10.7). If `pubspec.yaml` has `sdk: ^3.10.7`, this should work. |
| **Install dependencies** | `Because event_hub depends on X` / version conflict | Run `flutter pub get` locally and fix any conflicts. |
| **Build Web** | Build errors | Run `flutter build web --release` locally to reproduce. |
| **Build Web** | `ENV not defined` | CI sets ENV. For local builds, add `--dart-define=ENV=dev` or `--dart-define=ENV=prod`. |

### Cloudflare deploy failures

| Error | Cause | Fix |
|-------|-------|-----|
| `Error: No account id found` | Missing `CLOUDFLARE_ACCOUNT_ID` secret | Add repo secret in **Settings → Secrets → Actions**. |
| `Error: Invalid API token` or `401` | Missing or wrong `CLOUDFLARE_API_TOKEN` | Create a new token at [dash.cloudflare.com/profile/api-tokens](https://dash.cloudflare.com/profile/api-tokens) with **Account → Cloudflare Pages → Edit**. Add as secret. |
| `Error: Project not found` / `404` | Cloudflare Pages project doesn't exist | Create **event-hub** (prod) and **event-hub-dev** (dev) in Cloudflare Dashboard → **Workers & Pages** → **Create** → **Pages** → **Direct Upload**. |
| `Error: No such file or directory 'build/web'` | Flutter build failed earlier | Fix the Build Web step; the deploy step runs only after a successful build. |

### Where to see errors

1. **Actions** → **Deploy** → click the failed run
2. Expand the failed step (e.g. "Deploy to Cloudflare Pages")
3. Check the red error lines in the log
