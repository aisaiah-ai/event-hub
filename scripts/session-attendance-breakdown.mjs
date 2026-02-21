// Session attendance breakdown: pre-registered vs walk-in check-ins
// Uses application default credentials (gcloud auth application-default login)
// Run: node scripts/session-attendance-breakdown.mjs

import { initializeApp, cert, getApps } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { GoogleAuth } from 'google-auth-library';

const PROJECT_ID = 'aisaiah-event-hub';
const DATABASE_ID = process.env.EVENT_HUB_DB || 'event-hub-prod';
const EVENT_ID    = process.env.EVENT_HUB_EVENT || 'nlc-2026';
const OUTPUT_MD   = process.env.OUTPUT_MD === '1';

// Use application default credentials (gcloud auth application-default login)
if (!getApps().length) {
  initializeApp({ projectId: PROJECT_ID });
}
const db = getFirestore();
db.settings({ databaseId: DATABASE_ID });

async function main() {
  console.log(`\n📋 Session Attendance Breakdown`);
  console.log(`   Project: ${PROJECT_ID}  DB: ${DATABASE_ID}  Event: ${EVENT_ID}\n`);

  // 1. Get all sessions
  const sessionsSnap = await db.collection(`events/${EVENT_ID}/sessions`).get();
  const sessions = sessionsSnap.docs
    .map(d => ({ id: d.id, ...d.data() }))
    .filter(s => !s.isMain)
    .sort((a, b) => (a.order ?? 999) - (b.order ?? 999));

  console.log(`Found ${sessions.length} breakout session(s)\n`);

  // 2. Build pre-reg map: sessionId → Set of registrantIds
  const preRegSnap = await db.collection(`events/${EVENT_ID}/sessionRegistrations`).get();
  const preRegMap = {}; // sessionId → Set<registrantId>
  for (const doc of preRegSnap.docs) {
    const sessionIds = doc.data().sessionIds ?? [];
    for (const sid of sessionIds) {
      if (!preRegMap[sid]) preRegMap[sid] = new Set();
      preRegMap[sid].add(doc.id);
    }
  }

  // 3. For each session, get attendance and cross-reference
  const rows = [];
  for (const session of sessions) {
    const attSnap = await db
      .collection(`events/${EVENT_ID}/sessions/${session.id}/attendance`)
      .get();

    const checkedInIds = new Set(attSnap.docs.map(d => d.id));
    const preRegSet    = preRegMap[session.id] ?? new Set();

    const preRegCheckedIn    = [...checkedInIds].filter(id => preRegSet.has(id)).length;
    const walkInCheckedIn    = [...checkedInIds].filter(id => !preRegSet.has(id)).length;
    const preRegNotCheckedIn = [...preRegSet].filter(id => !checkedInIds.has(id)).length;

    const capacity    = session.capacity ?? 0;
    const totalCheckedIn = checkedInIds.size;
    const openSeats   = capacity > 0 ? Math.max(0, capacity - totalCheckedIn) : '∞';

    rows.push({
      name: session.name ?? session.title ?? session.id,
      capacity,
      preReg: preRegSet.size,
      preRegCheckedIn,
      preRegNotCheckedIn,
      walkInCheckedIn,
      totalCheckedIn,
      openSeats,
    });
  }

  // 4. Print table
  const col = (s, w) => String(s).padStart(w);
  const colL = (s, w) => String(s).padEnd(w);

  const header = [
    colL('Session', 32),
    col('Cap', 5),
    col('PreReg', 7),
    col('PreReg✓', 8),
    col('PreReg✗', 8),
    col('WalkIn✓', 8),
    col('Total✓', 7),
    col('Open', 6),
  ].join('  ');

  console.log(header);
  console.log('-'.repeat(header.length));

  for (const r of rows) {
    console.log([
      colL(r.name, 32),
      col(r.capacity || '∞', 5),
      col(r.preReg, 7),
      col(r.preRegCheckedIn, 8),
      col(r.preRegNotCheckedIn, 8),
      col(r.walkInCheckedIn, 8),
      col(r.totalCheckedIn, 7),
      col(r.openSeats, 6),
    ].join('  '));
  }

  const totals = rows.reduce((acc, r) => ({
    preReg: acc.preReg + r.preReg,
    preRegCheckedIn: acc.preRegCheckedIn + r.preRegCheckedIn,
    preRegNotCheckedIn: acc.preRegNotCheckedIn + r.preRegNotCheckedIn,
    walkInCheckedIn: acc.walkInCheckedIn + r.walkInCheckedIn,
    totalCheckedIn: acc.totalCheckedIn + r.totalCheckedIn,
  }), { preReg: 0, preRegCheckedIn: 0, preRegNotCheckedIn: 0, walkInCheckedIn: 0, totalCheckedIn: 0 });

  console.log('-'.repeat(header.length));
  console.log([
    colL('TOTAL', 32),
    col('', 5),
    col(totals.preReg, 7),
    col(totals.preRegCheckedIn, 8),
    col(totals.preRegNotCheckedIn, 8),
    col(totals.walkInCheckedIn, 8),
    col(totals.totalCheckedIn, 7),
    col('', 6),
  ].join('  '));

  if (!OUTPUT_MD) {
    console.log('\nLegend:');
    console.log('  PreReg✓  = pre-registered AND checked in');
    console.log('  PreReg✗  = pre-registered but NOT yet checked in');
    console.log('  WalkIn✓  = checked in WITHOUT pre-registering');
    console.log('  Open     = capacity − total checked in\n');
  } else {
    // Markdown table for docs/data2/summary_count.md
    console.log('\n<!-- computed from attendance -->\n');
    console.log('| Session | Pre-reg | Total check-in | Pre-reg ✓ | Walk-in ✓ |');
    console.log('|---------|--------:|---------------:|----------:|----------:|');
    for (const r of rows) {
      console.log(`| ${r.name} | ${r.preReg} | ${r.totalCheckedIn} | ${r.preRegCheckedIn} | ${r.walkInCheckedIn} |`);
    }
    console.log(`| **Total** | **${totals.preReg}** | **${totals.totalCheckedIn}** | **${totals.preRegCheckedIn}** | **${totals.walkInCheckedIn}** |`);
    console.log('');
  }
}

main().catch(err => {
  console.error('Error:', err.message ?? err);
  process.exit(1);
});
