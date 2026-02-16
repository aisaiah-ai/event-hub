# Firestore event-hub-dev Troubleshooting Log

**Goal:** Get event-hub-dev database working for check-in search (read `events/nlc-2026/registrants`).

---

## ✅ Immediate fix: Paste rules manually (event-hub-dev)

If the app uses **event-hub-dev** and you get `permission-denied` on registrant read/search, the CLI deploy may not be updating event-hub-dev. Use the Console:

1. Open [Firebase Console → Firestore](https://console.firebase.google.com/project/aisaiah-event-hub/firestore).
2. At the top, open the **database** dropdown and select **event-hub-dev** (not “(default)”).
3. Go to the **Rules** tab.
4. Replace the entire rules editor content with the contents of **`firestore.rules`** in this repo (same rules as (default) that allow `eventId == 'nlc-2026'` read).
5. Click **Publish**.

After publishing, reload the app; `listRegistrants` / search on event-hub-dev should succeed.

---

## Deploy option (try after manual fix if you want CLI in sync)

- **firebase.prod.json** now includes **event-hub-dev**. To deploy rules to (default), event-hub-dev, and event-hub-prod in one go:
  ```bash
  firebase deploy --only firestore:rules --config firebase.prod.json
  ```
- If event-hub-dev still returns permission-denied after this, use the manual paste above; the CLI may not update named databases reliably.

---

## Current Status (as of this doc)

| Item | Status |
|------|--------|
| (default) database | ✅ **WORKING** – search returns 436 docs |
| event-hub-dev database | ❌ **NOT WORKING** – permission-denied |
| App Check | Commented out in app; enforcement status unknown |
| App using | (default) via `_useDefaultDbForDev = true` |

---

## What Works (default)

- **Database:** `(default)`
- **Rules source:** `firestore.rules` (deployed via `deploy-firestore-prod.sh` → firebase.prod.json)
- **Registrants read:** `allow read: if eventId == 'nlc-2026' || isStaff(eventId) || ...`
- **Config:** (default) is in `firebase.prod.json` → gets rules when prod deploy runs

---

## What Does Not Work (event-hub-dev)

- **Database:** `event-hub-dev`
- **Symptom:** `[cloud_firestore/permission-denied] Missing or insufficient permissions`
- **Observed rules in Console:** Production-style, `allow read: if isStaff(eventId)` for registrants (no public nlc-2026 read)
- **Config:** event-hub-dev is in `firebase.json` and `firebase.dev.json` → both use `firestore.dev.rules`
- **Attempted:** Deploy with `firebase deploy --only firestore:rules --config firebase.dev.json` – reported success but rules in Console did not change (per user)

---

## Config Files Reference

| File | (default) | event-hub-dev | Rules file |
|------|-----------|---------------|------------|
| firebase.json | ✅ | ✅ | firestore.rules |
| firebase.prod.json | ✅ | ✅ | firestore.rules |
| firebase.dev.json | ❌ | ✅ | firestore.rules |

---

## Attempt Log

### Attempt 1: Deploy firestore.dev.rules to event-hub-dev
- **Action:** `firebase deploy --only firestore:rules --config firebase.dev.json`
- **Result:** CLI reported success; user says rules in Console did not change
- **Conclusion:** Deploy may not be updating event-hub-dev, or rules source is wrong

### Attempt 2: Point event-hub-dev at firestore.rules (same as default)
- **Action:** Updated firebase.dev.json: `"rules":"firestore.dev.rules"` → `"rules":"firestore.rules"`; ran `./scripts/deploy-firestore-rules-event-hub-dev.sh`
- **Rationale:** (default) works with firestore.rules; give event-hub-dev identical rules
- **Result:** ❌ FAILED. Deploy reported success, but event-hub-dev still returns permission-denied. Hot-restart toggling in same session: db=(default) → 436 docs ✅; db=event-hub-dev → permission-denied ❌.
- **Conclusion:** Deploy via firebase.dev.json is not actually updating event-hub-dev rules, OR rules propagation is delayed/broken for named databases.

---

## Critical Finding (from terminal)

Same app, same project, same path, same session – only database differs:
- `db=(default)` → `listRegistrants: got 436 docs` ✅
- `db=event-hub-dev` → `permission-denied` ❌

This proves: **not App Check, not API key** (both would affect all databases). The difference is **rules per database** – event-hub-dev has different/stricter rules than (default).

---

## Files Modified (Attempt 2)

- `firebase.dev.json` – `firestore.dev.rules` → `firestore.rules`
- `lib/src/config/firestore_config.dart` – `_useDefaultDbForDev = true` (back to default; event-hub-dev still broken)
- `scripts/deploy-firestore-rules-event-hub-dev.sh` – echo message

---

## Next Attempts

### Attempt 3: Add event-hub-dev to firebase.prod.json
- **Rationale:** (default) gets firestore.rules from `deploy-firestore-prod.sh` (which uses firebase.prod.json). Add event-hub-dev to that same config so it receives the identical deploy.
- **Action:** Add event-hub-dev to firebase.prod.json firestore array; run `./scripts/deploy-firestore-prod.sh` (or a dev-safe variant that deploys to event-hub-dev using firestore.rules).
- **Caveat:** Prod deploy script overwrites firebase.json with prod config – ensure we don't break existing workflow.

### Attempt 4: Manual rules in Firebase Console
- **Action:** Firebase Console → Firestore → switch to event-hub-dev → Rules tab → copy rules from (default) database → paste and publish.
- **Pros:** Bypasses deploy/config issues. **Cons:** Manual, not in version control.

### Attempt 5: Verify Firebase CLI behavior
- Run `firebase firestore:databases:list` – confirm event-hub-dev exists.
- Run deploy with `--debug` – see exactly what gets pushed.
