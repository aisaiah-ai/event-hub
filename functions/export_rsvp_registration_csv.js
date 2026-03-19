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
  if (s.includes(',') || s.includes('"') || s.includes('\n')) {
    return `"${s.replace(/"/g, '""')}"`;
  }
  return s;
}

function toRow(fields) {
  return fields.map(escapeCsv).join(',');
}

function formatTimestamp(ts) {
  if (!ts) return '';
  if (ts.toDate) return ts.toDate().toISOString();
  if (ts._seconds) return new Date(ts._seconds * 1000).toISOString();
  return String(ts);
}

async function exportCsv() {
  if (!fs.existsSync(OUTPUT_DIR)) fs.mkdirSync(OUTPUT_DIR, { recursive: true });

  // ── RSVPs ──
  const rsvps = await db.collection('events').doc(EVENT_ID).collection('rsvps').get();
  const rsvpHeaders = [
    'doc_id', 'name', 'area', 'household', 'attendees_count',
    'attending_rally', 'attending_dinner', 'celebration_type',
    'kids', 'cfc_id', 'created_at',
  ];

  const rsvpRows = [toRow(rsvpHeaders)];
  for (const doc of rsvps.docs) {
    const d = doc.data();
    const kids = d.kids && d.kids.length > 0
      ? d.kids.map(k => `${k.name} (age ${k.age})`).join('; ')
      : '';
    rsvpRows.push(toRow([
      doc.id,
      d.name || '',
      d.area || '',
      d.household || '',
      d.attendeesCount || 1,
      d.attendingRally ? 'YES' : 'NO',
      d.attendingDinner ? 'YES' : 'NO',
      d.celebrationType || '',
      kids,
      d.cfcId || '',
      formatTimestamp(d.createdAt),
    ]));
  }

  const rsvpFile = path.join(OUTPUT_DIR, `${EVENT_ID}_rsvps_${new Date().toISOString().slice(0, 10)}.csv`);
  fs.writeFileSync(rsvpFile, rsvpRows.join('\n') + '\n');
  console.log(`✓ RSVPs exported: ${rsvpFile} (${rsvps.size} rows)`);

  // ── Registrants ──
  const regs = await db.collection('events').doc(EVENT_ID).collection('registrants').get();
  const regHeaders = [
    'registrant_id', 'name', 'first_name', 'last_name', 'email',
    'member_id', 'service', 'chapter', 'role', 'gender',
    'uid', 'registration_status', 'source',
    'additional_guests', 'additional_registrants',
    'registered_by', 'registration_type',
    'created_at',
  ];

  const regRows = [toRow(regHeaders)];
  for (const doc of regs.docs) {
    const d = doc.data();
    const p = d.profile || {};
    const additionalRegs = d.additionalRegistrants
      ? d.additionalRegistrants.map(ar =>
          `${ar.type}: ${ar.firstName} ${ar.lastName || ''} (${ar.memberId || 'no-id'})`
        ).join('; ')
      : '';
    regRows.push(toRow([
      doc.id,
      p.name || '',
      p.firstName || '',
      p.lastName || '',
      p.email || '',
      p.memberId || doc.id,
      p.service || '',
      p.chapter || '',
      p.role || '',
      p.gender || '',
      d.uid || '',
      d.registrationStatus || d.status || '',
      d.source || '',
      d.additionalGuests || 0,
      additionalRegs,
      d.registeredBy || '',
      d.registrationType || '',
      formatTimestamp(d.createdAt),
    ]));
  }

  const regFile = path.join(OUTPUT_DIR, `${EVENT_ID}_registrants_${new Date().toISOString().slice(0, 10)}.csv`);
  fs.writeFileSync(regFile, regRows.join('\n') + '\n');
  console.log(`✓ Registrants exported: ${regFile} (${regs.size} rows)`);

  // ── Combined summary ──
  const summaryHeaders = [
    'source', 'doc_id', 'name', 'area_or_chapter', 'household',
    'member_id', 'attendees_count', 'rally', 'dinner',
    'status', 'created_at',
  ];

  const summaryRows = [toRow(summaryHeaders)];

  for (const doc of rsvps.docs) {
    const d = doc.data();
    summaryRows.push(toRow([
      'RSVP',
      doc.id,
      d.name || '',
      d.area || '',
      d.household || '',
      d.cfcId || '',
      d.attendeesCount || 1,
      d.attendingRally ? 'YES' : 'NO',
      d.attendingDinner ? 'YES' : 'NO',
      'rsvp',
      formatTimestamp(d.createdAt),
    ]));
  }

  for (const doc of regs.docs) {
    const d = doc.data();
    const p = d.profile || {};
    summaryRows.push(toRow([
      'REGISTRATION',
      doc.id,
      p.name || '',
      p.chapter || '',
      '',
      p.memberId || doc.id,
      (d.additionalGuests || 0) + 1,
      '',
      '',
      d.registrationStatus || d.status || '',
      formatTimestamp(d.createdAt),
    ]));
  }

  const summaryFile = path.join(OUTPUT_DIR, `${EVENT_ID}_combined_${new Date().toISOString().slice(0, 10)}.csv`);
  fs.writeFileSync(summaryFile, summaryRows.join('\n') + '\n');
  console.log(`✓ Combined exported: ${summaryFile} (${rsvps.size + regs.size} rows)`);

  console.log(`\n=== Summary ===`);
  console.log(`RSVPs: ${rsvps.size} entries`);
  let totalAttendees = 0;
  for (const doc of rsvps.docs) totalAttendees += doc.data().attendeesCount || 1;
  console.log(`RSVP total headcount: ${totalAttendees}`);
  console.log(`Registrants: ${regs.size}`);

  process.exit(0);
}
exportCsv().catch(e => { console.error(e); process.exit(1); });
