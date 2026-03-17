# Ready Room App Icon Workspace

This folder holds the app icon concept work, the approved master source, and the prompt text used for the concept pass.

## Selected Direction

- Family: command-center / briefing console
- Style: premium macOS glass
- Accent treatment: subtle John/Amy/Ellie/Mia signal rails
- Mark style: symbol-only

## Key Files

- `concepts/`: concept renders plus concept prompt text
- `final/AppIcon-master.png`: approved 1024 master used for the app bundle icon set

## Regeneration

Render the approved master:

```bash
swift scripts/render_app_icon.swift \
  --concept ready-room-final \
  --size 1024 \
  --output design/app-icon/final/AppIcon-master.png
```

Generate the tracked macOS icon set:

```bash
./scripts/generate_iconset.sh
```

## Note

The concept prompts were verified with the image generation CLI in dry-run mode because `OPENAI_API_KEY` was not configured in this environment during implementation. The shipped icon art is therefore a local deterministic render that follows the same approved art direction.
