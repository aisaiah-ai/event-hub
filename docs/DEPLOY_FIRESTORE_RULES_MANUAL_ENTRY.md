# Deploy Firestore Rules (Manual Entry Fix)

Manual entry fails when Firebase still has **old rules** (no `allow create` on registrants). The rules in this repo are already updated; they must be **deployed** to your Firebase project.

## Option A: Deploy from CLI (after re-auth)

1. **Re-authenticate** (required if you see "credentials are no longer valid"):
   ```bash
   firebase login --reauth
   ```

2. **Deploy to the database your app uses** (see JOURNAL.md — app uses **(default)**):
   ```bash
   cd /path/to/event-hub
   ./scripts/deploy-firestore-dev.sh
   ```
   This deploys to `(default)` and `event-hub-dev`.

   Or deploy only to default:
   ```bash
   firebase deploy --only 'firestore:(default)'
   ```

3. Reload the app and try **Enter Manually** again.

## Option B: Paste rules manually in Firebase Console

Use this when CLI deploy fails (auth, network, etc.):

1. **Print rules to copy:**
   ```bash
   ./scripts/print-firestore-rules-for-paste.sh
   ```

2. **In Firebase Console:**
   - Open: https://console.firebase.google.com/project/aisaiah-event-hub/firestore  
   - At the **top**, open the **database dropdown** and select **(default)** (or `event-hub-dev` if your app uses that).
   - Click the **Rules** tab.
   - Select **all** text in the editor, delete it.
   - **Paste** the rules printed by the script (the full contents of `firestore.rules`).
   - Click **Publish**.

3. If you use **event-hub-dev** as well, switch the database dropdown to `event-hub-dev` and repeat (same rules, Publish).

4. Reload the app and try manual entry again.

## What the updated rules do

- **`registrants`**: `allow create: if true` — anyone can create a registrant (walk-in).
- **`registrants`**: `allow update` — unauthenticated can update only `eventAttendance`, `checkInSource`, `updatedAt`, `sessionsCheckedIn`.
- **`sessions/{id}/attendance`**: `allow create, read: if true` — unchanged.

Without deploying, Firebase keeps the previous rules and manual entry will keep failing.
