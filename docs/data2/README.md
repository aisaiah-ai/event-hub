# data2 — NLC + Export matching (clean workflow, multiple passes)

This folder is a **fresh start** with the corrected workflow. It never overwrites your curated "not in NLC" file and supports **multiple passes** to fix errors and shrink the unmatched list.

---

## What was fixed (from data/)

1. **Your file is never overwritten** — The main script writes "still not in NLC" to `export_still_not_in_nlc.csv` only. Your working list is `export_not_in_nlc.csv`; no script writes to it.
2. **Match script only reads your file** — `match_export_not_in_nlc.py` reads `export_not_in_nlc.csv` (or a file you pass). It writes to `export_still_not_in_nlc_v2.csv` (or another file you pass), appends to `export_matched_to_nlc.csv`, and updates `nlc_main.csv`.
3. **Sync step** — After every match run, any NLC row in `nlc_main` with "matched to NLC with no match" is ensured to have a row in `export_matched_to_nlc.csv`. If that file was overwritten, the sync repairs it.
4. **Multiple passes** — You can run the match script again with the *output* of the previous pass as *input* (e.g. `--input export_still_not_in_nlc_v2.csv --output export_still_not_in_nlc_v3.csv`) so the list shrinks pass by pass without renaming files.

---

## Files you need in data2

Put (or copy) these **source** files here:

- `NLC 2026 Registration as of 2-16-26.csv` — NLC registration (canonical).
- `Export-20260217-DIGNITAS INFINITA BREAKOUT SESSIONS.csv` — Breakout sign-ups (Flocknote export).

---

## Workflow

### Pass 1: One-time run from sources (when NLC or Export data changes)

```bash
cd docs/data2 && python3 relate_nlc_export.py
```

**What it does:**

- **Pass 1a — Exact match:** Email, then first + last name. Rows that match get `match_type = exact_match`.
- **Pass 1b — Possible match (same run):** For rows still unmatched, match by **last name only** to NLC rows that **don’t already have a match**. Reduces "not in NLC" list.

**Outputs (nothing overwrites your curated file):**

- `nlc_main.csv` — All NLC rows + `id`, `match_type`, `match_by_comment`, export_* when matched.
- `export_matched_to_nlc.csv` — All Export rows that matched (exact or possible).
- `export_still_not_in_nlc.csv` — Export rows that still didn’t match. **Use this as your starting "not in NLC" list.**

### Pass 2+: Match your curated "not in NLC" list (run whenever you want)

**First time (use default input):**

```bash
cd docs/data2 && python3 match_export_not_in_nlc.py
```

- **Reads:** `export_not_in_nlc.csv` (your file; never overwritten).
- **Matches:** By last name only, and only to NLC rows that have **no match** in `nlc_main`.
- **Writes:** `export_still_not_in_nlc_v2.csv` (still not matched).
- **Appends:** Newly matched rows to `export_matched_to_nlc.csv`.
- **Updates:** `nlc_main.csv` with new matches.
- **Syncs:** Ensures every "matched to NLC with no match" row in `nlc_main` has a row in `export_matched_to_nlc.csv`.

**Next pass (use previous output as input):**

```bash
python3 match_export_not_in_nlc.py --input export_still_not_in_nlc_v2.csv --output export_still_not_in_nlc_v3.csv
```

Then:

```bash
python3 match_export_not_in_nlc.py --input export_still_not_in_nlc_v3.csv --output export_still_not_in_nlc_v4.csv
```

and so on. Each pass only matches to NLC rows that still have no match, so you don’t double-assign. Your **input** file is never overwritten.

**Optional: use output as next input without overwriting**

- Keep `export_not_in_nlc.csv` as your main working file (edit, fix names, remove duplicates).
- For a new pass, either:
  - Copy `export_still_not_in_nlc_v2.csv` → `export_not_in_nlc.csv` and run with no args, or
  - Run with `--input export_still_not_in_nlc_v2.csv --output export_still_not_in_nlc_v3.csv` and keep v2 as-is.

---

## Errors and how multiple passes correct them

| Error / situation | How it’s handled |
|-------------------|------------------|
| **Typo / nickname** (e.g. Export "BECKY" vs NLC "Rebecca") | Pass 1b and Pass 2+ match by **last name** to NLC with no match; one of the Alazas gets the match. |
| **Multiple NLC same last name** | We only assign to an NLC row that **doesn’t already have a match**, so we don’t double-assign. |
| **Curated list overwritten** | Scripts never write to `export_not_in_nlc.csv`. Still-not-matched goes to `export_still_not_in_nlc*.csv`. |
| **export_matched_to_nlc overwritten** (e.g. by re-running the main script) | After every match run, a **sync** step copies any "matched to NLC with no match" rows from `nlc_main` into `export_matched_to_nlc.csv`. |
| **Need to shrink "not in NLC" more** | Run `match_export_not_in_nlc.py` again with the latest still-not file as `--input` and a new `--output` (or copy to `export_not_in_nlc.csv` and run with no args). |

---

## Do not

- **Do not** re-run `relate_nlc_export.py` just to "get more matches." Run it only when the **source** NLC or Export CSV changes. Re-running it overwrites `export_matched_to_nlc.csv` and `nlc_main.csv` from the original Export and wipes matches that came from your curated list (sync will repair `export_matched_to_nlc` the next time you run the match script).

---

## Summary

1. **One-time (or when sources change):** `python3 relate_nlc_export.py` → get `nlc_main`, `export_matched_to_nlc`, `export_still_not_in_nlc`.
2. **Your list:** Copy `export_still_not_in_nlc.csv` to `export_not_in_nlc.csv` and curate (fix names, etc.).
3. **Match passes:** `python3 match_export_not_in_nlc.py` [optional: `--input <file> --output <file>`]. Still-not → v2 (or v3, v4…); newly matched → appended to `export_matched_to_nlc`; `nlc_main` updated; sync ensures list of matching is complete.
4. **Repeat:** Use v2 as input for next pass (or copy v2 → `export_not_in_nlc.csv`) and run again.
