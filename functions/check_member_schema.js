const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');

if (!admin.apps.length) admin.initializeApp({ projectId: 'aisaiah-event-hub' });
const checkInDb = getFirestore(admin.app(), 'aisaiah-check-in-dev');

async function main() {
  const members = await checkInDb.collection('members').get();

  // Show 3 sample members with all fields
  console.log('=== Sample Member Docs ===\n');
  let count = 0;
  for (const doc of members.docs) {
    if (count >= 3) break;
    const d = doc.data();
    console.log(`--- ${doc.id} ---`);
    for (const [key, val] of Object.entries(d)) {
      let dv = val;
      if (val && val.toDate) dv = val.toDate().toISOString();
      else if (val && typeof val === 'object') dv = JSON.stringify(val);
      console.log(`  ${key}: ${dv}`);
    }
    console.log('');
    count++;
  }

  // Collect all field names across all members
  const fieldCounts = {};
  for (const doc of members.docs) {
    for (const key of Object.keys(doc.data())) {
      fieldCounts[key] = (fieldCounts[key] || 0) + 1;
    }
  }

  console.log('=== Field Frequency (across all ${members.size} members) ===\n');
  const sorted = Object.entries(fieldCounts).sort((a, b) => b[1] - a[1]);
  for (const [field, count] of sorted) {
    const pct = Math.round(count / members.size * 100);
    console.log(`  ${field}: ${count}/${members.size} (${pct}%)`);
  }

  // Show unique values for service field
  const services = new Set();
  const areas = new Set();
  for (const doc of members.docs) {
    const d = doc.data();
    if (d.service) services.add(d.service);
    if (d.area) {
      // Just get the last segment
      const parts = (d.area || '').split(' > ');
      areas.add(parts[parts.length - 1] || d.area);
    }
  }
  console.log('\n=== Unique service values ===');
  console.log([...services].sort().join(', '));

  console.log('\n=== Unique area leaf values ===');
  console.log([...areas].sort().join(', '));

  process.exit(0);
}
main().catch(e => { console.error(e); process.exit(1); });
