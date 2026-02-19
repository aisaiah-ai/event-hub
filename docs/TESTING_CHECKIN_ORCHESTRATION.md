# Testing: Session Allocation + Capacity + Confirmation

Lightweight manual verification for the check-in orchestration flow.

## Prerequisites

- Event and session docs exist (e.g. `events/nlc-2026`, `events/nlc-2026/sessions/main-checkin`).
- Main session has `isMain: true`. Session docs should have `attendanceCount` (and optionally `capacity`, `status`, `colorHex`) for capacity/availability.
- Firestore rules deployed: `firebase deploy --only firestore:(default)` (or target DB per project).

## Checklist

1. **Not main checked-in → session check-in**
   - Use a registrant who has no main check-in yet.
   - Go through session check-in (e.g. select a breakout session).
   - Confirm main attendance is created first, then session attendance.
   - No double main check-in.

2. **Idempotency (double tap)**
   - Check in the same registrant to the same session again (e.g. tap again or retry).
   - Should see "Already checked in" or success without double increment.
   - Session `attendanceCount` should not increase twice.

3. **Capacity full**
   - Set a session’s `capacity` to current `attendanceCount` (or 1 for a test session).
   - Try to check in another registrant to that session.
   - Transaction should fail with "Session full" (or equivalent).
   - Refresh session list; session should show Full/Closed and not be tappable.

4. **Pre-registered session**
   - Create `events/{eventId}/sessionRegistrations/{registrantId}` with `sessionIds: ["some-session-id"]`.
   - Resolve that registrant (QR/search/manual) and Continue.
   - Should go directly to check-in for that session (no selection screen), then confirmation.

5. **Multiple registered sessions**
   - Set `sessionIds: ["id1", "id2"]` for a registrant.
   - Resolve and Continue.
   - Session selection should show only those sessions (filtered by availability).

6. **No pre-registration**
   - Use a registrant with no `sessionRegistrations` doc (or empty `sessionIds`).
   - Resolve and Continue.
   - Session selection should show all available sessions.

7. **Confirmation screen**
   - After check-in, confirmation shows session name, date/time, location, receipt (name, registrantId, timestamp).
   - **Save as Image:** On web, triggers download of PNG. On mobile, may show "Coming soon" or unsupported message.
   - **Apple Wallet / Google Wallet:** Show placeholder buttons with "Coming soon".

8. **Dashboard**
   - Total Registrants: shows number or "—" when unknown/zero.
   - Main Check-In Total = main session’s count.
   - Session Check-Ins = sum of non-main session counts.

## Mode-aware labels

- Do not show "Checked In" for main when the user is in breakout session mode.
- Use "Main check-in complete" vs "Session check-in complete" as appropriate.
- Target session name is clear at top of session check-in flow.
