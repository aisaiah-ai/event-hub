const admin = require('firebase-admin');
if (admin.apps.length === 0) admin.initializeApp({ projectId: 'aisaiah-event-hub' });
const db = admin.firestore();

async function check() {
  console.log('=== Project: aisaiah-event-hub | Database: (default) ===\n');

  const events = await db.collection('events').get();
  console.log('Events found:', events.docs.map(d => d.id));

  for (const doc of events.docs) {
    const data = doc.data();
    console.log('\n--- Event:', doc.id, '---');
    console.log('  title:', data.title || data.name);
    console.log('  registrationSettings:', JSON.stringify(data.registrationSettings || 'NONE'));
    console.log('  allowCheckin:', data.allowCheckin);
    console.log('  allowRsvp:', data.allowRsvp);

    const regs = await db.collection('events/' + doc.id + '/registrants').get();
    console.log('  Registrants:', regs.size);
    for (const r of regs.docs) {
      const rd = r.data();
      console.log('    -', r.id,
        '| uid:', rd.uid,
        '| status:', rd.registrationStatus || rd.status,
        '| checkedIn:', rd.eventAttendance ? rd.eventAttendance.checkedIn : (rd.checkedIn || 'N/A'),
        '| additionalRegistrants:', JSON.stringify(rd.additionalRegistrants || []));
    }

    const sessions = await db.collection('events/' + doc.id + '/sessions').get();
    console.log('  Sessions:', sessions.size);
  }

  process.exit(0);
}
check().catch(e => { console.error(e); process.exit(1); });
