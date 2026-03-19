const admin = require('firebase-admin');
if (!admin.apps.length) admin.initializeApp({ projectId: 'aisaiah-event-hub' });
const db = admin.firestore();

async function search() {
  for (const docId of ['march-assembly', 'march-cluster-2026']) {
    for (const coll of ['registrants', 'rsvps']) {
      const snap = await db.collection(`events/${docId}/${coll}`).get();
      for (const d of snap.docs) {
        const data = d.data();
        const profile = data.profile || {};
        const name = (data.name || profile.name || `${profile.firstName || ''} ${profile.lastName || ''}`).trim();
        if (name.toLowerCase().includes('fisher')) {
          console.log(`${docId}/${coll}: ${name} (id: ${d.id})`);
        }
      }
    }
  }
}
search().then(() => process.exit(0)).catch(e => { console.error(e.message); process.exit(1); });
