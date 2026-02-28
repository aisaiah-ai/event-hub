# Event Detail Page (Event Landing)

**Location:** `lib/src/features/events/presentation/event_landing_page.dart`  
**Route:** `/events/:eventSlug` (e.g. `/events/march-cluster-2026`)

The event detail page shows event info, a Register button, short description, and a schedule with session check-in. All colors and branding come from the event’s branding (no hardcoded colors).

---

## Page structure (top to bottom)

1. **Header** — Logo + title, date, venue, “Get Directions”
2. **Short description** (optional) — One block below header when `event.shortDescription` is set
3. **Register to Event** — Secondary button; states: “Register to Event” | “Pending Approval” | “Registered ✓” (disabled)
4. **Tabs** — Schedule | Announcements
5. **Schedule** — Session cards with left-flow layout and per-session check-in button

---

## Header

- **Layout:** Row: optional logo (72×120) → 16px gap → Expanded column (title, date, venue lines, “Get Directions”).
- **Logo:** `CachedNetworkImage` for URLs, `Image.asset` for `assets/` paths. Hidden if `branding.logoUrl` (effective) is null; no extra left spacing when hidden.
- **Title:** event name, fontSize 20, fontWeight 800; wraps (maxLines 3).
- **Date:** `event.displayDate`, 16, w700.
- **Venue:** From `event.effectiveVenue` (structured Venue or derived from locationName/address). Venue name 15/w600; street 14; city/state/zip 14.
- **Get Directions:** Tappable text, `branding.primaryColor`, w700, underline. Opens Google Maps search with venue full address via `url_launcher`.

---

## Register button

- **Placement:** Below header (and below short description when present). Margin top 12, bottom 20.
- **Style:** Height 48, radius 14, background `branding.accentColor.withOpacity(0.18)`, border `branding.accentColor.withOpacity(0.35)`, text `branding.accentColor`, w700. Secondary (subtle), not primary.
- **States:**
  - `event.isRegistered == true` → “Registered ✓”, disabled.
  - `event.registrationStatus == "pending"` → “Pending Approval”.
  - Else → “Register to Event”, navigates to RSVP route.

---

## Short description

- **When:** Rendered only if `event.shortDescription != null && event.shortDescription!.isNotEmpty`.
- **Layout:** Container, margin top 12 / bottom 16, padding 14, radius 14, background `branding.cardBackgroundColor.withOpacity(0.75)`, border white 0.06.
- **Text:** `event.shortDescription`, 15, height 1.4, white 0.85. No maxLines; wraps.

---

## Schedule / session cards

- **Layout:** Left-flow vertical structure inside each card: title row → speaker row(s) → materials list → description (if any) → 12px spacing → check-in button.
- **Timeline:** Time column + rail (dot + vertical line) unchanged; only the content column uses the new layout.

### Session check-in button

- **Main Check-In** (`session.id == 'main-checkin'`): Full-width button, height 38.
- **Other sessions:** Left-aligned, intrinsic width (no stretch), height 38.
- **Colors:** Background `branding.checkInButtonColor` (default #3E7D4C). When `session.sessionCheckedIn == true`: button disabled, label “Checked In ✓”, background `checkInButtonColor.withOpacity(0.35)`.
- **Spacing:** 12 between sections above the button.

---

## Models

- **EventModel** (`lib/src/features/events/data/event_model.dart`): id, slug, name, dates, locationName, address, **venue** (Venue?), **shortDescription**, **isRegistered**, **registrationStatus**, branding (primaryColor, accentColor, **cardBackgroundColor**, **checkInButtonColor**), etc. `effectiveVenue` getter for display/maps.
- **Venue** (`lib/src/features/events/data/venue_model.dart`): name, street, city, state, zip; `fullAddress` for maps.
- **EventSession** (`lib/src/features/events/data/event_schedule_model.dart`): id, name, title, description, startAt, endAt, materials, speakerIds, **sessionCheckedIn** (bool, optional).

---

## Dependencies

- **url_launcher** — “Get Directions” opens Google Maps with `https://www.google.com/maps/search/?api=1&query=<encoded address>`.
- **cached_network_image** — Logo when URL is network.

---

## March Cluster behavior

- For slug/eventId March Cluster, the app uses **in-code fallback** for sessions and speakers (so schedule and speaker asset paths are correct: Main Check-In 1:30 PM, Birthdays & Anniversaries 7 PM, Bro Rommel Dolar / Bro. Mike Suela with `assets/images/speakers/rommel_dolar.png`, `mike_suela.png`). Event doc still loaded from Firestore when available (shortDescription, etc.). See `lib/src/features/events/data/event_repository.dart` and `docs/MARCH_ASSEMBLY_MOCK_DATA.md`.
