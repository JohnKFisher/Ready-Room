# Ready Room: Where We Stand

Updated for version `0.2.0 (20)`

## Overall Status

Ready Room is now a usable personal foundation build, not a polished or fully trustworthy daily-driver release.

The app is already helpful for:
- viewing a merged family/work timeline
- managing obligations
- previewing morning briefings
- running a basic scheduled-send flow
- sharing app data across Macs through a custom synced folder

It is **not** yet in a state where you should fully trust unattended morning emails or assume every live data source is real and complete.

## What Is Working Now

### Core Engine
- normalized event and obligation model
- rules-based relevance, ownership, work/home classification, due-soon handling, change tracking, and conflict detection
- decision-trace structures for inspectability

### Dashboard
- 7-day style timeline with grouped days
- yesterday remains visible until about 3:00 AM
- completed items from the current day are dimmed and marked complete
- multi-day all-day events show on each day they span
- obligations appear in the timeline as all-day items
- due-soon card shows remaining days
- placeholder data is clearly labeled in the dashboard and debug views

### Obligations
- YAML-backed obligations storage
- natural-language parsing
- parse-and-approve flow
- editable “I understood this as...” explanation
- saved obligations can be clicked and edited later
- shared obligations reload across open Macs when the shared file changes

### Briefings
- deterministic briefing generation works
- preview screen works
- compare-modes preview works
- placeholder items are clearly labeled in the briefing
- every event line now includes an explicit date
- briefings include a strong early-development warning banner

### Sending / Scheduling
- Apple Mail send path exists
- scheduled-send coordination exists
- primary sender selection exists
- same-day catch-up window exists
- manual test sends no longer block the real scheduled send for the same day
- sent messages now arrive as readable plain-text compatibility mail instead of raw HTML tags

### Storage / Multi-Mac
- clear local-vs-shared storage boundary
- custom shared folder support works
- each Mac can use a different absolute path to the same synced folder
- storage/sync settings explain what is shared, local, created, and not yet created

## Partially Implemented

### Live Data Connectors
- EventKit calendars are partly real and actively used
- weather now has a real configuration screen and live data path
- weather location resolves through Apple location search and current conditions come from Open-Meteo
- news and media are still mostly placeholder-driven in normal use
- configuration UX for news and media is still mostly missing

### AI
- templated fallback works
- Ollama HTTP path exists in code
- Foundation Models provider is only a stub and currently falls back
- there is no full AI configuration, health display, or prompt/output inspection yet

### Settings / Preferences
- the sidebar structure exists
- sender, storage/sync, and weather are meaningfully usable
- most other settings pages are still placeholders or explanatory shells

### Debuggability
- source health is visible
- raw normalized payload inspection exists
- but logs, source test buttons, resend tools, and richer debug workflows are not there yet

### Dashboard Mode / Operational Polish
- “minimal window chrome” exists
- but the fuller kiosk-like dashboard mode from the plan is not built yet
- quiet hours exist conceptually and are surfaced, but the full operational behavior is still light

## Not Implemented Yet

### Setup
- real first-run setup wizard
- skip/resume onboarding flow
- permission-guidance flow

### Calendar Management UI
- calendar role confirmation UI
- per-calendar owner and include/exclude controls
- inactive-until-classified workflow
- per-calendar color and override management

### Notifications
- macOS notifications for major near-term changes
- family/kid conflict notifications

### Archive / History
- archive browser UI
- per-day sent briefing views
- resend-from-debug workflow

### Correction / Override Workflow
- item-level “this is wrong” correction flow
- “make this a rule going forward” workflow

### Sending / Delivery
- true rendered HTML email delivery through Mail
- additional sender methods
- sender fallback methods
- richer delivery diagnostics and error recovery UX

### Operational Hardening
- full real-world validation of multi-Mac duplicate-send protection
- runtime launch-at-login / auto-start behavior
- polished packaging/signing/distribution flow

## Known Limitations And Trust Warnings

- News and media may still be placeholder data unless explicitly wired to live sources.
- Weather now has a live path, but it depends on Apple location resolution succeeding and Open-Meteo being reachable.
- Foundation Models is not really implemented yet.
- Apple Mail currently sends a readable plain-text compatibility version, not a fully rendered HTML email.
- Scheduled sending is improved, but still not fully proven as “trust it every morning without checking.”
- Much of Settings is still scaffold/UI shell rather than finished product.
- Notifications are not implemented, so the app will not proactively warn you about important changes yet.
- This is still an early build and should be treated as helpful-but-experimental.

## Setup / Runtime Requirements

To get useful daily behavior right now:
- macOS app must be running on the chosen primary sender Mac
- Apple Mail must be configured and able to send mail
- Apple Events/Mail automation permission must be granted
- Calendar permission must be granted for live EventKit calendars
- if using cross-Mac sync, each Mac should point Ready Room at its own local path to the same synced folder
- if using scheduled sends, real John and Amy recipient lists must be configured

## Important Operational Risks

- Morning send reliability is better than before, but still needs more real-world validation.
- Cross-Mac coordination is practical, not fully hardened.
- Placeholder data can still leak into daily use for news and media because those connectors are not fully configured yet.
- Some configuration areas exist in the data model but not yet in a real user-facing workflow.

## Recommended Next Priorities

1. Make live news/media actually usable with real configuration screens.
2. Improve sender reliability and diagnostics so morning-send failures are obvious and recoverable.
3. Build the real setup wizard and permissions guidance.
4. Add notifications and archive/history UI.
5. Finish the most important settings pages, especially calendars and briefings.

## Latest Durable Rollback Point

- `known-good/20260314-ready-room-0.2.0`

This is the current durable “last known good” anchor to return to if a later change breaks something important.
