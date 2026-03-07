const admin = require("firebase-admin");
const { applicationDefault } = require("google-auth-library");

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: "aisaiah-event-hub",
});

const db = admin.firestore();
const eventId = "march-assembly";

// Only these sessions require registration
const requireRegistration = new Set(["talk-1", "talk-2", "fellowship"]);

async function run() {
  const sessionsSnap = await db
    .collection("events")
    .doc(eventId)
    .collection("sessions")
    .get();

  const batch = db.batch();
  for (const doc of sessionsSnap.docs) {
    const shouldRequire = requireRegistration.has(doc.id);
    console.log(`${doc.id}: registrationRequired = ${shouldRequire}`);
    batch.update(doc.ref, { registrationRequired: shouldRequire });
  }

  await batch.commit();
  console.log(`Updated ${sessionsSnap.size} sessions.`);
  process.exit(0);
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
