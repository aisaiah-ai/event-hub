const admin = require('firebase-admin');
// Main app project
const app = admin.initializeApp({ projectId: 'aisaiah-sfa-dev-app' }, 'sfa');
const db = admin.firestore(app);

async function search() {
  const roots = await db.listCollections();
  console.log('Root collections:', roots.map(c => c.id).join(', '));

  for (const col of roots) {
    try {
      const snap = await col.limit(500).get();
      for (const d of snap.docs) {
        const data = d.data();
        const profile = data.profile || {};
        const name = (data.name || data.displayName || profile.name || `${data.firstName || profile.firstName || ''} ${data.lastName || profile.lastName || ''}`).trim();
        if (name.toLowerCase().includes('fisher')) {
          console.log(`\n${col.id}/${d.id}: ${name}`);
          console.log('  Keys:', Object.keys(data).join(', '));
        }
      }
    } catch (e) {
      console.log(`${col.id}: error - ${e.message}`);
    }
  }
}
search().then(() => process.exit(0)).catch(e => { console.error(e.message); process.exit(1); });
