#!/usr/bin/env python3
"""
Seed NLC registrants and session registrations from CSV to Firestore.

Runs bootstrap first: ensures event doc and sessions exist (main-checkin with isMain=true
+ dialogue sessions), so you don't need to run ensure-nlc-event-doc.js separately.

Usage:
  pip install -r tools/requirements.txt
  python tools/seed_registrants.py docs/data2/nlc_main_clean.csv
  python tools/seed_registrants.py docs/data2/nlc_main_clean.csv --clear-first
  python tools/seed_registrants.py docs/data2/nlc_main_clean.csv --database "(default)"
  python tools/seed_registrants.py --dry-run                 # parse only, no write

Session registrations: When CSV has columns export_Gender_Identity_Dialogue,
export_Contraception_Dialogue, export_Immigration_Dialogue, any cell with "X"
means the registrant is pre-registered to that session.

Requires: Firebase credentials (re-auth if you see "Reauthentication is needed").
  gcloud auth application-default login
  Or: GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json
  Or: --key /path/to/key.json

With valid auth, 453 registrants + session regs typically finish in 15–45 seconds
(batches of 100; clear-first adds a few seconds).
"""

# Suppress noisy library warnings (Python EOL, OpenSSL, etc.) so real errors are visible
import warnings
warnings.filterwarnings("ignore", category=FutureWarning)
warnings.filterwarnings("ignore", message=".*OpenSSL.*")
warnings.filterwarnings("ignore", message=".*LibreSSL.*")
warnings.filterwarnings("ignore", module="urllib3")

import argparse
import csv
import os
import sys
from datetime import datetime, timezone

import firebase_admin
from firebase_admin import credentials, firestore

EVENT_ID = "nlc-2026"

# Session column (CSV header, normalized) -> Firestore session ID
SESSION_COLUMN_TO_ID = {
    "export_gender_identity_dialogue": "gender-ideology-dialogue",
    "export_contraception_dialogue": "contraception-ivf-abortion-dialogue",
    "export_immigration_dialogue": "immigration-dialogue",
}

# Map CSV headers to schema keys (normalized header -> schema key)
HEADER_MAP = {
    "registrant - person's name - first name": "firstName",
    "registrant - person's name - last name": "lastName",
    "registrant - email": "email",
    "registrant - phone number": "phone",
    "registrant - allergies & special need": "allergies",
    "region": "region",
    "region - other text": "regionOther",
    "ministry membership": "ministry",
    "service": "service",
    "have kids to register for kidszone? (ages 4 - 12 yrs old)": "hasKids",
    "how many kids for kidswatch?": "kidsCount",
    "billing discount code": "discountCode",
    "member id": "cfcId",
    "firstname": "firstName",
    "lastname": "lastName",
    "email": "email",
    "phone": "phone",
    "cfcid": "cfcId",
    "unit": "unit",
    "role": "role",
    "chapter": "unit",
}

PROFILE_KEYS = {"firstName", "lastName", "email", "phone", "cfcId", "name", "unit", "role"}


def normalize_header(h):
    """Lowercase for lookup; preserve spaces for HEADER_MAP."""
    return h.strip().lower()


def map_header(h):
    n = normalize_header(h)
    if n in HEADER_MAP:
        return HEADER_MAP[n]
    return n.replace(" ", "_").replace("-", "_")


def make_doc_id(index, row):
    """Use CSV 'id' column when present (e.g. nlc_xxx); else derive from row."""
    doc_id = row.get("id", "").strip()
    if doc_id:
        return doc_id
    parts = []
    for key in ["email", "cfcId", "firstName", "lastName"]:
        val = row.get(key, "")
        if val:
            parts.append(str(val).strip().lower().replace(" ", "-").replace("@", "-at-")[:20])
    if parts:
        return "-".join(parts)[:60]
    return f"registrant-{index}"


def session_ids_from_row(row):
    """Return list of session IDs for which the row has 'X' in the export column."""
    out = []
    for col_norm, session_id in SESSION_COLUMN_TO_ID.items():
        val = row.get(col_norm, "").strip().upper() if row.get(col_norm) else ""
        if val == "X":
            out.append(session_id)
    return out


def read_csv(path):
    """Read CSV; return list of dicts with normalized/mapped keys (preserves export_* columns)."""
    rows = []
    with open(path, newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for raw in reader:
            mapped = {}
            for header, value in raw.items():
                if not header:
                    continue
                key = map_header(header)
                # Keep non-empty values; for session columns keep "X" etc.
                if value is not None and str(value).strip() != "":
                    mapped[key] = str(value).strip()
            if mapped:
                rows.append(mapped)
    return rows


# Event + sessions bootstrap (same as ensure-nlc-event-doc.js). Merge so we don't overwrite attendanceCount.
# Official breakout colors: Gender Identity (Blue), Abortion & Contraception (Orange), Immigration (Yellow).
BOOTSTRAP_SESSIONS = [
    {"id": "main-checkin", "name": "Main Check-In", "location": "Registration", "capacity": 0, "colorHex": "#1E3A5F", "order": 0, "isMain": True},
    {"id": "gender-ideology-dialogue", "name": "Gender Ideology Dialogue", "location": "Main Ballroom", "capacity": 450, "colorHex": "#2563EB", "order": 1, "isMain": False},
    {"id": "immigration-dialogue", "name": "Immigration Dialogue", "location": "Valencia Ballroom", "capacity": 192, "colorHex": "#EAB308", "order": 2, "isMain": False},
    {"id": "contraception-ivf-abortion-dialogue", "name": "Contraception/IVF/Abortion Dialogue", "location": "Saugus/Castaic", "capacity": 72, "colorHex": "#EA580C", "order": 3, "isMain": False},
]


def ensure_event_and_sessions(db):
    """Ensure event doc and session docs (including main-checkin with isMain=true) exist. Merge."""
    now = datetime.now(timezone.utc)
    events = db.collection("events")
    event_ref = events.document(EVENT_ID)
    event_ref.set({
        "name": "National Leaders Conference 2026",
        "slug": "nlc-2026",
        "venue": "Hyatt Regency Valencia",
        "createdAt": now,
        "isActive": True,
        "metadata": {"selfCheckinEnabled": True, "sessionsEnabled": True},
    }, merge=True)
    print("  Event: events/nlc-2026", flush=True)
    sessions_ref = event_ref.collection("sessions")
    for s in BOOTSTRAP_SESSIONS:
        ref = sessions_ref.document(s["id"])
        # Merge: set capacity/location/colorHex/name so UI shows remaining seats.
        # Do NOT send attendanceCount so existing check-in counts are preserved when re-running seed.
        # New session docs have no attendanceCount field; app treats missing as 0.
        ref.set({
            "name": s["name"],
            "location": s.get("location", ""),
            "order": s["order"],
            "isActive": True,
            "isMain": s.get("isMain", False),
            "capacity": s.get("capacity", 0),
            "status": "open",
            "colorHex": s.get("colorHex", ""),
        }, merge=True)
    print(f"  Sessions: main-checkin (isMain=true) + {len(BOOTSTRAP_SESSIONS) - 1} dialogue sessions", flush=True)


def clear_registration_data(db):
    """Delete all docs in registrants and sessionRegistrations for the event."""
    batch_size = 500
    for coll_name in ("registrants", "sessionRegistrations"):
        coll = db.collection(f"events/{EVENT_ID}/{coll_name}")
        total = 0
        while True:
            docs = coll.limit(batch_size).stream()
            to_del = list(docs)
            if not to_del:
                break
            batch = db.batch()
            for d in to_del:
                batch.delete(d.reference)
                total += 1
            batch.commit()
        print(f"  Cleared {total} documents from events/{EVENT_ID}/{coll_name}", flush=True)
    print("Cleared registrants and sessionRegistrations.", flush=True)


def seed_registrants(db, rows):
    """Write registrant docs in batches (max 500 per batch). Returns (imported, skipped), doc_ids."""
    collection = db.collection(f"events/{EVENT_ID}/registrants")
    now = datetime.now(timezone.utc)
    doc_ids = []
    pending = []  # list of (doc_ref, doc_data)

    for i, row in enumerate(rows):
        profile = {}
        answers = {}
        for key, value in row.items():
            if key in PROFILE_KEYS:
                profile[key] = value
            elif key not in ("id",) and not key.startswith("export_"):
                answers[key] = value

        doc_id = make_doc_id(i, row)
        doc_ids.append((i, doc_id))
        doc_data = {
            "profile": profile,
            "answers": answers,
            "source": "import",
            "registrationStatus": "registered",
            "registeredAt": now,
            "createdAt": now,
            "updatedAt": now,
            "eventAttendance": {"checkedIn": False},
            "flags": {"isWalkIn": False, "hasValidationWarnings": False},
        }
        pending.append((collection.document(doc_id), doc_data))

    # Commit in batches (100 per batch = faster feedback, avoids huge single commit)
    imported = 0
    batch_size = 100
    for start in range(0, len(pending), batch_size):
        batch = db.batch()
        chunk = pending[start : start + batch_size]
        for ref, data in chunk:
            batch.set(ref, data, merge=True)
            imported += 1
        batch.commit()
        print(f"  Registrants: {imported}/{len(rows)}", flush=True)
    return imported, 0, doc_ids


def seed_session_registrations(db, rows, doc_ids):
    """Write sessionRegistrations in batches for rows with X in export_*_Dialogue."""
    coll = db.collection(f"events/{EVENT_ID}/sessionRegistrations")
    now = datetime.now(timezone.utc)
    pending = []
    print("Seeding session registrations (export_*_Dialogue = X → sessionIds)...")
    for (i, doc_id), row in zip(doc_ids, rows):
        session_ids = session_ids_from_row(row)
        if not session_ids:
            continue
        pending.append((doc_id, {
            "registrantId": doc_id,
            "sessionIds": session_ids,
            "updatedAt": now,
        }))
    if not pending:
        print("Session registrations written: 0", flush=True)
        return 0
    for n, (doc_id, data) in enumerate(pending[:5]):
        print(f"  Session reg {n + 1}: {doc_id} → {', '.join(data['sessionIds'])}", flush=True)
    batch_size = 100
    for start in range(0, len(pending), batch_size):
        batch = db.batch()
        for doc_id, data in pending[start : start + batch_size]:
            batch.set(coll.document(doc_id), data)
        batch.commit()
    print(f"Session registrations written: {len(pending)}", flush=True)
    return len(pending)


def main():
    parser = argparse.ArgumentParser(description="Seed NLC registrants and session registrations to Firestore")
    parser.add_argument("csv_file", nargs="?", default="docs/data2/nlc_main_clean.csv",
                        help="Path to CSV (default: docs/data2/nlc_main_clean.csv)")
    parser.add_argument("--database", default="(default)",
                        help="Firestore database ID (default: (default) to match app)")
    parser.add_argument("--key", default=None,
                        help="Path to Firebase service account key JSON")
    parser.add_argument("--project", default="aisaiah-event-hub",
                        help="Firebase project ID")
    parser.add_argument("--clear-first", action="store_true",
                        help="Delete all registrants and sessionRegistrations before seeding")
    parser.add_argument("--dry-run", action="store_true",
                        help="Parse CSV and print stats without writing")
    args = parser.parse_args()

    if not os.path.exists(args.csv_file):
        print(f"Error: File not found: {args.csv_file}")
        sys.exit(1)

    rows = read_csv(args.csv_file)
    print(f"Read {len(rows)} rows from {args.csv_file}", flush=True)

    if not rows:
        print("No data rows found.")
        sys.exit(0)

    if args.dry_run:
        sample = rows[0]
        session_ids = session_ids_from_row(sample)
        print(f"Dry run: would import {len(rows)} registrants to events/{EVENT_ID}/registrants")
        print(f"  Sample doc_id: {make_doc_id(0, sample)}")
        print(f"  Sample session_ids from first row: {session_ids}")
        sys.exit(0)

    # Initialize Firebase (fail fast if auth is missing/expired)
    try:
        if args.key:
            cred = credentials.Certificate(args.key)
        else:
            cred = credentials.ApplicationDefault()
    except Exception as e:
        print("Firebase credentials failed.", flush=True)
        print("  Run: gcloud auth application-default login", flush=True)
        print("  Or set GOOGLE_APPLICATION_CREDENTIALS or use --key /path/to/serviceAccountKey.json", flush=True)
        print(e, flush=True)
        sys.exit(1)

    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred, {"projectId": args.project})

    db = firestore.client(database_id=args.database)
    print(f"Target: project={args.project}, database={args.database}", flush=True)

    print("Ensuring event and sessions exist (bootstrap)...", flush=True)
    ensure_event_and_sessions(db)

    if args.clear_first:
        print("Clearing existing data...", flush=True)
        clear_registration_data(db)

    print(f"Writing {len(rows)} registrants (batches of 100)...", flush=True)
    imported, skipped, doc_ids = seed_registrants(db, rows)
    print(f"Registrants: imported={imported}, skipped={skipped}")

    session_count = seed_session_registrations(db, rows, doc_ids)
    print(f"\nDone. Registrants: {imported}, Session registrations: {session_count}", flush=True)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print("Error:", e, flush=True)
        raise
