/**
 * Simulate manual check-ins over real time for dashboard demo.
 * Writes main-checkin and breakout session check-ins so both "Main Check-In Total"
 * and "Session Check-Ins" update live.
 *
 * DEV ONLY — aborts if --dev not passed or database is prod.
 *
 * Run (open dashboard in browser first, then run this in terminal):
 *   cd functions && node scripts/seed-gradual-checkins-dev.js "--database=(default)" --dev
 *
 * Options (all optional):
 *   --duration=120   Demo duration in seconds (default 120 = 2 min)
 *   --max-pct=0.9    Max fraction of registrants to check in (default 0.9 = 90%)
 *   --power=2        Ramp curve: higher = more gradual start (default 2)
 *   --session-pct=0.5  Fraction of checked-in registrants who also get one breakout session (default 0.5)
 *
 * Requires: gcloud auth application-default login
 */

const admin = require('firebase-admin');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || 'aisaiah-event-hub';

const hasDev = process.argv.includes('--dev');
const dbArg = process.argv.find((a) => a.startsWith('--database='));
const databaseId = dbArg ? dbArg.replace(/^--database=/, '').trim() : '(default)';

const parseNum = (argPrefix, defaultVal) => {
  const a = process.argv.find((x) => x.startsWith(argPrefix + '='));
  if (!a) return defaultVal;
  const v = parseFloat(a.replace(argPrefix + '=', ''));
  return Number.isFinite(v) ? v : defaultVal;
};

if (!hasDev) {
  console.error('ABORT: This script must not run without --dev. Add --dev to confirm dev environment.');
  process.exit(1);
}
if (databaseId === 'event-hub-prod' || databaseId.toLowerCase().includes('prod')) {
  console.error('ABORT: This script must not run in prod. Use --database=(default) or --database=event-hub-dev');
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

const db = databaseId === '(default)' ? getFirestore() : getFirestore(databaseId);

const EVENT_ID = 'nlc-2026';
const MAIN_CHECKIN = 'main-checkin';
const BREAKOUT_SESSION_IDS = [
  'gender-ideology-dialogue',
  'contraception-ivf-abortion-dialogue',
  'immigration-dialogue',
];

const DURATION_SEC = Math.max(10, parseNum('--duration', 120));
const MAX_PCT = parseNum('--max-pct', 0.9);
const POWER = Math.max(0.5, parseNum('--power', 2));
const SESSION_PCT = parseNum('--session-pct', 0.5);

function shuffle(arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Gradually increasing: more check-ins later in the demo window.
 * time fraction = random()^(1/power) => skewed toward 1.
 */
function randomTimeFraction() {
  const u = Math.random();
  return Math.pow(u, 1 / POWER);
}

async function run() {
  console.log('Live demo: gradual check-ins (DEV ONLY) database=' + databaseId + ' event=' + EVENT_ID);
  console.log('  Main check-in + breakout session check-ins so both metrics update.');
  console.log('  duration:', DURATION_SEC, 's  max registrants:', Math.round(MAX_PCT * 100) + '%  session-pct:', Math.round(SESSION_PCT * 100) + '%');

  const registrantsSnap = await db.collection(`events/${EVENT_ID}/registrants`).get();
  const registrantIds = registrantsSnap.docs.map((d) => d.id);
  if (registrantIds.length === 0) {
    console.log('No registrants found. Run registrant seed first.');
    return;
  }

  const sessionsSnap = await db.collection(`events/${EVENT_ID}/sessions`).get();
  const existingSessionIds = sessionsSnap.docs.map((d) => d.id);
  const breakoutSessions = BREAKOUT_SESSION_IDS.filter((id) => existingSessionIds.includes(id));
  if (breakoutSessions.length === 0) {
    console.log('No breakout sessions found (looked for', BREAKOUT_SESSION_IDS.join(', ') + '). Only main-checkin will be used.');
  }

  const checkInCount = Math.max(1, Math.floor(registrantIds.length * MAX_PCT));
  const shuffled = shuffle(registrantIds);
  const toCheckIn = shuffled.slice(0, checkInCount);

  // Build events: each registrant gets main-checkin at time T; SESSION_PCT also get one breakout at T+0.5s
  const offsets = toCheckIn.map(() => randomTimeFraction() * DURATION_SEC);
  offsets.sort((a, b) => a - b);
  const events = [];
  for (let i = 0; i < toCheckIn.length; i++) {
    const registrantId = toCheckIn[i];
    const t = offsets[i];
    events.push({ registrantId, sessionId: MAIN_CHECKIN, time: t });
    if (breakoutSessions.length > 0 && Math.random() < SESSION_PCT) {
      const sessionId = breakoutSessions[Math.floor(Math.random() * breakoutSessions.length)];
      events.push({ registrantId, sessionId, time: t + 0.5 });
    }
  }
  events.sort((a, b) => a.time - b.time);

  const startMs = Date.now();
  let written = 0;

  for (const ev of events) {
    const elapsedSec = (Date.now() - startMs) / 1000;
    const waitSec = Math.max(0, ev.time - elapsedSec);
    if (waitSec > 0) {
      await sleep(waitSec * 1000);
    }

    const ref = db.doc(`events/${EVENT_ID}/sessions/${ev.sessionId}/attendance/${ev.registrantId}`);
    await ref.set({
      checkedInAt: FieldValue.serverTimestamp(),
      checkedInBy: 'demo-script',
    }, { merge: true });
    written++;
    process.stdout.write(`\r  Check-ins: ${written} (main + session)`);
  }

  console.log('\nDone. Main Check-In Total and Session Check-Ins should have updated in real time.');
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
