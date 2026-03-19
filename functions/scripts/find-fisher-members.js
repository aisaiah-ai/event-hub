const admin = require('firebase-admin');
if (!admin.apps.length) admin.initializeApp({ projectId: 'aisaiah-event-hub' });
const db = admin.firestore();

async function search() {
  // Search common member collection names
  const collections = ['members', 'users', 'profiles', 'people', 'contacts'];

  // First, list root collections to find the right one
  const roots = await db.listCollections();
  console.log('Root collections:', roots.map(c => c.id).join(', '));

  for (const col of roots) {
    const snap = await col.limit(500).get();
    for (const d of snap.docs) {
      const data = d.data();
      const profile = data.profile || {};
      const name = (data.name || data.displayName || profile.name || `${data.firstName || profile.firstName || ''} ${data.lastName || profile.lastName || ''}`).trim();
      if (name.toLowerCase().includes('fisher')) {
        console.log(`${col.id}/${d.id}: ${name}`);
        console.log('  Data:', JSON.stringify(data, null, 2).substring(0, 500));
      }
    }
  }
}
search().then(() => process.exit(0)).catch(e => { console.error(e.message); process.exit(1); });
