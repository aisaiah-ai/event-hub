# Seed Prod Database from Dev

Copy data from **event-hub-dev** to **event-hub-prod** within the same Firebase project (Aisaiah Event Hub).

**No service accounts.** Run locally with `gcloud auth login`. Scripts hardly work — use manual steps if the script fails.

---

## Manual steps (use when script fails)

### 1. Set project and create bucket

```bash
gcloud config set project aisaiah-event-hub
gsutil mb -p aisaiah-event-hub -l US gs://aisaiah-event-hub-firestore-exports
```

### 2. Export from event-hub-dev

```bash
PREFIX="seed-prod-$(date +%Y%m%d-%H%M%S)"
gcloud firestore export gs://aisaiah-event-hub-firestore-exports/${PREFIX} --database=event-hub-dev
echo "Export prefix: ${PREFIX}"
```

Export writes `.overall_export_metadata` at the prefix root. Use that same path for import.

### 3. Import into event-hub-prod

Use the same PREFIX from step 2:

```bash
gcloud firestore import gs://aisaiah-event-hub-firestore-exports/${PREFIX}/ \
  --database=event-hub-prod
```

---

## Script (try first)

```bash
gcloud auth login
./scripts/seed-prod-from-dev.sh
```

---

## Database Names (Permanent)

| Environment | Database ID |
|-------------|-------------|
| DEV | `event-hub-dev` |
| PROD | `event-hub-prod` |

**Never use** the `(default)` database. See `docs/DATABASE_NAMES.md`.

---

## Troubleshooting

| Error | Fix |
|-------|-----|
| `Permission denied` on bucket | Ensure Firestore service agent has Storage Admin on the bucket |
| `Database not found` | Verify database IDs: `event-hub-dev`, `event-hub-prod` |
| Export/import fails | Check [Firestore Import/Export](https://cloud.google.com/firestore/docs/manage-data/export-import) docs |
