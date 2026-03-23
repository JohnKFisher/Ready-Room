# Ready Room Living Plan

## Project Summary

Build a macOS-native dashboard and daily briefing app for household/work operations with:

1. a rules-first normalization layer
2. a dashboard that stays readable all day
3. deterministic email briefings with AI as optional enhancement
4. clear shared-vs-local storage boundaries for multi-Mac use

## Stage Matrix

| Stage | Description | Status |
| --- | --- | --- |
| S0 | Repository bootstrap + architecture scaffold | In Progress |
| S1 | Core models, rules, persistence boundaries | In Progress |
| S2 | Dashboard shell + preview shell | In Progress |
| S3 | Deterministic briefings + sender coordination | In Progress |
| S4 | Live connectors + setup + operational polish | In Progress |

## Current Snapshot

Implemented in this foundation pass:

- SwiftPM app + target split for `Core`, `Persistence`, `Connectors`, `Briefings`, and `App`
- normalized domain models and decision-trace structures
- rules engine for required calendar ownership, adult-only briefing relevance, work/home classification, due-soon logic, change tracking, and conflict detection
- file-based shared/local storage scaffolding, YAML obligations store, Keychain-backed secrets, and send/archive stores
- connector scaffolding for EventKit, weather, news, and Plex-family services
- deterministic briefing composer with truthful preferred-vs-actual AI fallback disclosure
- sender abstraction, scheduled-send coordination logic, an SMTP HTML sender path, and an Apple Mail compatibility fallback path
- SwiftUI app shell for dashboard, preview, obligations, settings, and debug flows
- obligations editor now supports post-parse field edits, inline explanation editing, and click-to-edit for saved items
- sample placeholder sources are explicitly labeled in the dashboard and debug source-health views until live connectors replace them
- obligations now appear on the dashboard timeline as all-day items, due-soon cards show remaining days, and Storage/Sync preferences expose the actual shared-vs-local file locations and sync mode
- open apps now reload shared obligations on refresh and watch the shared obligations file timestamp during the existing minute loop so cross-Mac updates can appear without relaunch
- calendar items are only marked cancelled when the source explicitly reports cancellation, and the dashboard now keeps yesterday visible until 3:00 AM while dimming finished items as complete
- dashboard and briefing day breaks now use a fixed five-day window: `Today`, `Tomorrow`, and a combined `Upcoming` bucket for the next visible future days, while the dashboard still preserves the overnight `Yesterday` carry window
- dashboard timeline items and briefing event rows now use owner-based accent colors driven by shared, customizable John/Amy/Ellie/Mia palette settings
- the app now has a real icon workspace, deterministic iconset generation script, and bundled `.icns` packaging path instead of shipping without a proper app icon
- the timeline remains permissive for calendar items even when their dashboard include-flag is false, preventing a regression where the main timeline appeared nearly empty
- the Settings sidebar now uses explicit tagged sidebar rows so subsection selection works reliably on macOS
- the Calendars settings page is now real: it lists discovered calendars, saves shared per-calendar role/default-owner/default-relevance defaults, and shows read-only preview rows with the current owner/relevance trace for recent events
- the Storage/Sync screen now distinguishes between iCloud not being active for the current build/Mac and files simply not having been created yet
- obligation occurrences now use the same carry-yesterday-until-3:00-AM day boundary as the timeline, so late-night recurring items stay attached to the expected day group
- multi-day all-day events now appear on each day they cover in the timeline instead of only their start day, and they are only marked complete after their final covered day
- Storage/Sync now supports a machine-local custom shared folder so different Macs can point Ready Room at different absolute Resilio Sync paths without syncing the path setting itself
- Sender settings are now shared config instead of hardcoded placeholder recipients, with explicit primary-sender designation, SMTP configuration, Keychain-backed per-Mac SMTP passwords, and fresh regeneration before scheduled morning sends
- generated briefings now carry a prominent early-development warning banner and explicitly label placeholder-derived weather, news, media, and calendar content
- scheduled-send dedupe now distinguishes manual test sends from scheduled sends, SMTP delivery now emits multipart plain-text-plus-HTML mail, and Apple Mail remains a readable compatibility fallback instead of receiving raw HTML tags
- briefing sections now carry dated `Today`/`Tomorrow` headers, `Upcoming` day subheaders, and trailing audience initials so previewed and sent briefings stay readable without repeating the date on every row
- `New or Changed` calendar state now uses a machine-local persisted baseline so previously seen events stay stable across app restarts instead of resetting to `new` on each relaunch
- calendar location URLs for Zoom and Teams meetings now surface as friendly labels instead of dumping raw meeting links into the dashboard and briefings
- due-soon obligations now suppress obviously duplicate all-day calendar items when owner, visible day, and normalized title match, avoiding duplicate dashboard/briefing rows from capitalization or punctuation-only differences
- Weather now has a real shared configuration screen: it defaults to ZIP `08854`, resolves ZIP or city/state input through Apple location search, fetches live conditions from Open-Meteo, keeps the hero weather compact, and gives the dashboard weather card richer today-detail plus `Today`/`Tonight`/`Tomorrow` forecast context
- News now has a real shared configuration screen with a working seeded starter bundle centered on Reuters, ABC News U.S., FOX 5 NY / My9 New Jersey, NJ Spotlight News, NJ.com, NPR, and CBS News U.S., plus optional manual local feeds, story-lane metadata for national vs New Jersey vs regional-overflow selection, and shared-base-plus-override profile controls for Dashboard/John/Amy
- live news refresh now fetches configured feeds on startup, manual refresh, pre-send refresh, and a bounded while-open cadence; failures surface as `stale` or `unavailable` while reusing the last good cached headlines instead of silently dropping back to sample content
- news ranking is now deterministic and inspectable: feed priority, dedupe clustering, recency decay, and per-surface feed boosts produce separate ranked outputs for the dashboard, John's briefing, and Amy's briefing from one fetch pass, and the dashboard now picks featured stories as national + New Jersey + best remaining when the day supports that mix
- dashboard news headlines now open the real article URL in the default browser
- the default Dashboard screen now uses a Beacon Wall layout with a large hero band, left timeline rail, slot-based module placement, and a compact controls strip for compare mode and module arrangement while still honoring the existing local card-order persistence
- `docs/WHERE_WE_STAND.md` now captures the current implemented/partial/missing status and should be regenerated on future major or minor version bumps

Still open after this pass:

- richer live connector configuration and authentication UX beyond weather/news's current path
- item-level correction workflows and keyword-owner rule editing beyond the new per-calendar defaults screen
- production-grade Foundation Models prompt integration
- full setup wizard persistence and permissions UX
- app bundling/signing refinement and runtime smoke-testing against real local services
- OAuth-grade SMTP auth and broader provider-specific setup guidance beyond basic username/app-password flows
- real live media connectors and settings beyond today's sample media placeholder path

## Decisions Log

- 2026-03-13: Personal local-signed macOS app first; no Mac App Store constraints in v1.
- 2026-03-13: EventKit is the only required v1 calendar integration boundary.
- 2026-03-13: Shared synced state stays file-based in iCloud Drive; machine-local state stays in Application Support.
- 2026-03-13: `Yams` is the only new third-party dependency, used for obligations YAML.
- 2026-03-13: AI provider order is Foundation Models -> Ollama -> no-AI templates, with deterministic fallback always available.
- 2026-03-22: Beacon Wall becomes the default dashboard layout; advanced dashboard controls stay available in a compact strip instead of per-card chrome.
- 2026-03-23: The unfinished minimal-chrome toggle is removed; dashboard weather stays lean in the hero but expands in-card; dashboard news defaults shift to a North Jersey / U.S. mix with featured national-plus-local selection, and dead AP/MyCentral placeholders are replaced by live ABC News U.S., FOX 5 NY / My9 New Jersey, and NJ Spotlight News feeds.

## Risks And Follow-Ups

- Foundation Models integration is intentionally wrapped behind a provider boundary because the deterministic fallback must remain the trustworthy path.
- SMTP HTML delivery now depends on each sending Mac having a valid local Keychain password and provider-compatible SMTP settings; Apple Mail automation remains the plain-text fallback path when SMTP is unavailable or fails.
- iCloud shared storage and duplicate-send protection must be validated with two Macs before the scheduler is considered production-safe.
