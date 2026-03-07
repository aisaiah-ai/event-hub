const admin = require("firebase-admin");

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: "aisaiah-event-hub",
});

const db = admin.firestore();
const eventId = "march-assembly";
const uid = "HGgsFxRH4NdUuwSkdPZ1GQz7tpE3";

async function run() {
  // 1. Find and delete registrant doc (keyed by memberId, ZZ ID, or uid)
  const regQuery = await db
    .collection("events")
    .doc(eventId)
    .collection("registrants")
    .where("uid", "==", uid)
    .get();

  for (const doc of regQuery.docs) {
    console.log(`Deleting registrant: ${doc.id}`);
    // Also delete any session attendance docs
    const sessionsSnap = await db
      .collection("events")
      .doc(eventId)
      .collection("sessions")
      .get();
    for (const sessionDoc of sessionsSnap.docs) {
      const attDoc = await db
        .collection("events")
        .doc(eventId)
        .collection("sessions")
        .doc(sessionDoc.id)
        .collection("attendance")
        .doc(doc.id)
        .get();
      if (attDoc.exists) {
        console.log(`  Deleting attendance: sessions/${sessionDoc.id}/attendance/${doc.id}`);
        await attDoc.ref.delete();
      }
    }
    await doc.ref.delete();
  }

  // 2. Delete mirror doc
  const mirrorRef = db.collection("users").doc(uid).collection("registrations").doc(eventId);
  const mirrorDoc = await mirrorRef.get();
  if (mirrorDoc.exists) {
    console.log(`Deleting mirror: users/${uid}/registrations/${eventId}`);
    await mirrorRef.delete();
  }

  console.log("Cleanup done.");
  process.exit(0);
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
