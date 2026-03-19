/**
 * Check in all Bilbao registrants for March Assembly.
 * Also searches RSVPs and auto-registers if only in RSVPs.
 * Run: cd functions && node scripts/checkin-bilbao.js
 */

const admin = require('firebase-admin');
const projectId = 'aisaiah-event-hub';

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

const db = admin.firestore();
const EVENT_ID = 'march-assembly';
const SESSION_ID = 'main';

async function run() {
  const registrantsRef = db.collection(`events/${EVENT_ID}/registrants`);
  const snap = await registrantsRef.get();

  let found = 0;
  let checkedIn = 0;
  const batch = db.batch();
  const foundNames = new Set();

  // 1. Search registrants
  for (const doc of snap.docs) {
    const data = doc.data();
    const profile = data.profile || {};
    const name = (profile.name || `${profile.firstName || ''} ${profile.lastName || ''}`).trim().toLowerCase();

    if (name.includes('bilbao')) {
      found++;
      foundNames.add(name);
      const alreadyCheckedIn = !!data.eventAttendance;
      console.log(`  Found registrant: ${name} (id: ${doc.id}) ${alreadyCheckedIn ? '[already checked in]' : '[will check in]'}`);

      if (!alreadyCheckedIn) {
        batch.update(doc.ref, {
          eventAttendance: {
            checkedInAt: admin.firestore.Timestamp.now(),
            method: 'manual',
            checkedInBy: 'admin-script',
          },
        });
        const attendanceRef = db.doc(`events/${EVENT_ID}/sessions/${SESSION_ID}/attendance/${doc.id}`);
        batch.set(attendanceRef, {
          registrantId: doc.id,
          name: (profile.name || `${profile.firstName || ''} ${profile.lastName || ''}`).trim(),
          checkedInAt: admin.firestore.Timestamp.now(),
          method: 'manual',
          checkedInBy: 'admin-script',
        });
        checkedIn++;
      } else {
        const attendanceRef = db.doc(`events/${EVENT_ID}/sessions/${SESSION_ID}/attendance/${doc.id}`);
        const attendanceDoc = await attendanceRef.get();
        if (!attendanceDoc.exists) {
          batch.set(attendanceRef, {
            registrantId: doc.id,
            name: (profile.name || `${profile.firstName || ''} ${profile.lastName || ''}`).trim(),
            checkedInAt: admin.firestore.Timestamp.now(),
            method: 'manual',
            checkedInBy: 'admin-script',
          });
          console.log(`    -> Also writing session attendance for ${name}`);
        }
      }
    }
  }

  // 2. Search RSVPs for any Bilbaos not already registered
  const rsvpSnap = await db.collection(`events/${EVENT_ID}/rsvps`).get();
  for (const doc of rsvpSnap.docs) {
    const data = doc.data();
    const rsvpName = (data.name || '').trim();
    if (!rsvpName.toLowerCase().includes('bilbao')) continue;
    if (foundNames.has(rsvpName.toLowerCase())) {
      console.log(`  RSVP ${rsvpName} already in registrants, skipping.`);
      continue;
    }

    console.log(`  Found RSVP: ${rsvpName} — auto-registering and checking in.`);
    const parts = rsvpName.split(' ');
    const firstName = parts[0] || '';
    const lastName = parts.slice(1).join(' ') || '';
    const newRef = registrantsRef.doc();
    batch.set(newRef, {
      profile: { name: rsvpName, firstName, lastName },
      source: 'RSVP',
      registrationStatus: 'registered',
      createdAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now(),
      eventAttendance: {
        checkedInAt: admin.firestore.Timestamp.now(),
        method: 'manual',
        checkedInBy: 'admin-script',
      },
    });
    const attendanceRef = db.doc(`events/${EVENT_ID}/sessions/${SESSION_ID}/attendance/${newRef.id}`);
    batch.set(attendanceRef, {
      registrantId: newRef.id,
      name: rsvpName,
      checkedInAt: admin.firestore.Timestamp.now(),
      method: 'manual',
      checkedInBy: 'admin-script',
    });
    found++;
    checkedIn++;
    foundNames.add(rsvpName.toLowerCase());
  }

  if (found > 0) {
    await batch.commit();
  }

  console.log(`\nFound ${found} Bilbao(s), checked in ${checkedIn} new.`);
}

run()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Failed:', err.message);
    process.exit(1);
  });
