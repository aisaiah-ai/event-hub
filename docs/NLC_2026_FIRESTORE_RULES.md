# NLC 2026 – Firestore Rules (Section 7)

**Staff-only production.** Deploy these rules when only staff should read/update registrants and write attendance. No client writes to stats (Cloud Functions only).

- Staff read registrants
- Staff update registrants
- Staff read sessions
- Staff read stats
- No client writes to stats
- No client writes to attendance except staff

Use `firestore.rules` (current) if you need **self-check-in kiosk** (unauthenticated) for event nlc-2026; that file allows public read for nlc-2026 and self-check-in when `metadata.selfCheckinEnabled` is true.
