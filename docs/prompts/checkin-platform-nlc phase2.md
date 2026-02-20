Below are Cursor-ready, repo-friendly prompts for the next phase, plus a production scaling plan for ~3,000 attendees. I’m assuming Firebase/Firestore, Flutter web, and your events-dev / prod hosting targets.

⸻

1) 🔐 Staff + Admin check-in + Admin login (write access)

You are working in the existing AIsaiah Flutter + Firebase repo.

We already have a reusable self-checkin module at:
/events/:slug/checkin

Now implement a secure Staff/Admin layer:

Goals
	1.	Add staff/admin login (web)
	2.	Enforce role-based access (RBAC) for write operations
	3.	Add “Staff Mode” features:
	•	Override duplicate check-in
	•	Edit registrant fields (optional)
	•	Session management (toggle active sessions)
	4.	Add “Admin Mode” features:
	•	Bulk tools (export, reset session checkins)
	•	Manage staff accounts/roles
	•	Audit log visibility

Constraints
	•	Do NOT hardcode NLC.
	•	Must be event-driven and reusable for any event slug.
	•	Self-checkin stays PUBLIC but limited (write only to checkins).
	•	Staff/Admin requires authentication.

⸻

1. AUTH PROVIDER

Use Firebase Auth for staff/admin:
	•	Email/password OR Google Sign-In (prefer Google for staff convenience).
	•	Keep self-checkin unauthenticated.

Implement:
lib/features/auth/
	•	auth_repository.dart
	•	auth_guard.dart
	•	login_page.dart

Add routes:
	•	/events/:slug/staff/login
	•	/events/:slug/staff
	•	/events/:slug/admin

⸻

2. RBAC DATA MODEL

Create Firestore:
events/{eventId}/roles/{uid} document:

Example:

{
  "role": "staff", // staff | admin
  "displayName": "John Volunteer",
  "email": "john@...",
  "isActive": true,
  "createdAt": <timestamp>
}

Also allow a global super-admin list (optional):
platform_roles/{uid}

Role resolution priority:
	1.	platform_roles (admin overrides)
	2.	events/{eventId}/roles/{uid}

⸻

3. SECURITY RULES (FIRESTORE)

Implement rules so:
	•	Public users can only:
	•	read event config needed for checkin UI (safe fields only)
	•	read sessions (active only)
	•	write a checkin record with limited fields
	•	Auth staff can:
	•	read registrants
	•	write checkins
	•	override duplicates (write special field override=true)
	•	Admin can:
	•	write sessions (activate/deactivate)
	•	manage event roles
	•	perform reset operations via Cloud Function (preferred)

Write rules with helper functions:
	•	isSignedIn()
	•	isEventStaff(eventId)
	•	isEventAdmin(eventId)
	•	isPlatformAdmin()

Rules must ensure:
	•	Public cannot read full registrant list (PII exposure)
	•	Public search must go through a callable function OR restricted query strategy (see section below)

⸻

4. PUBLIC SEARCH HARDENING (IMPORTANT)

Do NOT allow public users to query registrants freely.

Implement one of:
A) Callable Cloud Function searchRegistrantPublic that returns limited fields (name + masked info) and rate limits
OR
B) Use QR-only for public self-checkin, and keep manual search behind staff login

Implement A) if possible.

⸻

5. STAFF MODE UI

Create StaffHomePage:
	•	Session selector
	•	Search registrant (full access)
	•	Check-in actions:
	•	Check-in
	•	Undo check-in (admin only or staff with permission)
	•	Override duplicate (staff allowed with reason required)
	•	“Manual add check-in” for walk-ins

All writes must include:
	•	createdByUid
	•	createdByRole
	•	method
	•	source

⸻

6. ADMIN MODE UI

Create AdminHomePage:
	•	Real-time counts per session
	•	Manage sessions (CRUD limited to name/code/isActive/order)
	•	Manage staff roles: add/remove user by email (requires function to map email→uid or invite workflow)
	•	View audit logs

Add audit log collection:
events/{eventId}/audit_logs/{autoId}:
	•	action, actorUid, timestamp, payload summary

⸻

7. CLOUD FUNCTIONS (RECOMMENDED)

Implement callable functions:
	•	publicSearchRegistrant(eventId, query) -> limited response + rate limit
	•	adminResetSessionCheckins(eventId, sessionId) -> admin only
	•	adminAssignRole(eventId, email, role) -> admin only

⸻

8. ACCEPTANCE
	•	Public route works without login
	•	Staff login required for staff routes
	•	RBAC enforced by rules (not only UI)
	•	Admin can manage sessions and roles
	•	Audit logs written for privileged actions

⸻

2) 📊 Real-time attendance dashboard

CURSOR PROMPT — Real-time Dashboard (Per Session + Totals)

Add a dashboard under:
	•	/events/:slug/staff/dashboard
	•	/events/:slug/admin/dashboard

Requirements
	1.	Real-time counts:
	•	total check-ins overall
	•	per session check-ins
	•	check-ins over time (last 60 minutes)
	2.	Breakdown:
	•	by method: qr/search/manual
	•	by new vs duplicate attempts
	3.	Search + lookup:
	•	Find registrant and see check-in status across sessions
	4.	Live feed:
	•	Most recent 25 check-ins (masked PII for staff view if needed)

Data strategy (avoid expensive reads)

Do NOT compute counts by scanning checkins collection in real time.

Instead implement aggregated counters:
events/{eventId}/stats/{sessionId} doc:

{
  "sessionId": "S1",
  "checkedInCount": 1234,
  "byMethod": { "qr": 900, "search": 250, "manual": 84 },
  "updatedAt": <timestamp>
}

Also a stats/overall doc.

Update stats via Cloud Function on checkin write:
	•	Firestore trigger onCreate(checkin)
	•	transaction increment counters

Dashboard subscribes to these docs (cheap, real-time).

Charting

Use a simple line chart for checkins per 5-minute bucket:
events/{eventId}/stats_timeseries/{bucketId}:
	•	bucketId = yyyyMMddHHmm rounded to 5min
	•	increment count per session

UI
	•	Top row: Total + per-session cards
	•	Middle: line chart
	•	Bottom: recent checkins list
	•	Works well on iPad landscape

Acceptance
	•	Dashboard loads fast
	•	No heavy queries
	•	Updates within seconds
	•	Costs remain low

⸻

3) 🚀 Production scaling strategy for 3,000+ attendees

Here’s what will keep check-in smooth (and cheap) when 3,000 phones hit it.

A. Use a single “entry QR” that points to a stable URL

Example:
	•	events.aisaiah.org/events/nlc/checkin
Use Cloudflare to redirect or route, but keep the final URL stable for caching and app behavior.

B. Avoid public registrant list reads (PII + load)

For public self-check-in:
	•	Prefer QR scan → lookup
	•	If name search is required publicly, do it via callable function with:
	•	rate limiting (per IP/device)
	•	minimum query length (>=3)
	•	returns only top 10
	•	returns minimal fields

C. Prevent hot-document contention

If you increment ONE stats doc for every check-in, you can hit write contention.

Use sharded counters:
	•	events/{eventId}/stats_shards/{sessionId}_{shardN} (N=0..19)
	•	function picks shard by hash(uid or random)
	•	dashboard reads shards and sums (or a background reducer updates a single doc every 10s)

For 3,000 check-ins over an hour, this matters.

D. Use Cloud Functions for validation + atomic operations

For check-in writes:
	•	callable createCheckin(eventId, sessionId, identifier, method)
	•	function:
	1.	validates session active
	2.	resolves registrant
	3.	checks duplicates
	4.	writes checkin + updates counters in a transaction
This prevents client race conditions.

You can still allow direct client writes for “manual” if needed, but function is better.

E. Indexing

Create Firestore composite indexes for:
	•	checkins: (eventId, sessionId, registrantId)
	•	registrants: (eventId, cfcId), (eventId, email)
	•	sessions: (eventId, isActive, order)

F. Performance UX
	•	Optimistic UI: show “Checking you in…” instantly
	•	Success screen auto returns
	•	Offline handling:
	•	If offline, store pending checkins locally and submit later (staff mode only is safer)

G. Security & Abuse

Public check-in endpoint can be abused.
Use:
	•	Cloudflare WAF / rate limits on /events/*/checkin
	•	reCAPTCHA only if you see abuse (adds friction; avoid unless needed)

H. Observability

Add:
	•	Cloud Logging alerts for function errors
	•	A “Check-in Health” admin panel showing:
	•	last function run time
	•	error rate last 15 minutes

⸻

My recommended production shape (simple + robust)
	•	Public self-check-in:
	•	QR scan only + manual entry fallback
	•	public name search via callable function with limits
	•	Staff/Admin:
	•	full search access + overrides
	•	dashboards using aggregated counters
	•	All privileged actions:
	•	Cloud Functions + audit logs
	•	Stats:
	•	sharded counters (20 shards per session)

⸻

Below is a single, copy/paste Cursor prompt that includes:
	•	✅ Exact Firestore Security Rules (RBAC + public/self-checkin safety)
	•	✅ Cloud Functions skeleton (TypeScript) (callables + triggers + role helpers + rate limiting stubs)
	•	✅ Flutter screens wiring (routes, guards, repo interfaces, UI flow)

It’s written to be dropped into your existing repo with minimal surprises.

⸻

CURSOR PROMPT (COPY/PASTE)

You are working in the existing AIsaiah Flutter + Firebase repo.

Implement Event Check-In (Public + Staff + Admin) as a reusable feature for any event slug. Focus on NLC first but DO NOT hardcode it.

Targets:
	•	DEV deploy: events-dev.aisaiah.org/events/nlc/checkin
	•	Feature must work for other events by changing event doc + sessions.

Implement:
	1.	Firestore Security Rules (exact)
	2.	Cloud Functions skeleton (TypeScript)
	3.	Flutter routing + screens wiring + auth guards

Use clean architecture patterns already in repo. Do not refactor unrelated modules.

⸻

A) FIRESTORE DATA MODEL (ASSUMED)

Collections:
	1.	events/{eventId}
Fields (public-safe subset):

	•	slug (string)
	•	name (string)
	•	checkinEnabled (bool)
	•	selfCheckinEnabled (bool)
	•	sessionsEnabled (bool)

	2.	events/{eventId}/sessions/{sessionId}

	•	name (string)
	•	code (string)
	•	order (number)
	•	isActive (bool)

	3.	events/{eventId}/registrants/{registrantId}

	•	firstName, lastName, email, cfcId, chapter, role, isActive
(PII: must NOT be publicly readable)

	4.	events/{eventId}/checkins/{checkinId}

	•	registrantId (nullable)
	•	manual (bool)
	•	method (“qr”|“search”|“manual”)
	•	sessionId
	•	eventId
	•	createdAt timestamp
	•	createdByUid nullable (for public = null)
	•	source (“self”|“staff”|“admin”)
	•	override bool default false
	•	overrideReason optional

	5.	RBAC:
events/{eventId}/roles/{uid}

	•	role: “staff” | “admin”
	•	email, displayName, isActive

Optional platform RBAC:
platform_roles/{uid}
	•	role: “admin”
	•	isActive: true

	6.	Stats:
events/{eventId}/stats/{docId} where docId can be overall or sessionId

	•	checkedInCount
	•	byMethod map
	•	updatedAt

Optional sharded stats:
events/{eventId}/stats_shards/{shardDocId}
	7.	Audit logs:
events/{eventId}/audit_logs/{id}

⸻

B) FIRESTORE SECURITY RULES (EXACT)

Create/replace firestore.rules with:

rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function signedIn() {
      return request.auth != null;
    }

    function platformAdmin() {
      return signedIn()
        && exists(/databases/$(database)/documents/platform_roles/$(request.auth.uid))
        && get(/databases/$(database)/documents/platform_roles/$(request.auth.uid)).data.isActive == true
        && get(/databases/$(database)/documents/platform_roles/$(request.auth.uid)).data.role == "admin";
    }

    function eventRoleDoc(eventId) {
      return /databases/$(database)/documents/events/$(eventId)/roles/$(request.auth.uid);
    }

    function isEventStaff(eventId) {
      return signedIn()
        && exists(eventRoleDoc(eventId))
        && get(eventRoleDoc(eventId)).data.isActive == true
        && (get(eventRoleDoc(eventId)).data.role == "staff"
            || get(eventRoleDoc(eventId)).data.role == "admin")
        || platformAdmin();
    }

    function isEventAdmin(eventId) {
      return signedIn()
        && exists(eventRoleDoc(eventId))
        && get(eventRoleDoc(eventId)).data.isActive == true
        && get(eventRoleDoc(eventId)).data.role == "admin"
        || platformAdmin();
    }

    function publicEventReadableFieldsOnly() {
      // Basic guard for event doc writes (we will not allow public writes anyway).
      return true;
    }

    // EVENTS (public read allowed; no public write)
    match /events/{eventId} {
      allow read: if true; // Event landing/checkin needs to read config
      allow create, update, delete: if platformAdmin(); // only platform admins can create events

      // SESSIONS: public can read active sessions only; staff/admin can read all
      match /sessions/{sessionId} {
        allow read: if resource.data.isActive == true || isEventStaff(eventId);
        allow create, update, delete: if isEventAdmin(eventId);
      }

      // REGISTRANTS: NEVER public read. Staff/Admin only.
      match /registrants/{registrantId} {
        allow read: if isEventStaff(eventId);
        allow create, update, delete: if isEventAdmin(eventId);
      }

      // ROLES: staff can read roles (optional), admin can write roles
      match /roles/{uid} {
        allow read: if isEventAdmin(eventId);
        allow create, update, delete: if isEventAdmin(eventId);
      }

      // CHECKINS:
      // Public can CREATE a checkin record but with strict constraints.
      // Staff/Admin can create as well and can read checkins; public cannot read checkins.
      match /checkins/{checkinId} {
        allow read: if isEventStaff(eventId);

        allow create: if (
          // Public self-checkin create:
          (
            // public allowed only if event allows self checkin
            get(/databases/$(database)/documents/events/$(eventId)).data.selfCheckinEnabled == true
            && request.auth == null
            // only allow limited fields for public
            && request.resource.data.eventId == eventId
            && request.resource.data.sessionId is string
            && request.resource.data.method in ["qr", "manual"]
            && request.resource.data.source == "self"
            && request.resource.data.createdByUid == null
            && request.resource.data.override == false
            && !("overrideReason" in request.resource.data)
            && request.resource.data.createdAt == request.time
          )
          ||
          // Staff/Admin create:
          (
            isEventStaff(eventId)
            && request.resource.data.eventId == eventId
            && request.resource.data.sessionId is string
            && request.resource.data.method in ["qr", "search", "manual"]
            && request.resource.data.source in ["staff", "admin"]
            && request.resource.data.createdByUid == request.auth.uid
            && request.resource.data.createdAt == request.time
          )
        );

        // Updates/deletes should be admin only (undo check-in, overrides)
        allow update, delete: if isEventAdmin(eventId);
      }

      // STATS: staff read, only functions/service account writes (deny client writes)
      match /stats/{docId} {
        allow read: if isEventStaff(eventId);
        allow write: if false;
      }
      match /stats_shards/{docId} {
        allow read: if isEventStaff(eventId);
        allow write: if false;
      }

      // AUDIT LOGS: staff/admin read; deny client writes (functions only)
      match /audit_logs/{id} {
        allow read: if isEventStaff(eventId);
        allow write: if false;
      }
    }

    // PLATFORM ROLES
    match /platform_roles/{uid} {
      allow read: if platformAdmin();
      allow write: if platformAdmin();
    }
  }
}

Notes:
	•	Public cannot read registrants or checkins.
	•	Public can create checkins with strict limited fields.
	•	Staff/Admin operations are authenticated and role-guarded.
	•	Stats/audit logs are function-only writes.

⸻

C) CLOUD FUNCTIONS SKELETON (TypeScript)

Add to functions/ (Firebase Functions v2 preferred). Create:

functions/src/index.ts

Use admin SDK, enforce RBAC, and implement callables:
	•	publicLookupByQr (public) -> returns minimal registrant info OR not found
	•	publicSearchRegistrant (public with rate limit) -> minimal results
	•	createCheckin (public + staff) -> canonical atomic checkin creation
	•	adminAssignRole (admin)
	•	adminResetSessionCheckins (admin)
Triggers:
	•	onCheckinCreate -> update stats + audit log

Skeleton code:

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";

admin.initializeApp();
const db = admin.firestore();

// --- Helpers ---
async function getPlatformRole(uid: string) {
  const snap = await db.doc(`platform_roles/${uid}`).get();
  return snap.exists ? snap.data() : null;
}

async function getEventRole(eventId: string, uid: string) {
  const snap = await db.doc(`events/${eventId}/roles/${uid}`).get();
  return snap.exists ? snap.data() : null;
}

async function assertEventStaff(eventId: string, uid: string) {
  const platform = await getPlatformRole(uid);
  if (platform?.isActive && platform?.role === "admin") return;

  const role = await getEventRole(eventId, uid);
  if (!role?.isActive || (role.role !== "staff" && role.role !== "admin")) {
    throw new HttpsError("permission-denied", "Not event staff.");
  }
}

async function assertEventAdmin(eventId: string, uid: string) {
  const platform = await getPlatformRole(uid);
  if (platform?.isActive && platform?.role === "admin") return;

  const role = await getEventRole(eventId, uid);
  if (!role?.isActive || role.role !== "admin") {
    throw new HttpsError("permission-denied", "Not event admin.");
  }
}

// Basic rate limit stub (replace with Cloudflare/WAF or Firestore counters)
async function basicRateLimit(key: string, maxPerMinute: number) {
  // Optional: Implement a simple token bucket in Firestore:
  // rate_limits/{key}_{yyyyMMddHHmm}
  // This is intentionally a stub to keep skeleton simple.
  return;
}

// --- Public: lookup by QR (cfcId or email) returns minimal fields ---
export const publicLookupByQr = onCall(async (req) => {
  const { eventId, cfcId, email } = req.data ?? {};
  if (!eventId || (!cfcId && !email)) {
    throw new HttpsError("invalid-argument", "eventId and cfcId/email required.");
  }

  await basicRateLimit(`publicLookup:${eventId}:${req.rawRequest.ip}`, 60);

  // Ensure event allows selfCheckin
  const eventSnap = await db.doc(`events/${eventId}`).get();
  if (!eventSnap.exists) throw new HttpsError("not-found", "Event not found.");
  if (eventSnap.data()?.selfCheckinEnabled !== true) {
    throw new HttpsError("failed-precondition", "Self check-in disabled.");
  }

  let query = db.collection(`events/${eventId}/registrants`).where("isActive", "==", true).limit(1);
  if (cfcId) query = query.where("cfcId", "==", String(cfcId));
  else query = query.where("email", "==", String(email).toLowerCase());

  const result = await query.get();
  if (result.empty) return { found: false };

  const doc = result.docs[0];
  const data = doc.data();
  // Return minimal safe subset
  return {
    found: true,
    registrantId: doc.id,
    firstName: data.firstName ?? "",
    lastName: data.lastName ?? "",
    chapter: data.chapter ?? "",
    role: data.role ?? "",
  };
});

// --- Public: search registrant (minimal fields, limited results) ---
export const publicSearchRegistrant = onCall(async (req) => {
  const { eventId, q } = req.data ?? {};
  if (!eventId || !q || String(q).trim().length < 3) {
    throw new HttpsError("invalid-argument", "eventId and q (>=3 chars) required.");
  }

  await basicRateLimit(`publicSearch:${eventId}:${req.rawRequest.ip}`, 30);

  const eventSnap = await db.doc(`events/${eventId}`).get();
  if (!eventSnap.exists) throw new HttpsError("not-found", "Event not found.");
  if (eventSnap.data()?.selfCheckinEnabled !== true) {
    throw new HttpsError("failed-precondition", "Self check-in disabled.");
  }

  // NOTE: Firestore "startsWith" requires additional indexing approach.
  // Minimal skeleton: use a "searchTokens" array precomputed on registrants (preferred).
  // If not available, you can disable public search and keep it staff-only.
  // Here we assume registrants have `searchTokens: string[]`.
  const token = String(q).trim().toLowerCase();

  const snap = await db.collection(`events/${eventId}/registrants`)
    .where("isActive", "==", true)
    .where("searchTokens", "array-contains", token)
    .limit(10)
    .get();

  const items = snap.docs.map(d => {
    const r = d.data();
    return {
      registrantId: d.id,
      firstName: r.firstName ?? "",
      lastName: r.lastName ?? "",
      chapter: r.chapter ?? "",
      role: r.role ?? "",
    };
  });

  return { items };
});

// --- Create checkin (canonical) ---
// Use for public + staff. Performs duplicate check + writes checkin + updates stats (optional here)
export const createCheckin = onCall(async (req) => {
  const { eventId, sessionId, method, source, registrantId, manualPayload, override, overrideReason } = req.data ?? {};
  if (!eventId || !sessionId || !method || !source) {
    throw new HttpsError("invalid-argument", "eventId, sessionId, method, source required.");
  }

  const isAuthed = !!req.auth?.uid;

  // Validate event/session
  const [eventSnap, sessionSnap] = await Promise.all([
    db.doc(`events/${eventId}`).get(),
    db.doc(`events/${eventId}/sessions/${sessionId}`).get(),
  ]);
  if (!eventSnap.exists) throw new HttpsError("not-found", "Event not found.");
  if (!sessionSnap.exists) throw new HttpsError("not-found", "Session not found.");
  if (sessionSnap.data()?.isActive !== true) throw new HttpsError("failed-precondition", "Session not active.");

  // Authorization logic
  if (!isAuthed) {
    // public
    if (eventSnap.data()?.selfCheckinEnabled !== true) {
      throw new HttpsError("failed-precondition", "Self check-in disabled.");
    }
    if (source !== "self") throw new HttpsError("permission-denied", "Public source must be self.");
    if (method !== "qr" && method !== "manual") throw new HttpsError("invalid-argument", "Public method must be qr/manual.");
    if (override === true) throw new HttpsError("permission-denied", "Override not allowed.");
  } else {
    // staff/admin
    await assertEventStaff(eventId, req.auth!.uid);
    if (source !== "staff" && source !== "admin") throw new HttpsError("invalid-argument", "Staff source must be staff/admin.");
    if (override === true) {
      // Only admin for override OR allow staff with reason (choose policy).
      // Here: allow staff override with reason.
      if (!overrideReason || String(overrideReason).trim().length < 5) {
        throw new HttpsError("invalid-argument", "Override reason required (>=5 chars).");
      }
    }
  }

  // Determine registrantId
  let resolvedRegistrantId: string | null = null;
  if (method === "manual") {
    resolvedRegistrantId = null;
  } else {
    if (!registrantId) throw new HttpsError("invalid-argument", "registrantId required for non-manual methods.");
    resolvedRegistrantId = String(registrantId);
  }

  const checkinsCol = db.collection(`events/${eventId}/checkins`);

  // Transaction: prevent duplicates per (registrantId, sessionId)
  await db.runTransaction(async (tx) => {
    if (resolvedRegistrantId) {
      const dupQuery = await tx.get(
        checkinsCol
          .where("sessionId", "==", sessionId)
          .where("registrantId", "==", resolvedRegistrantId)
          .limit(1)
      );
      if (!dupQuery.empty && override !== true) {
        throw new HttpsError("already-exists", "Already checked in for this session.");
      }
    }

    const now = admin.firestore.FieldValue.serverTimestamp();

    const docRef = checkinsCol.doc();
    tx.set(docRef, {
      eventId,
      sessionId,
      registrantId: resolvedRegistrantId,
      manual: method === "manual",
      manualPayload: method === "manual" ? (manualPayload ?? {}) : null,
      method,
      source,
      createdAt: now,
      createdByUid: isAuthed ? req.auth!.uid : null,
      override: override === true,
      overrideReason: override === true ? String(overrideReason ?? "") : null,
    });
  });

  return { ok: true };
});

// --- Admin: assign role by uid (simpler). Email→uid requires separate directory.
export const adminAssignRole = onCall(async (req) => {
  if (!req.auth?.uid) throw new HttpsError("unauthenticated", "Login required.");
  const { eventId, targetUid, role, email, displayName, isActive } = req.data ?? {};
  if (!eventId || !targetUid || !role) {
    throw new HttpsError("invalid-argument", "eventId, targetUid, role required.");
  }
  await assertEventAdmin(eventId, req.auth.uid);

  const roleDoc = db.doc(`events/${eventId}/roles/${String(targetUid)}`);
  await roleDoc.set({
    role: role, // staff|admin
    email: email ?? "",
    displayName: displayName ?? "",
    isActive: isActive ?? true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  return { ok: true };
});

export const adminResetSessionCheckins = onCall(async (req) => {
  if (!req.auth?.uid) throw new HttpsError("unauthenticated", "Login required.");
  const { eventId, sessionId } = req.data ?? {};
  if (!eventId || !sessionId) throw new HttpsError("invalid-argument", "eventId, sessionId required.");
  await assertEventAdmin(eventId, req.auth.uid);

  // Skeleton: for production, do this in batches with recursion and add audit logs.
  // Here we just return not-implemented to avoid accidental destructive ops.
  throw new HttpsError("unimplemented", "Implement batched delete/reset with safeguards.");
});

// --- Trigger: on checkin create -> update stats + audit log (skeleton)
export const onCheckinCreate = onDocumentCreated("events/{eventId}/checkins/{checkinId}", async (event) => {
  const { eventId, checkinId } = event.params;
  const snap = event.data;
  if (!snap) return;

  const data = snap.data() as any;
  const sessionId = data.sessionId as string;
  const method = data.method as string;

  // Update stats doc (simple non-sharded skeleton). For high scale use shards.
  const overallRef = db.doc(`events/${eventId}/stats/overall`);
  const sessionRef = db.doc(`events/${eventId}/stats/${sessionId}`);

  const inc = admin.firestore.FieldValue.increment(1);

  await db.runTransaction(async (tx) => {
    const now = admin.firestore.FieldValue.serverTimestamp();
    tx.set(overallRef, {
      checkedInCount: inc,
      [`byMethod.${method}`]: inc,
      updatedAt: now,
    }, { merge: true });

    tx.set(sessionRef, {
      sessionId,
      checkedInCount: inc,
      [`byMethod.${method}`]: inc,
      updatedAt: now,
    }, { merge: true });
  });

  // Audit log (optional; keep minimal)
  const auditRef = db.collection(`events/${eventId}/audit_logs`).doc();
  await auditRef.set({
    action: "checkin_created",
    checkinId,
    sessionId,
    method,
    source: data.source ?? "",
    createdByUid: data.createdByUid ?? null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
});

Also update functions/src/package.json / tsconfig if needed (follow repo standards). Ensure exports exist.

⸻

D) FLUTTER WIRING (ROUTES + SCREENS + GUARDS)

1. ROUTES

Add routes (GoRouter or existing):
Public:
	•	/events/:slug/checkin (public landing)
	•	/events/:slug/checkin/scan
	•	/events/:slug/checkin/search
	•	/events/:slug/checkin/manual

Staff:
	•	/events/:slug/staff/login
	•	/events/:slug/staff (home)
	•	/events/:slug/staff/dashboard

Admin:
	•	/events/:slug/admin (home)
	•	/events/:slug/admin/dashboard

2. AUTH GUARDS

Implement AuthState from FirebaseAuth.
Implement guard:
	•	if not signed in -> redirect to staff/login
	•	if signed in but not staff -> show access denied
Role resolution:
	•	call Firestore doc events/{eventId}/roles/{uid} (and optional platform_roles)

Cache role in memory for session.

3. REPOSITORIES

Create EventCheckinRepository with methods:
	•	Future<EventModel> getEventBySlug(slug)
	•	Future<List<SessionModel>> getActiveSessions(eventId)
	•	Future<PublicRegistrantLookupResult> publicLookupByQr(eventId, cfcId/email) -> calls callable
	•	Future<List<RegistrantLite>> publicSearch(eventId, query) -> calls callable
	•	Future<void> createCheckinPublic(...) -> calls callable createCheckin with source=self
	•	Future<void> createCheckinStaff(...) -> calls callable with source=staff/admin
	•	Stream<Stats> watchStatsOverall(eventId)
	•	Stream<Stats> watchStatsSession(eventId, sessionId)
	•	Stream<List<RecentCheckin>> watchRecentCheckins(eventId) (staff only; read checkins collection)

Use cloud_functions plugin for callables.
Do not write checkins directly from client; always call createCheckin function to unify logic and prevent races.

4. SCREENS

Implement minimal but wired screens:

Public Landing
	•	Loads event by slug
	•	Loads active sessions
	•	Requires session selected
	•	Buttons: Scan / Search / Manual

Public Scan
	•	Uses mobile camera scanning package already in repo (or mobile_scanner)
	•	Extracts cfcId/email
	•	Calls publicLookupByQr
	•	If found -> call createCheckin (method=qr, source=self)
	•	If not found -> show manual entry CTA

Public Search
	•	input >= 3 chars
	•	calls publicSearchRegistrant
	•	list results -> tap -> call createCheckin (method=search? for public disallow search; if public search is allowed set method=qr or search; align with rules/functions)
NOTE: if public search is enabled, update rules+function to allow method “search” for public. Otherwise keep search behind staff only.

Public Manual
	•	minimal form (first/last/email optional)
	•	calls createCheckin with method=manual, source=self, manualPayload

Staff Login
	•	Firebase Auth sign-in

Staff Home
	•	Same flow but full registrant search allowed (direct Firestore reads to registrants collection permitted for staff)
	•	Override duplicate with reason (calls createCheckin override=true)

Dashboards
	•	Subscribe to stats docs; show counts per session and overall, plus recent checkins list (staff-only reads)

5. IMPORTANT POLICY ALIGNMENT

If you keep public search enabled:
	•	Add method “search” to allowed public methods in rules + function.
If you disable public search:
	•	Remove public search screen route or show “Staff login required”.

⸻

E) DEPLOYMENT NOTES
	•	Ensure Firebase Hosting rewrite supports Flutter web routes.
	•	Ensure events-dev.aisaiah.org points to the correct hosting target.
	•	Ensure Functions are deployed to the same project.
	•	Add indexes for:
	•	checkins (sessionId+registrantId)
	•	registrants (searchTokens array contains)
Create required indexes when Firestore console prompts.

⸻

F) DELIVERABLES CHECKLIST
	1.	firestore.rules updated
	2.	Functions skeleton compiles and deploys
	3.	Flutter routes compile
	4.	Public checkin works via scan/manual
	5.	Staff login + dashboard loads stats
	6.	Staff can search registrants (if implemented) and check in
	7.	Duplicate protection enforced by function
	8.	Stats update in real time

END.

