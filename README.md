# Ready Room

Ready Room is a macOS-native family operations dashboard and daily briefing app.

The first foundation build in this repository establishes:

- a SwiftPM-based macOS app shell
- a modular core/rules/connectors/persistence/briefings architecture
- file-based shared-vs-local storage boundaries
- a deterministic dashboard and briefing pipeline
- tests around the rules and briefing logic that matter most

This repo is intentionally local-first and personal-app-first. AI is optional enhancement, not a dependency for correctness.

## Development

```bash
swift build
swift test
```

## Packaging

Once the app target is built, a local `.app` bundle can be created with:

```bash
./scripts/build_app.sh
```

`build_app.sh` is the official packaging path. It uses the checked-in `VERSION` and `BUILD_NUMBER` metadata, generates a bundle-local `Info.plist`, and does not mutate tracked files during a normal build.

If you intentionally want to change the tracked app version/build metadata, run:

```bash
./scripts/set_app_version.sh 0.2.16 36
```
