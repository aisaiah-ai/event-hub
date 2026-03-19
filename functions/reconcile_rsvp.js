/**
 * Reconcile RSVPs → Registrations for march-assembly
 *
 * Sources:
 *   1. (default) DB → events/march-assembly/rsvps (20)
 *   2. event-hub-prod DB → events/march-cluster-2026/rsvps (40)
 *
 * Steps:
 *   1. Load all RSVPs from both sources
 *   2. Split multi-person entries into individuals
 *   3. Deduplicate across sources
 *   4. Match to members DB (aisaiah-check-in-dev)
 *   5. Matched → registrant doc with IM-xxxx ID
 *   6. Unmatched → registrant doc with ZZ-9999-XXXXXX ID
 *   7. Write registrants to (default) DB events/march-assembly/registrants
 *   8. Archive original RSVPs in both databases
 *
 * Usage:
 *   node reconcile_rsvp.js --dry-run     (preview only)
 *   node reconcile_rsvp.js --execute      (write to Firestore)
 */

const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');

if (!admin.apps.length) admin.initializeApp({ projectId: 'aisaiah-event-hub' });
const db = admin.firestore(); // default — registrants live here
const prodDb = getFirestore(admin.app(), 'event-hub-prod');
const checkInDb = getFirestore(admin.app(), 'aisaiah-check-in-dev');

const TARGET_EVENT = 'march-assembly';
const DRY_RUN = !process.argv.includes('--execute');

// ── Helpers ──────────────────────────────────────────────────────────────────

function normalize(name) {
  return (name || '').toUpperCase().replace(/[^A-Z\s]/g, '').replace(/\s+/g, ' ').trim();
}

// Common nickname → formal name mappings
const NICKNAMES = {
  DAVE: ['DAVID'], DAVID: ['DAVE'],
  CHELLE: ['ROCHELLE'], ROCHELLE: ['CHELLE'],
  JOSIE: ['JOSEPHINE'], JOSEPHINE: ['JOSIE'],
  TESS: ['TERESA', 'MA TERESA', 'TERESITA'],
  FLORY: ['FLORINDA', 'FLORA'], FLORINDA: ['FLORY'],
  PHIL: ['PHILIP', 'FELICIANO'], PHILIP: ['PHIL'],
  RICH: ['RICHARD'], RICHARD: ['RICH'],
  CRIS: ['CRISANTO', 'CRISTINA'], CRISANTO: ['CRIS'],
  GREG: ['GREGORY'], GREGORY: ['GREG'],
  NAT: ['NATHANIEL', 'NATALIE'], NATHANIEL: ['NAT'],
  LYNN: ['LYN'], LYN: ['LYNN'],
  CECILE: ['CECILIA', 'CECILLE'], CECILIA: ['CECILE', 'CECILLE'], CECILLE: ['CECILIA', 'CECILE'],
  JUN: ['JUNEXIII', 'JUNIOR'],
  BEBOT: ['ROBERTO', 'ROBERT'],
  BOBBY: ['ROBERTO', 'ROBERT'],
  ERNIE: ['ERNESTO', 'ERNESITO'],
  JOEL: ['JOSE'], JOSE: ['JOEL'],
  ANDY: ['ANDREW', 'FERDINAND', 'ANDRES'],
  FRANCISCO: ['FRANCIS'], FRANCIS: ['FRANCISCO'],
  MELUJEAN: ['MELU-JEAN', 'MELUJEAN'],
  NOREEN: ['NOREEN'],
};

/** Split multi-person RSVP names into individual names */
function splitRsvpNames(rsvpName) {
  const name = (rsvpName || '').trim();

  // First split by semicolons
  const semiParts = name.includes(';')
    ? name.split(';').map(n => n.trim()).filter(Boolean)
    : [name];

  const result = [];
  for (const part of semiParts) {
    // Split "FirstA and/& FirstB LastName" or "Donald &Lina Mariano"
    const andMatch = part.match(/^(.+?)\s*(?:\band\b|&)\s*(.+?)$/i);
    if (andMatch) {
      const left = andMatch[1].trim();
      const right = andMatch[2].trim();
      const rightParts = right.split(/\s+/);
      const leftParts = left.split(/\s+/);

      if (rightParts.length >= 2) {
        const sharedLast = rightParts[rightParts.length - 1];
        const rightFirst = rightParts.slice(0, -1).join(' ');
        if (leftParts.length === 1) {
          result.push(`${left} ${sharedLast}`);
        } else {
          result.push(left);
        }
        result.push(`${rightFirst} ${sharedLast}`);
      } else {
        if (leftParts.length >= 2) {
          const sharedLast = leftParts[leftParts.length - 1];
          const leftFirst = leftParts.slice(0, -1).join(' ');
          result.push(`${leftFirst} ${sharedLast}`);
          result.push(`${right} ${sharedLast}`);
        } else {
          result.push(left);
          result.push(right);
        }
      }
    } else {
      // Handle "Claro, Linda Dela Cruz" → "Claro Dela Cruz", "Linda Dela Cruz"
      const commaMatch = part.match(/^(\w+),\s*(\w+)\s+(.+)$/);
      if (commaMatch) {
        result.push(`${commaMatch[1]} ${commaMatch[3]}`);
        result.push(`${commaMatch[2]} ${commaMatch[3]}`);
      } else {
        // Handle "Lady Rose/Louie Buenaflor" → "Lady Rose Buenaflor", "Louie Buenaflor"
        const slashMatch = part.match(/^(.+?)\/(.+?)$/);
        if (slashMatch) {
          const left = slashMatch[1].trim();
          const right = slashMatch[2].trim();
          const rightParts = right.split(/\s+/);
          if (rightParts.length >= 2) {
            // Right has a last name — share it with left
            const sharedLast = rightParts[rightParts.length - 1];
            result.push(`${left} ${sharedLast}`);
            result.push(right);
          } else {
            const leftParts = left.split(/\s+/);
            if (leftParts.length >= 2) {
              const sharedLast = leftParts[leftParts.length - 1];
              result.push(left);
              result.push(`${right} ${sharedLast}`);
            } else {
              result.push(left);
              result.push(right);
            }
          }
        } else {
          // Handle "Lynn Canent- Togado" → clean up hyphen spacing
          result.push(part.replace(/\s*-\s*/g, '-'));
        }
      }
    }
  }

  return result.map(n => n.trim()).filter(n => n.length > 1);
}

/** ZZ-9999 ID counter */
let zzMax = 0;
let zzMaxLoaded = false;

async function getNextZzId(zzIdsUsed) {
  if (!zzMaxLoaded) {
    const snap = await db.collection('events').doc(TARGET_EVENT).collection('registrants').get();
    for (const doc of snap.docs) {
      const m = doc.id.match(/^ZZ-9999-(\d+)$/);
      if (m) {
        const num = parseInt(m[1], 10);
        if (num > zzMax) zzMax = num;
      }
    }
    zzMaxLoaded = true;
  }
  for (const id of zzIdsUsed) {
    const m = id.match(/^ZZ-9999-(\d+)$/);
    if (m) {
      const num = parseInt(m[1], 10);
      if (num > zzMax) zzMax = num;
    }
  }
  zzMax++;
  return `ZZ-9999-${String(zzMax).padStart(6, '0')}`;
}

// ── Main ─────────────────────────────────────────────────────────────────────

async function reconcile() {
  console.log(`\n${'='.repeat(70)}`);
  console.log(`  RSVP → Registration Reconciliation (All Sources)`);
  console.log(`  Target: (default) / events/${TARGET_EVENT}/registrants`);
  console.log(`  Mode:   ${DRY_RUN ? 'DRY RUN (no writes)' : 'EXECUTE (writing to Firestore)'}`);
  console.log(`${'='.repeat(70)}\n`);

  // ── 1. Load members DB ─────────────────────────────────────────────────────
  const membersSnap = await checkInDb.collection('members').get();
  const membersByNormName = new Map();
  const membersByLastName = new Map();
  const membersById = new Map();

  for (const doc of membersSnap.docs) {
    const d = doc.data();
    const normName = normalize(d.memberName);
    membersByNormName.set(normName, { id: doc.id, ...d });
    membersById.set(doc.id, { id: doc.id, name: normName, ...d });

    const parts = normName.split(' ');
    if (parts.length > 1) {
      const lastName = parts[parts.length - 1];
      if (!membersByLastName.has(lastName)) membersByLastName.set(lastName, []);
      membersByLastName.get(lastName).push({ id: doc.id, name: normName, ...d });
    }
  }
  console.log(`Members DB: ${membersSnap.size} members loaded\n`);

  // ── 2. Load existing registrants ───────────────────────────────────────────
  const existingRegs = await db.collection('events').doc(TARGET_EVENT).collection('registrants').get();
  const existingRegIds = new Set(existingRegs.docs.map(d => d.id));
  const existingRegNames = new Set();
  for (const doc of existingRegs.docs) {
    const p = doc.data().profile || {};
    const name = normalize(p.name || `${p.firstName || ''} ${p.lastName || ''}`);
    if (name) existingRegNames.add(name);
  }
  console.log(`Existing registrants: ${existingRegs.size}\n`);

  // ── 3. Load RSVPs from both sources ────────────────────────────────────────
  const defaultRsvps = await db.collection('events').doc(TARGET_EVENT).collection('rsvps').get();
  const prodRsvps = await prodDb.collection('events').doc('march-cluster-2026').collection('rsvps').get();

  console.log(`RSVPs from (default)/march-assembly: ${defaultRsvps.size}`);
  console.log(`RSVPs from event-hub-prod/march-cluster-2026: ${prodRsvps.size}`);
  console.log('');

  // Combine into unified list with source tracking
  const allRsvps = [];
  for (const doc of defaultRsvps.docs) {
    allRsvps.push({ doc, data: doc.data(), source: 'default', sourceEvent: TARGET_EVENT });
  }
  for (const doc of prodRsvps.docs) {
    allRsvps.push({ doc, data: doc.data(), source: 'prod', sourceEvent: 'march-cluster-2026' });
  }

  // ── 4. Process all RSVPs ───────────────────────────────────────────────────
  const actions = [];
  const zzIdsUsed = [];
  const seenNormNames = new Set(); // dedup across sources
  let skippedDuplicates = 0;
  let skippedTest = 0;

  for (const rsvp of allRsvps) {
    const d = rsvp.data;
    const rsvpName = (d.name || '').trim();

    // Skip test entries
    if (rsvpName.toLowerCase() === 'test') {
      console.log(`── [${rsvp.source}] "${rsvpName}" → SKIPPED (test entry)`);
      skippedTest++;
      continue;
    }

    const names = splitRsvpNames(rsvpName);
    const sourceTag = rsvp.source === 'prod' ? 'PROD' : 'DEFAULT';

    console.log(`── [${sourceTag}] "${rsvpName}" (${d.area}, HH: ${d.household}, count: ${d.attendeesCount}) ──`);
    if (names.length > 1) {
      console.log(`   Split → ${names.join(' | ')}`);
    }

    for (const individualName of names) {
      const normName = normalize(individualName);
      if (!normName || normName.length < 2) {
        console.log(`   ⏭  Skipping empty/short: "${individualName}"`);
        continue;
      }

      // Dedup: skip if already seen in this run or already registered
      if (seenNormNames.has(normName)) {
        console.log(`   ⏭  Duplicate (already processed): "${individualName}"`);
        skippedDuplicates++;
        continue;
      }
      if (existingRegNames.has(normName)) {
        console.log(`   ⏭  Already registered: "${individualName}"`);
        skippedDuplicates++;
        seenNormNames.add(normName);
        continue;
      }
      // Single first-name dedup: "SALOME" matches "SALOME LLAGAS CANTUBA" already processed
      if (normName.split(' ').length === 1) {
        const singleName = normName;
        let foundDup = false;
        for (const seen of seenNormNames) {
          if (seen.startsWith(singleName + ' ') || seen.split(' ').includes(singleName)) {
            console.log(`   ⏭  Duplicate (single name "${individualName}" matches "${seen}")`);
            skippedDuplicates++;
            foundDup = true;
            break;
          }
        }
        if (!foundDup) {
          for (const seen of existingRegNames) {
            if (seen.startsWith(singleName + ' ') || seen.split(' ').includes(singleName)) {
              console.log(`   ⏭  Already registered (single name "${individualName}" matches "${seen}")`);
              skippedDuplicates++;
              foundDup = true;
              break;
            }
          }
        }
        if (foundDup) {
          seenNormNames.add(normName);
          continue;
        }
      }

      // ── Match to members DB ────────────────────────────────────────────
      let memberId = null;
      let matchType = 'none';

      // Use cfcId from RSVP if available (single-person only)
      if (d.cfcId && names.length === 1 && membersById.has(d.cfcId)) {
        memberId = d.cfcId;
        matchType = 'cfcId';
      }

      // Exact name match
      if (!memberId) {
        const exact = membersByNormName.get(normName);
        if (exact) {
          memberId = exact.id;
          matchType = 'exact';
        }
      }

      // Fuzzy: last name + first name prefix + nickname matching
      if (!memberId) {
        // Normalize hyphenated names: "LYNN CANENT-TOGADO" → try "LYNN CANENT TOGADO" and "LYN CANENT TOGADO"
        const normVariants = [normName];
        if (normName.includes('-')) {
          normVariants.push(normName.replace(/-/g, ' '));
        }

        const parts = normName.replace(/-/g, ' ').split(' ');
        const firstName = parts[0];
        const lastName = parts[parts.length - 1];

        // Get nickname variants for the first name
        const firstNameVariants = [firstName, ...(NICKNAMES[firstName] || [])];

        const candidates = membersByLastName.get(lastName) || [];

        let bestScore = 0;
        let bestCandidate = null;
        for (const c of candidates) {
          const cParts = c.name.split(' ');
          const cFirstName = cParts[0];
          // Also get nickname variants for the candidate first name
          const cFirstVariants = [cFirstName, ...(NICKNAMES[cFirstName] || [])];

          // Check all first name variants against all candidate variants
          for (const fn of firstNameVariants) {
            for (const cfn of cFirstVariants) {
              if (cfn === fn) {
                const score = 100;
                if (score > bestScore) { bestScore = score; bestCandidate = c; }
              }
            }
          }

          // Prefix matching
          if (cFirstName.startsWith(firstName) || firstName.startsWith(cFirstName)) {
            const overlap = Math.min(firstName.length, cFirstName.length);
            const score = overlap * 15;
            if (score > bestScore) { bestScore = score; bestCandidate = c; }
          }

          // Also try nickname prefix matching
          for (const fn of firstNameVariants) {
            if (cFirstName.startsWith(fn) || fn.startsWith(cFirstName)) {
              const overlap = Math.min(fn.length, cFirstName.length);
              const score = overlap * 12;
              if (score > bestScore) { bestScore = score; bestCandidate = c; }
            }
          }

          // Check middle/alternate name parts
          for (const cp of cParts) {
            if (cp !== lastName) {
              for (const fn of firstNameVariants) {
                if ((cp.startsWith(fn) || fn.startsWith(cp)) && cp.length >= 3) {
                  const overlap = Math.min(fn.length, cp.length);
                  const score = overlap * 10;
                  if (score > bestScore) { bestScore = score; bestCandidate = c; }
                }
              }
            }
          }
        }

        // Also try hyphenated name as exact match (e.g., "LYN CANENT TOGADO")
        if (!bestCandidate || bestScore < 100) {
          for (const variant of normVariants) {
            const exact = membersByNormName.get(variant);
            if (exact) {
              bestScore = 100;
              bestCandidate = { id: exact.id, name: variant };
              break;
            }
          }
        }

        if (bestCandidate && bestScore >= 30) {
          memberId = bestCandidate.id;
          matchType = `fuzzy (${bestScore}, "${bestCandidate.name}")`;
        }
      }

      // Check if matched member is already registered
      if (memberId && (existingRegIds.has(memberId) || actions.some(a => a.registrantId === memberId))) {
        console.log(`   ⏭  Member ${memberId} already registered: "${individualName}"`);
        skippedDuplicates++;
        seenNormNames.add(normName);
        continue;
      }

      // Assign ID
      let registrantId;
      if (memberId) {
        registrantId = memberId;
        console.log(`   ✓  MATCH (${matchType}): "${individualName}" → ${memberId}`);
      } else {
        registrantId = await getNextZzId(zzIdsUsed);
        zzIdsUsed.push(registrantId);
        console.log(`   ★  ZZ ID: "${individualName}" → ${registrantId}`);
      }

      const nameParts = individualName.trim().split(/\s+/);
      const firstName = nameParts[0] || '';
      const lastName = nameParts.length > 1 ? nameParts.slice(1).join(' ') : '';

      actions.push({
        registrantId,
        name: individualName.trim(),
        firstName,
        lastName,
        memberId: memberId || null,
        matchType,
        rsvpDocId: rsvp.doc.id,
        rsvpSource: rsvp.source,
        rsvpData: {
          area: d.area || '',
          household: d.household || '',
          attendeesCount: d.attendeesCount || 1,
          attendingRally: d.attendingRally || false,
          attendingDinner: d.attendingDinner || false,
          celebrationType: d.celebrationType || null,
          birthday: d.birthday || d.celebrationType || null,
          kids: d.kids || [],
          cfcId: d.cfcId || null,
          originalRsvpName: d.name,
        },
      });

      existingRegIds.add(registrantId);
      seenNormNames.add(normName);
    }
  }

  // ── 5. Summary ─────────────────────────────────────────────────────────────
  const matched = actions.filter(a => a.memberId);
  const unmatched = actions.filter(a => !a.memberId);

  console.log(`\n${'='.repeat(70)}`);
  console.log(`  RECONCILIATION PLAN`);
  console.log(`${'='.repeat(70)}\n`);
  console.log(`New registrants to create:     ${actions.length}`);
  console.log(`  ✓ Matched (IM-xxxx):         ${matched.length}`);
  console.log(`  ★ Unmatched (ZZ-9999-xxxx):  ${unmatched.length}`);
  console.log(`Skipped (duplicate/existing):   ${skippedDuplicates}`);
  console.log(`Skipped (test entries):         ${skippedTest}`);
  console.log(`RSVPs to archive (default):     ${defaultRsvps.size}`);
  console.log(`RSVPs to archive (prod):        ${prodRsvps.size}`);
  console.log(`Post-reconciliation total:      ${existingRegs.size} + ${actions.length} = ${existingRegs.size + actions.length} registrants\n`);

  console.log('── Matched (IM-xxxx) ──\n');
  for (const a of matched) {
    console.log(`  ✓ ${a.registrantId} | ${a.name} | ${a.rsvpData.area} | HH: ${a.rsvpData.household} | [${a.rsvpSource}]`);
  }

  console.log('\n── Unmatched (ZZ-9999) ──\n');
  for (const a of unmatched) {
    console.log(`  ★ ${a.registrantId} | ${a.name} | ${a.rsvpData.area} | HH: ${a.rsvpData.household} | [${a.rsvpSource}]`);
  }

  if (DRY_RUN) {
    console.log(`\n${'─'.repeat(70)}`);
    console.log(`  DRY RUN complete. No changes made.`);
    console.log(`  Run with --execute to apply.`);
    console.log(`${'─'.repeat(70)}\n`);
    process.exit(0);
    return;
  }

  // ── 6. EXECUTE ─────────────────────────────────────────────────────────────
  console.log(`\n⚡ Executing...\n`);

  const now = admin.firestore.FieldValue.serverTimestamp();

  // ── Default DB writes (registrants + archive default RSVPs) ────────────
  const defaultWrites = [];

  // Create registrant docs
  for (const a of actions) {
    defaultWrites.push({
      type: 'set',
      ref: db.collection('events').doc(TARGET_EVENT).collection('registrants').doc(a.registrantId),
      data: {
        registrantId: a.registrantId,
        registrationStatus: 'registered',
        status: 'registered',
        createdAt: now,
        updatedAt: now,
        source: 'rsvp-import',
        profile: {
          name: a.name,
          firstName: a.firstName,
          lastName: a.lastName,
          ...(a.memberId ? { memberId: a.memberId } : {}),
        },
        rsvpImport: {
          rsvpDocId: a.rsvpDocId,
          rsvpSource: a.rsvpSource,
          originalName: a.rsvpData.originalRsvpName,
          area: a.rsvpData.area,
          household: a.rsvpData.household,
          attendeesCount: a.rsvpData.attendeesCount,
          attendingRally: a.rsvpData.attendingRally,
          attendingDinner: a.rsvpData.attendingDinner,
          ...(a.rsvpData.celebrationType ? { celebrationType: a.rsvpData.celebrationType } : {}),
          ...(a.rsvpData.kids.length > 0 ? { kids: a.rsvpData.kids } : {}),
          ...(a.rsvpData.cfcId ? { cfcId: a.rsvpData.cfcId } : {}),
          ...(a.rsvpData.birthday ? { birthday: a.rsvpData.birthday } : {}),
          matchType: a.matchType,
          reconciledAt: now,
        },
      },
    });
  }

  // Archive default RSVPs
  for (const doc of defaultRsvps.docs) {
    defaultWrites.push({
      type: 'set',
      ref: db.collection('events').doc(TARGET_EVENT).collection('rsvps-archived').doc(doc.id),
      data: { ...doc.data(), archivedAt: now, archivedReason: 'reconciled', archivedFrom: 'default' },
    });
    defaultWrites.push({ type: 'delete', ref: doc.ref });
  }

  // ── Prod DB writes (archive prod RSVPs) ────────────────────────────────
  const prodWrites = [];
  for (const doc of prodRsvps.docs) {
    prodWrites.push({
      type: 'set',
      ref: prodDb.collection('events').doc('march-cluster-2026').collection('rsvps-archived').doc(doc.id),
      data: { ...doc.data(), archivedAt: now, archivedReason: 'reconciled', archivedFrom: 'prod' },
    });
    prodWrites.push({ type: 'delete', ref: doc.ref });
  }

  // Execute default DB in batches of 450
  const BATCH_SIZE = 450;
  for (let i = 0; i < defaultWrites.length; i += BATCH_SIZE) {
    const chunk = defaultWrites.slice(i, i + BATCH_SIZE);
    const batch = db.batch();
    for (const w of chunk) {
      if (w.type === 'set') batch.set(w.ref, w.data);
      else if (w.type === 'delete') batch.delete(w.ref);
    }
    await batch.commit();
    console.log(`  Default DB batch: ${chunk.length} ops`);
  }

  // Execute prod DB in batches of 450
  for (let i = 0; i < prodWrites.length; i += BATCH_SIZE) {
    const chunk = prodWrites.slice(i, i + BATCH_SIZE);
    const batch = prodDb.batch();
    for (const w of chunk) {
      if (w.type === 'set') batch.set(w.ref, w.data);
      else if (w.type === 'delete') batch.delete(w.ref);
    }
    await batch.commit();
    console.log(`  Prod DB batch: ${chunk.length} ops`);
  }

  // Verify
  const finalRegs = await db.collection('events').doc(TARGET_EVENT).collection('registrants').get();
  const finalDefaultRsvps = await db.collection('events').doc(TARGET_EVENT).collection('rsvps').get();
  const finalProdRsvps = await prodDb.collection('events').doc('march-cluster-2026').collection('rsvps').get();
  const archivedDefault = await db.collection('events').doc(TARGET_EVENT).collection('rsvps-archived').get();
  const archivedProd = await prodDb.collection('events').doc('march-cluster-2026').collection('rsvps-archived').get();

  console.log(`\n=== Post-reconciliation ===`);
  console.log(`Registrants:              ${finalRegs.size}`);
  console.log(`RSVPs remaining (default): ${finalDefaultRsvps.size}`);
  console.log(`RSVPs remaining (prod):    ${finalProdRsvps.size}`);
  console.log(`RSVPs archived (default):  ${archivedDefault.size}`);
  console.log(`RSVPs archived (prod):     ${archivedProd.size}`);

  process.exit(0);
}

reconcile().catch(e => { console.error(e); process.exit(1); });
