const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');

if (!admin.apps.length) admin.initializeApp({ projectId: 'aisaiah-event-hub' });
const db = admin.firestore(); // default database
const checkInDb = getFirestore(admin.app(), 'aisaiah-check-in-dev');

const EVENT_ID = 'march-assembly';

async function preview() {
  // 1. Load RSVPs
  const rsvps = await db.collection('events').doc(EVENT_ID).collection('rsvps').get();
  console.log(`=== RSVPs: ${rsvps.size} ===\n`);
  for (const doc of rsvps.docs) {
    const d = doc.data();
    console.log(`  ${doc.id}: ${d.name} | area: ${d.area} | HH: ${d.household} | count: ${d.attendeesCount} | rally: ${d.attendingRally} | dinner: ${d.attendingDinner}`);
    if (d.kids && d.kids.length > 0) console.log(`    kids: ${JSON.stringify(d.kids)}`);
  }

  // 2. Load registrants
  const regs = await db.collection('events').doc(EVENT_ID).collection('registrants').get();
  console.log(`\n=== Registrants: ${regs.size} ===\n`);
  for (const doc of regs.docs) {
    const d = doc.data();
    const p = d.profile || {};
    console.log(`  ${doc.id}: ${p.name || p.firstName || 'N/A'} | uid: ${d.uid || 'none'} | source: ${d.source || 'N/A'} | additionalGuests: ${d.additionalGuests || 0}`);
    if (d.additionalRegistrants) {
      for (const ar of d.additionalRegistrants) {
        console.log(`    +${ar.type}: ${ar.firstName} ${ar.lastName || ''} (${ar.memberId || 'no-id'})`);
      }
    }
  }

  // 3. Load members from check-in DB
  const members = await checkInDb.collection('members').get();
  console.log(`\n=== Members DB: ${members.size} total ===\n`);

  // 4. Try matching RSVPs to members by name
  const membersByName = new Map();
  for (const doc of members.docs) {
    const d = doc.data();
    const name = (d.memberName || '').toUpperCase().trim();
    membersByName.set(name, { id: doc.id, ...d });
    // Also index by last name for partial match
    const parts = name.split(' ');
    if (parts.length > 1) {
      const lastName = parts[parts.length - 1];
      if (!membersByName.has(`LAST:${lastName}`)) {
        membersByName.set(`LAST:${lastName}`, []);
      }
      membersByName.get(`LAST:${lastName}`).push({ id: doc.id, name, ...d });
    }
  }

  console.log('=== RSVP → Member Matching ===\n');
  for (const doc of rsvps.docs) {
    const d = doc.data();
    const rsvpName = (d.name || '').toUpperCase().trim();

    // Try exact match
    const exact = membersByName.get(rsvpName);
    if (exact && exact.id) {
      console.log(`  ✓ EXACT: "${d.name}" → ${exact.id} (${exact.memberName})`);
      continue;
    }

    // Try matching by last name from RSVP name
    const nameParts = rsvpName.split(/[\s&,]+/).filter(Boolean);
    let found = false;
    for (const part of nameParts) {
      const lastNameMatches = membersByName.get(`LAST:${part}`);
      if (lastNameMatches && Array.isArray(lastNameMatches)) {
        console.log(`  ~ PARTIAL: "${d.name}" → possible matches by "${part}":`);
        for (const m of lastNameMatches.slice(0, 5)) {
          console.log(`      ${m.id}: ${m.name}`);
        }
        found = true;
        break;
      }
    }
    if (!found) {
      console.log(`  ✗ NO MATCH: "${d.name}" (area: ${d.area}, HH: ${d.household})`);
    }
  }

  // 5. Summary: total headcount from RSVPs
  let totalAttendees = 0;
  for (const doc of rsvps.docs) {
    totalAttendees += doc.data().attendeesCount || 1;
  }
  console.log(`\n=== Summary ===`);
  console.log(`RSVPs: ${rsvps.size} entries, ${totalAttendees} total attendees`);
  console.log(`Registrants: ${regs.size}`);
  console.log(`Members DB: ${members.size}`);

  process.exit(0);
}
preview().catch(e => { console.error(e); process.exit(1); });
