# Firestore Database Names (Permanent)

**Do not change these.** The Event Hub project uses named Firestore databases:

| Environment | Database ID |
|-------------|-------------|
| DEV | `event-hub-dev` |
| PROD | `event-hub-prod` |

## Rules

- **Never use** the `(default)` database for Event Hub data
- All code, config, and docs must reference `event-hub-dev` and `event-hub-prod`
- `FirestoreConfig` (`lib/src/config/firestore_config.dart`) maps `AppEnvironment.dev` → `event-hub-dev`, `AppEnvironment.prod` → `event-hub-prod`

## References

- `firebase.json` — Firestore rules/indexes for these databases
- `lib/src/config/firestore_config.dart` — `databaseId` getter
- `.cursor/rules/firestore-databases.mdc` — Cursor rule enforcing this
