#!/usr/bin/env bash
# Check App Check enforcement status for Firestore.
# Requires: gcloud auth login (NOT application-default)
set -e
PROJECT_ID="aisaiah-event-hub"
PROJECT_NUMBER="834534025096"
SERVICE="firestore.googleapis.com"

ACCESS_TOKEN=$(gcloud auth print-access-token 2>/dev/null) || {
  echo "ERROR: Run: gcloud auth login"
  echo "       (gcloud auth application-default login does NOT work for App Check API)"
  exit 1
}

echo "→ Checking App Check status for Firestore..."
RESPONSE=$(curl -s -X GET \
  "https://firebaseappcheck.googleapis.com/v1/projects/${PROJECT_NUMBER}/services/${SERVICE}" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "x-goog-user-project: ${PROJECT_ID}")

echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"

# Parse enforcementMode if present
MODE=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('enforcementMode','(not in response - often means OFF)'))" 2>/dev/null)
echo ""
echo "enforcementMode: $MODE"
echo ""
echo "Interpretation:"
echo "  OFF / UNENFORCED / (not in response) = Firestore allows requests without App Check token"
echo "  ENFORCED = Firestore REQUIRES App Check token (causes permission-denied)"
echo ""
echo "If ENFORCED: run ./scripts/disable-app-check-firestore.sh"
