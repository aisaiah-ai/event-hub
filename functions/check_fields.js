const admin = require('firebase-admin');
if (admin.apps.length === 0) admin.initializeApp({ projectId: 'aisaiah-event-hub' });
const db = admin.firestore();

async function check() {
  const ids = ['march-assembly', 'nlc-2026', 'refresh-seminar-jax-2026', 'twr-southeast-b-2026'];
  for (const id of ids) {
    const doc = await db.collection('events').doc(id).get();
    if (!doc.exists) { console.log(id + ': NOT FOUND\n'); continue; }
    const d = doc.data();
    console.log('=== ' + id + ' ===');
    console.log('  All keys:', Object.keys(d).sort().join(', '));
    console.log('  startDate:', d.startDate ? typeof d.startDate + ' → ' + d.startDate.toDate().toISOString() : 'MISSING');
    console.log('  endDate:', d.endDate ? typeof d.endDate + ' → ' + d.endDate.toDate().toISOString() : 'MISSING');
    console.log('  startAt:', d.startAt ? typeof d.startAt + ' → ' + d.startAt.toDate().toISOString() : 'MISSING');
    console.log('  endAt:', d.endAt ? typeof d.endAt + ' → ' + d.endAt.toDate().toISOString() : 'MISSING');
    console.log('');
  }
  process.exit(0);
}
check().catch(e => { console.error(e); process.exit(1); });
