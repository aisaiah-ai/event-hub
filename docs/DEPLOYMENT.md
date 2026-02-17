# Event Hub Deployment Guide

CI/CD and infrastructure for Event Hub (Cloudflare Pages + Firestore).

## Environments (Cloudflare Pages)

| Branch | ENV  | Pages project    | Domain (typical)   |
|--------|------|------------------|--------------------|
| `dev`  | dev  | event-hub-dev    | *.pages.dev        |
| `main` | prod | event-hub        | rsvp.aisaiah.org   |
| `nlc`  | prod | event-hub-nlc    | nlc.aisaiah.org    |

Pushing to **nlc** deploys the same app (prod build) to a separate project so **rsvp.aisaiah.org** is not updated.

### One-time setup: nlc.aisaiah.org

Create the Pages project in Cloudflare **without** connecting a Git repo — we use **GitHub Actions** to build and deploy (wrangler uploads the build to this project).

1. **Cloudflare Dashboard** → **Workers & Pages** → **Create** → **Pages** → choose **Create project** (direct upload), not “Connect to Git”.
2. Name the project **event-hub-nlc**.
3. In that project: **Custom domains** → **Set up a custom domain** → add **nlc.aisaiah.org**.
4. Add the CNAME Cloudflare shows (e.g. `nlc` → `event-hub-nlc.pages.dev`) in your aisaiah.org DNS.
5. **Deploys**: Push to the **nlc** branch on GitHub (e.g. `git push origin dev:nlc`). The **Deploy** workflow in GitHub Actions builds and runs `wrangler pages deploy` to upload to **event-hub-nlc**. Check **Actions** on GitHub to see if the deploy succeeded.

---

## 1. How CI/CD Works (legacy / reference)

### Branch-based deployment

- **Push to `dev`** → Build Flutter web (ENV=dev) → Deploy to Firebase Hosting (aisaiah-events-dev)
- **Push to `main`** → Build Flutter web (ENV=prod) → Deploy to Firebase Hosting (aisaiah-events-prod)

### No manual switching

- No `firebase use` commands
- Branch determines which Firebase project receives the deploy
- Service account secrets select credentials per environment

### Workflow

1. Checkout code
2. Install Flutter, run `flutter pub get`
3. Build: `flutter build web --release --dart-define=ENV=dev|prod`
4. Deploy via `FirebaseExtended/action-hosting-deploy@v0` with `projectId` and `channelId: live`

---

## 2. GitHub Secrets

Add these in **Settings → Secrets and variables → Actions**:

### Deploy (Firebase Hosting)


| Secret | Value | Used for |
|--------|-------|----------|
| `FIREBASE_SERVICE_ACCOUNT_DEV` | JSON key for aisaiah-events-dev | Deploy to DEV |
| `FIREBASE_SERVICE_ACCOUNT_PROD` | JSON key for aisaiah-events-prod | Deploy to PROD |

### Creating service account keys

1. [Firebase Console](https://console.firebase.google.com/) → Select project (e.g. aisaiah-events-dev)
2. **Project Settings** (gear) → **Service accounts**
3. **Generate new private key**
4. Copy the JSON content
5. **Settings → Secrets → Actions → New repository secret** → Name: `FIREBASE_SERVICE_ACCOUNT_DEV` (or `_PROD`)

### Required IAM roles

The service account needs:

- **Firebase Hosting Admin** (or equivalent)
- **Firebase Deploy** permissions

---

## 3. Terraform Infrastructure

### Prerequisites

- Terraform installed
- `gcloud` CLI installed and authenticated
- GCP projects created: `aisaiah-events-dev`, `aisaiah-events-prod`

### Initialize and apply (per environment)

**DEV:**

```bash
cd infra/dev
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

**PROD:**

```bash
cd infra/prod
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### What Terraform provisions

- Enables APIs: `firebase.googleapis.com`, `firestore.googleapis.com`, `cloudbuild.googleapis.com`, `cloudfunctions.googleapis.com`
- Adds Firebase to the GCP project
- Creates Firestore database (default, location `nam5`)

**Note:** If the databases already exist (e.g. in Aisaiah Event Hub), you can import them: `terraform import google_firestore_database.event_hub_dev projects/PROJECT_ID/databases/event-hub-dev` (dev) or `event_hub_prod` / `event-hub-prod` (prod).

### Terraform state

- Default: local state (`terraform.tfstate` in each env dir)
- Add `*.tfstate` and ` infra/**/.terraform/` to `.gitignore` (do not commit state)
- For team use: switch to GCS backend:

```bash
terraform init -backend-config="bucket=YOUR_BUCKET" -backend-config="prefix=events-dev"
```

---

## 4. Firebase configuration in the app

The Flutter app connects to Firestore using `firebase_options.dart`. For the new two-project setup:

1. Run `flutterfire configure` for **aisaiah-events-dev** → save as `lib/firebase_options_dev.dart` (or merge into a single file)
2. Run `flutterfire configure` for **aisaiah-events-prod** → save as `lib/firebase_options_prod.dart`
3. Or: maintain a single `firebase_options.dart` that selects config based on `ENV` dart-define (both project configs in one file)

The build uses `--dart-define=ENV=dev` or `ENV=prod` to select the correct Firebase project at compile time.

**Note:** The app uses the named databases `event-hub-dev` (DEV) and `event-hub-prod` (PROD). See `docs/DATABASE_NAMES.md`.

---

## 5. Rotating service account keys

1. Create a new JSON key for the service account in Firebase Console
2. Update the GitHub secret (`FIREBASE_SERVICE_ACCOUNT_DEV` or `_PROD`) with the new JSON
3. Run a deploy (push to branch or run workflow manually)
4. Revoke or delete the old key in GCP Console → IAM → Service accounts

---

## 6. Rollback production

### Option A: Revert and redeploy

```bash
git revert <commit>
git push origin main
```

GitHub Actions will deploy the reverted build.

### Option B: Firebase Hosting rollback

1. [Firebase Console](https://console.firebase.google.com/) → **aisaiah-events-prod** → **Hosting**
2. **Release history** → select a previous release
3. **Rollback** (if available)

### Option C: Redeploy a specific commit

```bash
git checkout <known-good-commit>
git push origin main --force  # Use with caution
```

---

## 7. Custom domains

Configure in Firebase Console → Hosting → Add custom domain:

- **DEV:** events-dev.aisaiah.org → aisaiah-events-dev
- **PROD:** events.aisaiah.org → aisaiah-events-prod

Add DNS records as instructed by Firebase.

---

## 8. Firestore rules and indexes

- Rules: `firestore.rules` (deployed via scripts — dev/prod separated)
- Indexes: `firestore.indexes.json`

Use `./scripts/deploy-firestore-dev.sh` for dev, `./scripts/deploy-firestore-prod.sh` for prod. See **docs/FIRESTORE_DEPLOY.md**. The GitHub Action deploys Hosting; Firestore rules are deployed separately via these scripts (or add a step to the workflow if needed).
