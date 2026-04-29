# Ready Room Decisions

## 2026-04-28: Use GitHub Actions for version-triggered releases

Status: approved.

Ready Room uses a two-workflow GitHub Actions model: a build workflow runs tests and creates a universal DMG artifact on pushes to `main`, and a release workflow publishes a GitHub Release when the checked-in `VERSION` file changes on `main`. The release artifact is an ad-hoc-signed universal macOS DMG; Developer ID signing and notarization remain future work.

## 2026-04-29: Preserve Beacon Wall as the intentional dashboard character

Status: approved.

Ready Room's Beacon Wall dashboard is intentionally custom and dashboard-like, even where it is less generic Mac than a standard source-list utility app. Compliance work should improve accessibility, commands, reliability, and safety without flattening the app into a generic macOS layout.

## 2026-04-29: Keep operational settings inside the main app for now

Status: approved.

Ready Room's current settings are operational controls for calendars, sender setup, storage/sync, news, weather, and dashboard behavior, so they remain in the main app sidebar for now. A small native macOS Settings scene can be added later for narrow app-level preferences if that becomes useful.

## 2026-04-29: Use macOS 26 GitHub runners for Swift 6.2 builds

Status: approved.

Ready Room's Swift package currently uses Swift tools version 6.2, so the GitHub workflows intentionally run on `macos-26`. Older runner compatibility should not be assumed unless the toolchain or package manifest changes.

## 2026-04-29: Remove notification permission text until notifications exist

Status: approved.

Ready Room does not implement notifications yet, so the notification privacy usage string is removed to avoid implying a permission or feature that is not active. Notification permission text should return only with real notification behavior and a clear user-facing control path.
