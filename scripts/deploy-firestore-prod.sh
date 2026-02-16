#!/usr/bin/env bash
# Deploy Firestore rules to PROD only (event-hub-prod and default databases).
# Use with care — affects production.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

BACKUP="$PROJECT_ROOT/firebase.json.bak"
PROD_CONFIG="$PROJECT_ROOT/firebase.prod.json"

cleanup() {
  if [[ -f "$BACKUP" ]]; then
    mv "$BACKUP" "$PROJECT_ROOT/firebase.json"
    echo "Restored firebase.json"
  fi
}
trap cleanup EXIT

echo "→ Deploying Firestore rules to PROD databases..."
cp firebase.json "$BACKUP"
cp "$PROD_CONFIG" firebase.json
firebase deploy --only 'firestore:(default)'
firebase deploy --only 'firestore:event-hub-dev'
firebase deploy --only 'firestore:event-hub-prod'
echo "✔ Prod deploy complete."
