# Ready Room Decisions

## 2026-04-28: Use GitHub Actions for version-triggered releases

Status: approved.

Ready Room uses a two-workflow GitHub Actions model: a build workflow runs tests and creates a universal DMG artifact on pushes to `main`, and a release workflow publishes a GitHub Release when the checked-in `VERSION` file changes on `main`. The release artifact is an ad-hoc-signed universal macOS DMG; Developer ID signing and notarization remain future work.
