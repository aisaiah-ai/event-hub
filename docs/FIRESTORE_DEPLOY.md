# Firestore Deploy: Dev vs Prod Separation

**Rule:** Develop in dev without affecting prod. Firestore rule deploys are separated by environment.

## Quick Reference

| Action | Command | Targets |
|--------|---------|---------|
| **Deploy to DEV** (local development) | `./scripts/deploy-firestore-dev.sh` | `event-hub-dev` only |
| **Deploy to PROD** | `./scripts/deploy-firestore-prod.sh` | `event-hub-prod` + `(default)` |

## How It Works

- **firebase.json** (default): Dev only — `event-hub-dev`. Running `firebase deploy --only firestore:rules` deploys to dev only.
- **firebase.prod.json**: Prod config — `event-hub-prod` and `(default)`. Used by `deploy-firestore-prod.sh`.
- **firebase.dev.json**: Explicit dev config (matches firebase.json). Used for reference.

## Local Development

When developing locally with `ENV=dev`:

```bash
# Deploy rules to dev (safe — prod untouched)
./scripts/deploy-firestore-dev.sh
```

Or directly:

```bash
firebase deploy --only firestore:rules
```

Both deploy only to `event-hub-dev`.

## Production Deploy

Deploy to prod only when rules are ready for production:

```bash
./scripts/deploy-firestore-prod.sh
```

This temporarily swaps in `firebase.prod.json`, deploys, then restores `firebase.json`.

## Before First Deploy

1. `firebase login --reauth` (if credentials expired)
2. Ensure `.firebaserc` has `"default": "aisaiah-event-hub"`
