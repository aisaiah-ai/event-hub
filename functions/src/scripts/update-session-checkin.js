const admin = require("firebase-admin");

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: "aisaiah-event-hub",
});

const db = admin.firestore();
const eventId = "march-assembly";

// Only these sessions have check-in enabled
const checkinEnabled = new Set(["main-checkin", "talk-1", "talk-2", "fellowship"]);

async function run() {
  const sessionsSnap = await db
    .collection("events")
    .doc(eventId)
    .collection("sessions")
    .get();

  const batch = db.batch();
  for (const doc of sessionsSnap.docs) {
    const enabled = checkinEnabled.has(doc.id);
    console.log(`${doc.id}: checkin_available = ${enabled}`);
    batch.update(doc.ref, { checkin_available: enabled });
  }

  await batch.commit();
  console.log(`Updated ${sessionsSnap.size} sessions.`);
  process.exit(0);
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
