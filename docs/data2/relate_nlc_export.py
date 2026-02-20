#!/usr/bin/env python3
"""
Relate NLC (main source) and Export CSVs.
Run only when source data (NLC or Export CSV) changes.
- Pre-processing: resolve spouse last names (no Flocknote ID, same confirmation as
  previous row, blank last name). Extracts last name from first name field.
  If first name is a single token with no parseable last name, inherits previous
  row's last name (spouse fallback).
- Pass 1a: exact match (email, then first+last name). Last names are normalized:
  parentheticals stripped (e.g. "Lacson (personal)" → "Lacson") and internal spaces
  removed for compound names (e.g. "De Vega" / "DeVega" → "devega").
  Also tries first word of first name (e.g. "Inying Grace" → "Inying").
- Pass 1b: possible match by last name only to NLC with no match.
- Pass 1c: fuzzy last name match (Damerau–Levenshtein ≤ 1) when first word of first
  name matches exactly — catches single-letter typos like "Arcaido" vs "Arcadio".
Output: nlc_main.csv, export_matched_to_nlc.csv, export_still_not_in_nlc.csv.
Never writes to export_not_in_nlc.csv.
"""
import csv
import hashlib
import os
import re
import uuid
from typing import Optional

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
NLC_PATH = os.path.join(SCRIPT_DIR, "NLC 2026 Registration as of 2-16-26.csv")
EXPORT_PATH = os.path.join(SCRIPT_DIR, "Export-20260219-DIGNITAS INFINITA BREAKOUT SESSIONS.csv")
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


def clean_last(s: str) -> str:
    """Strip parenthetical annotations from last name (e.g. 'Lacson (personal)' → 'Lacson')."""
    return re.sub(r'\s*\(.*?\)', '', s or '').strip()


def normalize_last(s: str) -> str:
    """Normalize last name: strip parentheticals, lowercase, remove internal spaces.
    Handles compound names like 'De Vega' / 'DeVega' → 'devega'."""
    return normalize(clean_last(s)).replace(' ', '')


def first_word(s: str) -> str:
    """Return the first whitespace token of a normalized string."""
    parts = normalize(s).split()
    return parts[0] if parts else ""


def damerau_levenshtein(a: str, b: str) -> int:
    """Damerau–Levenshtein distance (counts adjacent transpositions as cost 1)."""
    la, lb = len(a), len(b)
    if la == 0:
        return lb
    if lb == 0:
        return la
    prev2 = list(range(lb + 1))
    prev = list(range(lb + 1))
    for i in range(1, la + 1):
        curr = [i] + [0] * lb
        for j in range(1, lb + 1):
            cost = 0 if a[i - 1] == b[j - 1] else 1
            curr[j] = min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost)
            if i > 1 and j > 1 and a[i - 1] == b[j - 2] and a[i - 2] == b[j - 1]:
                curr[j] = min(curr[j], prev2[j - 2] + cost)
        prev2, prev = prev, curr
    return prev[lb]


def name_key(first: str, last: str) -> str:
    """Build a match key using normalized last name (no spaces, no parens) and normalized first name."""
    return f"{normalize_last(last)}|{normalize(first)}"


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


def _looks_like_email(s: str) -> bool:
    return "@" in s


def resolve_spouse_names(rows: list[dict]) -> None:
    """
    For rows with no Flocknote ID and the same Confirmation Number as the
    previous row (spouse/companion pattern), attempt to fill in a blank
    Last Name:

      Step 1 — prev-last extraction:
        If the previous row's Last Name appears (case-insensitive) inside the
        current First Name field, use that as Last Name and remove it from
        First Name.

      Step 2 — space-split fallback:
        Otherwise split First Name by spaces.
        - 2 tokens  → last token = Last Name, first token = First Name.
        - 3+ tokens → last token = Last Name, all preceding tokens joined
                      with a space = First Name.
        - 1 token / email → leave unchanged (can't determine last name).

    Mutates rows in-place. Skips rows where Last Name is already present.
    """
    for i, row in enumerate(rows):
        if i == 0:
            continue

        flocknote_id = (row.get("Flocknote ID") or "").strip()
        conf = (row.get("Confirmation Number") or "").strip()
        prev = rows[i - 1]
        prev_conf = (prev.get("Confirmation Number") or "").strip()

        # Only process spouse rows: no Flocknote ID, same confirmation number
        if flocknote_id or not conf or conf != prev_conf:
            continue

        last = (row.get(EXPORT_LAST) or "").strip()
        if last:
            # Last name already present — nothing to infer
            continue

        first = (row.get(EXPORT_FIRST) or "").strip()
        if not first or _looks_like_email(first):
            continue

        prev_last = (prev.get(EXPORT_LAST) or "").strip()

        # Step 1: check if prev_last is embedded in the first-name field
        if prev_last and prev_last.lower() in first.lower():
            pattern = re.compile(re.escape(prev_last), re.IGNORECASE)
            new_first = pattern.sub("", first).strip()
            row[EXPORT_FIRST] = new_first
            row[EXPORT_LAST] = prev_last
            continue

        # Step 2: split by spaces and use last token as last name
        parts = first.split()
        if len(parts) >= 2:
            row[EXPORT_LAST] = parts[-1]
            row[EXPORT_FIRST] = " ".join(parts[:-1])
        elif len(parts) == 1 and prev_last:
            # Step 3: single-token first name, can't split — inherit spouse's last name
            row[EXPORT_LAST] = prev_last


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
        nl = normalize_last(last)
        if nl:
            nlc_by_last_only.setdefault(nl, []).append(row)

    exp_headers, exp_rows = read_csv(EXPORT_PATH)

    # Pre-process: infer last names for spouse/companion rows before matching
    resolve_spouse_names(exp_rows)

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
        # Exact name match — normalize_last handles compound spaces and parentheticals
        key = name_key(first, last)
        if key:
            candidates = nlc_by_name.get(key, [])
            if candidates:
                return candidates[0], "exact_match", "name" if len(candidates) == 1 else "name (multiple NLC)"
        # Try first word of first name (e.g. "Inying Grace" → "Inying")
        fw = first_word(first)
        if fw and fw != normalize(first):
            key2 = name_key(fw, last)
            if key2:
                candidates = nlc_by_name.get(key2, [])
                if candidates:
                    return candidates[0], "exact_match", "name (first word match)" if len(candidates) == 1 else "name (first word, multiple NLC)"
        last_n = normalize_last(last)
        if last_n:
            candidates = nlc_by_last_only.get(last_n, [])
            if len(candidates) == 1:
                return candidates[0], "possible_match", "last_name_only (only one in NLC)"
        return None, "", ""

    def try_match_last_name_only(row: dict, matched_nlc_ids: set[str]) -> tuple[Optional[dict], str, str]:
        last_n = normalize_last((row.get(EXPORT_LAST) or "").strip())
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

    def try_match_fuzzy_last(row: dict, matched_nlc_ids: set[str]) -> tuple[Optional[dict], str, str]:
        """Pass 1c: fuzzy last name (DL distance ≤ 1) when first word of first name matches exactly.
        Catches single-letter typos like 'Arcaido' vs 'Arcadio'."""
        exp_last = normalize_last((row.get(EXPORT_LAST) or "").strip())
        exp_first_w = first_word((row.get(EXPORT_FIRST) or "").strip())
        if not exp_last or not exp_first_w or len(exp_last) < 4:
            return None, "", ""
        best: Optional[dict] = None
        best_dist = 2
        for nlc_last_key, candidates in nlc_by_last_only.items():
            dist = damerau_levenshtein(exp_last, nlc_last_key)
            if dist < best_dist:
                for c in candidates:
                    if c["id"] in matched_nlc_ids:
                        continue
                    nlc_first_w = first_word((c.get(NLC_FIRST) or "").strip())
                    if nlc_first_w == exp_first_w:
                        best = c
                        best_dist = dist
        if best is not None:
            return best, "possible_match", f"fuzzy last name (dist={best_dist})"
        return None, "", ""

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

    # Pass 1c: fuzzy last name (DL ≤ 1) + exact first word — catches single-letter typos
    still_not_found = []
    for row in not_found:
        nlc_row, match_type, match_by = try_match_fuzzy_last(row, matched_nlc_ids)
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
