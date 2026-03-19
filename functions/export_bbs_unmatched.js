const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

if (!admin.apps.length) admin.initializeApp({ projectId: 'aisaiah-event-hub' });
const db = admin.firestore();

const EVENT_ID = 'march-assembly';
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
  if (!fs.existsSync(OUTPUT_DIR)) fs.mkdirSync(OUTPUT_DIR, { recursive: true });

  const regs = await db.collection('events').doc(EVENT_ID).collection('registrants').get();

  const headers = [
    'registrant_id', 'name', 'first_name', 'last_name',
    'area', 'household', 'source', 'match_type',
    'original_rsvp_name', 'rsvp_source',
    'attendees_count', 'attending_rally', 'attending_dinner',
    'birthday', 'kids',
  ];

  const bbsRows = [toRow(headers)];
  let bbsCount = 0;

  for (const doc of regs.docs) {
    // Only ZZ-9999 IDs (unmatched)
    if (!doc.id.startsWith('ZZ-9999-')) continue;

    const d = doc.data();
    const imp = d.rsvpImport || {};
    const p = d.profile || {};
    const area = (imp.area || '').toUpperCase();

    // BBS area only
    if (area !== 'BBS') continue;

    const kids = imp.kids && imp.kids.length > 0
      ? imp.kids.map(k => `${k.name} (age ${k.age})`).join('; ')
      : '';

    bbsRows.push(toRow([
      doc.id,
      p.name || '',
      p.firstName || '',
      p.lastName || '',
      imp.area || '',
      imp.household || '',
      d.source || '',
      imp.matchType || '',
      imp.originalName || '',
      imp.rsvpSource || '',
      imp.attendeesCount || 1,
      imp.attendingRally ? 'YES' : 'NO',
      imp.attendingDinner ? 'YES' : 'NO',
      imp.birthday || imp.celebrationType || '',
      kids,
    ]));
    bbsCount++;
  }

  const file = path.join(OUTPUT_DIR, `${EVENT_ID}_bbs_unmatched_${new Date().toISOString().slice(0, 10)}.csv`);
  fs.writeFileSync(file, bbsRows.join('\n') + '\n');
  console.log(`✓ BBS unmatched exported: ${file} (${bbsCount} rows)`);

  process.exit(0);
}
main().catch(e => { console.error(e); process.exit(1); });
