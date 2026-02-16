#!/usr/bin/env bash
# Deploy Firestore rules to DEV databases: (default) and event-hub-dev.
# Must target each database explicitly — firestore:rules alone can skip databases.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "→ Deploying rules to (default)..."
firebase deploy --only 'firestore:(default)'

echo "→ Deploying rules to event-hub-dev..."
firebase deploy --only 'firestore:event-hub-dev'

echo "✔ Dev deploy complete. Prod unchanged."
