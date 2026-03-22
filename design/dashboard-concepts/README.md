# Dashboard Concepts

This workspace is intentionally design-only. Nothing here is authoritative for implementation until a later selection pass.

## What This Pack Covers

- `9` dashboard mockups built from one frozen content payload
- `3` conservative revamps
- `3` medium-shift directions
- `3` big swings
- a comparison contact sheet at [contact-sheet.png](/Users/jkfisher/Resilio%20Sync/Family%20Documents/Codex/Ready%20Room/design/dashboard-concepts/previews/contact-sheet.png)

## Frozen Content Payload

Every concept uses the same information mix so the comparison stays honest:

- header: app name, date, time, runtime label, weather summary
- summary: one shared “what matters this morning” sentence
- timeline: `Today`, `Tomorrow`, and `Upcoming`
- side modules: `Due Soon`, `Weather`, `News`, `Media`
- status chips: `Sources`, `Conflicts`, `Quiet Hours`, `Status`

The payload is defined in [render_dashboard_concepts.swift](/Users/jkfisher/Resilio%20Sync/Family%20Documents/Codex/Ready%20Room/design/dashboard-concepts/render_dashboard_concepts.swift).

## Gallery

### Conservative

- [Morning Ledger](/Users/jkfisher/Resilio%20Sync/Family%20Documents/Codex/Ready%20Room/design/dashboard-concepts/concepts/01-morning-ledger.md)  
  ![Morning Ledger](/Users/jkfisher/Resilio%20Sync/Family%20Documents/Codex/Ready%20Room/design/dashboard-concepts/previews/01-morning-ledger.png)

- [Glass Rail](/Users/jkfisher/Resilio%20Sync/Family%20Documents/Codex/Ready%20Room/design/dashboard-concepts/concepts/02-glass-rail.md)  
  ![Glass Rail](/Users/jkfisher/Resilio%20Sync/Family%20Documents/Codex/Ready%20Room/design/dashboard-concepts/previews/02-glass-rail.png)

- [Quiet Columns](/Users/jkfisher/Resilio%20Sync/Family%20Documents/Codex/Ready%20Room/design/dashboard-concepts/concepts/03-quiet-columns.md)  
  ![Quiet Columns](/Users/jkfisher/Resilio%20Sync/Family%20Documents/Codex/Ready%20Room/design/dashboard-concepts/previews/03-quiet-columns.png)

### Medium Shifts

- [Signal Board](/Users/jkfisher/Resilio%20Sync/Family%20Documents/Codex/Ready%20Room/design/dashboard-concepts/concepts/04-signal-board.md)  
  ![Signal Board](/Users/jkfisher/Resilio%20Sync/Family%20Documents/Codex/Ready%20Room/design/dashboard-concepts/previews/04-signal-board.png)

- [Bento Pulse](/Users/jkfisher/Resilio%20Sync/Family%20Documents/Codex/Ready%20Room/design/dashboard-concepts/concepts/05-bento-pulse.md)  
  ![Bento Pulse](/Users/jkfisher/Resilio%20Sync/Family%20Documents/Codex/Ready%20Room/design/dashboard-concepts/previews/05-bento-pulse.png)

- [Dayline Focus](/Users/jkfisher/Resilio%20Sync/Family%20Documents/Codex/Ready%20Room/design/dashboard-concepts/concepts/06-dayline-focus.md)  
  ![Dayline Focus](/Users/jkfisher/Resilio%20Sync/Family%20Documents/Codex/Ready%20Room/design/dashboard-concepts/previews/06-dayline-focus.png)

### Big Swings

- [Command Theater](/Users/jkfisher/Resilio%20Sync/Family%20Documents/Codex/Ready%20Room/design/dashboard-concepts/concepts/07-command-theater.md)  
  ![Command Theater](/Users/jkfisher/Resilio%20Sync/Family%20Documents/Codex/Ready%20Room/design/dashboard-concepts/previews/07-command-theater.png)

- [Editorial Desk](/Users/jkfisher/Resilio%20Sync/Family%20Documents/Codex/Ready%20Room/design/dashboard-concepts/concepts/08-editorial-desk.md)  
  ![Editorial Desk](/Users/jkfisher/Resilio%20Sync/Family%20Documents/Codex/Ready%20Room/design/dashboard-concepts/previews/08-editorial-desk.png)

- [Beacon Wall](/Users/jkfisher/Resilio%20Sync/Family%20Documents/Codex/Ready%20Room/design/dashboard-concepts/concepts/09-beacon-wall.md)  
  ![Beacon Wall](/Users/jkfisher/Resilio%20Sync/Family%20Documents/Codex/Ready%20Room/design/dashboard-concepts/previews/09-beacon-wall.png)

## Regenerating

```bash
swift design/dashboard-concepts/render_dashboard_concepts.swift
```

That command rewrites the PNG previews from the frozen payload without touching the shipping app UI.
