const admin = require('firebase-admin');
if (admin.apps.length === 0) admin.initializeApp({ projectId: 'aisaiah-event-hub' });
const db = admin.firestore();

async function report() {
  // List ALL events with ALL subcollections
  console.log('=== All Events in aisaiah-event-hub ===\n');
  const events = await db.collection('events').get();
  for (const doc of events.docs) {
    const d = doc.data();
    const start = d.startDate ? d.startDate.toDate().toISOString().slice(0, 10) : (d.startAt ? d.startAt.toDate().toISOString().slice(0, 10) : 'N/A');
    const name = d.name || d.title || 'Untitled';
    console.log(`  ${doc.id}: ${name} (${start})`);

    // Check ALL subcollections
    const subcols = await doc.ref.listCollections();
    for (const subcol of subcols) {
      const snap = await subcol.get();
      console.log(`    └─ ${subcol.id}: ${snap.size} docs`);
    }
  }

  // Also search top-level collections for any assembly/checkin data
  console.log('\n=== Top-level collections ===\n');
  const collections = await db.listCollections();
  for (const col of collections) {
    const snap = await col.get();
    console.log(`  ${col.id}: ${snap.size} docs`);
  }

  // Search for february/assembly in event names
  console.log('\n=== Events matching "february" or "assembly" ===\n');
  for (const doc of events.docs) {
    const d = doc.data();
    const name = (d.name || d.title || '').toLowerCase();
    const id = doc.id.toLowerCase();
    if (name.includes('feb') || name.includes('assembly') || id.includes('feb') || id.includes('assembly')) {
      console.log(`  MATCH: ${doc.id} — ${d.name || d.title}`);
      const subcols = await doc.ref.listCollections();
      for (const subcol of subcols) {
        const snap = await subcol.get();
        console.log(`    └─ ${subcol.id}: ${snap.size} docs`);
        if (snap.size > 0 && snap.size <= 50) {
          for (const sdoc of snap.docs) {
            const sd = sdoc.data();
            console.log(`      - ${sdoc.id}: ${JSON.stringify(sd).slice(0, 200)}`);
          }
        }
      }
    }
  }

  // Check if there's a separate checkins collection at top level
  console.log('\n=== Checking top-level checkins/check-ins collections ===\n');
  for (const colName of ['checkins', 'check-ins', 'check_ins', 'attendance']) {
    try {
      const snap = await db.collection(colName).get();
      if (snap.size > 0) {
        console.log(`  ${colName}: ${snap.size} docs`);
      }
    } catch (e) {
      // ignore
    }
  }

  process.exit(0);
}
report().catch(e => { console.error(e); process.exit(1); });
