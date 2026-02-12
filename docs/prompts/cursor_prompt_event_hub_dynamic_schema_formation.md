# CURSOR PROMPT — Event Hub Dynamic Schema, Schema Editor, CSV Import, Formation

You are implementing a **generic Event Hub platform** in Flutter.

The system must support:
- Dynamic registration schemas (event‑defined)
- Event‑level and session‑level check‑in
- Manual entry (walk‑ins)
- CSV import mapped to schema
- Role‑based validation overrides
- Formation signal generation
- **Admin Schema Editor UI**

NLC (CFC National Leaders Conference) is the first deployment.

---

## A) Firestore Collections (REQUIRED)

### 1. Registration Schema
`events/{eventId}/schemas/registration`

Fields:
- version (int)
- updatedAt (timestamp)
- fields (array)
- roleOverrides (map)

Field object:
- key (string)
- label (string)
- type (enum)
- required (bool)
- options (array?)
- validators (array?)
- systemField (string?)
- locked (bool?)
- formation.tags (array?)

roleOverrides:
- ADMIN.allowMissingRequired
- STAFF.allowMissingRequired

---

### 2. Registrants
`events/{eventId}/registrants/{registrantId}`

Structure:
- profile {}
- answers {}
- source (IMPORT | REGISTRATION | MANUAL)
- registrationStatus
- registeredAt
- createdAt / updatedAt
- eventAttendance {}
- flags { isWalkIn, hasValidationWarnings, validationWarnings[] }

---

### 3. Sessions & Attendance
`events/{eventId}/sessions/{sessionId}`
`events/{eventId}/sessions/{sessionId}/attendance/{registrantId}`

---

### 4. Formation Signals
`events/{eventId}/formationSignals/{registrantId}`

---

## B) Dynamic Form Renderer (Flutter)

Implement a reusable `DynamicFormWidget`:

Inputs:
- schema
- initialValues
- role

Responsibilities:
- Render fields by type
- Validate required + validators
- Enforce role overrides
- Return values map

Mapping:
- systemField → profile / answers
- fallback → answers[field.key]

---

## C) Manual Entry (Admin & Staff)

Routes:
- /admin/registrants/new
- /admin/registrants/:id/edit
- /admin/sessions/:sessionId/manual-checkin

Rules:
- Always create registrant first
- STAFF must satisfy required fields
- ADMIN may bypass required → log warnings
- Manual registrants:
  - source = MANUAL
  - flags.isWalkIn = true

---

## D) CSV Import with Schema Mapping

Route:
- /admin/import/registrants

Workflow:
1. Upload CSV
2. Auto‑map headers → schema keys
3. Manual override mapping UI
4. Preview rows
5. Import using ADMIN validation

Features:
- Deterministic registrant ID
- Warnings for missing required
- Store mapping under:
  events/{eventId}/importMappings/

---

## E) Schema Editor UI (ADMIN ONLY)

Route:
- /admin/schema/registration

Features:
- List fields
- Add field
- Edit field
- Delete field
- Reorder fields
- Toggle required
- Manage select options
- Define validators
- Define formation tags
- Preview dynamic form

Rules:
- Locked fields cannot be removed
- Increment schema.version on save
- Update updatedAt

Warnings:
- If marking field required after data exists → show confirmation

---

## F) Event & Session Check‑In Integration

Event check‑in:
- Uses registrant.eventAttendance

Session check‑in:
- Requires eventAttendance.checkedIn == true
- Writes to session attendance collection

Manual session check‑in:
- Create registrant if missing

---

## G) Formation Signal Service

Create `FormationSignalService`:

Triggers:
- Event check‑in
- Session check‑in
- Registrant creation/update

Logic:
- Generate tags from:
  - eventId
  - registration answers
  - schema formation tags
  - attended sessions

Write to:
- events/{eventId}/formationSignals/{registrantId}

---

## H) Deliverables

- Dynamic schema loader
- Dynamic form renderer
- Admin Schema Editor UI
- Manual entry flows
- CSV import with mapping
- Session & event check‑in
- Formation signals
- README explaining schema evolution

Implement cleanly, modularly, and event‑agnostic.

