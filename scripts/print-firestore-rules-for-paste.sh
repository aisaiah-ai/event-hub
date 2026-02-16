#!/usr/bin/env bash
# Print firestore.rules so you can paste them into Firebase Console.
# CLI deploy often reports success but does NOT update rules. Manual paste is reliable.
# App uses (default) database — paste there for dashboard/analytics to work.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

DB="${1:-(default)}"

echo "=============================================="
echo " MANUAL FIX: Paste rules into Firebase"
echo "=============================================="
echo ""
echo "Use when CLI deploy fails (auth, network). Otherwise: ./scripts/deploy-firestore-dev.sh"
echo ""
echo "1. Open: https://console.firebase.google.com/project/aisaiah-event-hub/firestore"
echo "2. At the top, open the database dropdown and select: $DB"
echo "   (App uses (default); use event-hub-dev if your app targets that)"
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
echo "After publishing, reload your app."
