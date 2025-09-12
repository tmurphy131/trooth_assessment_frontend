# Apprentice “Mentor” Section – Product Spec

## Purpose
A focused hub where apprentices can interact with their mentor, see shared context, and manage mentorship artifacts (agreements, meetings, assessments, notes shared to the apprentice). This consolidates mentor-related items out of the generic apprentice dashboard.

## Objectives
- Centralize mentor relationship info and actions.
- Make mentorship agreements easy to find, read, and track.
- Provide clarity on next steps (signing, meeting prep, assessments).
- Respect privacy and role boundaries (mentor-only notes remain hidden unless explicitly shared).

---

## Information Architecture
Mentor section (tab/screen) composed of modular cards:
1. Mentor Overview
2. Mentorship Agreement(s)
3. Meetings
4. Assessments with Mentor
5. Messages & Announcements
6. Shared Notes & Resources
7. Safety & Boundaries (static info)

Optional: “Request Change” (e.g., request a different mentor) or “Request Pause/End” flow.

---

## Feature Breakdown

### 1) Mentor Overview
- Mentor avatar, name, role, church/org (if provided).
- Contact CTA:
  - Message mentor (in-app messaging or deep link to preferred channel).
  - Request a meeting.
- Relationship status:
  - Active | Paused | Ended.
- If Ended: show banner + read-only history.

Data:
- mentor_name, mentor_email (mask if privacy required), mentor_avatar_url.

Permissions:
- View-only for apprentice.

---

### 2) Mentorship Agreements (moved here from apprentice dashboard)
- Card shows current active agreement status:
  - Awaiting You | Awaiting Parent | Fully Signed | Revoked.
- Actions:
  - Open Full Agreement (markdown rendered to readable HTML in-app).
  - “Review & Sign” (if awaiting apprentice; opens sign screen).
- History:
  - Show prior agreements (archive) collapsed by default.
- Parent status:
  - If under 18, surface parent signing status + “Resend Parent Link” request to mentor (sends a mentor-side notification/request; apprentice doesn’t email parent directly unless allowed).

Data:
- agreements: id, status, content_rendered, created_at, mentor_name, parent_email, token states.

Permissions:
- Apprentice can sign when status = awaiting_apprentice.

Empty state:
- “No agreement yet. Your mentor will share one when ready.”

---

### 3) Meetings
- Upcoming meeting card:
  - Date, time, location, duration, notes (derived from agreement fields).
- Actions:
  - Add to calendar (export ICS or device add).
  - Request reschedule (opens lightweight request form).
- History list (past meetings with notes shared by mentor).

Data:
- Derived from agreement fields (meeting_day, meeting_time, location, frequency) and/or a future Meetings endpoint.

Permissions:
- Apprentice can request; mentor approves/schedules.

---

### 4) Assessments with Mentor
- Shows assessments started or requested by mentor:
  - Status pill: In Progress | Submitted | Scored.
- Actions:
  - Continue (if in progress).
  - View Results (if scored).
- CTA: “New Assessment” if mentor requires one (optional banner).

Data:
- Reuse existing assessments API filtered by mentor or linked to mentorship.

---

### 5) Messages & Announcements
- Optional simple feed of mentor broadcasts (short text cards).
- Notify apprentice of milestone events:
  - Agreement created/updated/signed.
  - Meeting changes.
  - Assessment deadlines.

Data:
- notifications endpoint (filter category=mentorship).

---

### 6) Shared Notes & Resources
- Mentor-shared notes (explicitly marked shareable).
- Attachments/links: PDFs, reading plans, study guides.
- Download or open in-app.

Permissions:
- Only shared items visible to apprentice.

---

### 7) Safety & Boundaries
- Static content summarizing boundaries from agreement.
- Links to policy page.
- Contact for concerns.

---

## UX Details

- Entry: Add a bottom/tab item “Mentor” or icon in the main nav (visible to apprentices).
- Move agreements out of apprentice dashboard:
  - ApprenticeDashboard no longer shows “Mentorship Agreements.”
  - Mentor section shows agreements card only when any agreement exists.
- Visual status chips:
  - awaiting_apprentice (orange)
  - awaiting_parent (purple)
  - fully_signed (green)
  - revoked (red)
- Full-screen Agreement Preview:
  - Rich markdown rendering (consistent with mentor app preview).
  - Print/Save PDF button available for read-only previews (optional).
- Signing:
  - In-app public sign screen (token-based route) opens from “Review & Sign.”
  - After signing, show “Successfully Signed” confirmation page and return control to Mentor section on close.

---

## API & Data Contracts

Fetch:
- GET /agreements/my – list apprentice’s agreements (all statuses)
  - Fields: id, status, content_rendered, mentor_name, apprentice_email, parent_email, created_at.

Open/sign:
- Public token GET/POST remains unchanged for deep links.
- In-app route uses same token flow or authenticated helper.

Meetings:
- Later: GET /mentorship/meetings (optional future enhancement)
- For now: derive schedule fields from agreement fields if present.

Resources/Notes:
- Later: GET /mentorship/resources (mentor-shared only) or reuse notifications with attachments.

---

## Permissions & Roles
- Apprentice:
  - View mentor info, agreements, shared notes/resources.
  - Sign agreement (awaiting_apprentice).
  - Request meeting change.
- Mentor:
  - All existing mentor capabilities.
- Parent:
  - Public signing page only (token-based).

Admin:
- Superset of mentor permissions (already implemented).

---

## Telemetry & Success Metrics
- View rate of Mentor section.
- Agreement “Open” vs “Sign” conversion.
- Time-to-sign (apprentice and parent).
- Meeting request volume.
- Resource click/downloads.

---

## Implementation Plan

Phase 1 (Move Agreements + Section Shell)
- Add Mentor tab/screen for apprentices.
- Remove agreements block from ApprenticeDashboard; render in Mentor screen only if any exist.
- Card shows current agreement status and “Open/Sign.”

Phase 2 (Quality & UX)
- Rich markdown preview with consistent styles.
- Success page after signing (apprentice already done; ensure return path to Mentor section).
- Pull meeting defaults from agreement fields.

Phase 3 (Enhancements)
- Request rescheduling form.
- Mentor messages feed (notifications filter).
- Shared notes/resources list.

---

## Edge Cases
- Multiple active drafts: show the most recent prominently; archive section for older.
- Revoked: clearly labeled; disable actions.
- Under 18 without parent email: display reminder to mentor (non-blocking to apprentice).
- Offline: cache last agreement render read-only.

---

## Visual Notes
- Keep color scheme consistent with dark theme.
- Clearly distinguish actions vs read-only content.
- Use concise copy with Poppins/Inter for readability.

---