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
    localFile: path.join(
      __dirname,
      '../../assets/images/speakers/rommel_dolar.png',
    ),
    storagePath: `events/${EVENT_ID}/speakers/rommel-dolar/profile.png`,
  },
  {
    id: 'mike-suela',
    localFile: path.join(
      __dirname,
      '../../assets/images/speakers/mike_suela.png',
    ),
    storagePath: `events/${EVENT_ID}/speakers/mike-suela/profile.png`,
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

    const file = bucket.file(speaker.storagePath);
    await file.save(buffer, {
      contentType: 'image/png',
      metadata: {
        // firebaseStorageDownloadTokens is the field Firebase Storage reads
        // to validate token-based download URLs.
        firebaseStorageDownloadTokens: token,
        cacheControl: 'public, max-age=31536000',
      },
    });

    const downloadUrl = buildDownloadUrl(bucketName, speaker.storagePath, token);

    // Update the speaker document in Firestore.
    await db
      .collection('events')
      .doc(EVENT_ID)
      .collection('speakers')
      .doc(speaker.id)
      .update({
        photoUrl: downloadUrl,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

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
