const admin = require('firebase-admin');
const app = admin.initializeApp({ projectId: 'aisaiah-sfa-dev-app' }, 'sfa');
const db = admin.firestore(app);

async function search() {
  const snap = await db.collection('members').get();
  console.log(`Total members: ${snap.size}`);
  for (const d of snap.docs) {
    const data = d.data();
    const name = (data.name || data.displayName || `${data.firstName || ''} ${data.lastName || ''}`).trim();
    if (name.toLowerCase().includes('fisher')) {
      console.log(`\nmembers/${d.id}: ${name}`);
      console.log('  Data:', JSON.stringify(data, null, 2).substring(0, 800));
    }
  }
}
search().then(() => process.exit(0)).catch(e => { console.error(e.message); process.exit(1); });
