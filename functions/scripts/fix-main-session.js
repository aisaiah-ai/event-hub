const admin = require('firebase-admin');
if (!admin.apps.length) admin.initializeApp({ projectId: 'aisaiah-event-hub' });
const db = admin.firestore();

async function run() {
  const ref = db.doc('events/march-assembly/sessions/main');
  await ref.update({ isMain: true });
  console.log('Set isMain=true on events/march-assembly/sessions/main');
}

run().then(() => process.exit(0)).catch(e => { console.error(e.message); process.exit(1); });
