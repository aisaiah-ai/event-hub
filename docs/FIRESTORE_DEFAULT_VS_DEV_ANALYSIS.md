# Firestore: (default) vs event-hub-dev Configuration

## Summary

**(default) works, event-hub-dev does not** — even though both are configured to use `firestore.dev.rules` in the codebase. The difference is in which deploy scripts actually update each database.

## Config Files

| Config | (default) | event-hub-dev | event-hub-prod |
|--------|-----------|---------------|----------------|
| **firebase.json** | ✅ firestore.dev.rules | ✅ firestore.dev.rules | — |
| **firebase.prod.json** | ✅ firestore.rules | — | ✅ firestore.rules |
| **firebase.dev.json** | — | ✅ firestore.dev.rules | — |

## Deploy Scripts

| Script | What it does | (default) | event-hub-dev |
|--------|--------------|-----------|---------------|
| **deploy-firestore-prod.sh** | Copies firebase.prod.json → firebase.json, deploys | ✅ gets firestore.rules | ❌ not touched |
| **deploy-firestore-dev.sh** | Runs firebase deploy (firebase.json), then firebase.dev.json | ✅ gets firestore.dev.rules | ✅ gets firestore.dev.rules |
| **Plain `firebase deploy`** | Uses firebase.json | ✅ | ✅ |

## The Difference

- **(default)** is in **firebase.prod.json** → gets **firestore.rules** when prod deploy runs.
- **event-hub-dev** is **not** in firebase.prod.json → never receives rules from prod deploy.
- Both are in firebase.json → both should get **firestore.dev.rules** when dev deploy runs.

## Why event-hub-dev Had Different Rules

event-hub-dev had rules that require `isStaff` for registrants (no public read for nlc-2026). Those rules do not match either current file:

- **firestore.rules** and **firestore.dev.rules** both include: `allow read: if eventId == 'nlc-2026'` for registrants.

So event-hub-dev’s rules likely came from:

1. An older version of the rules, or
2. Manual edits in Firebase Console, or
3. A deploy that did not reach event-hub-dev (e.g. due to config or Firebase CLI behavior).

## Both Rule Files Allow nlc-2026 Public Read

- **firestore.rules** (lines 36–39): `allow read: if eventId == 'nlc-2026' || isStaff(eventId) || ...`
- **firestore.dev.rules** (line 17): `allow read: if eventId == "nlc-2026"`

So, if the same rules are deployed, both databases should allow unauthenticated read of `events/nlc-2026/registrants`.

## Recommendation to Make event-hub-dev Match (default)

1. Confirm what rules (default) actually has in Firebase Console → Firestore → (default) → Rules.
2. Ensure event-hub-dev receives the same rules by deploying with the dev config:
   ```bash
   firebase deploy --only firestore:rules --config firebase.dev.json
   ```
3. Check Firebase Console → Firestore → event-hub-dev → Rules and confirm they match.
4. If event-hub-dev still shows different rules, deploy using the main config:
   ```bash
   firebase deploy --only firestore:rules
   ```
   and verify both (default) and event-hub-dev are listed in the deploy output.
