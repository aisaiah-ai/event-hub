/**
 * March 14 Assembly — RSVP Report
 *
 * Fetches all RSVPs from Firestore and prints:
 *   - Summary totals (total RSVPs, rally headcount, dinner headcount, celebrations)
 *   - Full table grouped by area
 *   - Saves report to march-assembly-rsvp-report.csv in the project root
 *
 * Run from project root (event-hub/):
 *   cd functions && node scripts/rsvp-report.js
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const projectId =
  process.env.GCLOUD_PROJECT ||
  process.env.GOOGLE_CLOUD_PROJECT ||
  'aisaiah-event-hub';

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

const db = admin.firestore();

// March Assembly can live under either ID — try both
const CANDIDATE_IDS = ['march-assembly', 'march-cluster-2026'];

// ── helpers ───────────────────────────────────────────────────────────────────

function pad(str, len) {
  const s = String(str ?? '');
  return s.length >= len ? s.substring(0, len) : s + ' '.repeat(len - s.length);
}

function fmt(dt) {
  if (!dt) return '';
  const d = dt.toDate ? dt.toDate() : new Date(dt);
  return d.toISOString().replace('T', ' ').substring(0, 16);
}

function escapeCsv(v) {
  const s = String(v ?? '');
  return s.includes(',') || s.includes('"') || s.includes('\n')
    ? `"${s.replace(/"/g, '""')}"` : s;
}

// ── main ──────────────────────────────────────────────────────────────────────

async function main() {
  // Find which event ID has RSVP data
  let rsvps = [];
  let sourceId = null;

  for (const eventId of CANDIDATE_IDS) {
    const snap = await db
      .collection('events')
      .doc(eventId)
      .collection('rsvps')
      .orderBy('createdAt', 'asc')
      .get();

    if (snap.size > 0) {
      rsvps = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      sourceId = eventId;
      break;
    }
  }

  if (rsvps.length === 0) {
    console.log('No RSVPs found under:', CANDIDATE_IDS.join(', '));
    process.exit(0);
  }

  console.log(`\nSource: events/${sourceId}/rsvps\n`);

  // ── Totals ──────────────────────────────────────────────────────────────────

  const totalPeople = rsvps.reduce((s, r) => s + (r.attendeesCount || 1), 0);
  const rallyCount = rsvps
    .filter((r) => r.attendingRally !== false)
    .reduce((s, r) => s + (r.attendeesCount || 1), 0);
  const dinnerCount = rsvps
    .filter((r) => r.attendingDinner !== false)
    .reduce((s, r) => s + (r.attendeesCount || 1), 0);

  const celebrations = rsvps.filter((r) => r.celebrationType);
  const birthdays = celebrations.filter(
    (r) => r.celebrationType?.toLowerCase().includes('birthday'),
  ).length;
  const anniversaries = celebrations.filter(
    (r) => r.celebrationType?.toLowerCase().includes('anniversary'),
  ).length;

  // Group by area
  const byArea = {};
  for (const r of rsvps) {
    const area = r.area || '(no area)';
    if (!byArea[area]) byArea[area] = [];
    byArea[area].push(r);
  }

  // ── Print summary ───────────────────────────────────────────────────────────

  console.log('══════════════════════════════════════════════════════════════');
  console.log('  MARCH 14 ASSEMBLY — RSVP REPORT');
  console.log('══════════════════════════════════════════════════════════════');
  console.log(`  Total RSVPs submitted : ${rsvps.length}`);
  console.log(`  Total attendees       : ${totalPeople}`);
  console.log(`  Attending rally       : ${rallyCount}`);
  console.log(`  Attending dinner      : ${dinnerCount}`);
  console.log(`  Birthday celebrations : ${birthdays}`);
  console.log(`  Anniversary celebrations : ${anniversaries}`);
  console.log('──────────────────────────────────────────────────────────────\n');

  // ── Print by area ───────────────────────────────────────────────────────────

  const areaNames = Object.keys(byArea).sort();
  for (const area of areaNames) {
    const list = byArea[area];
    const areaHeads = list.reduce((s, r) => s + (r.attendeesCount || 1), 0);
    console.log(`  ${area}  (${list.length} households, ${areaHeads} people)`);
    for (const r of list) {
      const rally = r.attendingRally !== false ? 'Rally' : '     ';
      const dinner = r.attendingDinner !== false ? 'Dinner' : '      ';
      const cel = r.celebrationType ? ` 🎉 ${r.celebrationType}` : '';
      console.log(
        `    ${pad(r.name, 28)} ${pad(r.household, 22)} ${rally} ${dinner}` +
          `  (${r.attendeesCount || 1})${cel}`,
      );
    }
    console.log('');
  }

  // ── Full table ───────────────────────────────────────────────────────────────

  console.log('──────────────────────────────────────────────────────────────');
  console.log(
    pad('Name', 28) +
      pad('Household', 22) +
      pad('Area', 16) +
      pad('Rally', 6) +
      pad('Dinner', 7) +
      pad('Pax', 4) +
      pad('Celebration', 20) +
      'RSVP time',
  );
  console.log('─'.repeat(120));
  for (const r of rsvps) {
    console.log(
      pad(r.name, 28) +
        pad(r.household, 22) +
        pad(r.area, 16) +
        pad(r.attendingRally !== false ? 'Yes' : 'No', 6) +
        pad(r.attendingDinner !== false ? 'Yes' : 'No', 7) +
        pad(r.attendeesCount || 1, 4) +
        pad(r.celebrationType ?? '', 20) +
        fmt(r.createdAt),
    );
  }
  console.log('');

  // ── CSV export ───────────────────────────────────────────────────────────────

  const columns = [
    'name', 'household', 'area', 'cfcId',
    'attendingRally', 'attendingDinner', 'attendeesCount',
    'celebrationType', 'source', 'createdAt',
  ];

  const csvLines = [
    columns.join(','),
    ...rsvps.map((r) =>
      [
        r.name,
        r.household,
        r.area ?? '',
        r.cfcId ?? '',
        r.attendingRally !== false,
        r.attendingDinner !== false,
        r.attendeesCount || 1,
        r.celebrationType ?? '',
        r.source ?? '',
        fmt(r.createdAt),
      ]
        .map(escapeCsv)
        .join(','),
    ),
  ];

  const csvPath = path.join(__dirname, '../../march-assembly-rsvp-report.csv');
  fs.writeFileSync(csvPath, csvLines.join('\n'), 'utf8');

  console.log(`CSV saved → ${csvPath}`);
  console.log(`Total rows: ${rsvps.length}\n`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
