const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');
const fs = require('fs');
const path = require('path');

if (!admin.apps.length) admin.initializeApp({ projectId: 'aisaiah-event-hub' });
const prodDb = getFirestore(admin.app(), 'event-hub-prod');

const OUTPUT_DIR = path.join(__dirname, 'reports');

function escapeCsv(val) {
  if (val == null) return '';
  const s = String(val);
  if (s.includes(',') || s.includes('"') || s.includes('\n')) return `"${s.replace(/"/g, '""')}"`;
  return s;
}
function toRow(fields) { return fields.map(escapeCsv).join(','); }
function formatTs(ts) {
  if (!ts) return '';
  if (ts.toDate) return ts.toDate().toISOString();
  if (ts._seconds) return new Date(ts._seconds * 1000).toISOString();
  return String(ts);
}

async function main() {
  // List all events in event-hub-prod
  console.log('=== Events in event-hub-prod ===\n');
  const events = await prodDb.collection('events').listDocuments();
  for (const ref of events) {
    const doc = await ref.get();
    console.log(`  ${ref.id} (exists: ${doc.exists})`);
    const subcols = await ref.listCollections();
    for (const sc of subcols) {
      const snap = await sc.get();
      console.log(`    └─ ${sc.id}: ${snap.size} docs`);
    }
  }

  // Get RSVPs from march-cluster-2026
  const EVENT_ID = 'march-cluster-2026';
  console.log(`\n=== RSVPs in event-hub-prod / ${EVENT_ID} ===\n`);
  const rsvps = await prodDb.collection('events').doc(EVENT_ID).collection('rsvps').get();
  console.log(`Total: ${rsvps.size}\n`);

  const headers = ['doc_id', 'name', 'area', 'household', 'attendees_count',
    'attending_rally', 'attending_dinner', 'celebration_type', 'kids', 'cfc_id', 'created_at'];
  const rows = [toRow(headers)];

  let totalAttendees = 0;
  for (const doc of rsvps.docs) {
    const d = doc.data();
    const kids = d.kids && d.kids.length > 0
      ? d.kids.map(k => `${k.name} (age ${k.age})`).join('; ') : '';
    totalAttendees += d.attendeesCount || 1;

    console.log(`  ${doc.id}: ${d.name} | ${d.area} | HH: ${d.household} | count: ${d.attendeesCount} | rally: ${d.attendingRally} | dinner: ${d.attendingDinner}`);
    if (kids) console.log(`    kids: ${kids}`);

    rows.push(toRow([
      doc.id, d.name || '', d.area || '', d.household || '',
      d.attendeesCount || 1,
      d.attendingRally ? 'YES' : 'NO',
      d.attendingDinner ? 'YES' : 'NO',
      d.celebrationType || '', kids, d.cfcId || '',
      formatTs(d.createdAt),
    ]));
  }

  if (!fs.existsSync(OUTPUT_DIR)) fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  const csvFile = path.join(OUTPUT_DIR, `event-hub-prod_${EVENT_ID}_rsvps_${new Date().toISOString().slice(0, 10)}.csv`);
  fs.writeFileSync(csvFile, rows.join('\n') + '\n');

  console.log(`\n=== Summary ===`);
  console.log(`RSVPs: ${rsvps.size} entries, ${totalAttendees} total attendees`);
  console.log(`CSV: ${csvFile}`);

  process.exit(0);
}
main().catch(e => { console.error(e); process.exit(1); });
