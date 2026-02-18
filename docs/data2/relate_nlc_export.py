#!/usr/bin/env python3
"""
Relate NLC (main source) and Export CSVs.
Run only when source data (NLC or Export CSV) changes.
- Pass 1a: exact match (email, then first+last name).
- Pass 1b: possible match by last name only to NLC with no match.
Output: nlc_main.csv, export_matched_to_nlc.csv, export_still_not_in_nlc.csv.
Never writes to export_not_in_nlc.csv.
"""
import csv
import hashlib
import os
import uuid
from typing import Optional

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
NLC_PATH = os.path.join(SCRIPT_DIR, "NLC 2026 Registration as of 2-16-26.csv")
EXPORT_PATH = os.path.join(SCRIPT_DIR, "Export-20260217-DIGNITAS INFINITA BREAKOUT SESSIONS.csv")
NLC_MAIN_PATH = os.path.join(SCRIPT_DIR, "nlc_main.csv")
EXPORT_MATCHED_PATH = os.path.join(SCRIPT_DIR, "export_matched_to_nlc.csv")
EXPORT_STILL_NOT_IN_NLC_PATH = os.path.join(SCRIPT_DIR, "export_still_not_in_nlc.csv")

NLC_FIRST = "Registrant - Person's Name - First Name"
NLC_LAST = "Registrant - Person's Name - Last Name"
NLC_EMAIL = "Registrant - Email"
EXPORT_FIRST = "First Name"
EXPORT_LAST = "Last Name"
EXPORT_PREFIX = "export_"


def normalize(s: str) -> str:
    if not s or not isinstance(s, str):
        return ""
    return s.strip().lower()


def name_key(first: str, last: str) -> str:
    return f"{normalize(last)}|{normalize(first)}"


def unique_id(*parts: str) -> str:
    combined = "|".join(p or "" for p in parts)
    if not combined.strip():
        return "id_" + uuid.uuid4().hex[:12]
    h = hashlib.sha256(combined.strip().lower().encode("utf-8")).hexdigest()
    return "nlc_" + h[:12]


def read_csv(path: str) -> tuple[list[str], list[dict]]:
    with open(path, newline="", encoding="utf-8-sig", errors="replace") as f:
        reader = csv.DictReader(f)
        headers = reader.fieldnames or []
        rows = list(reader)
    return headers, rows


def write_csv(path: str, headers: list[str], rows: list[dict]) -> None:
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=headers, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)


def main() -> None:
    nlc_headers, nlc_rows = read_csv(NLC_PATH)
    if "id" not in nlc_headers:
        nlc_headers = ["id"] + list(nlc_headers)

    nlc_by_email: dict[str, list[dict]] = {}
    nlc_by_name: dict[str, list[dict]] = {}
    nlc_by_last_only: dict[str, list[dict]] = {}

    for row in nlc_rows:
        first = (row.get(NLC_FIRST) or "").strip()
        last = (row.get(NLC_LAST) or "").strip()
        email = (row.get(NLC_EMAIL) or "").strip()
        nid = unique_id(email or "", first, last)
        row["id"] = nid
        if email:
            nlc_by_email.setdefault(normalize(email), []).append(row)
        key = name_key(first, last)
        if key:
            nlc_by_name.setdefault(key, []).append(row)
        if normalize(last):
            nlc_by_last_only.setdefault(normalize(last), []).append(row)

    exp_headers, exp_rows = read_csv(EXPORT_PATH)
    matched_headers = ["nlc_id", "match_type", "match_by"] + list(exp_headers)
    not_found_headers = ["export_id", "match_type", "match_by"] + list(exp_headers)
    nlc_matched_export: dict[str, tuple[str, dict]] = {}
    matched: list[dict] = []
    not_found: list[dict] = []

    def try_match(row: dict, first: str, last: str, email_from_export: str) -> tuple[Optional[dict], str, str]:
        if email_from_export:
            candidates = nlc_by_email.get(normalize(email_from_export), [])
            if candidates:
                return candidates[0], "exact_match", "email" if len(candidates) == 1 else "email (multiple NLC)"
        key = name_key(first, last)
        if key:
            candidates = nlc_by_name.get(key, [])
            if candidates:
                return candidates[0], "exact_match", "name" if len(candidates) == 1 else "name (multiple NLC)"
        last_n = normalize(last)
        if last_n:
            candidates = nlc_by_last_only.get(last_n, [])
            if len(candidates) == 1:
                return candidates[0], "possible_match", "last_name_only (only one in NLC)"
        return None, "", ""

    def try_match_last_name_only(row: dict, matched_nlc_ids: set[str]) -> tuple[Optional[dict], str, str]:
        last_n = normalize((row.get(EXPORT_LAST) or "").strip())
        if not last_n:
            return None, "", ""
        candidates = nlc_by_last_only.get(last_n, [])
        unmatched = [c for c in candidates if c["id"] not in matched_nlc_ids]
        if not unmatched:
            return None, "", ""
        chosen = unmatched[0]
        if len(unmatched) == 1 and len(candidates) == 1:
            return chosen, "possible_match", "possible match by lastname (only one in NLC)"
        if len(unmatched) == 1:
            return chosen, "possible_match", "possible match by lastname (only one NLC with no match)"
        return chosen, "possible_match", "possible match by lastname (matched to NLC with no match)"

    matched_nlc_ids: set[str] = set()

    for row in exp_rows:
        first = (row.get(EXPORT_FIRST) or "").strip()
        last = (row.get(EXPORT_LAST) or "").strip()
        email_from_export = first if first and "@" in first else ""
        if email_from_export:
            first = ""
        nlc_row, match_type, match_by = try_match(row, first, last, email_from_export)
        if nlc_row is not None:
            nid = nlc_row["id"]
            matched_nlc_ids.add(nid)
            row["nlc_id"] = nid
            row["match_type"] = match_type
            row["match_by"] = match_by
            matched.append(row)
            existing = nlc_matched_export.get(nid)
            if not existing or (existing[0] == "possible_match" and match_type == "exact_match"):
                nlc_matched_export[nid] = (match_type, row)
        else:
            row["export_id"] = "export_" + uuid.uuid4().hex[:12]
            row["match_type"] = ""
            row["match_by"] = ""
            not_found.append(row)

    still_not_found: list[dict] = []
    for row in not_found:
        nlc_row, match_type, match_by = try_match_last_name_only(row, matched_nlc_ids)
        if nlc_row is not None:
            nid = nlc_row["id"]
            row["nlc_id"] = nid
            row["match_type"] = match_type
            row["match_by"] = match_by
            matched.append(row)
            if nlc_matched_export.get(nid, (None,))[0] != "exact_match":
                nlc_matched_export[nid] = (match_type, row)
            matched_nlc_ids.add(nid)
        else:
            still_not_found.append(row)
    not_found = still_not_found

    match_headers = ["match_type", "match_by_comment"]
    export_col_headers = [
        EXPORT_PREFIX + "Flocknote_ID", EXPORT_PREFIX + "First_Name", EXPORT_PREFIX + "Last_Name",
        EXPORT_PREFIX + "Confirmation_Number", EXPORT_PREFIX + "Gender_Identity_Dialogue",
        EXPORT_PREFIX + "Contraception_Dialogue", EXPORT_PREFIX + "Immigration_Dialogue",
        EXPORT_PREFIX + "Signed_Up_Date",
    ]
    nlc_main_headers = [nlc_headers[0]] + match_headers + nlc_headers[1:] + export_col_headers

    for nlc_row in nlc_rows:
        nid = nlc_row.get("id", "")
        for col in match_headers + export_col_headers:
            nlc_row.setdefault(col, "")
        if nid in nlc_matched_export:
            match_type, exp_row = nlc_matched_export[nid]
            nlc_row["match_type"] = match_type
            nlc_row["match_by_comment"] = (
                "exact_match: email or first+last name" if match_type == "exact_match"
                else (exp_row.get("match_by") or "possible match by lastname")
            )
            nlc_row[EXPORT_PREFIX + "Flocknote_ID"] = exp_row.get("Flocknote ID", "")
            nlc_row[EXPORT_PREFIX + "First_Name"] = exp_row.get(EXPORT_FIRST, "")
            nlc_row[EXPORT_PREFIX + "Last_Name"] = exp_row.get(EXPORT_LAST, "")
            nlc_row[EXPORT_PREFIX + "Confirmation_Number"] = exp_row.get("Confirmation Number", "")
            nlc_row[EXPORT_PREFIX + "Gender_Identity_Dialogue"] = exp_row.get("Gender Identity, Homosexuality, and Same Sex Attraction Dialogue", "")
            nlc_row[EXPORT_PREFIX + "Contraception_Dialogue"] = exp_row.get("Contraception/IVF/Abortion Dialogue", "")
            nlc_row[EXPORT_PREFIX + "Immigration_Dialogue"] = exp_row.get("Immigration Dialogue", "")
            nlc_row[EXPORT_PREFIX + "Signed_Up_Date"] = exp_row.get("Signed Up Date", "")

    write_csv(NLC_MAIN_PATH, nlc_main_headers, nlc_rows)
    print(f"Wrote {len(nlc_rows)} rows to {os.path.basename(NLC_MAIN_PATH)}")
    write_csv(EXPORT_MATCHED_PATH, matched_headers, matched)
    print(f"Wrote {len(matched)} matched rows to {os.path.basename(EXPORT_MATCHED_PATH)}")
    write_csv(EXPORT_STILL_NOT_IN_NLC_PATH, not_found_headers, not_found)
    print(f"Wrote {len(not_found)} still-not-in-NLC rows to {os.path.basename(EXPORT_STILL_NOT_IN_NLC_PATH)}")


if __name__ == "__main__":
    main()
