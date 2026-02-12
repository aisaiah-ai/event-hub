# Seed Prod Database from Dev

Copy data from **event-hub-dev** to **event-hub-prod** within the same Firebase project (Aisaiah Event Hub).

## Prerequisites

- `gcloud` CLI installed and authenticated
- Project on Blaze plan (billing enabled)
- A Cloud Storage bucket in the same project (or another project with Firestore service agent access)

## Database Names (Permanent)

| Environment | Database ID |
|-------------|-------------|
| DEV | `event-hub-dev` |
| PROD | `event-hub-prod` |

**Never use** the `(default)` database. See `docs/DATABASE_NAMES.md`.

---

## Steps

### 1. Set project and create bucket (if needed)

```bash
gcloud config set project aisaiah-event-hub
```

Create a bucket in the same region as Firestore (e.g. `nam5` → `us` multi-region):

```bash
gsutil mb -p aisaiah-event-hub -l US gs://aisaiah-event-hub-firestore-exports
```

### 2. Export from event-hub-dev

```bash
gcloud firestore export gs://aisaiah-event-hub-firestore-exports/seed-prod-$(date +%Y%m%d-%H%M%S) \
  --database=event-hub-dev
```

The export creates a timestamped folder. Note the path (e.g. `gs://aisaiah-event-hub-firestore-exports/seed-prod-20260211-200000/`).

### 3. Import into event-hub-prod

Replace `EXPORT_PATH` with the folder from the export (e.g. `seed-prod-20260211-200000`):

```bash
gcloud firestore import gs://aisaiah-event-hub-firestore-exports/EXPORT_PATH/ \
  --database=event-hub-prod
```

**Warning:** Import overwrites existing documents with the same ID. Other documents in prod remain unchanged.

### 4. Deploy rules (if needed)

```bash
firebase deploy --only firestore
```

---

## One-liner (export + import)

```bash
# Export
EXPORT_PATH="seed-prod-$(date +%Y%m%d-%H%M%S)"
gcloud firestore export gs://aisaiah-event-hub-firestore-exports/${EXPORT_PATH} --database=event-hub-dev || exit 1

# Wait for export to complete (check Firebase Console or operations list)
# gcloud firestore operations list

# Import
gcloud firestore import gs://aisaiah-event-hub-firestore-exports/${EXPORT_PATH}/ --database=event-hub-prod
```

---

## Troubleshooting

| Error | Fix |
|-------|-----|
| `Permission denied` on bucket | Ensure Firestore service agent has Storage Admin on the bucket |
| `Database not found` | Verify database IDs: `event-hub-dev`, `event-hub-prod` |
| Export/import fails | Check [Firestore Import/Export](https://cloud.google.com/firestore/docs/manage-data/export-import) docs |
