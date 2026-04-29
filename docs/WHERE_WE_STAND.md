# Ready Room: Where We Stand

Updated for version `0.3.0 (37)`

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
- rules-based required ownership, adult-only briefing relevance, work/home classification, due-soon handling, change tracking, and conflict detection
- machine-local persisted calendar baseline keeps `New or Changed` stable across restarts
- decision-trace structures for inspectability

### Dashboard
- 5-day timeline with `Today`, `Tomorrow`, and grouped `Upcoming` days
- yesterday remains visible until about 3:00 AM
- completed items from the current day are dimmed and marked complete
- multi-day all-day events show on each day they span
- obligations appear in the timeline as all-day items
- due-soon obligations no longer duplicate an obviously matching all-day calendar item when owner, day, and normalized title line up
- due-soon card shows remaining days
- timeline items now show owner-based accent rails and pills for John, Amy, Ellie, Mia, and Family
- placeholder data is clearly labeled in the dashboard and debug views when a source is still sample-backed
- dashboard hero weather stays compact while the weather module now shows richer today metrics plus a short `Today`/`Tonight`/`Tomorrow` strip
- dashboard news now shows featured live headlines from configured RSS/Atom feeds, with clickable article links that open in the default browser
- Beacon Wall remains the intentional custom dashboard character; compliance work is not meant to flatten it into a generic Mac utility UI

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
- dated `Today`/`Tomorrow` headers and grouped `Upcoming` day headers now keep briefings readable without repeating the date on every line
- briefing item rows now include owner-only chips using the shared people-color palette
- meeting-link locations now render as friendly labels such as `Zoom Meeting` and `Teams Meeting`
- briefings include a strong early-development warning banner

### Sending / Scheduling
- SMTP HTML send path exists
- Apple Mail compatibility fallback exists
- scheduled-send coordination exists
- primary sender selection exists
- same-day catch-up window exists
- manual test sends no longer block the real scheduled send for the same day
- sent messages can now go out as multipart HTML+plain-text mail when SMTP is configured
- send history now records requested-versus-actual sender path when fallback occurs

### Storage / Multi-Mac
- clear local-vs-shared storage boundary
- custom shared folder support works
- custom shared folder selection now rejects paths that cannot be used as directories
- each Mac can use a different absolute path to the same synced folder
- storage/sync settings explain what is shared, local, created, and not yet created

### CI / Release Packaging
- GitHub Actions build workflow runs tests and creates a universal macOS DMG artifact on pushes to `main`
- GitHub Actions release workflow publishes a GitHub Release when the checked-in `VERSION` file changes on `main`
- release packaging validates checked-in version metadata, builds Apple Silicon and Intel slices, combines them into a universal app, ad-hoc signs it, and wraps it in a DMG
- local development now has `script/build_and_run.sh`, which stages and opens a real `.app` bundle for app testing

## Partially Implemented

### Live Data Connectors
- EventKit calendars are partly real and actively used
- live EventKit access now requires an explicit enable action in Calendars settings instead of prompting during automatic startup/refresh
- weather now has a real configuration screen and live data path
- weather location resolves through Apple location search and current conditions plus short forecast data come from Open-Meteo
- news now has a real shared configuration screen, a curated North Jersey / U.S. starter bundle, optional manual local feeds, and deterministic per-surface ranking for dashboard/John/Amy
- enabled news feeds now require absolute `http` or `https` URLs with a host
- news now refreshes on startup, manual refresh, scheduled-send prep, every 30 minutes for calendar/obligations, and every 60 minutes for news/weather while the app stays open
- media is still mostly placeholder-driven in normal use
- configuration UX for media is still mostly missing

### AI
- templated fallback works
- Ollama HTTP path exists in code
- Foundation Models provider is only a stub and currently falls back
- there is no full AI configuration, health display, or prompt/output inspection yet

### Settings / Preferences
- the sidebar structure exists
- sender, storage/sync, weather, news, and calendars are meaningfully usable
- calendar settings now expose per-calendar role, default owner, dashboard inclusion, default John/Amy relevance, and read-only preview rows for recent normalized events
- in-app operational Settings are an intentional product choice for now; there is not a separate native macOS Settings scene yet
- dashboard settings now include shared person-color customization with a live preview and reset-to-defaults control
- sender settings now include SMTP server details, sender selection, and local Keychain-backed password status
- most other settings pages are still placeholders or explanatory shells

### Debuggability
- source health is visible
- raw normalized payload inspection exists
- ranked news weights and feed settings now show up in the debug payload
- sparse unified logging now covers refresh, calendar permission, storage-folder selection, scheduled sends, and send fallback paths
- but logs, source test buttons, resend tools, and richer debug workflows are not there yet

### Dashboard Mode / Operational Polish
- direct toolbar access back to Dashboard now exists
- the unfinished minimal window chrome toggle is gone
- a fuller kiosk-like dashboard mode from the older plan is still not built
- quiet hours exist conceptually and are surfaced, but the full operational behavior is still light

## Not Implemented Yet

### Setup
- real first-run setup wizard
- skip/resume onboarding flow
- broader permission-guidance flow beyond the explicit Calendars enable action

### Calendar Management UI
- inactive-until-classified workflow
- per-calendar color management
- keyword-owner override editing
- item-level correction and “make this a rule” workflows

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
- richer delivery diagnostics and error recovery UX

### Operational Hardening
- full real-world validation of multi-Mac duplicate-send protection
- runtime launch-at-login / auto-start behavior
- Developer ID signing and notarization

## Known Limitations And Trust Warnings

- Release DMGs are ad-hoc signed but not Developer ID signed or notarized, so macOS Gatekeeper may still require manual approval in System Settings.
- Media may still be placeholder data unless explicitly wired to live sources.
- Weather now has a live path, but it depends on Apple location resolution succeeding and Open-Meteo being reachable.
- News now has a live path, but it depends on configured publisher feeds remaining reachable and parseable; when feeds fail, Ready Room falls back to the last good cached headlines and marks the source stale or unavailable instead of pretending sample news is current.
- Foundation Models is not really implemented yet.
- SMTP delivery currently assumes username/app-password style auth; OAuth-specific provider flows are not implemented.
- Apple Mail still sends the readable plain-text compatibility version, not a fully rendered HTML email, when fallback is used.
- Scheduled sending is improved, but still not fully proven as “trust it every morning without checking.”
- Calendar defaults are now configurable, but correction is still per-calendar only; item-level fixes and keyword rules are not built yet.
- Several settings pages are still scaffold/UI shell rather than finished product.
- Notifications are not implemented, so the app will not proactively warn you about important changes yet. Notification permission text is intentionally absent until that feature exists.
- Live calendars must be enabled from Calendars settings before Ready Room asks macOS for Calendar access.
- This is still an early build and should be treated as helpful-but-experimental.

## Setup / Runtime Requirements

To get useful daily behavior right now:
- macOS app must be running on the chosen primary sender Mac
- if you want HTML email, SMTP server details must be configured and an SMTP password must be stored locally in this Mac's Keychain
- if you want Apple Mail fallback, Apple Mail must be configured and able to send mail
- if you want Apple Mail fallback, Apple Events/Mail automation permission must be granted
- Calendar access must be explicitly enabled in Calendars settings and granted in macOS for live EventKit calendars
- if using cross-Mac sync, each Mac should point Ready Room at its own local path to the same synced folder
- if using scheduled sends, real John and Amy recipient lists must be configured
- if using a downloaded release DMG, Gatekeeper may require System Settings > Privacy & Security > Open Anyway because the app is not notarized

## Important Operational Risks

- Morning send reliability is better than before, but still needs more real-world validation.
- SMTP setup is partly shared and partly local: host/user/from settings sync, but each Mac needs its own local Keychain password.
- Cross-Mac coordination is practical, not fully hardened.
- Placeholder data can still leak into daily use for media because that connector is not fully configured yet.
- Per-calendar defaults improve classification, but misclassified single events still need a future item-level correction flow.
- People colors are configurable now, but per-calendar color overrides and richer calendar-rule management are still incomplete.
- CI can publish version-triggered releases, but downloaded builds still lack Developer ID signing and notarization.
- The Beacon Wall dashboard style and in-app operational Settings are intentional project choices; future compliance work should not replace them without a separate decision.

## Recommended Next Priorities

1. Build the real setup wizard and broader permissions guidance around the explicit calendar-access path.
2. Make live media actually usable with a real configuration screen and live connector path.
3. Improve sender reliability and diagnostics so morning-send failures are obvious and recoverable.
4. Add notifications and archive/history UI.
5. Add item-level correction workflows and finish the remaining briefing/calendar management controls.

## Latest Durable Rollback Point

- `known-good/20260321-ready-room-0.2.11`

This is the current durable “last known good” anchor to return to if a later change breaks something important.
