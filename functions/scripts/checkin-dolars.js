/**
 * Check in all Dolar registrants for March Assembly.
 * Writes to both registrant.eventAttendance AND sessions/main/attendance.
 * Run: cd functions && node scripts/checkin-dolars.js
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

  for (const doc of snap.docs) {
    const data = doc.data();
    const profile = data.profile || {};
    const name = (profile.name || `${profile.firstName || ''} ${profile.lastName || ''}`).trim().toLowerCase();

    if (name.includes('dolar')) {
      found++;
      const alreadyCheckedIn = !!data.eventAttendance;
      console.log(`  Found: ${name} (id: ${doc.id}) ${alreadyCheckedIn ? '[already checked in]' : '[will check in]'}`);

      if (!alreadyCheckedIn) {
        // Write eventAttendance on registrant doc
        batch.update(doc.ref, {
          eventAttendance: {
            checkedInAt: admin.firestore.Timestamp.now(),
            method: 'manual',
            checkedInBy: 'admin-script',
          },
        });
        // Write to session attendance subcollection
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
        // Already has eventAttendance, ensure session attendance exists too
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

  if (found > 0) {
    await batch.commit();
  }

  console.log(`\nFound ${found} Dolar registrants, checked in ${checkedIn} new.`);
}

run()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Failed:', err.message);
    process.exit(1);
  });
