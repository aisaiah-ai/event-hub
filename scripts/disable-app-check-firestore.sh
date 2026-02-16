#!/usr/bin/env bash
# Disable App Check enforcement for Firestore via REST API.
# Requires: gcloud auth login (NOT application-default login)
# Run: ./scripts/disable-app-check-firestore.sh
set -e
PROJECT_ID="aisaiah-event-hub"
PROJECT_NUMBER="834534025096"
SERVICE="firestore.googleapis.com"

echo "→ Disabling App Check enforcement for Firestore..."
ACCESS_TOKEN=$(gcloud auth print-access-token 2>/dev/null) || {
  echo "ERROR: Run: gcloud auth login"
  echo "       (gcloud auth application-default login does NOT work for this script)"
  exit 1
}

RESPONSE=$(curl -s -w "\n%{http_code}" -X PATCH \
  "https://firebaseappcheck.googleapis.com/v1/projects/${PROJECT_NUMBER}/services/${SERVICE}?updateMask=enforcementMode" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -H "x-goog-user-project: ${PROJECT_ID}" \
  -d '{"enforcementMode": "OFF"}')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
  echo "✔ App Check enforcement disabled for Firestore."
  echo "  Wait 1-2 minutes, then retry the app or test page."
else
  echo "✗ API returned HTTP $HTTP_CODE"
  echo "$BODY" | head -20
  exit 1
fi
