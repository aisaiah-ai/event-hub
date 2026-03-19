const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');

if (!admin.apps.length) admin.initializeApp({ projectId: 'aisaiah-event-hub' });
const db = getFirestore(admin.app(), 'aisaiah-check-in-dev');

async function report() {
  const eventId = 'tampa-bay-february-2026-chapter-assembly';

  // Get attendance (checked-in members)
  const attendance = await db.collection('events').doc(eventId).collection('attendance').get();
  const checkedInIds = new Set(attendance.docs.map(d => d.id));
  console.log(`Checked in: ${checkedInIds.size} members\n`);

  // Check for members collection
  const topCols = await db.listCollections();
  console.log('Top-level collections:', topCols.map(c => c.id).join(', '));

  // Check for members/roster in various locations
  for (const colName of ['members', 'roster', 'users', 'pax', 'directory']) {
    const snap = await db.collection(colName).get();
    if (snap.size > 0) {
      console.log(`\n${colName}: ${snap.size} docs`);

      // Find who's NOT in attendance
      const missing = [];
      for (const doc of snap.docs) {
        if (!checkedInIds.has(doc.id)) {
          const d = doc.data();
          missing.push({
            id: doc.id,
            name: d.memberName || d.name || d.fullName || `${d.firstName || ''} ${d.lastName || ''}`.trim(),
            service: d.service || '',
            unit: d.unit || '',
            household: d.householdKey || d.household || '',
          });
        }
      }

      if (missing.length > 0) {
        console.log(`\n=== MISSING from attendance (${missing.length}) ===\n`);
        for (const m of missing) {
          console.log(`  ${m.id}: ${m.name} | Service: ${m.service} | Unit: ${m.unit} | HH: ${m.household}`);
        }
      } else {
        console.log('  All members checked in!');
      }
    }
  }

  // Also check event subcollections for a roster/members list
  const eventSubcols = await db.collection('events').doc(eventId).listCollections();
  console.log(`\nEvent subcollections: ${eventSubcols.map(c => c.id).join(', ')}`);

  for (const subcol of eventSubcols) {
    if (subcol.id !== 'attendance') {
      const snap = await subcol.get();
      if (snap.size > 0) {
        console.log(`\n${subcol.id}: ${snap.size} docs`);
      }
    }
  }

  process.exit(0);
}
report().catch(e => { console.error(e); process.exit(1); });
