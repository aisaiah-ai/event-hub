const admin = require('firebase-admin');
if (!admin.apps.length) admin.initializeApp({ projectId: 'aisaiah-event-hub' });
const db = admin.firestore();

const EVENT_ID = 'march-assembly';
const SESSION_ID = 'main';

async function run() {
  // Search registrants and rsvps
  let found = false;
  const batch = db.batch();

  for (const coll of ['registrants', 'rsvps']) {
    const snap = await db.collection(`events/${EVENT_ID}/${coll}`).get();
    for (const d of snap.docs) {
      const data = d.data();
      const p = data.profile || {};
      const name = (data.name || p.name || `${p.firstName || ''} ${p.lastName || ''}`).trim();
      if (name.toLowerCase().includes('tagaylo')) {
        console.log(`Found in ${coll}: ${name} (id: ${d.id})`);
        found = true;
      }
    }
  }

  if (!found) {
    console.log('Not found — registering and checking in Jessi Tagaylo.');
    const registrantsRef = db.collection(`events/${EVENT_ID}/registrants`);
    const newRef = registrantsRef.doc();
    batch.set(newRef, {
      profile: { name: 'Jessi Tagaylo', firstName: 'Jessi', lastName: 'Tagaylo' },
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
      name: 'Jessi Tagaylo',
      checkedInAt: admin.firestore.Timestamp.now(),
      method: 'manual',
      checkedInBy: 'admin-script',
    });
    await batch.commit();
    console.log('Done.');
  }
}

run().then(() => process.exit(0)).catch(e => { console.error(e.message); process.exit(1); });
