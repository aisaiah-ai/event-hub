# Data Reconciliation Summary
_Generated: 2026-02-20_

## Source files

| File | Rows |
|---|---|
| NLC 2026 Registration (source) | 459 rows → **454 valid registrants** (5 removed, see below) |
| Export-20260219 Breakout Sessions | 271 sign-ups |

### Removed from NLC source (5 rows)

| Row | Reason |
|---|---|
| Joe Millares-duplicate | Explicit duplicate |
| Beth Millares-duplicate | Explicit duplicate |
| Alan Deiparine-Duplicate | Explicit duplicate |
| Joe Millares (`4dquaretag@gmail.com`) | Typo-variant duplicate |
| SERVICE/PRODUCTION/TECH TEAM (blank) | Staff/crew — not a registrant |

---

## Matching results

| | Count |
|---|---|
| **Matched** (export → NLC) | **268** rows |
| Intentionally unmatched | 3 (see below) |
| **Total export rows** | **271 ✓** |

**NLC registrants matched:**

| Match type | Count |
|---|---|
| Exact match | 219 |
| Possible match | 47 |
| No breakout sign-up | 188 |
| **Total NLC registrants (seeded)** | **454** |

**Session pre-registrations (seeded to Firestore):**

| Session | Count |
|---|---|
| Gender Identity | 108 |
| Contraception / Abortion | 54 |
| Immigration | 104 |
| **Total slots** | **266** |

---

## Session attendance breakdown

| Session | Capacity | Pre-reg | Total check-in | Pre-reg ✓ | Non Pre-reg ✓ |
|---------|--------:|--------:|---------------:|----------:|--------------:|
| Gender Identity | 450 | 108 | 153 | 86 | 67 |
| Contraception / Abortion | 72 | 54 | 59 | 41 | 18 |
| Immigration | 192 | 104 | 146 | 77 | 69 |
| **Total** | **714** | **266** | **358** | **204** | **154** |

Main Check-In attendance: **358** (capacity: unlimited)

_Source: (default) database, `events/nlc-2026`._

**Analytics backup guarantee:** Every check-in (pre-registered or not) writes an attendance doc at `sessions/{sessionId}/attendance/{registrantId}` where the doc ID is the NLC registrant ID. This raw attendance data is the single source of truth. If `attendanceCount` or analytics ever drift, all counts can be recomputed by querying the attendance subcollection per session and cross-referencing `sessionRegistrations` for the pre-reg / non-pre-reg split.

---

## Intentionally unmatched (3 rows)

| Name | Reason |
|---|---|
| Dave Guirao | Duplicate sign-up |
| Vince Claudette West | Canceled |
| Mel Tess Ebrada | Duplicate sign-up |

---

## ⚠️ Gotchas

**1. Two export rows mapped to one NLC registrant — Emmanuel Wong**
- `Emmanuel Wong` (export, exact match) and `Mannie Wong` (export, possible match by last name) both map to the same NLC row **Emmanuel Wong**.
- `Mannie` is a nickname for Emmanuel and there is only one Wong in the NLC list.
- These are almost certainly the same person — harmless, but the NLC count of 266 unique matched registrants reflects this.

**2. Two export rows mapped to wrong NLC registrant — Capinpin**
- `Cocoy Capinpin` (export) correctly maps to **Allain Capinpin** (NLC) — "Cocoy" is Allain's nickname.
- `Arlyn Capinpin` (export) is **incorrectly mapped** to Allain Capinpin instead of **Arlyn Navarro-Capinpin** (NLC).
- The hyphenated last name `Navarro-Capinpin` in the NLC source causes the last-name-only lookup to miss. This is **1 wrong match** — Arlyn's breakout session pre-registration is currently attached to Allain's NLC record, not hers.

**3. Unique NLC registrants matched = 266, not 268**
- 268 export rows matched, but 2 NLC IDs each absorbed 2 export rows (Wong × 2, Capinpin × 2), so only **266 distinct NLC registrants** are linked to a breakout sign-up.

**4. Spouse/companion rows (no Flocknote ID)**
- 34 export rows had no Flocknote ID (registered as companion under a shared confirmation number).
- The updated script resolves their last names from the primary registrant's row before matching — this is what pushed exact matches up significantly.
- Rows where the companion's last name couldn't be inferred (email in name field, single-token name) remain on their own for manual review.
