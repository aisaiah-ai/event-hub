# Publish to events.aisaiah.org via GitHub → Cloudflare Pages

## Flow

1. **Push to GitHub** (`main` branch)
2. **GitHub Actions** builds Flutter web and deploys to Cloudflare Pages
3. **Cloudflare Pages** serves at events.aisaiah.org

## URLs

Clean path-based URLs (no hash):

- `https://events.aisaiah.org/events/march-cluster-2026/rsvp`
- `web/_redirects` routes all paths to `index.html` for SPA routing

## 1. One-time setup

### Create Cloudflare Pages project

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/) → **Workers & Pages** → **Create** → **Pages** → **Connect to Git**.
2. Skip the Git connection (we use GitHub Actions); instead choose **Direct Upload**.
3. Create a project named **event-hub** (or note the name you use).

### Get API token and Account ID

1. **Account ID:** Cloudflare Dashboard → Overview (right sidebar, or URL).
2. **API Token:** [Create Token](https://dash.cloudflare.com/profile/api-tokens) → **Create Custom Token**:
   - Permissions: **Account** → **Cloudflare Pages** → **Edit**
   - (Or use the "Edit Cloudflare Workers" template and add Pages)

### Add GitHub secrets

In your repo: **Settings** → **Secrets and variables** → **Actions** → **New repository secret**:

| Secret | Value |
|--------|-------|
| `CLOUDFLARE_API_TOKEN` | Your Cloudflare API token |
| `CLOUDFLARE_ACCOUNT_ID` | Your Cloudflare Account ID |

### Add Firebase authorized domain

1. [Firebase Console](https://console.firebase.google.com/) → **aisaiah-event-hub** → **Authentication** → **Settings** → **Authorized domains**.
2. Add **events.aisaiah.org** so Firebase (and Firestore) work from the custom domain.

### Add custom domain in Cloudflare

1. **Workers & Pages** → **event-hub** → **Custom domains** → **Set up a custom domain**.
2. Enter **events.aisaiah.org**.
3. Cloudflare will show DNS records. If aisaiah.org uses Cloudflare DNS, it will often auto-configure. Otherwise, add the CNAME (or A records) at your DNS provider.

## 2. Deploy

**Push to `main`** deploys with `ENV=prod` (uses `event-hub-prod` database). No service account needed.

### Automatic (recommended)

Push to `main`:

```bash
git add .
git commit -m "Deploy"
git push origin main
```

GitHub Actions will build and deploy. Check **Actions** tab for status.

### Manual trigger

Repo → **Actions** → **Deploy** → **Run workflow**.

## 3. URLs after setup

- **Custom domain:** https://events.aisaiah.org
- **RSVP page:** https://events.aisaiah.org/events/march-cluster-2026
- **Cloudflare default:** https://event-hub.pages.dev (or similar, from your project)

## 4. Project name

The workflow uses `--project-name=event-hub`. If your Cloudflare Pages project has a different name, update `.github/workflows/deploy.yml`:

```yaml
command: pages deploy build/web --project-name=YOUR_PROJECT_NAME
```

## 5. Troubleshooting deploy errors

### Build failures

| Step | Error | Fix |
|------|-------|-----|
| **Install dependencies** | `Bad state: No element` or SDK version mismatch | The workflow uses Flutter 3.38.7 (Dart 3.10.7). If `pubspec.yaml` has `sdk: ^3.10.7`, this should work. |
| **Install dependencies** | `Because event_hub depends on X` / version conflict | Run `flutter pub get` locally and fix any conflicts. |
| **Build Web** | Build errors | Run `flutter build web --release` locally to reproduce. |

### Cloudflare deploy failures

| Error | Cause | Fix |
|-------|-------|-----|
| `Error: No account id found` | Missing `CLOUDFLARE_ACCOUNT_ID` secret | Add repo secret in **Settings → Secrets → Actions**. |
| `Error: Invalid API token` or `401` | Missing or wrong `CLOUDFLARE_API_TOKEN` | Create a new token at [dash.cloudflare.com/profile/api-tokens](https://dash.cloudflare.com/profile/api-tokens) with **Account → Cloudflare Pages → Edit**. Add as secret. |
| `Error: Project not found` / `404` | Cloudflare Pages project doesn't exist | Create the project in Cloudflare Dashboard → **Workers & Pages** → **Create** → **Pages** → **Direct Upload**, name it `event-hub`. |
| `Error: No such file or directory 'build/web'` | Flutter build failed earlier | Fix the Build Web step; the deploy step runs only after a successful build. |

### Where to see errors

1. **Actions** → **Deploy** → click the failed run
2. Expand the failed step (e.g. "Deploy to Cloudflare Pages")
3. Check the red error lines in the log
