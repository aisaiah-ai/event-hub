# Security and Scalability

This document summarizes how the NLC check-in and dashboard system handles access control, data integrity, and scale without changing runtime behavior.

---

## Role-Based Access

- **Admins** — Stored per event at `events/{eventId}/admins/{email}` with role `ADMIN`. Can manage registrants, schemas, event settings, and run backfill/callable functions where protected.
- **Staff** — Same path with role `STAFF` or `ADMIN`. Can read registrants, run check-in flows, access dashboard and wallboard, read/write layout settings.
- **Self-check-in** — When `metadata.selfCheckinEnabled` is true (or event is nlc-2026), unauthenticated or anonymous users can read registrants (for search) and create attendance documents for allowed sessions.

Firestore rules use helper functions (e.g. `isStaff(eventId)`, `selfCheckinEnabled(eventId)`) to keep rules readable and consistent.

---

## Analytics: Read-Only for Clients

- **analytics/global** and **sessions/{sessionId}/analytics/summary** — **Read: allow** (e.g. for dashboard); **Write: false** for all clients. Only Cloud Functions (using Admin SDK) write these documents.
- **attendeeIndex** — Same: write only by Cloud Functions; read can be restricted to authenticated users.

This ensures:
- No client can inflate or corrupt metrics.
- Aggregation logic lives in one place (Functions) and is auditable.

---

## Atomic Updates and Cost Efficiency

- **Cloud Functions** use **transactions** and **FieldValue.increment()** for analytics updates. No read-modify-write from the client; no race conditions on counters.
- **Pre-aggregation** means the dashboard does not:
  - Scan `attendance` or `registrants` collections.
  - Run expensive count or group-by queries from the client.
- **Real-time listeners** on a small set of documents (one global doc + one summary per session) scale well: few document reads per update, and Firestore charges are dominated by document read/write, not listener count on the same doc.

---

## Why Constant Refresh Is Not Expensive

- **Dashboard** subscribes to:
  - One document: `events/{eventId}/analytics/global`.
  - A bounded number of documents: session list + `sessions/*/analytics/summary`.
- Each check-in triggers **one** Function run, which updates **one** global doc and **one** session summary. Listeners receive one update per changed document.
- No polling over large collections; no client-side aggregation. Cost grows with **event size** (number of sessions) and **update frequency**, not with the number of attendance documents.

---

## Summary

| Concern | Approach |
|---------|----------|
| **Access** | Role-based rules (admin/staff/self-check-in); analytics read-only for client. |
| **Integrity** | Analytics written only by Cloud Functions; atomic increments in transactions. |
| **Scale** | Pre-aggregation; dashboard reads only analytics docs; real-time listeners on a small set of paths. |
| **Cost** | Few documents read per dashboard view; no client-side scans or heavy queries. |
