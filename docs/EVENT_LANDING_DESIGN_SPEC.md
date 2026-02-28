# Event Landing Page — Design Spec (Mobile-Ready)

This document defines the visual design for the event detail / landing screen so it can be replicated in a native or cross-platform mobile app. All values are derived from the Flutter implementation in `lib/src/features/events/presentation/event_landing_page.dart`.

**Principle:** All colors come from **event branding**. Do not hardcode theme colors; use the event’s `cardBackgroundColor`, `checkInButtonColor`, `primaryColor`, and `accentColor`.

---

## 1. Branding tokens (from event)

| Token | Use | Fallback (if missing) |
|-------|-----|------------------------|
| `cardBackgroundColor` | Card gradients, chips, avatar, material row | `#141420` |
| `checkInButtonColor` | Event Check In button, session check-in buttons, main-checkin card tint | `#3E7D4C` |
| `primaryColor` | Timeline dot, tab indicator, “Get Directions”, “Today” icon | — |
| `accentColor` | Register button (border, text, background tint) | — |

---

## 2. Glass-style cards (all card surfaces)

Use the same gradient for every card so the look is consistent.

**Gradient:**
- Type: **Linear gradient**
- Start: **Top-left**
- End: **Bottom-right**
- Color 1: `cardBackgroundColor` at **opacity 0.68**
- Color 2: `cardBackgroundColor` at **opacity 0.62**

**Border:**
- Color: **White** at **opacity 0.05**
- Width: **1**

**Where this applies:**
- Event header card
- Short description block
- Tabs container (Schedule / Announcements)
- “Updated X mins ago” chip
- “Today” button container
- All session cards (see exception below)
- Material/download rows
- Speaker avatar (use **solid** `cardBackgroundColor` at **0.68** for the circle)

**Main-checkin session card only:** Same gradient direction, but:
- Color 1: `checkInButtonColor` at **opacity 0.11**
- Color 2: `cardBackgroundColor` at **opacity 0.68**
- Border: `checkInButtonColor` at **opacity 0.25**, width 1

---

## 3. Border radius and shadow

| Element | Border radius | Shadow (optional) |
|--------|----------------|--------------------|
| Header, tabs, session cards | **18** | Color `#000000` 33% opacity, blur 18, offset (0, 10) — header; blur 14, offset (0, 8) — session cards |
| Short description | **14** | — |
| Chips (“Updated…”, “Today”) | **999** (pill) | — |
| Buttons (check-in, register) | **12** (check-in), **14** (register) | — |
| Material row | **14** | — |
| Material row icon box | **10** | — |

---

## 4. Typography and text contrast

**Primary text (titles, names, time, tab labels, button labels):**
- Color: **White** at **opacity 0.92**
- Use for: Event name, date, venue name, session title, time, speaker name, material title, tab text, “Today”, “Event Check In”, “Check In”, “Checked In ✓”

**Secondary text (supporting copy):**
- Color: **White** at **opacity 0.70**
- Use for: Venue street, city/state/zip, speaker title, session description, empty states (“No sessions yet”, “No announcements yet”)

**Links / accents (branding):**
- “Get Directions”: `primaryColor`, fontWeight 700, underline
- Register button: `accentColor` (see Register button below)
- “Updated X mins ago” chip: accent green (e.g. `#7AE3A5`) for text and icon

**Sizes (logical / pt):**
- Event name: **20**, weight **800**, line height 1.3, max 3 lines
- Event date: **16**, weight **700**
- Venue name: **15**, weight **600**
- Venue address lines: **14**
- Session title: **18**, weight **800**, letterSpacing -0.2
- Time (in session card): **15**, weight **700**
- Speaker name: **16**, weight **800**
- Speaker title: **13**, weight **500**
- Session description: **14**, height 1.4, max 2 lines
- Material row title: **14**, weight **700**
- Check-in button label: **15**, weight **800**
- Tab labels: **18**, weight **700** (selected), **500** (unselected)
- Chip / “Today”: **13** (chip), **14** (“Today”), weight **700**
- Short description: **15**, height 1.4
- Empty state: **14**

---

## 5. Event Check In button (main check-in only)

**Identification:** Shown when `session.id === 'main-checkin'`.

**Label:**
- Default: **"Event Check In"**
- After check-in (disabled): **"Checked In ✓"**

**Style (outlined, not solid fill):**
- Height: **42**
- Full width
- Background: **20% brighter** green than `checkInButtonColor` (e.g. lerp `checkInButtonColor` with white, factor **0.2**) at **opacity 0.40**
- Border: same brighter green at **opacity 0.45**, width 1
- Text color: **White** (not green)
- Font: **15**, weight **800**
- Corner radius: **12**
- Horizontal padding: **20**
- Elevation / shadow: **0**

**Disabled (checked in):**
- Background: same brighter green at **opacity 0.12**
- Text: **White**
- Button not pressable

**Brighter green formula:**  
`brighter = lerp(checkInButtonColor, white, 0.2)`

---

## 6. Session check-in buttons (other sessions)

**Identification:** Any session where `session.id !== 'main-checkin'`.

**Label:** **"Check In"** / **"Checked In ✓"** when disabled.

**Style (solid):**
- Height: **36**
- Width: intrinsic (wrap content), left-aligned
- Background: `checkInButtonColor` at **opacity 0.90** (0.35 when checked in)
- Text: **White** at **opacity 0.92**
- Font: **15**, weight **800**
- Corner radius: **12**
- Horizontal padding: **20**
- Elevation: **0**

---

## 7. Schedule timeline (session cards)

**Layout:** Row per card: [Time] → [Dot + rail] → [Content column].

- **Time column:** Width **76**, left-aligned time (e.g. “1:30 PM”), primary text style.
- **Gap:** **8** between time and rail.
- **Timeline dot:** Circle, size **10×10**, color `primaryColor` at **opacity 0.90**.
- **Rail (vertical line):** Width **2**, color white at **opacity 0.2** (e.g. `#33FFFFFF`). Height **48** if the card has content (speakers, materials, or description), else **24**.
- **Gap:** **12** between rail and content.
- **Content:** Column, left-aligned: session title → speakers → materials → description → 12 spacing → check-in button.

---

## 8. Speaker row

- Avatar: **38×38** circle, background `cardBackgroundColor` at **0.68**, border white **0.05**.
- Gap: **12** between avatar and text.
- Name: primary text, **16**, **800**.
- Title: secondary text, **13**, **500** (optional line).
- Vertical spacing between multiple speakers: **8**.

---

## 9. Material / download row

- Height: **52**
- Background: same **glass gradient** as cards (0.68 / 0.62).
- Border: white **0.05**, radius **14**.
- Left: icon box **34×34**, radius **10**, background `cardBackgroundColor` at **0.65**, border white **0.05**. Icon e.g. download, size **18**, color accent green (`#7AE3A5`).
- Gap: **12** between icon and text.
- Text: `"Title (TYPELABEL)"`, primary text, **14**, **700**, single line with ellipsis.
- **No trailing chevron** (left-aligned balance).

---

## 10. Register button

- Height: **48**
- Full width
- Background: `accentColor` at **opacity 0.18**
- Border: `accentColor` at **opacity 0.35**
- Text: `accentColor`, **16**, weight **700**
- Corner radius: **14**
- States: “Register to Event” | “Pending Approval” | “Registered ✓” (disabled)

---

## 11. Short description block

- Margin top **12**, bottom **16**
- Padding: **14**
- Same **glass gradient** and border as cards (0.68 / 0.62, white 0.05).
- Radius: **14**
- Text: primary (0.92), **15**, height 1.4

---

## 12. Spacing and layout

- Screen padding: horizontal **20**, vertical **14**
- Between header and short description: **12**
- Between short description and Register: **16**
- Between Register and tabs: **20**
- Between tabs and schedule list: **12**
- Between session cards: **12**
- Between sections inside a session card: **12**
- Header internal padding: **16**
- Tabs container padding: **14** L, **10** T, **10** R, **14** B
- Session card padding: **16**

---

## 13. Opacity summary (no fully opaque cards)

| Element | Opacity |
|--------|--------|
| Card gradient start | 0.68 |
| Card gradient end | 0.62 |
| Main-checkin card green tint | 0.11 |
| Main-checkin card border | 0.25 (checkInButtonColor) |
| Card border (default) | 0.05 (white) |
| Event Check In button background | 0.40 (brighter green) |
| Event Check In button border | 0.45 (brighter green) |
| Event Check In disabled background | 0.12 (brighter green) |
| Session check-in button background | 0.90 (0.35 when checked in) |
| Primary text | 0.92 (white) |
| Secondary text | 0.70 (white) |
| Speaker avatar / chip / Today bg | 0.68 (cardBackgroundColor) |
| Material icon box | 0.65 (cardBackgroundColor) |
| Timeline dot | 0.9 (primaryColor) |
| Timeline rail | ~0.2 (white) |

---

## 14. Reference implementation

- **Web/Flutter:** `lib/src/features/events/presentation/event_landing_page.dart`
- **Event model / branding:** `lib/src/features/events/data/event_model.dart` (e.g. `cardBackgroundColor`, `checkInButtonColor`, `primaryColor`, `accentColor`)

Use this spec to match the same glass cards, contrast, and Event Check In treatment on iOS, Android, or React Native.
