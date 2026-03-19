const admin = require('firebase-admin');
if (!admin.apps.length) admin.initializeApp({ projectId: 'aisaiah-event-hub' });
const db = admin.firestore();

const EVENT_ID = 'march-assembly';
const SESSION_ID = 'main';
const SEARCH = ['pardee', 'roa'];

async function run() {
  const snap = await db.collection(`events/${EVENT_ID}/registrants`).get();
  const rsvpSnap = await db.collection(`events/${EVENT_ID}/rsvps`).get();
  const batch = db.batch();
  const matched = [];

  // Search registrants
  for (const d of snap.docs) {
    const data = d.data();
    const p = data.profile || {};
    const name = (p.name || `${p.firstName || ''} ${p.lastName || ''}`).trim();
    if (SEARCH.some(s => name.toLowerCase().includes(s))) {
      const already = !!data.eventAttendance;
      console.log(`Registrant: ${name} (${d.id}) ${already ? '[already]' : '[checking in]'}`);
      if (!already) {
        batch.update(d.ref, {
          eventAttendance: { checkedInAt: admin.firestore.Timestamp.now(), method: 'manual', checkedInBy: 'admin-script' },
        });
      }
      const attRef = db.doc(`events/${EVENT_ID}/sessions/${SESSION_ID}/attendance/${d.id}`);
      const attDoc = await attRef.get();
      if (!attDoc.exists) {
        batch.set(attRef, { registrantId: d.id, name, checkedInAt: admin.firestore.Timestamp.now(), method: 'manual', checkedInBy: 'admin-script' });
      }
      matched.push(name.toLowerCase());
    }
  }

  // Search RSVPs for anyone not already in registrants
  for (const d of rsvpSnap.docs) {
    const data = d.data();
    const name = (data.name || '').trim();
    if (!SEARCH.some(s => name.toLowerCase().includes(s))) continue;
    if (matched.includes(name.toLowerCase())) continue;
    console.log(`RSVP: ${name} — auto-registering and checking in.`);
    const regRef = db.collection(`events/${EVENT_ID}/registrants`).doc();
    const parts = name.split(' ');
    batch.set(regRef, {
      profile: { name, firstName: parts[0] || '', lastName: parts.slice(1).join(' ') || '' },
      source: 'RSVP', registrationStatus: 'registered',
      createdAt: admin.firestore.Timestamp.now(), updatedAt: admin.firestore.Timestamp.now(),
      eventAttendance: { checkedInAt: admin.firestore.Timestamp.now(), method: 'manual', checkedInBy: 'admin-script' },
    });
    batch.set(db.doc(`events/${EVENT_ID}/sessions/${SESSION_ID}/attendance/${regRef.id}`), {
      registrantId: regRef.id, name, checkedInAt: admin.firestore.Timestamp.now(), method: 'manual', checkedInBy: 'admin-script',
    });
    matched.push(name.toLowerCase());
  }

  if (matched.length > 0) {
    await batch.commit();
  }
  console.log(`\nChecked in ${matched.length} people.`);
}

run().then(() => process.exit(0)).catch(e => { console.error(e.message); process.exit(1); });
