const admin = require('firebase-admin');
if (!admin.apps.length) admin.initializeApp({ projectId: 'aisaiah-event-hub' });
const db = admin.firestore();

const EVENT_ID = 'march-assembly';
const SESSION_ID = 'main';

const people = [
  { name: 'Cecilia Fischer', firstName: 'Cecilia', lastName: 'Fischer', cfcId: 'IM-2014-141113' },
  { name: 'Michael Fischer', firstName: 'Michael', lastName: 'Fischer', cfcId: 'IM-2014-140764' },
];

async function run() {
  const batch = db.batch();
  const registrantsRef = db.collection(`events/${EVENT_ID}/registrants`);

  for (const p of people) {
    const newRef = registrantsRef.doc();
    batch.set(newRef, {
      profile: { name: p.name, firstName: p.firstName, lastName: p.lastName, cfcId: p.cfcId },
      source: 'MANUAL',
      registrationStatus: 'registered',
      createdAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now(),
      eventAttendance: {
        checkedInAt: admin.firestore.Timestamp.now(),
        method: 'manual',
        checkedInBy: 'admin-script',
      },
    });
    const attendanceRef = db.doc(`events/${EVENT_ID}/sessions/${SESSION_ID}/attendance/${newRef.id}`);
    batch.set(attendanceRef, {
      registrantId: newRef.id,
      name: p.name,
      checkedInAt: admin.firestore.Timestamp.now(),
      method: 'manual',
      checkedInBy: 'admin-script',
    });
    console.log(`Registering & checking in: ${p.name} (${p.cfcId})`);
  }

  await batch.commit();
  console.log(`\nDone. Registered and checked in ${people.length} Fischers.`);
}

run().then(() => process.exit(0)).catch(e => { console.error(e.message); process.exit(1); });
