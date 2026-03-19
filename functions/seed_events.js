const admin = require('firebase-admin');
if (admin.apps.length === 0) admin.initializeApp({ projectId: 'aisaiah-event-hub' });
const db = admin.firestore();

const events = [
  {
    id: 'nlc-2026',
    data: {
      name: 'National Leaders Conference 2026',
      slug: 'nlc-2026',
      startDate: admin.firestore.Timestamp.fromDate(new Date('2026-02-20T00:00:00Z')),
      endDate: admin.firestore.Timestamp.fromDate(new Date('2026-02-22T00:00:00Z')),
      startAt: admin.firestore.Timestamp.fromDate(new Date('2026-02-20T00:00:00Z')),
      endAt: admin.firestore.Timestamp.fromDate(new Date('2026-02-22T23:59:59Z')),
      locationName: 'Hyatt Regency Valencia | Grand Ballroom',
      address: '24500 Town Center Dr., Valencia, CA 91355',
      isActive: true,
      allowRsvp: false,
      allowCheckin: true,
      metadata: { selfCheckinEnabled: true, sessionsEnabled: true },
      organizationName: 'Couples for Christ',
      tag: 'National Conference',
    },
  },
  {
    id: 'refresh-seminar-jax-2026',
    data: {
      name: '"REFRESH" Seminar in Jacksonville',
      slug: 'refresh-seminar-jax-2026',
      startDate: admin.firestore.Timestamp.fromDate(new Date('2026-04-11T00:00:00Z')),
      endDate: admin.firestore.Timestamp.fromDate(new Date('2026-04-11T00:00:00Z')),
      startAt: admin.firestore.Timestamp.fromDate(new Date('2026-04-11T00:00:00Z')),
      endAt: admin.firestore.Timestamp.fromDate(new Date('2026-04-11T23:59:59Z')),
      locationName: 'Jacksonville, Florida',
      address: 'Jacksonville, FL',
      isActive: true,
      allowRsvp: true,
      allowCheckin: false,
      metadata: {},
      organizationName: 'CFC SE-B Region (FL, GA, AL, MS)',
      shortDescription: 'A leadership refresh seminar covering New Evangelization, Basic Pastoring, Communication, Building Our Homes for God, and more. Speakers: Joe Duran & Monina Duran, M.D.',
      tag: 'Regional Seminar',
    },
  },
  {
    id: 'twr-southeast-b-2026',
    data: {
      name: 'TWR Southeast – B: Theme Weekend Retreat',
      slug: 'twr-southeast-b-2026',
      startDate: admin.firestore.Timestamp.fromDate(new Date('2026-06-06T00:00:00Z')),
      endDate: admin.firestore.Timestamp.fromDate(new Date('2026-06-07T00:00:00Z')),
      startAt: admin.firestore.Timestamp.fromDate(new Date('2026-06-06T00:00:00Z')),
      endAt: admin.firestore.Timestamp.fromDate(new Date('2026-06-07T23:59:59Z')),
      locationName: 'Florida',
      address: 'Florida',
      isActive: true,
      allowRsvp: true,
      allowCheckin: false,
      metadata: {},
      organizationName: 'Couples for Christ',
      shortDescription: 'In the One, we are one. Join us for a powerful weekend of faith, unity, and spiritual renewal.',
      tag: 'Regional Event',
    },
  },
];

async function seed() {
  console.log('=== Seeding events to aisaiah-event-hub Firestore ===\n');

  for (const event of events) {
    const ref = db.collection('events').doc(event.id);
    const existing = await ref.get();

    if (existing.exists) {
      // Update with merge so we don't overwrite existing sub-collections or extra fields
      await ref.set(event.data, { merge: true });
      console.log(`✅ Updated: ${event.id} (merged with existing data)`);
    } else {
      await ref.set(event.data);
      console.log(`✅ Created: ${event.id}`);
    }
  }

  // Verify NLC date fix
  const nlc = await db.collection('events').doc('nlc-2026').get();
  const nlcData = nlc.data();
  const startDate = nlcData.startDate.toDate();
  console.log(`\n--- NLC verification ---`);
  console.log(`  startDate: ${startDate.toISOString()} (should be 2026-02-20)`);
  console.log(`  endDate: ${nlcData.endDate.toDate().toISOString()} (should be 2026-02-22)`);

  console.log('\nDone. All events seeded.');
  process.exit(0);
}

seed().catch(e => { console.error(e); process.exit(1); });
