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
      dajao.push({ id: doc.id, name: p.name, hasCheckin: !!d.eventAttendance });
    }
  }

  console.log('Found ' + dajao.length + ' Dajao registrants:');
  for (const r of dajao) {
    console.log('  ' + r.id + ' - ' + r.name + ' | checked in: ' + r.hasCheckin);
  }

  const toFix = dajao.filter(r => r.hasCheckin);
  if (toFix.length === 0) {
    console.log('\nNo check-ins to remove.');
  } else {
    const batch = db.batch();
    for (const r of toFix) {
      const ref = db.collection('events').doc('march-assembly').collection('registrants').doc(r.id);
      batch.update(ref, {
        eventAttendance: admin.firestore.FieldValue.delete(),
        checkInSource: admin.firestore.FieldValue.delete(),
        sessionsCheckedIn: admin.firestore.FieldValue.delete(),
      });
      console.log('Removing check-in for: ' + r.id + ' - ' + r.name);
    }
    await batch.commit();
    console.log('Done! Check-ins removed.');
  }

  process.exit(0);
}
main().catch(e => { console.error(e); process.exit(1); });
