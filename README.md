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

To create the release-style universal macOS DMG locally, run:

```bash
./scripts/create_dmg.sh
```

That script validates that `VERSION`, `BUILD_NUMBER`, `LAST_BUILT_VERSION`, and `Sources/App/Info.plist` agree, builds both Apple Silicon and Intel slices, combines them into one universal app, ad-hoc signs the app, and writes a DMG to `dist/`.

If you intentionally want to change the tracked app version/build metadata, run:

```bash
./scripts/set_app_version.sh 0.2.16 36
```

## CI and Releases

GitHub Actions runs the build workflow on every push to `main`. The build workflow runs tests, creates the universal DMG, and uploads it as a 30-day workflow artifact.

The release workflow runs when `VERSION` changes on `main`. It reads the checked-in version metadata, creates or reuses the matching `v<version>` tag when safe, builds the universal DMG, and publishes it to the GitHub Release for that version. A version bump is therefore the "publish this version" signal.

Ready Room releases are ad-hoc signed, not Developer ID signed or notarized. This is suitable for a personal app workflow, but downloaded builds may still trigger Gatekeeper. If macOS blocks the app, try opening it once, then go to System Settings > Privacy & Security and choose Open Anyway.
