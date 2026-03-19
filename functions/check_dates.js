const admin = require('firebase-admin');
if (admin.apps.length === 0) admin.initializeApp({ projectId: 'aisaiah-event-hub' });
const db = admin.firestore();

async function check() {
  const ids = ['nlc-2026', 'march-assembly', 'refresh-seminar-jax-2026', 'twr-southeast-b-2026'];
  for (const id of ids) {
    const doc = await db.collection('events').doc(id).get();
    if (!doc.exists) { console.log(id + ': NOT FOUND\n'); continue; }
    const d = doc.data();
    const start = d.startDate ? d.startDate.toDate().toISOString() : 'MISSING';
    const end = d.endDate ? d.endDate.toDate().toISOString() : 'MISSING';
    console.log(id + ':');
    console.log('  name:', d.name || d.title);
    console.log('  startDate:', start);
    console.log('  endDate:', end);
    console.log('  isActive:', d.isActive);
    console.log('');
  }
  process.exit(0);
}
check().catch(e => { console.error(e); process.exit(1); });
