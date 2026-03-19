const admin = require('firebase-admin');
if (!admin.apps.length) admin.initializeApp({ projectId: 'aisaiah-event-hub' });
const db = admin.firestore();

async function run() {
  const snap = await db.collection('events/march-assembly/registrants').get();
  let found = false;
  for (const doc of snap.docs) {
    const d = doc.data();
    const p = d.profile || {};
    const name = (p.name || ((p.firstName || '') + ' ' + (p.lastName || ''))).trim();
    if (name.toLowerCase().includes('claire') || name.toLowerCase().includes('dolar')) {
      found = true;
      console.log(`${doc.id} | ${name} | checkedIn: ${!!d.eventAttendance}`);
    }
  }
  if (!found) console.log('No registrant found matching "claire" or "dolar"');
}

run().then(() => process.exit(0)).catch(e => { console.error(e.message); process.exit(1); });
