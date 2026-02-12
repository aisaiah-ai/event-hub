#!/usr/bin/env bash
# Seed event-hub-prod from event-hub-dev (run locally: gcloud auth login)
# Databases: event-hub-dev, event-hub-prod (docs/DATABASE_NAMES.md)
# NOTE: Scripts hardly work. If this fails, use the manual steps in docs/seed-prod-from-dev.md

set -e
PROJECT="aisaiah-event-hub"
BUCKET="aisaiah-event-hub-firestore-exports"

echo "Checking gcloud auth..."
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1 >/dev/null; then
  echo "Error: Not authenticated. Run: gcloud auth login"
  exit 1
fi

echo "→ Project: $PROJECT"
gcloud config set project "$PROJECT"

echo "→ Creating bucket if needed"
gsutil mb -p "$PROJECT" -l US "gs://${BUCKET}" 2>/dev/null || true

PREFIX="seed-prod-$(date +%Y%m%d-%H%M%S)"
echo "→ Exporting from event-hub-dev to gs://${BUCKET}/${PREFIX} (this may take a few minutes)"
gcloud firestore export "gs://${BUCKET}/${PREFIX}" --database=event-hub-dev

# Export writes .overall_export_metadata at the prefix root; import uses that path
EXPORT_PATH="gs://${BUCKET}/${PREFIX}/"
echo "→ Importing into event-hub-prod from ${EXPORT_PATH}"
gcloud firestore import "${EXPORT_PATH}" --database=event-hub-prod

echo "Done. event-hub-prod seeded from event-hub-dev."
