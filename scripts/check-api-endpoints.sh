#!/usr/bin/env bash
# Check that the Events Hub API endpoints respond as expected.
# Usage: ./scripts/check-api-endpoints.sh [BASE_URL]
# Example: BASE_URL=https://us-central1-aisaiah-event-hub.cloudfunctions.net/api ./scripts/check-api-endpoints.sh

set -e
BASE_URL="${1:-${BASE_URL:-https://us-central1-aisaiah-event-hub.cloudfunctions.net/api}}"
echo "Checking API at: $BASE_URL"
echo ""

pass=0
fail=0

check() {
  local method="$1"
  local path="$2"
  local expect_status="${3:-200}"
  local name="$4"
  if [ -z "$name" ]; then name="$method $path"; fi
  local url="${BASE_URL}${path}"
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "$url" 2>/dev/null || echo "000")
  if [ "$status" = "$expect_status" ]; then
    echo "  OK   $name  -> $status"
    ((pass++)) || true
    return 0
  else
    echo "  FAIL $name  -> $status (expected $expect_status)"
    ((fail++)) || true
    return 1
  fi
}

echo "Public endpoints (no auth):"
check GET  ""                   200  "GET / (discovery)"
check GET  "/v1/events"         200  "GET /v1/events"
# Event may exist (200) or not (404)
url="${BASE_URL}/v1/events/nlc-2026"
status=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
if [ "$status" = "200" ] || [ "$status" = "404" ]; then
  echo "  OK   GET /v1/events/:eventId  -> $status"; ((pass++)) || true
else
  echo "  FAIL GET /v1/events/:eventId  -> $status (expected 200 or 404)"; ((fail++)) || true
fi
# Sessions/announcements: 200 if event exists, 404 if not
for path in "/v1/events/nlc-2026/sessions" "/v1/events/nlc-2026/announcements"; do
  status=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" 2>/dev/null || echo "000")
  if [ "$status" = "200" ] || [ "$status" = "404" ]; then
    echo "  OK   GET $path  -> $status"; ((pass++)) || true
  else
    echo "  FAIL GET $path  -> $status (expected 200 or 404)"; ((fail++)) || true
  fi
done
echo ""

echo "Auth-required (expect 401 without token):"
check GET  "/v1/me/registrations"           401  "GET /v1/me/registrations"
check GET  "/v1/events/nlc-2026/my-registration" 401  "GET /v1/events/:eventId/my-registration"
check POST "/v1/events/nlc-2026/register"   401  "POST /v1/events/:eventId/register"
check POST "/v1/events/nlc-2026/checkin/main" 401  "POST /v1/events/:eventId/checkin/main"
check GET  "/v1/events/nlc-2026/checkin/status" 401  "GET /v1/events/:eventId/checkin/status"
echo ""

echo "Not found:"
check GET  "/v1/unknown" 404  "GET /v1/unknown (404)"
echo ""

echo "---"
echo "Passed: $pass  Failed: $fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
echo "All checks passed."
