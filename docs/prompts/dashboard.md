Excellent. Now we’re moving from UI to system architecture.

Below is a comprehensive production-grade Cursor prompt that will make it implement:
	•	Proper Firestore data model
	•	Check-in transactional logic
	•	Real-time dashboard aggregation
	•	Cloud Functions for analytics
	•	Session-level tracking
	•	Early bird tracking
	•	First check-in tracking
	•	KPI-ready dashboard structure

This is written so Cursor builds it cleanly and scalable.

⸻

 NLC 2026 Check-In Logic + Analytics Architecture

You are implementing the production check-in logic and analytics system for:

Couples for Christ – National Leaders Conference 2026

The system must:

• Update in real time
• Scale to 3,000+ attendees
• Power a live analytics dashboard
• Support session-level tracking
• Avoid client-side aggregation
• Use Cloud Functions for analytics integrity

⸻

🔥 OBJECTIVE

When a participant checks in:
	1.	Registrant document updates
	2.	Attendance record is created
	3.	Analytics counters update automatically
	4.	Dashboard reflects change in real time

All KPIs must update immediately.

⸻

🧱 FIRESTORE DATA MODEL

1️⃣ Registrants Collection

Path:

events/{eventId}/registrants/{registrantId}

Structure:

{
  "firstName": "Juan",
  "lastName": "Dela Cruz",
  "email": "juan@email.com",
  "region": "NCR",
  "regionOtherText": null,
  "ministryMembership": "CFC",
  "service": "Chapter Head",
  "isEarlyBird": true,
  "registeredAt": Timestamp,
  "checkedInAt": Timestamp | null,
  "checkedInBy": "staff@email.com",
  "checkInSource": "QR | SEARCH | MANUAL",
  "sessionsCheckedIn": {
    "sessionId1": Timestamp,
    "sessionId2": Timestamp
  }
}


⸻

2️⃣ Event Stats Document (Live Aggregates)

Path:

events/{eventId}/stats/overview

Structure:

{
  "totalRegistrations": 1240,
  "totalCheckedIn": 850,
  "earlyBirdCount": 340,
  "firstCheckInAt": Timestamp,
  "firstCheckInRegistrantId": "abc123",
  "regionCounts": {
    "NCR": 200,
    "Region 1": 50,
    "Other": 12
  },
  "ministryCounts": {
    "CFC": 600,
    "SFC": 200
  },
  "serviceCounts": {
    "Chapter Head": 120,
    "Unit Leader": 340
  },
  "sessionTotals": {
    "session1": 430,
    "session2": 320
  }
}

This document must update automatically.

⸻

⚙️ CHECK-IN LOGIC (CLIENT SIDE)

When user checks in:
	1.	Use Firestore transaction
	2.	Update registrant:

checkedInAt = FieldValue.serverTimestamp()
checkedInBy = currentStaffEmail

	3.	Do NOT update analytics in client.
	4.	Cloud Function must handle aggregation.

⸻

☁️ CLOUD FUNCTION — REAL TIME ANALYTICS ENGINE

Implement:

onUpdate registrants/{registrantId}

Trigger only when:

before.checkedInAt == null && after.checkedInAt != null

Then:
	1.	Increment totalCheckedIn
	2.	Increment regionCounts[region]
	3.	Increment ministryCounts[ministryMembership]
	4.	Increment serviceCounts[service]
	5.	If early bird → increment earlyBirdCount
	6.	If first check-in → set firstCheckInAt
	7.	Update sessionTotals if applicable

Use:

FieldValue.increment(1)

Use batched updates.

Must be atomic.

⸻

📊 TOP 5 AGGREGATION

Do NOT compute in client.

In Cloud Function:

After updating counts:

Generate sorted arrays:

top5Regions: [
  { name: "NCR", count: 200 },
  { name: "Region 1", count: 150 }
]

Store in stats doc.

Same for:
	•	Top 5 Services
	•	Top 5 Ministries

⸻

🧠 SESSION CHECK-IN LOGIC

Session path:

events/{eventId}/sessions/{sessionId}/attendance/{registrantId}

When session check-in happens:
	1.	Write attendance doc
	2.	Cloud Function increments:

stats.sessionTotals.sessionId


⸻

📈 DASHBOARD REQUIREMENTS

Dashboard screen must:

Use StreamBuilder on:

events/{eventId}/stats/overview

Display:

• Total Registered
• Total Checked In
• Early Bird %
• First Check-In timestamp
• Top 5 Regions
• Top 5 Services
• Top 5 Ministries
• Session Attendance Totals
• Real-time check-in rate (per minute)

⸻

🚀 PERFORMANCE RULES

• No client-side counting
• No full collection scans
• No querying all registrants for dashboard
• Everything must come from stats doc
• Must support 3,000+ attendees

⸻

🔒 SECURITY

Only:
	•	Staff can check in
	•	Only Cloud Functions can update stats
	•	Stats doc must not be writable from client

Firestore rules:

match /stats/{doc} {
  allow read: if isStaff(eventId);
  allow write: if false;
}


⸻

📊 ADDITIONAL KPIs (RECOMMENDED)

Implement additional fields:

checkInsPerMinute
peakCheckInMinute
peakCheckInCount
averageCheckInTimeFromRegistration

Store in stats doc.

⸻

🏗 DELIVERABLES

Cursor must generate:
	1.	Firestore data model structure
	2.	Check-in transaction logic in Flutter
	3.	Cloud Function (TypeScript)
	4.	Real-time dashboard Flutter screen
	5.	Updated Firestore rules
	6.	KPI calculations
	7.	Comments explaining aggregation logic

⸻

🎯 FINAL REQUIREMENT

When:

1 person checks in →

Dashboard updates instantly.

No refresh.
No manual aggregation.

Must feel like:

Professional event command center.

