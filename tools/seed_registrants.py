#!/usr/bin/env python3
"""
Seed NLC registrants from CSV to Firestore (event-hub-dev).

Usage:
  pip install -r tools/requirements.txt
  python tools/seed_registrants.py                          # uses tools/nlc_registrants.csv
  python tools/seed_registrants.py tools/sample_nlc_registrants.csv
  python tools/seed_registrants.py --database event-hub-dev  # explicit database
  python tools/seed_registrants.py --database '(default)'    # use default database

Requires: Firebase service account key.
  Option 1: GOOGLE_APPLICATION_CREDENTIALS env var pointing to the JSON key file.
  Option 2: --key /path/to/serviceAccountKey.json
  Option 3: gcloud auth application-default login (uses ADC)
"""

import argparse
import csv
import os
import sys
from datetime import datetime, timezone

import firebase_admin
from firebase_admin import credentials, firestore

EVENT_ID = "nlc-2026"

# Map CSV headers to schema keys
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
    # Simple headers (sample CSV)
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
    return h.strip().lower()


def map_header(h):
    n = normalize_header(h)
    return HEADER_MAP.get(n, n.replace(" ", "_"))


def make_doc_id(index, row):
    """Generate a stable document ID from row data."""
    parts = []
    for key in ["email", "cfcId", "firstName", "lastName"]:
        val = row.get(key, "")
        if val:
            parts.append(val.strip().lower().replace(" ", "-").replace("@", "-at-")[:20])
    if parts:
        return "-".join(parts)[:60]
    return f"registrant-{index}"


def read_csv(path):
    """Read CSV and return list of dicts with mapped keys."""
    rows = []
    with open(path, newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for raw in reader:
            mapped = {}
            for header, value in raw.items():
                if not header or not value or not value.strip():
                    continue
                key = map_header(header)
                mapped[key] = value.strip()
            if mapped:
                rows.append(mapped)
    return rows


def seed(db, rows):
    """Write rows to Firestore."""
    collection = db.collection(f"events/{EVENT_ID}/registrants")
    now = datetime.now(timezone.utc)
    imported = 0
    skipped = 0

    for i, row in enumerate(rows):
        profile = {}
        answers = {}
        for key, value in row.items():
            if key in PROFILE_KEYS:
                profile[key] = value
            else:
                answers[key] = value

        doc_id = make_doc_id(i, row)
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

        try:
            collection.document(doc_id).set(doc_data, merge=True)
            imported += 1
            if (i + 1) % 50 == 0:
                print(f"  Progress: {i + 1}/{len(rows)}")
        except Exception as e:
            skipped += 1
            print(f"  Row {i + 2}: {e}")

    return imported, skipped


def main():
    parser = argparse.ArgumentParser(description="Seed NLC registrants to Firestore")
    parser.add_argument("csv_file", nargs="?", default="tools/nlc_registrants.csv",
                        help="Path to CSV file (default: tools/nlc_registrants.csv)")
    parser.add_argument("--database", default="event-hub-dev",
                        help="Firestore database ID (default: event-hub-dev)")
    parser.add_argument("--key", default=None,
                        help="Path to Firebase service account key JSON")
    parser.add_argument("--project", default="aisaiah-event-hub",
                        help="Firebase project ID")
    parser.add_argument("--dry-run", action="store_true",
                        help="Parse CSV and print stats without writing")
    args = parser.parse_args()

    # Read CSV
    if not os.path.exists(args.csv_file):
        print(f"Error: File not found: {args.csv_file}")
        sys.exit(1)

    rows = read_csv(args.csv_file)
    print(f"Read {len(rows)} registrants from {args.csv_file}")

    if not rows:
        print("No data rows found.")
        sys.exit(0)

    if args.dry_run:
        print(f"Dry run: would import {len(rows)} registrants to events/{EVENT_ID}/registrants")
        for i, row in enumerate(rows[:3]):
            print(f"  Sample {i + 1}: {row}")
        sys.exit(0)

    # Initialize Firebase Admin
    if args.key:
        cred = credentials.Certificate(args.key)
    elif os.environ.get("GOOGLE_APPLICATION_CREDENTIALS"):
        cred = credentials.ApplicationDefault()
    else:
        # Try Application Default Credentials (gcloud auth application-default login)
        cred = credentials.ApplicationDefault()

    firebase_admin.initialize_app(cred, {"projectId": args.project})

    # Get Firestore client for the specified database
    db = firestore.client(database_id=args.database)

    print(f"Target: project={args.project}, database={args.database}")
    print(f"Collection: events/{EVENT_ID}/registrants")
    print(f"Writing {len(rows)} registrants...")

    imported, skipped = seed(db, rows)
    print(f"\nDone. Imported: {imported}, Skipped: {skipped}")


if __name__ == "__main__":
    main()
