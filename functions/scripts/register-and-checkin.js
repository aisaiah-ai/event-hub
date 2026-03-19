const admin = require('firebase-admin');
if (!admin.apps.length) admin.initializeApp({ projectId: 'aisaiah-event-hub' });
const db = admin.firestore();

const EVENT_ID = 'march-assembly';
const SESSION_ID = 'main';

// Pass name as argument: node scripts/register-and-checkin.js "Claire Dolar"
const nameArg = process.argv[2] || 'Claire Dolar';
const parts = nameArg.trim().split(/\s+/);
const firstName = parts[0] || '';
const lastName = parts.slice(1).join(' ') || '';

const registrant = {
  profile: {
    name: nameArg.trim(),
    firstName,
    lastName,
  },
  source: 'manual',
  createdAt: admin.firestore.Timestamp.now(),
  eventAttendance: {
    checkedInAt: admin.firestore.Timestamp.now(),
    method: 'manual',
    checkedInBy: 'admin-script',
  },
};

async function run() {
  const ref = db.collection(`events/${EVENT_ID}/registrants`).doc();
  const batch = db.batch();

  // Write registrant
  batch.set(ref, registrant);

  // Write session attendance
  const attendanceRef = db.doc(`events/${EVENT_ID}/sessions/${SESSION_ID}/attendance/${ref.id}`);
  batch.set(attendanceRef, {
    registrantId: ref.id,
    name: nameArg.trim(),
    checkedInAt: admin.firestore.Timestamp.now(),
    method: 'manual',
    checkedInBy: 'admin-script',
  });

  await batch.commit();
  console.log(`Registered and checked in ${nameArg.trim()} (id: ${ref.id})`);
}

run().then(() => process.exit(0)).catch(e => { console.error(e.message); process.exit(1); });
