# Product Roadmap — Event Management Infrastructure

The NLC dashboard and check-in system is positioned as **Event Management Infrastructure**: a scalable, real-time platform that can support multiple events and future product phases. Below is a high-level roadmap without commitment to specific delivery dates.

---

## Phase 1 — Registration & Identity

- **Digital registration** — Expand registration flows (forms, confirmation, optional payment) integrated with the same event/registrant model.
- **QR generation** — Per-registrant or per-session QR codes for fast check-in at gates and sessions, scanned by staff or kiosks.
- **Identity linking** — Optional link between anonymous check-in and registered identity for consistent reporting and engagement tracking.

---

## Phase 2 — Session Experience & Content

- **Session documentation** — Attach handouts, agendas, or links to session documents; surface in check-in or post-check-in experience.
- **Speaker evaluations** — Post-session feedback or ratings tied to session and registrant (anonymous or identified per policy).
- **Digital handouts** — Distribution of materials by session or track, with optional download/access tracking.

---

## Phase 3 — Executive & Multi-Event

- **Multi-event executive dashboard** — Single view across events: totals, trends, and comparisons (e.g. by year, region, or event type).
- **Regional analytics** — Roll-ups and filters by region (or other dimensions) for leadership reporting.
- **Participation heatmap** — Visualize attendance over time and across sessions (e.g. which sessions peak when).
- **Long-term engagement tracking** — Cross-event attendance and engagement metrics for returning attendees and cohort analysis.

---

## Positioning

The system is designed as **event management infrastructure**:

- **Pure Session** model and pre-aggregated analytics support adding new sessions and event types without schema churn.
- **Real-time dashboard and wallboard** provide leadership visibility today and a base for executive views tomorrow.
- **Cloud Functions** and Firestore allow new triggers (e.g. new document types or events) and new aggregates without changing client read patterns.

This roadmap is for product and strategy discussion; implementation priorities are set by stakeholder and resource availability.
