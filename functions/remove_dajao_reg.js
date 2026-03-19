const admin = require('firebase-admin');
if (!admin.apps.length) admin.initializeApp({ projectId: 'aisaiah-event-hub' });
const db = admin.firestore();

async function main() {
  const regs = await db.collection('events').doc('march-assembly').collection('registrants').get();
  const dajao = [];
  for (const doc of regs.docs) {
    const d = doc.data();
    const p = d.profile || {};
    const name = (p.name || '').toLowerCase();
    const lastName = (p.lastName || '').toLowerCase();
    if (lastName === 'dajao' || name.includes('dajao')) {
      dajao.push({ id: doc.id, name: p.name });
    }
  }

  console.log('Deleting ' + dajao.length + ' Dajao registrants:');
  const batch = db.batch();
  for (const r of dajao) {
    console.log('  ' + r.id + ' - ' + r.name);
    batch.delete(db.collection('events').doc('march-assembly').collection('registrants').doc(r.id));
  }
  await batch.commit();
  console.log('Done! All Dajao registrations removed.');
  process.exit(0);
}
main().catch(e => { console.error(e); process.exit(1); });
