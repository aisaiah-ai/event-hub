# NLC dashboard live demo

**The app uses the (default) Firestore database.** All scripts below must use `"--database=(default)"` or the dashboard will not update.

## One-time setup (if you haven’t already)

1. **Bootstrap event + sessions + stats in (default)**  
   Otherwise the dashboard and Cloud Functions have nothing to read/update.

   ```bash
   cd functions && node scripts/ensure-nlc-event-doc.js "--database=(default)"
   ```

2. **Seed registrants into (default)**  
   The demo script only “check-ins” existing registrants. Flutter seed uses the app’s DB, which is (default).

   ```bash
   SEED_FILE="tools/sample_nlc_registrants.csv" flutter run -t lib/seed_main.dart -d macos --dart-define=ENV=dev
   ```

## Auth (if scripts fail with invalid_grant)

```bash
gcloud auth application-default login
```

## Cleanup

From `functions/`:

```bash
node scripts/delete-seed-attendance-dev.js "--database=(default)" --dev
```

This deletes all attendance docs **and** resets analytics (global, stats/overview, session summaries) so the dashboard shows empty — no Top 5 bars, 0 counts. If the script is too slow, you can delete attendance in Firebase Console, but you must also clear or zero out `events/nlc-2026/analytics/global` and `events/nlc-2026/stats/overview` (e.g. set `regionCounts: {}`, `ministryCounts: {}`, `totalCheckins: 0`) or the bars will stay.

## Demo

1. Open the dashboard in the app (e.g. `/admin/dashboard?eventId=nlc-2026`).
2. **Run the gradual check-in script** (creates attendance docs so the dashboard and backfill have data). From `functions/`:

   ```bash
   node scripts/seed-gradual-checkins-dev.js "--database=(default)" --dev --duration=60 --max-pct=0.8
   ```

   You should see `Check-ins: 1/xxx`, `2/xxx`, … as it runs. If you see "No registrants found", seed registrants first (One-time setup step 2).

3. Watch the dashboard: **Main Check-In Total** and **Session Check-Ins** (breakout sessions) both increase. The script writes main-checkin for everyone and, for ~50%, one random breakout session (Gender Ideology, Contraception/IVF/Abortion, or Immigration dialogue). Use `--session-pct=0.6` to increase that fraction. If you see "No breakout sessions found", add session docs under `events/nlc-2026/sessions/` with ids `gender-ideology-dialogue`, `contraception-ivf-abortion-dialogue`, `immigration-dialogue`.

4. **Backfill Top 5 and Check-In Trend** (demo-only: updates only regionCounts, ministryCounts, hourlyCheckins). Run this **after** the gradual check-in script has created attendance (step 2). From `functions/`:

   ```bash
   node scripts/backfill-demo-top5-trend.js "--database=(default)" --dev
   ```

   You should see output like `regionCounts: N keys`, `ministryCounts: N keys`, `hourlyCheckins: N keys`. If all are 0, no attendance was found — run step 2 first, then backfill again. (For a full backfill including session summaries and totals, use `backfill-analytics-dev.js` instead.)

5. **Verify and refresh:** From `functions/` run `node scripts/inspect-analytics-global.js "--database=(default)" --dev` — you should see non‑zero keys for regionCounts, ministryCounts, hourlyCheckins. Then **hard refresh** the dashboard (e.g. Cmd+Shift+R) or restart the app so it reloads from Firestore. Top 5 and the trend graph should appear.

**End of demo:** After the gradual check-ins finish, always run the demo backfill (step 4) so Top 5 Regions, Top 5 Ministries, and Check-In Trend appear on the dashboard.

## If the dashboard still doesn’t change

- **Same database:** Cleanup and demo must both use `"--database=(default)"` (the app only reads from (default)).
- **Registrants in (default):** If you only ever seeded into `event-hub-dev`, (default) has no registrants. Run the “One-time setup” steps above for (default).
- **Script output:** The script should print `Check-ins: 1/xxx`, `2/xxx`, … If it exits with “No registrants found”, seed registrants into (default) (see above).
- **Top 5 Regions / Check-In Trend empty after backfill:** (1) Run the demo backfill **after** the gradual check-in script (step 2): `node scripts/backfill-demo-top5-trend.js "--database=(default)" --dev`. (2) Use `"--database=(default)"`. (3) Check backfill output: it should print `regionCounts: N keys`, etc.; if N is 0, run the gradual script first. (4) Run `node scripts/inspect-analytics-global.js "--database=(default)" --dev` — if it shows keys but the app doesn’t, **restart the app**. (5) In Firebase Console → Firestore → **(default)** → `events/nlc-2026/analytics/global`, confirm `regionCounts`, `ministryCounts`, `hourlyCheckins` have data. (6) For full backfill (session summaries, totals): `node scripts/backfill-analytics-dev.js "--database=(default)" --dev`. (7) Deploy Cloud Functions for real-time updates: `cd functions && npm run build && firebase deploy --only functions`.
- **Firebase Console:** In Firestore, switch to the **(default)** database and check that `events/nlc-2026/registrants` has documents and that `events/nlc-2026/sessions/main-checkin/attendance` gets new docs while the script runs.
