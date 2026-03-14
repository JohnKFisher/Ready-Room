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
| S4 | Live connectors + setup + operational polish | Pending |

## Current Snapshot

Implemented in this foundation pass:

- SwiftPM app + target split for `Core`, `Persistence`, `Connectors`, `Briefings`, and `App`
- normalized domain models and decision-trace structures
- rules engine for calendar relevance, work/home classification, due-soon logic, change tracking, and conflict detection
- file-based shared/local storage scaffolding, YAML obligations store, Keychain-backed secrets, and send/archive stores
- connector scaffolding for EventKit, weather, news, and Plex-family services
- deterministic briefing composer with preferred-vs-actual AI mode disclosure
- sender abstraction, scheduled-send coordination logic, and an Apple Mail sender implementation path
- SwiftUI app shell for dashboard, preview, obligations, settings, and debug flows
- obligations editor now supports post-parse field edits, inline explanation editing, and click-to-edit for saved items
- sample placeholder sources are explicitly labeled in the dashboard and debug source-health views until live connectors replace them
- obligations now appear on the dashboard timeline as all-day items, due-soon cards show remaining days, and Storage/Sync preferences expose the actual shared-vs-local file locations and sync mode

Still open after this pass:

- richer live connector configuration and authentication UX
- production-grade Foundation Models prompt integration
- full setup wizard persistence and permissions UX
- app bundling/signing refinement and runtime smoke-testing against real local services

## Decisions Log

- 2026-03-13: Personal local-signed macOS app first; no Mac App Store constraints in v1.
- 2026-03-13: EventKit is the only required v1 calendar integration boundary.
- 2026-03-13: Shared synced state stays file-based in iCloud Drive; machine-local state stays in Application Support.
- 2026-03-13: `Yams` is the only new third-party dependency, used for obligations YAML.
- 2026-03-13: AI provider order is Foundation Models -> Ollama -> no-AI templates, with deterministic fallback always available.

## Risks And Follow-Ups

- Foundation Models integration is intentionally wrapped behind a provider boundary because the deterministic fallback must remain the trustworthy path.
- Apple Mail automation will require runtime Apple Events authorization and real-machine testing before it should be trusted for scheduled sending.
- iCloud shared storage and duplicate-send protection must be validated with two Macs before the scheduler is considered production-safe.
