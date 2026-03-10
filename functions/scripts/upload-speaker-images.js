/**
 * Upload speaker profile images to Firebase Storage and update photoUrl in Firestore.
 *
 * Reads local PNGs from:
 *   assets/images/speakers/{name}.png   (relative to project root)
 *
 * Uploads to Storage at:
 *   events/{eventId}/speakers/{speakerId}/profile.png
 *
 * Updates Firestore at:
 *   events/{eventId}/speakers/{speakerId}.photoUrl
 *
 * Run from project root (event-hub/):
 *   cd functions && node scripts/upload-speaker-images.js
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const projectId =
  process.env.GCLOUD_PROJECT ||
  process.env.GOOGLE_CLOUD_PROJECT ||
  'aisaiah-event-hub';

if (!admin.apps.length) {
  admin.initializeApp({
    projectId,
    storageBucket: 'aisaiah-event-hub.firebasestorage.app',
  });
}

const db = admin.firestore();
const EVENT_ID = 'march-assembly';

// ── speakers to upload ────────────────────────────────────────────────────────
const SPEAKERS = [
  {
    id: 'rommel-dolar',
    localFile: path.join(__dirname, '../../assets/images/speakers/rommel_dolar.png'),
    storagePath: `events/${EVENT_ID}/speakers/rommel-dolar/profile.png`,
  },
  {
    id: 'mike-suela',
    localFile: path.join(__dirname, '../../assets/images/speakers/mike_suela.png'),
    storagePath: `events/${EVENT_ID}/speakers/mike-suela/profile.png`,
  },
  {
    id: 'alvin-martinez',
    localFile: path.join(__dirname, '../../assets/images/speakers/alvin_martinez.png'),
    storagePath: `events/${EVENT_ID}/speakers/alvin-martinez/profile.png`,
  },
  {
    id: 'francis',
    localFile: path.join(__dirname, '../../assets/images/speakers/francis_navales.png'),
    storagePath: `events/${EVENT_ID}/speakers/francis/profile.png`,
  },
  {
    id: 'ernie-angeles',
    localFile: path.join(__dirname, '../../assets/images/speakers/ernie_angeles.png'),
    storagePath: `events/${EVENT_ID}/speakers/ernie-angeles/profile.png`,
  },
  {
    id: 'ed-bilbao',
    localFile: path.join(__dirname, '../../assets/images/speakers/ed_bilbao.png'),
    storagePath: `events/${EVENT_ID}/speakers/ed-bilbao/profile.png`,
  },
  {
    id: 'eric-zalamea',
    localFile: path.join(__dirname, '../../assets/images/speakers/eric_zalamea.png'),
    storagePath: `events/${EVENT_ID}/speakers/eric-zalamea/profile.png`,
  },
  {
    id: 'ron-ares',
    localFile: path.join(__dirname, '../../assets/images/speakers/ron_ares.png'),
    storagePath: `events/${EVENT_ID}/speakers/ron-ares/profile.png`,
  },
  {
    id: 'art-barlaan',
    localFile: path.join(__dirname, '../../assets/images/speakers/art_barlaan.jpg'),
    storagePath: `events/${EVENT_ID}/speakers/art-barlaan/profile.jpg`,
  },
  {
    id: 'sam-jutba',
    localFile: path.join(__dirname, '../../assets/images/speakers/sam_jutba.png'),
    storagePath: `events/${EVENT_ID}/speakers/sam-jutba/profile.png`,
  },
  {
    id: 'irwin-goingo',
    localFile: path.join(__dirname, '../../assets/images/speakers/irwin_goingo.png'),
    storagePath: `events/${EVENT_ID}/speakers/irwin-goingo/profile.png`,
  },
];

// ── helpers ───────────────────────────────────────────────────────────────────

/**
 * Builds a Firebase Storage download URL identical to what
 * FirebaseStorage.ref().getDownloadURL() returns on the client.
 * A random token is embedded so the URL is stable and revocable.
 */
function buildDownloadUrl(bucketName, storagePath, token) {
  const encoded = encodeURIComponent(storagePath);
  return (
    `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/` +
    `${encoded}?alt=media&token=${token}`
  );
}

// ── main ──────────────────────────────────────────────────────────────────────

async function main() {
  const bucket = admin.storage().bucket(); // default bucket for project
  const bucketName = bucket.name;
  console.log(`Bucket: ${bucketName}`);
  console.log(`Event:  events/${EVENT_ID}\n`);

  for (const speaker of SPEAKERS) {
    process.stdout.write(`Uploading ${speaker.id} … `);

    if (!fs.existsSync(speaker.localFile)) {
      console.error(`MISSING: ${speaker.localFile}`);
      continue;
    }

    const buffer = fs.readFileSync(speaker.localFile);

    // Generate a stable download token (same mechanism as Firebase client SDK).
    const token = crypto.randomUUID();

    const contentType = speaker.storagePath.endsWith('.jpg') ? 'image/jpeg' : 'image/png';
    const file = bucket.file(speaker.storagePath);
    await file.save(buffer, {
      contentType,
      metadata: {
        // firebaseStorageDownloadTokens is the field Firebase Storage reads
        // to validate token-based download URLs.
        firebaseStorageDownloadTokens: token,
        cacheControl: 'public, max-age=31536000',
      },
    });

    const downloadUrl = buildDownloadUrl(bucketName, speaker.storagePath, token);

    // Update the speaker document in Firestore (merge to create if missing).
    await db
      .collection('events')
      .doc(EVENT_ID)
      .collection('speakers')
      .doc(speaker.id)
      .set({
        photoUrl: downloadUrl,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

    console.log('done');
    console.log(`  Storage : gs://${bucketName}/${speaker.storagePath}`);
    console.log(`  photoUrl: ${downloadUrl}\n`);
  }

  console.log('All speaker images uploaded and Firestore updated.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
