#!/usr/bin/env bash
# Export Firestore data model to docs/FIRESTORE_DATA_MODEL.md.
# Run from project root. When you get a Firestore error, run this and check the doc:
#   ./scripts/export_firestore_data_model.sh
# then open docs/FIRESTORE_DATA_MODEL.md and verify the failing path's PARENT exists.

set -e
cd "$(dirname "$0")/.."
dart scripts/firestore_data_model.dart
