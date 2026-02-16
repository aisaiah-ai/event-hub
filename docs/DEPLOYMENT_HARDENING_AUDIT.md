# Deployment Hardening Audit Summary

**Date:** February 2026

## Weaknesses Found

1. **Silent prod fallback** — `Environment` used `defaultValue: 'prod'` when ENV was undefined, allowing accidental prod builds.
2. **No fail-fast on invalid ENV** — Invalid or empty ENV was not rejected at startup.
3. **No documentation** — Branch protection and rollback procedures were undocumented.
4. **host_utils ambiguity** — Hostname check could be mistaken for ENV detection (it's routing only).

## Changes Made

### Part 1: ENV Switching

- **Environment** (`lib/config/environment.dart`):
  - Throws `StateError` if ENV is undefined (empty) or not `dev`/`prod`.
  - No default fallback; explicit `--dart-define=ENV=dev|prod` required.
- **host_utils_web.dart**: Added comment that hostname is for routing only, not Firebase/ENV.
- **main.dart**: Added startup log (`print`), assertion, and FirestoreConfig match assertion.

### Part 2: Build Validation

- **docs/deploy-events-aisaiah-org.md**: Added "Required build commands" section with DEV and PROD commands.

### Part 3: Branch Protection

- **docs/BRANCH_PROTECTION.md**: New document with GitHub settings for main and dev, deployment flow, Cloudflare mapping.

### Part 4: Rollback Strategy

- **docs/ROLLBACK_STRATEGY.md**: New document with Cloudflare Pages rollback steps, checklist, tagging recommendation.

### Part 5: Safety Validation

- **main.dart**: Added `assert(Environment.isDev || Environment.isProd)` and FirestoreConfig/Environment match assertion.

## Architecture Notes

- **Single Firebase project**: The app uses one Firebase project (`aisaiah-event-hub`) with two named Firestore databases (`event-hub-dev`, `event-hub-prod`). ENV selects the database. No separate `firebase_options_dev.dart` / `firebase_options_prod.dart`.
- **host_utils**: Used only for routing (rsvp.aisaiah.org → short RSVP URL). Never used for ENV or Firebase.

## Firestore Deploy Separation (Added)

- **firebase.json** defaults to dev only (`event-hub-dev`). `firebase deploy --only firestore:rules` deploys to dev only.
- **scripts/deploy-firestore-dev.sh** — deploy rules to dev (safe for local development).
- **scripts/deploy-firestore-prod.sh** — deploy rules to prod (explicit, use with care).
- See **docs/FIRESTORE_DEPLOY.md** for details.

## Remaining Risks

1. **Build without ENV**: `flutter build web --release` (no `--dart-define`) compiles successfully. The app throws at **runtime** when loaded. CI always passes ENV, so production builds are safe. Local builds without ENV will fail when run.
2. **Manual workflow trigger**: When manually triggering the deploy workflow, ensure the correct branch is selected (dev vs main).
3. **Cloudflare project creation**: If `event-hub-dev` does not exist, dev deployments will fail. Create it in Cloudflare before pushing to dev.

## Verification

```bash
# Prod build (succeeds)
flutter build web --release --dart-define=ENV=prod

# Dev build (succeeds)
flutter build web --release --dart-define=ENV=dev

# Build without ENV (compiles; fails at runtime when app loads)
flutter build web --release
```
