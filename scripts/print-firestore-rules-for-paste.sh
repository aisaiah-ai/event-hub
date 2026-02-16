#!/usr/bin/env bash
# Print firestore.rules so you can paste them into Firebase Console for event-hub-dev.
# Use when CLI deploy fails (e.g. auth) and you need to fix permission-denied immediately.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "=============================================="
echo " MANUAL FIX: Paste these rules into Firebase"
echo "=============================================="
echo ""
echo "1. Open: https://console.firebase.google.com/project/aisaiah-event-hub/firestore"
echo "2. At the top, open the database dropdown and select: event-hub-dev"
echo "3. Click the 'Rules' tab"
echo "4. Select ALL text in the editor, delete it"
echo "5. Paste the rules below (between the --- lines)"
echo "6. Click 'Publish'"
echo ""
echo "--- COPY FROM HERE ---"
cat firestore.rules
echo ""
echo "--- COPY TO HERE ---"
echo ""
echo "After publishing, reload your app; search should work."
