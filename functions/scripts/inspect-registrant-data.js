/**
 * Inspect one registrant document from Firestore to verify data shape.
 * Use this to confirm region/ministry/service keys and values before debugging Top 5 / UI.
 *
 * Run:
 *   cd functions && node scripts/inspect-registrant-data.js "--database=(default)" --dev
 *   cd functions && node scripts/inspect-registrant-data.js "--database=(default)" --dev --id=REGISTRANT_ID
 *
 * Requires: gcloud auth application-default login
 */

const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');

const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || 'aisaiah-event-hub';
const hasDev = process.argv.includes('--dev');
const dbArg = process.argv.find((a) => a.startsWith('--database='));
const databaseId = dbArg ? dbArg.replace(/^--database=/, '').trim() : '(default)';
const idArg = process.argv.find((a) => a.startsWith('--id='));
const registrantId = idArg ? idArg.replace(/^--id=/, '').trim() : null;

if (!hasDev) {
  console.error('ABORT: Add --dev to confirm dev environment.');
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

const db = databaseId === '(default)' ? getFirestore() : getFirestore(databaseId);
const EVENT_ID = 'nlc-2026';

function getString(data, ...keys) {
  if (!data) return null;
  for (const key of keys) {
    const profile = data.profile || {};
    const answers = data.answers || {};
    const v = data[key] ?? profile[key] ?? answers[key];
    if (v != null && typeof v === 'string' && v.trim()) return v.trim();
  }
  return null;
}

async function run() {
  console.log('Database:', databaseId);
  console.log('Event:', EVENT_ID);
  console.log('');

  let docRef;
  if (registrantId) {
    docRef = db.doc(`events/${EVENT_ID}/registrants/${registrantId}`);
    const snap = await docRef.get();
    if (!snap.exists) {
      console.error('No registrant with id:', registrantId);
      process.exit(1);
    }
    const data = snap.data();
    printRegistrant(registrantId, data);
    return;
  }

  const snap = await db.collection(`events/${EVENT_ID}/registrants`).limit(3).get();
  if (snap.empty) {
    console.error('No registrants in events/' + EVENT_ID + '/registrants');
    process.exit(1);
  }
  for (const doc of snap.docs) {
    printRegistrant(doc.id, doc.data());
    console.log('---');
  }
}

function printRegistrant(id, data) {
  console.log('Registrant id:', id);
  console.log('Top-level keys:', Object.keys(data).sort().join(', '));

  const profile = data.profile || {};
  const answers = data.answers || {};
  console.log('profile keys:', Object.keys(profile).sort().join(', '));
  console.log('answers keys:', Object.keys(answers).sort().join(', '));

  console.log('');
  console.log('Values used by Cloud Function / UI:');
  console.log('  region (getString region, regionMembership, Region):', getString(data, 'region', 'regionMembership', 'Region') ?? '(null)');
  console.log('  ministry (getString ministryMembership, ministry, Ministry):', getString(data, 'ministryMembership', 'ministry', 'Ministry') ?? '(null)');
  console.log('  service (for UI):', answers.service ?? profile.service ?? data.service ?? '(not set)');

  console.log('');
  console.log('Raw answers.region:', answers.region ?? '(not set)');
  console.log('Raw answers.ministry:', answers.ministry ?? '(not set)');
  console.log('Raw answers.service:', answers.service ?? '(not set)');
  console.log('Raw profile.region:', profile.region ?? '(not set)');
  console.log('Raw profile.ministry:', profile.ministry ?? '(not set)');
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
