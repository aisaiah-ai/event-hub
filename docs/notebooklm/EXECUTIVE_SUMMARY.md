# Executive Summary — NLC Dashboard & Check-In System

One-page strategic overview for leadership and IT stakeholders.

---

## Manual vs Automated

| Manual / legacy | NLC system (automated) |
|------------------|-------------------------|
| Paper lists, clipboards, or ad-hoc spreadsheets | Digital registrant list; search by name; one-tap check-in per session |
| Post-event tally and manual aggregation | Real-time dashboard and wallboard; metrics update as check-ins happen |
| Risk of double-counting or missed sessions | Single source of truth: one document per registrant per session; server-side aggregation |
| Limited visibility for leadership during event | Live metrics: total registrants, main check-in, session breakdowns, region/ministry, trend |

---

## Operational Efficiency

- **Staff** — Search registrant, select session, confirm check-in. No manual counting or reconciliation during the event.
- **Leadership** — Dashboard and wallboard show current totals, session leaderboard, top regions/ministries, and check-in trend without running reports or waiting for exports.
- **Scalability** — Architecture supports thousands of registrants and multiple concurrent sessions; analytics are pre-aggregated so the dashboard does not slow down as data grows.

---

## Governance and Security

- **Role-based access** — Admin and staff roles per event; self-check-in can be enabled per event with clear rules.
- **Analytics integrity** — All dashboard metrics are computed and written by Cloud Functions; clients cannot modify aggregates. Firestore rules enforce read-only access to analytics documents for the client.
- **Auditability** — Check-in writes are to a single, well-defined path (session attendance); server-side logic is in version-controlled Cloud Functions.

---

## Real-Time Leadership Visibility

- **Main dashboard** — Default landing for the app: metric tiles (registrants, main check-in, session check-ins), session leaderboard, top 5 regions/ministries, first 3 registrations/check-ins. All numbers from pre-aggregated analytics.
- **Wallboard** — Full-screen mode for lobbies and projectors: large rolling counters, session leaderboard, and check-in trend chart. Same data, presentation optimized for at-a-glance viewing.
- **No batch delay** — Listeners on analytics documents receive updates as soon as Cloud Functions write them after each check-in.

---

## Future Expansion

The system is built as **event management infrastructure**: Pure Session model, server-side aggregation, and real-time streams support future phases such as digital registration, QR check-in, session content and evaluations, and multi-event executive dashboards. See **PRODUCT_ROADMAP.md** for phased options.

---

## Summary

The NLC dashboard and check-in system replace manual or fragmented processes with a single, real-time platform: secure, scalable, and designed for leadership visibility and future product expansion. Tone and design are aligned with professional, IT-governed event operations.
