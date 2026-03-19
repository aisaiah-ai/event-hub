const admin = require('firebase-admin');
if (!admin.apps.length) admin.initializeApp({ projectId: 'aisaiah-event-hub' });
const db = admin.firestore();

const EVENT_ID = 'march-assembly';
const SESSION_ID = 'main';
const IDS = ['IM-2025-497023', 'IM-2025-497103'];

async function run() {
  const batch = db.batch();
  for (const id of IDS) {
    const ref = db.doc(`events/${EVENT_ID}/registrants/${id}`);
    const doc = await ref.get();
    const p = doc.data().profile || {};
    const name = p.name || `${p.firstName || ''} ${p.lastName || ''}`.trim();

    batch.update(ref, {
      eventAttendance: {
        checkedInAt: admin.firestore.Timestamp.now(),
        method: 'manual',
        checkedInBy: 'admin-script',
      },
    });
    const attRef = db.doc(`events/${EVENT_ID}/sessions/${SESSION_ID}/attendance/${id}`);
    batch.set(attRef, {
      registrantId: id,
      name,
      checkedInAt: admin.firestore.Timestamp.now(),
      method: 'manual',
      checkedInBy: 'admin-script',
    });
    console.log(`Checking in: ${name} (${id})`);
  }
  await batch.commit();
  console.log('Done.');
}

run().then(() => process.exit(0)).catch(e => { console.error(e.message); process.exit(1); });
