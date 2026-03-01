/**
 * patch-speakers-session.ts
 *
 * Sets the `sessionId` field on each speaker document so the app can match
 * speakers to session cards.
 *
 * USAGE:
 *   1. Fill in the SPEAKERS array below with the correct mapping.
 *   2. Run:
 *        cd functions
 *        npx ts-node --project tsconfig.json src/scripts/patch-speakers-session.ts
 *
 * HOW TO FIND SPEAKER IDs:
 *   - Open Firebase Console → Firestore → events/march-assembly/speakers
 *   - Copy each document ID (e.g. "rommel-dolar")
 *
 * HOW TO FIND SESSION IDs:
 *   - Open Firebase Console → Firestore → events/march-assembly/sessions
 *   - Session IDs are: main-checkin, evangelization-rally, birthdays-anniversaries, dinner-fellowship
 */

import * as admin from "firebase-admin";
// Uses Application Default Credentials (firebase-admin auto-detects when
// GOOGLE_APPLICATION_CREDENTIALS env var or gcloud auth is configured).
admin.initializeApp();

const db = admin.firestore();

// ─── EDIT THIS MAPPING ────────────────────────────────────────────────────────
// Format: { eventId, speakerId (Firestore doc ID), sessionId }
const SPEAKERS: { eventId: string; speakerId: string; sessionId: string }[] = [
  // Example for march-assembly — replace speakerId with actual Firestore doc IDs:
  { eventId: "march-assembly", speakerId: "rommel-dolar",      sessionId: "evangelization-rally" },
  { eventId: "march-assembly", speakerId: "mike-suela",        sessionId: "birthdays-anniversaries" },
  // Add more entries as needed:
  // { eventId: "march-assembly", speakerId: "...", sessionId: "dinner-fellowship" },
];
// ─────────────────────────────────────────────────────────────────────────────

async function main() {
  for (const { eventId, speakerId, sessionId } of SPEAKERS) {
    const ref = db
      .collection("events")
      .doc(eventId)
      .collection("speakers")
      .doc(speakerId);

    const snap = await ref.get();
    if (!snap.exists) {
      console.warn(`⚠️  Speaker not found: events/${eventId}/speakers/${speakerId}`);
      continue;
    }

    await ref.update({ sessionId });
    console.log(`✅  events/${eventId}/speakers/${speakerId} → sessionId="${sessionId}"`);
  }
  console.log("Done.");
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
