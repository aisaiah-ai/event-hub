# Event Hub – Dynamic Schema, Registration, Check-In, and Formation Design

## 1. Purpose

This document defines the Event Hub dynamic data model and workflows that support:
- Event-level and session-level check-in (required for NLC)
- Manual entry (walk-ins / missing records)
- Schema-driven registration data that can evolve over time
- CSV import mapped to dynamic schema
- Role-based validation overrides
- Formation tracking signals consumable by AIsaiah
- Admin Schema Editor UI (live field creation/editing)

**First deployment:** NLC (CFC National Leaders Conference)

## 2. Core Principles

1. Schema is data, not code
2. Event check-in ≠ Session check-in
3. Manual entry is first-class
4. Validation is role-aware
5. Formation is derived, not entered

---

## 3. Firestore Model

### 3.1 Collection Structure

```
events/{eventId}
├── registrants/{registrantId}
├── sessions/{sessionId}
│   └── attendance/{registrantId}
├── schemas/registration  (single document)
├── formationSignals/{registrantId}
└── importMappings/{mappingId}
```

### 3.2 Registration Schema

**Path:** `events/{eventId}/schemas/registration`

| Field | Type | Description |
|-------|------|-------------|
| version | int | Incremented on each save |
| updatedAt | timestamp | Last modified |
| fields | array | Field definitions |
| roleOverrides | map | Validation overrides by role |

**Field object:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| key | string | ✓ | Unique identifier |
| label | string | ✓ | Display label |
| type | enum | ✓ | See Field Types |
| required | bool | ✓ | Validation flag |
| options | array? | | For select/multiselect |
| validators | array? | | Validator configs |
| systemField | string? | | Maps to profile vs answers |
| locked | bool? | | If true, cannot be removed |
| formation.tags | array? | | Tags for formation signal |

**Field types enum:** `text`, `email`, `phone`, `select`, `multiselect`, `date`, `number`, `textarea`, `checkbox`

**Validators format:** `{ type: "regex"|"minLength"|"maxLength"|"email"|"custom", value?: string }`

**Role overrides:**
- `ADMIN.allowMissingRequired` (bool): ADMIN may bypass required validation → log warnings
- `STAFF.allowMissingRequired` (bool): STAFF may bypass required validation → log warnings

### 3.3 Registrants

**Path:** `events/{eventId}/registrants/{registrantId}`

| Field | Type | Description |
|-------|------|-------------|
| profile | map | System fields (name, email, etc.) |
| answers | map | Schema-defined custom fields |
| source | enum | IMPORT \| REGISTRATION \| MANUAL |
| registrationStatus | string | Status of registration |
| registeredAt | timestamp | When registered |
| createdAt | timestamp | Record creation |
| updatedAt | timestamp | Last update |
| eventAttendance | map | Event-level check-in state |
| flags | map | isWalkIn, hasValidationWarnings, validationWarnings[] |

**eventAttendance structure:**
- `checkedIn` (bool)
- `checkedInAt` (timestamp?)
- `checkedInBy` (string?)

### 3.4 Sessions

**Path:** `events/{eventId}/sessions/{sessionId}`

| Field | Type | Description |
|-------|------|-------------|
| title | string | Session name |
| startAt | timestamp | Start time |
| endAt | timestamp | End time |
| type | string? | Session type/category |

**Path:** `events/{eventId}/sessions/{sessionId}/attendance/{registrantId}`

| Field | Type | Description |
|-------|------|-------------|
| checkedInAt | timestamp | When checked in |
| checkedInBy | string? | User who performed check-in |

### 3.5 Formation Signals

**Path:** `events/{eventId}/formationSignals/{registrantId}`

| Field | Type | Description |
|-------|------|-------------|
| eventId | string | Event reference |
| registrantId | string | Registrant reference |
| tags | array | Derived tags for AIsaiah |
| updatedAt | timestamp | Last computed |

**Tag sources:** eventId, registration answers (from schema formation.tags), attended session IDs

### 3.6 Import Mappings

**Path:** `events/{eventId}/importMappings/{mappingId}`

Stores CSV header → schema key mappings for reuse.

---

## 4. Dynamic Form Renderer

**Widget:** `DynamicFormWidget`

**Inputs:**
- schema (RegistrationSchema)
- initialValues (Map<String, dynamic>)
- role (UserRole: ADMIN | STAFF | USER)

**Responsibilities:**
- Render fields by type
- Validate required + validators
- Enforce role overrides (allowMissingRequired)
- Return values map on submit

**Mapping:**
- `systemField` → write to `profile`
- Fallback → write to `answers[field.key]`

---

## 5. Routes

| Route | Purpose |
|-------|---------|
| /admin/registrants/new | Create new registrant (manual entry) |
| /admin/registrants/:id/edit | Edit existing registrant |
| /admin/sessions/:sessionId/manual-checkin | Manual session check-in |
| /admin/import/registrants | CSV import with mapping |
| /admin/schema/registration | Schema Editor UI (ADMIN only) |

---

## 6. Manual Entry

**Rules:**
- Always create registrant first, then session check-in
- STAFF must satisfy required fields
- ADMIN may bypass required → log warnings in flags.validationWarnings
- Manual registrants: source = MANUAL, flags.isWalkIn = true

**Manual session check-in:** If registrant does not exist, create first (walk-in).

---

## 7. CSV Import

**Workflow:**
1. Upload CSV
2. Auto-map headers → schema keys
3. Manual override mapping UI
4. Preview rows
5. Import using ADMIN validation (allowMissingRequired)

**Features:**
- Deterministic registrant ID (e.g., hash of key fields)
- Warnings for missing required
- Store mapping in `importMappings` for reuse

---

## 8. Event & Session Check-In

**Event check-in:** Updates `registrant.eventAttendance` (checkedIn, checkedInAt, checkedInBy).

**Session check-in:**
- Requires `eventAttendance.checkedIn == true`
- Writes to `sessions/{sessionId}/attendance/{registrantId}`

**Manual session check-in:** Create registrant if missing (walk-in flow).

---

## 9. Formation Signal Service

**Component:** `FormationSignalService`

**Triggers:**
- Event check-in
- Session check-in
- Registrant creation/update

**Logic:** Generate tags from eventId, registration answers (via schema formation.tags), attended sessions.

**Output:** Write to `events/{eventId}/formationSignals/{registrantId}`

---

## 10. Admin Schema Editor UI

**Features:**
- List, add, edit, delete fields
- Reorder fields
- Toggle required
- Manage select options
- Define validators
- Define formation tags
- Preview dynamic form

**Rules:**
- Locked fields cannot be removed
- Increment schema.version on save
- Update updatedAt
- Warning: If marking field required after data exists → show confirmation

---

## 11. Authentication & Roles

- **ADMIN:** Full access, can bypass required validation
- **STAFF:** Can create/edit registrants, must satisfy required (unless roleOverride allows)
- **USER:** Standard registrant self-service

Roles determined via Firebase Auth custom claims or Firestore user role document.

---

## 12. Deliverables

- Dynamic schema loader
- Dynamic form renderer
- Admin Schema Editor UI
- Manual entry flows
- CSV import with mapping
- Session & event check-in
- Formation signals
- README explaining schema evolution
- CI/CD deployment pipeline
- Unit tests

---

*Implement cleanly, modularly, and event-agnostic.*
