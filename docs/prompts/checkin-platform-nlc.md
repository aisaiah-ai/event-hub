Reusable Event Check-In Module (NLC First Implementation)

You are working inside the existing AIsaiah Flutter + Firebase monorepo.

We are implementing a reusable Event Check-In Module starting with:

Event: National Leaders Conference (NLC)

Deployment target (DEV):

events-dev.aisaiah.org/events/nlc

This module must be reusable for:
	•	NLC
	•	Cluster Assemblies
	•	Retreats
	•	Conferences
	•	Future events

DO NOT hardcode NLC-specific logic.
All configuration must be event-driven.

⸻

🎯 OBJECTIVE

Create a flexible self-check-in system with:
	1.	Single public check-in landing page
	2.	QR scan (CFC QR)
	3.	Manual search from registrant database
	4.	Manual entry if not found
	5.	Dynamic session selection (3 for NLC but unlimited)
	6.	Event-driven configuration
	7.	Reusable architecture

⸻

🏗️ ARCHITECTURE OVERVIEW

Create new module:

lib/features/event_checkin/
    presentation/
        checkin_landing_page.dart
        checkin_search_page.dart
        checkin_manual_entry_page.dart
        checkin_session_selector.dart
        checkin_success_page.dart
    data/
        checkin_repository.dart
        registrant_model.dart
        session_model.dart
        checkin_record_model.dart

This module must NOT depend on spiritual fitness modules.

⸻

📦 FIRESTORE STRUCTURE (Flexible)

1️⃣ EVENTS COLLECTION

events
   nlc-2026
      slug: "nlc"
      name: "National Leaders Conference"
      checkinEnabled: true
      selfCheckinEnabled: true
      sessionsEnabled: true


⸻

2️⃣ REGISTRANTS COLLECTION

Preloaded list exists.

events/{eventId}/registrants
   {registrantId}
      firstName
      lastName
      email
      cfcId
      role
      chapter
      isActive

Do NOT modify structure.

⸻

3️⃣ SESSIONS COLLECTION (Dynamic)

events/{eventId}/sessions
    session1
        name: "Day 1 Main Session"
        code: "S1"
        isActive: true
    session2
    session3

Must support unlimited sessions.

DO NOT hardcode 3.

⸻

4️⃣ CHECKIN RECORDS

events/{eventId}/checkins
    autoId
        registrantId (nullable if manual)
        sessionId
        method: "qr" | "search" | "manual"
        timestamp
        deviceInfo
        source: "self"


⸻

🖥️ 1️⃣ CHECK-IN LANDING PAGE

Route:

/events/:slug/checkin

This is accessed via a single QR code printed at venue.

Page displays:
	•	Event Name
	•	Session selector (if sessionsEnabled == true)
	•	Three large buttons:

[ 📷 Scan CFC QR Code ]
[ 🔎 Search Name ]
[ ✍️ Enter Manually ]

⸻

🎛️ 2️⃣ SESSION SELECTOR (Flexible)

On page load:
Fetch sessions where isActive == true.

If:
	•	0 sessions → hide selector
	•	1 session → auto-select
	•	Multiple sessions → dropdown or segmented buttons

Selected sessionId must be required before check-in.

⸻

📷 3️⃣ QR SCAN FLOW

Scan CFC QR code.

Expected data:
	•	cfcId OR email

Flow:
	1.	Extract identifier
	2.	Query registrants collection
	3.	If found → proceed to success
	4.	If not found → show option:
	•	“Not found? Enter manually”

⸻

🔎 4️⃣ SEARCH FLOW

Search by:
	•	First name
	•	Last name
	•	Email
	•	CFC ID

Implement:
Firestore query with prefix matching (limit 20 results)

Display:
List tiles:
Name
Role
Chapter

Tap to confirm check-in.

⸻

✍️ 5️⃣ MANUAL ENTRY FLOW

Form fields:
	•	First name
	•	Last name
	•	Email (optional)
	•	Chapter
	•	Role (optional)

Store:
registrantId = null
method = “manual”

Must not create registrant record automatically.
Only create checkin record.

⸻

🎉 6️⃣ SUCCESS PAGE

Display:

✅ Checked In Successfully
Name
Session Name
Timestamp

Auto-return to landing page after 3 seconds.

⸻

🔁 7️⃣ DUPLICATE CHECK PREVENTION

Before creating checkin record:

Query:

where registrantId == X
where sessionId == selectedSession

If exists:
Show:
⚠️ Already checked in for this session

Allow override? NO (for now).

⸻

🌐 8️⃣ SELF CHECK-IN SAFETY

Since this is public:

Implement:
	•	Rate limit client side (cooldown 2 seconds)
	•	Basic input validation
	•	No admin privileges

⸻

⚙️ 9️⃣ REUSABILITY REQUIREMENTS

Everything must be event-driven.

NO:

if (event == NLC)

Instead:

EventModel.sessionsEnabled
EventModel.selfCheckinEnabled


⸻

🧠 10️⃣ REPOSITORY LAYER

Create:

Future<List<SessionModel>> getActiveSessions(eventId)
Future<RegistrantModel?> findRegistrantByCfcId(...)
Future<List<RegistrantModel>> searchRegistrants(...)
Future<void> createCheckinRecord(...)
Future<bool> hasCheckedIn(...)

Keep clean separation.

⸻

🧪 11️⃣ DEV DEPLOYMENT

Ensure works at:

events-dev.aisaiah.org/events/nlc/checkin

No environment hardcoding.
Use existing firebase_options_dev.dart.

⸻

📱 12️⃣ UI DESIGN REQUIREMENTS

Professional.

Use:
	•	Deep navy / teal background
	•	Large rounded buttons
	•	High contrast success state
	•	Clean typography

Tablet-friendly layout.

⸻

🚫 DO NOT
	•	Mix event checkin with RSVP logic
	•	Modify spiritual fitness modules
	•	Hardcode session count
	•	Auto-create registrants
	•	Use client-only state for checkin verification

⸻

✅ ACCEPTANCE CRITERIA
	1.	Can check in via QR
	2.	Can check in via search
	3.	Can check in manually
	4.	Can select session dynamically
	5.	Duplicate session check prevented
	6.	Works for NLC
	7.	Can reuse for new event by changing slug only

⸻

🔮 NEXT PHASE (Do Not Implement Yet)
	•	Staff override mode
	•	Offline mode
	•	Badge printing
	•	Role-based dashboard
	•	Analytics screen

