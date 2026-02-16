#!/bin/sh
# Serve Flutter web build with SPA fallback (all routes -> index.html).
# Use when direct URLs like /events/nlc/checkin return 404 with flutter run.
#
# Usage:
#   ./tools/serve_web.sh
#   Then open http://localhost:8080/events/nlc/checkin
#
# Requires: flutter build web, then npx serve (or similar)

set -e
cd "$(dirname "$0")/.."
flutter build web
echo ""
echo "Serving on http://localhost:8080"
echo "Open: http://localhost:8080/events/nlc/checkin"
echo ""
npx serve build/web -l 8080 --single
