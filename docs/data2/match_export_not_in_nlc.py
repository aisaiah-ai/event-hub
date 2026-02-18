#!/usr/bin/env python3
"""
Run a "not in NLC" list against nlc_main (match by last name to NLC rows with no match).
READS input file only; never overwrites it.
- Still-not-matched → --output file (default: export_still_not_in_nlc_v2.csv)
- Newly matched → APPEND to export_matched_to_nlc.csv; update nlc_main.csv
- Sync: ensure every nlc_main "matched to NLC with no match" row is in export_matched_to_nlc.csv

Multiple passes: use previous output as next input:
  python3 match_export_not_in_nlc.py --input export_still_not_in_nlc_v2.csv --output export_still_not_in_nlc_v3.csv
"""
import argparse
import csv
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
NLC_MAIN_PATH = os.path.join(SCRIPT_DIR, "nlc_main.csv")
EXPORT_MATCHED_PATH = os.path.join(SCRIPT_DIR, "export_matched_to_nlc.csv")

NLC_LAST = "Registrant - Person's Name - Last Name"
EXPORT_FIRST = "First Name"
EXPORT_LAST = "Last Name"


def normalize(s: str) -> str:
    if not s or not isinstance(s, str):
        return ""
    return s.strip().lower()


def get_last_name(row: dict) -> str:
    last = (row.get(EXPORT_LAST) or "").strip()
    if last:
        return last
    first = (row.get(EXPORT_FIRST) or "").strip()
    if first:
        parts = first.split()
        return parts[-1] if parts else ""
    return ""


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


def append_to_matched(newly_matched: list[dict], new_headers: list[str], matched_path: str) -> None:
    existing: list[dict] = []
    headers: list[str] = []
    if os.path.exists(matched_path):
        with open(matched_path, newline="", encoding="utf-8-sig", errors="replace") as f:
            reader = csv.DictReader(f)
            headers = list(reader.fieldnames or [])
            existing = list(reader)
    if not headers and new_headers:
        headers = list(new_headers)
    write_csv(matched_path, headers, existing + newly_matched)


def main() -> None:
    parser = argparse.ArgumentParser(description="Match a 'not in NLC' list to nlc_main by last name (NLC with no match only).")
    parser.add_argument("--input", default="export_not_in_nlc.csv", help="Input CSV (read only; never overwritten). Default: export_not_in_nlc.csv")
    parser.add_argument("--output", default="export_still_not_in_nlc_v2.csv", help="Output CSV for still-not-matched. Default: export_still_not_in_nlc_v2.csv")
    args = parser.parse_args()
    input_path = os.path.join(SCRIPT_DIR, args.input)
    output_path = os.path.join(SCRIPT_DIR, args.output)

    if not os.path.exists(input_path):
        print(f"Missing {args.input}. Nothing to run.")
        return
    exp_headers, exp_rows = read_csv(input_path)
    print(f"Read {len(exp_rows)} rows from {args.input} (input only, file not modified).")

    nlc_headers, nlc_rows = read_csv(NLC_MAIN_PATH)
    unmatched_by_last: dict[str, list[dict]] = {}
    for row in nlc_rows:
        if (row.get("match_type") or "").strip():
            continue
        last = normalize((row.get(NLC_LAST) or "").strip())
        if last:
            unmatched_by_last.setdefault(last, []).append(row)

    newly_matched: list[dict] = []
    still_not: list[dict] = []
    matched_nlc_ids: set[str] = set()

    for row in exp_rows:
        last_n = normalize(get_last_name(row))
        if not last_n:
            still_not.append(row)
            continue
        candidates = unmatched_by_last.get(last_n, [])
        unmatched = [c for c in candidates if c["id"] not in matched_nlc_ids]
        if not unmatched:
            still_not.append(row)
            continue
        nlc_row = unmatched[0]
        nid = nlc_row["id"]
        matched_nlc_ids.add(nid)
        row["nlc_id"] = nid
        row["match_type"] = "possible_match"
        row["match_by"] = "possible match by lastname (matched to NLC with no match)"
        newly_matched.append(row)
        nlc_row["match_type"] = "possible_match"
        nlc_row["match_by_comment"] = "possible match by lastname (matched to NLC with no match)"
        nlc_row["export_Flocknote_ID"] = row.get("Flocknote ID", "")
        nlc_row["export_First_Name"] = row.get(EXPORT_FIRST, "")
        nlc_row["export_Last_Name"] = row.get(EXPORT_LAST, "")
        nlc_row["export_Confirmation_Number"] = row.get("Confirmation Number", "")
        nlc_row["export_Gender_Identity_Dialogue"] = row.get("Gender Identity, Homosexuality, and Same Sex Attraction Dialogue", "")
        nlc_row["export_Contraception_Dialogue"] = row.get("Contraception/IVF/Abortion Dialogue", "")
        nlc_row["export_Immigration_Dialogue"] = row.get("Immigration Dialogue", "")
        nlc_row["export_Signed_Up_Date"] = row.get("Signed Up Date", "")

    write_csv(output_path, list(exp_headers), still_not)
    print(f"Wrote {len(still_not)} still-not-matched rows to {args.output}")

    if newly_matched:
        newly_headers = ["nlc_id", "match_type", "match_by"] + [h for h in exp_headers if h not in ("export_id", "nlc_id", "match_type", "match_by")]
        append_to_matched(newly_matched, newly_headers, EXPORT_MATCHED_PATH)
        print(f"Appended {len(newly_matched)} newly matched rows to {os.path.basename(EXPORT_MATCHED_PATH)}")

    write_csv(NLC_MAIN_PATH, nlc_headers, nlc_rows)
    print(f"Updated {os.path.basename(NLC_MAIN_PATH)} with new matches.")

    # Sync: nlc_main "matched to NLC with no match" must exist in export_matched_to_nlc
    in_main = {
        r["id"]: r for r in nlc_rows
        if "matched to NLC with no match" in (r.get("match_by_comment") or "")
    }
    existing_matched: list[dict] = []
    matched_headers: list[str] = []
    if os.path.exists(EXPORT_MATCHED_PATH):
        with open(EXPORT_MATCHED_PATH, newline="", encoding="utf-8-sig", errors="replace") as f:
            reader = csv.DictReader(f)
            matched_headers = list(reader.fieldnames or [])
            existing_matched = list(reader)
    in_matched = {r.get("nlc_id", ""): True for r in existing_matched}
    missing_ids = [nid for nid in in_main if nid not in in_matched]
    if missing_ids and matched_headers:
        sync_rows = []
        for nid in missing_ids:
            r = in_main[nid]
            sync_rows.append({
                "nlc_id": nid,
                "match_type": "possible_match",
                "match_by": "possible match by lastname (matched to NLC with no match)",
                "Flocknote ID": r.get("export_Flocknote_ID", ""),
                EXPORT_FIRST: r.get("export_First_Name", ""),
                EXPORT_LAST: r.get("export_Last_Name", ""),
                "Confirmation Number": r.get("export_Confirmation_Number", ""),
                "Gender Identity, Homosexuality, and Same Sex Attraction Dialogue": r.get("export_Gender_Identity_Dialogue", ""),
                "Contraception/IVF/Abortion Dialogue": r.get("export_Contraception_Dialogue", ""),
                "Immigration Dialogue": r.get("export_Immigration_Dialogue", ""),
                "Signed Up Date": r.get("export_Signed_Up_Date", ""),
            })
        write_csv(EXPORT_MATCHED_PATH, matched_headers, existing_matched + sync_rows)
        print(f"Synced {len(sync_rows)} missing match row(s) from nlc_main into {os.path.basename(EXPORT_MATCHED_PATH)}.")
    print(f"{args.input} was NOT modified.")


if __name__ == "__main__":
    main()
