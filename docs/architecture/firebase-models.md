# Firebase / Firestore Models

Event Hub uses **Cloud Firestore** as the database. This document describes the collections, documents, and field structures.

## Database

- **Type:** Cloud Firestore (NoSQL document database)
- **Project:** aisaiah-event-hub
- **Rules:** `firestore.rules`
- **Indexes:** `firestore.indexes.json`

### Environments

| Database ID | Purpose |
|-------------|---------|
| `event-hub-dev` | Development |
| `event-hub-prod` | Production |

The app uses **event-hub-dev** when running in debug mode (`flutter run`), and **event-hub-prod** for release builds. Other applications can connect to the same databases using these IDs. Override with `--dart-define=ENV=dev` or `ENV=prod` if using `FirestoreConfig.initFromDartDefine()`.

---

## Collection Structure

```
events (collection)
└── {eventId} (document, optional Event metadata)
    ├── registrants (subcollection)
    │   └── {registrantId}
    ├── sessions (subcollection)
    │   └── {sessionId}
    │       └── attendance (subcollection)
    │           └── {registrantId}
    ├── schemas (subcollection)
    │   └── registration (document)
    ├── formationSignals (subcollection)
    │   └── {registrantId}
    └── importMappings (subcollection)
        └── {mappingId}
```

---

## Document Models

### Event (optional)

**Path:** `events/{eventId}`

| Field      | Type      | Description      |
|-----------|-----------|------------------|
| title     | string    | Event name       |
| description | string  | Event description |
| startAt   | timestamp | Start time       |
| endAt     | timestamp | End time         |
| createdAt | timestamp | Created at       |
| updatedAt | timestamp | Updated at       |

**Dart model:** `Event`

---

### Registration Schema

**Path:** `events/{eventId}/schemas/registration`

| Field       | Type      | Description          |
|-------------|-----------|----------------------|
| version     | int       | Schema version       |
| updatedAt   | timestamp | Last modified        |
| fields      | array     | Field definitions    |
| roleOverrides | map     | ADMIN/STAFF overrides |

**Field object:**

| Field   | Type   | Description                         |
|---------|--------|-------------------------------------|
| key     | string | Unique field key                    |
| label   | string | Display label                       |
| type    | string | text, email, phone, select, etc.    |
| required| bool   | Required validation                 |
| options | array? | Options for select/multiselect      |
| validators | array? | Validator configs                 |
| systemField | string? | Maps to profile vs answers       |
| locked  | bool?  | Cannot be removed                   |
| formation.tags | array? | Formation signal tags           |

**Dart model:** `RegistrationSchema`, `SchemaField`, `RoleOverrides`

---

### Registrant

**Path:** `events/{eventId}/registrants/{registrantId}`

| Field             | Type      | Description              |
|-------------------|-----------|--------------------------|
| profile           | map       | System fields            |
| answers           | map       | Schema custom fields     |
| source            | string    | IMPORT, REGISTRATION, MANUAL |
| registrationStatus| string    | Registration status      |
| registeredAt      | timestamp | When registered          |
| createdAt         | timestamp | Created at               |
| updatedAt         | timestamp | Updated at               |
| eventAttendance   | map       | Check-in state           |
| flags             | map       | isWalkIn, validationWarnings |

**eventAttendance:**

| Field      | Type      |
|------------|-----------|
| checkedIn  | bool      |
| checkedInAt| timestamp?|
| checkedInBy| string?   |

**flags:**

| Field              | Type   |
|--------------------|--------|
| isWalkIn           | bool   |
| hasValidationWarnings | bool |
| validationWarnings | array  |

**Dart model:** `Registrant`, `EventAttendance`, `RegistrantFlags`

---

### Session

**Path:** `events/{eventId}/sessions/{sessionId}`

| Field  | Type      | Description |
|--------|-----------|-------------|
| title  | string    | Session name |
| startAt| timestamp | Start time   |
| endAt  | timestamp | End time     |
| type   | string?   | Session type |

**Dart model:** `Session`

---

### Session Attendance

**Path:** `events/{eventId}/sessions/{sessionId}/attendance/{registrantId}`

| Field       | Type      | Description    |
|-------------|-----------|----------------|
| checkedInAt | timestamp | When checked in|
| checkedInBy | string?   | Who checked in |

**Dart model:** `SessionAttendance`

---

### Formation Signal

**Path:** `events/{eventId}/formationSignals/{registrantId}`

| Field        | Type      | Description       |
|--------------|-----------|-------------------|
| eventId      | string    | Event reference   |
| registrantId | string    | Registrant ref    |
| tags         | array     | Derived tags      |
| updatedAt    | timestamp | Last computed     |

**Dart model:** `FormationSignal`

---

### Import Mapping

**Path:** `events/{eventId}/importMappings/{mappingId}`

| Field     | Type  | Description                    |
|-----------|-------|--------------------------------|
| mapping   | map   | CSV header → schema key map    |
| updatedAt | timestamp | Last saved                  |

**Dart model:** `ImportMapping`

---

## Dart Model Files

| Model | File |
|-------|------|
| Event | `lib/src/models/event.dart` |
| RegistrationSchema | `lib/src/models/registration_schema.dart` |
| SchemaField | `lib/src/models/schema_field.dart` |
| RoleOverrides | `lib/src/models/role_override.dart` |
| Registrant | `lib/src/models/registrant.dart` |
| Session | `lib/src/models/session.dart` |
| SessionAttendance | `lib/src/models/session_attendance.dart` |
| FormationSignal | `lib/src/models/formation_signal.dart` |
| ImportMapping | `lib/src/models/import_mapping.dart` |

---

## Enabling Firestore

1. Firebase Console → Project **aisaiah-event-hub** → Firestore Database
2. Click **Create database**
3. Choose production or test mode (rules will be deployed via CLI)
4. Select region

Then deploy rules and indexes:

```bash
firebase deploy --only firestore
```
