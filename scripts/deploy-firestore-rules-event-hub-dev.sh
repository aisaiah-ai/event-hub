#!/usr/bin/env bash
# Deploy Firestore rules to event-hub-dev ONLY.
# Fixes "permission-denied" on registrant search when the app uses event-hub-dev.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "=============================================="
echo " Deploy Firestore rules to event-hub-dev"
echo "=============================================="
echo ""
echo "If you see 'Authentication Error' or 'credentials are no longer valid', run first:"
echo "  firebase login --reauth"
echo ""
read -p "Press Enter to continue (or Ctrl+C to cancel)..."

echo ""
echo "→ Deploying rules to event-hub-dev..."
if firebase deploy --only firestore:rules --config firebase.dev.json; then
  echo ""
  echo "✔ event-hub-dev rules updated. Reload the app and try search again."
  echo "  If you still see permission-denied, use manual paste: ./scripts/print-firestore-rules-for-paste.sh"
else
  echo ""
  echo "✗ Deploy failed. Try: firebase login --reauth then run this script again."
  echo "  Or fix manually: ./scripts/print-firestore-rules-for-paste.sh"
  exit 1
fi
