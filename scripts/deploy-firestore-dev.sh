#!/usr/bin/env bash
# Deploy Firestore rules to DEV databases: (default) and event-hub-dev.
# Uses firebase.json which targets both. For event-hub-dev only, use firebase.dev.json.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "→ Deploying Firestore rules to (default) and event-hub-dev..."
firebase deploy --only firestore:rules

echo "→ Deploying to event-hub-dev explicitly (in case main config skipped it)..."
firebase deploy --only firestore:rules --config firebase.dev.json

echo "✔ Dev deploy complete. Prod unchanged."
