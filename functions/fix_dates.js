const admin = require('firebase-admin');
if (admin.apps.length === 0) admin.initializeApp({ projectId: 'aisaiah-event-hub' });
const db = admin.firestore();

async function fix() {
  const updates = [
    {
      id: 'refresh-seminar-jax-2026',
      startAt: admin.firestore.Timestamp.fromDate(new Date('2026-04-11T00:00:00Z')),
      endAt: admin.firestore.Timestamp.fromDate(new Date('2026-04-11T23:59:59Z')),
    },
    {
      id: 'twr-southeast-b-2026',
      startAt: admin.firestore.Timestamp.fromDate(new Date('2026-06-06T00:00:00Z')),
      endAt: admin.firestore.Timestamp.fromDate(new Date('2026-06-07T23:59:59Z')),
    },
  ];

  for (const u of updates) {
    await db.collection('events').doc(u.id).update({
      startAt: u.startAt,
      endAt: u.endAt,
    });
    console.log('✅ ' + u.id + ': added startAt/endAt');
  }

  // Verify
  for (const u of updates) {
    const doc = await db.collection('events').doc(u.id).get();
    const d = doc.data();
    console.log('\n' + u.id + ':');
    console.log('  startAt:', d.startAt.toDate().toISOString());
    console.log('  endAt:', d.endAt.toDate().toISOString());
  }

  process.exit(0);
}
fix().catch(e => { console.error(e); process.exit(1); });
