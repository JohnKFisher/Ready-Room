# Ready Room Compliance Review

Audit date: 2026-04-29

This document is the working checklist for bringing Ready Room into alignment with the newly added project rules and the relevant Build macOS Apps guidance. It is intentionally not an approval record by itself. Items marked as proposed changes or intentional exceptions still need explicit owner approval before implementation or decision-log updates.

Default UI bias: preserve Ready Room's current Beacon Wall character. Custom, dashboard-like, or slightly iOS-flavored UI should be treated as an intentional product direction unless it creates a concrete macOS usability, accessibility, reliability, or maintainability problem.

## Sources Reviewed

- Project rules and docs: `AGENTS.md`, `CLAUDE.md`, `docs/agent-rules/*.md`, `docs/DECISIONS.md`, `docs/WHERE_WE_STAND.md`, `docs/LIVING_PLAN.md`
- Build macOS Apps guidance: SwiftPM macOS, build/run/debug, SwiftUI patterns, view refactor, window management, signing/entitlements, packaging/notarization, telemetry
- Implementation evidence: `Package.swift`, `Sources/App`, `Sources/Persistence`, `Sources/Connectors`, `.github/workflows`, `scripts`, `README.md`, `VERSION`, `BUILD_NUMBER`, `LAST_BUILT_VERSION`, `Sources/App/Info.plist`

## Status Key

- Compliant: current implementation appears to satisfy the rule.
- Partial: the project partly satisfies the rule, but a gap remains.
- Not compliant: current implementation conflicts with the rule.
- Needs discussion: the right answer is product-specific and should be explicitly approved.
- Not applicable: the rule does not currently apply.

## Project Rules And Workflow

| Rule / guidance | Current evidence | Status | Recommended path | Risk | Owner decision needed |
| --- | --- | --- | --- | --- | --- |
| `AGENTS.md` is the single project rule source; `CLAUDE.md` should point to it. | `CLAUDE.md` directly instructs Claude to read and follow root `AGENTS.md`. | Compliant | No action. | Low | No |
| Session startup docs should exist and be read. | `docs/DECISIONS.md`, `docs/WHERE_WE_STAND.md`, and `docs/LIVING_PLAN.md` exist and are current enough to guide work. | Compliant | No action for this audit. | Low | No |
| Conditional rule files should be available and used when triggers match. | `docs/agent-rules/` contains Apple, CI/release, user data, long-running work, untrusted input, diagnostics, AI, README/distribution, migration, cross-platform, Windows, and Tauri rules. | Compliant | No action. | Low | No |
| Meaningful decisions should be appended to `docs/DECISIONS.md`. | Release workflow decision is recorded. Current UI-preservation preference is not yet recorded as an approved project decision. | Partial | Proposed change: after owner approval, append a decision that Beacon Wall/custom dashboard character is intentional and should not be flattened by generic macOS compliance work. | Low | Yes |
| `docs/WHERE_WE_STAND.md` should track durable project state. | Status doc reflects version `0.2.15 (35)` while repo metadata is `0.2.16 (36)`. | Partial | Proposed change: update status doc in a later doc-maintenance pass, or record this as acceptable drift until the next material implementation session. | Low | Yes |
| Audit pass should not implement compliance fixes. | This review only adds the audit document. | Compliant | No action. | Low | No |

## README, Distribution, And Licensing

| Rule / guidance | Current evidence | Status | Recommended path | Risk | Owner decision needed |
| --- | --- | --- | --- | --- | --- |
| Personal/hobby apps should say plainly near the top that outside usefulness is incidental and no support, stability, warranty, or roadmap promise is implied. | `README.md` says Ready Room is local-first and personal-app-first, but does not include the fuller no-warranty/no-support framing. | Partial | Proposed change: strengthen the opening README language with a plain personal-app disclaimer. | Low | Yes |
| Default license is MIT unless specified otherwise. | No `LICENSE` file was found. `README.md` does not state a license. | Not compliant | Proposed change: add an MIT `LICENSE` naming John Kenneth Fisher, or record an intentional exception if this repo should remain unlicensed/private-only. | Medium | Yes |
| Notarization and Gatekeeper limitations must be disclosed honestly with GUI-first steps. | `README.md`, `docs/WHERE_WE_STAND.md`, and release notes disclose ad-hoc signing and System Settings > Privacy & Security > Open Anyway. | Partial | Proposed change: keep existing disclosure and add the rule's more explicit note that notarization is intentionally not being paid for in this personal-app workflow, if true. | Low | Yes |
| About screen should credit "John Kenneth Fisher" and link to public GitHub page if one exists. | No About screen or custom About scene was found. Public GitHub page existence was not verified during this audit. | Needs discussion | Deferred until feature milestone: decide whether Ready Room needs a custom About screen once public repo/distribution posture is settled. | Low | Yes |

## Apple Platform, Permissions, And Privacy

| Rule / guidance | Current evidence | Status | Recommended path | Risk | Owner decision needed |
| --- | --- | --- | --- | --- | --- |
| Use stable reverse-DNS bundle ID under `com.jkfisher`. | `Sources/App/Info.plist` uses `com.jkfisher.readyroom`. | Compliant | No action. | Low | No |
| Avoid private APIs and prefer documented Apple APIs. | EventKit, MapKit, SwiftUI, Keychain Services, NSAppleScript/Mail automation, and URLSession are documented APIs. | Compliant | No action. | Low | No |
| Request permissions as late as possible and handle denied states gracefully. | Calendar access is requested inside `EventKitCalendarConnector.refresh()`, which can happen during bootstrap/refresh; denied state becomes `.unauthorized`. | Partial | Proposed change: keep graceful denied handling, but discuss whether calendar permission should move into an explicit setup/permission flow before first live refresh. | Medium | Yes |
| Do not modify entitlements or app permissions without approval. | No entitlement file was found. Info.plist includes Calendar, Apple Events, and Notification usage strings. | Partial | Needs discussion: Apple Events and Calendar match current behavior; notification usage string exists while notifications are not implemented. Decide whether to remove it for now or keep it as an intentional near-term placeholder. | Medium | Yes |
| Notification permissions should not be implied before notification behavior exists. | `NSUserNotificationUsageDescription` exists; `docs/WHERE_WE_STAND.md` says notifications are not implemented. | Needs discussion | Recommended change: remove the notification usage string until notifications are implemented, unless owner explicitly wants to keep it as an intentional exception. | Medium | Yes |
| Local-first and least-privilege defaults. | Shared/local storage boundary exists; SMTP password is local Keychain-backed; no silent analytics or telemetry found. | Compliant | No action. | Low | No |
| User data writes should be user-initiated and scoped. | Obligations, sender settings, weather/news settings, calendar configurations, storage preferences, send records, and archives are app-owned files; writes are tied to user actions or scheduled send bookkeeping. | Partial | Deferred until setup/hardening milestone: add clearer setup screens and scope explanations before broadening any write behavior. | Medium | Yes |

## Long-Running Work, Sync, And External Inputs

| Rule / guidance | Current evidence | Status | Recommended path | Risk | Owner decision needed |
| --- | --- | --- | --- | --- | --- |
| Long-running work should keep UI responsive and expose liveness. | Refresh and scheduled-send work runs through async tasks; status messages and source health exist. | Partial | Proposed change: improve visible working/waiting/failed states during refresh and scheduled send, especially before trusting unattended morning emails. | Medium | Yes |
| Scheduled/time-based actions should prevent duplicates across devices. | Send registry and primary-sender configuration exist; status doc says multi-Mac duplicate-send protection needs real-world validation. | Partial | Deferred until reliability milestone: validate with two Macs and record results before calling scheduler production-safe. | High | Yes |
| Distinguish unavailable, stale, empty, unauthorized, and unconfigured states. | Source health model supports these states; news stale fallback is explicitly surfaced. | Compliant | No action. | Low | No |
| Treat URLs, feeds, paths, and network responses as untrusted. | Weather/news/media connectors use structured decoding and URL construction, but manual feed URLs and custom shared-folder paths deserve more guardrail review. | Partial | Proposed change: audit validation for manual feed URLs and custom shared-folder paths before expanding these features. | Medium | Yes |
| External network behavior should be explicit. | Weather uses Open-Meteo and Apple location search; news uses RSS/Atom feeds; Ollama endpoint is local. README does not list every network endpoint. | Partial | Proposed change: add a short README or status-doc data-source section if/when the app is shared beyond personal use. | Low | Yes |
| Diagnostics should avoid sensitive persistent logs. | No persistent logging system or committed logs found. Debug views expose local app state intentionally. | Compliant | No action now; recheck if telemetry/logging is added. | Low | No |

## CI, Release, Packaging, And Versioning

| Rule / guidance | Current evidence | Status | Recommended path | Risk | Owner decision needed |
| --- | --- | --- | --- | --- | --- |
| Use two-workflow GitHub Actions model for desktop releases. | `.github/workflows/build.yml` and `.github/workflows/release.yml` exist; decision log approves this model. | Compliant | No action. | Low | No |
| Workflows should use explicit least-privilege permissions. | Build uses `contents: read`; release uses `contents: write`. | Compliant | No action. | Low | No |
| JavaScript actions should use Node 24-compatible current majors and set `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24`. | Workflows use `actions/checkout@v6`, `actions/upload-artifact@v7`, and the Node 24 env variable. | Compliant | No action. | Low | No |
| Release should derive version from tracked source-of-truth and not local/generated state. | `VERSION`, `BUILD_NUMBER`, `LAST_BUILT_VERSION`, and `Info.plist` are checked; scripts validate consistency. | Compliant | No action. | Low | No |
| SwiftPM GUI app packaging should build universal app, assemble bundle, create icon, ad-hoc sign, and wrap DMG. | `scripts/create_dmg.sh` builds arm64/x86_64 slices, uses `lipo`, creates `.app`, copies `.icns`, ad-hoc signs, verifies, and creates DMG. | Compliant | No action. | Low | No |
| Ad-hoc signing should not be described as full distribution fix. | README, status doc, release notes, and decision log all say not Developer ID signed or notarized. | Compliant | No action. | Low | No |
| Build/release workflows should avoid tracked-file mutation. | `build_app.sh` and `create_dmg.sh` generate derived plist files under `.build`; prior docs note this was fixed. | Compliant | No action. | Low | No |
| macOS runner choice should be deliberate and compatible with Swift tools version. | Package uses Swift tools 6.2 and workflows run `macos-26`. | Needs discussion | Intentional exception candidate: keep `macos-26` to satisfy Swift 6.2/toolchain needs, but record this as a CI toolchain choice if it is expected to limit older runner compatibility. | Medium | Yes |
| Do not lower deployment targets or broaden compatibility claims without approval. | `Package.swift` and `Info.plist` target macOS 15.0. README does not make broader claims. | Compliant | No action; discuss before changing target. | Medium | No |

## Build macOS Apps Guidance

| Rule / guidance | Current evidence | Status | Recommended path | Risk | Owner decision needed |
| --- | --- | --- | --- | --- | --- |
| Prefer SwiftPM for package-first macOS projects. | Project is SwiftPM-only with `Package.swift`, library products, executable product, and tests. | Compliant | No action. | Low | No |
| SwiftPM GUI apps should have a stable project-local build/run script and Codex Run button config. | `scripts/build_app.sh` and `scripts/create_dmg.sh` exist, but no `script/build_and_run.sh` or `.codex/environments/environment.toml` was found. | Partial | Proposed change: add a lightweight `script/build_and_run.sh` and `.codex/environments/environment.toml` for local app launch/debug convenience. | Low | Yes |
| Do not launch SwiftUI/AppKit GUI apps as raw SwiftPM executables for normal app testing. | Packaging scripts create `.app` bundles; README development section still lists only `swift build` and `swift test`. | Partial | Proposed change: document the app-bundle run path once `script/build_and_run.sh` exists. | Low | Yes |
| Main window scene should match launch behavior. | `ReadyRoomApp.swift` uses `WindowGroup("Ready Room")` with sensible default and minimum sizes. | Compliant | No action. | Low | No |
| Settings should normally be a dedicated macOS `Settings` scene, not just a main-window destination. | Current Settings view lives inside the main sidebar and is a substantial in-app configuration surface. | Needs discussion | Intentional exception candidate: keep in-app Settings for now because Ready Room's configuration is operational and dashboard-adjacent, not just preferences. Consider adding a small native `Settings` scene later for app-level preferences only. | Low | Yes |
| Prefer commands, menus, keyboard paths, and toolbars for primary actions. | Toolbar has Refresh, Dashboard, Briefing, Send Now text buttons; no custom command menus or keyboard shortcuts found. | Partial | Proposed change: add menu/keyboard equivalents for core actions later, while preserving the current toolbar style if owner likes it. | Medium | Yes |
| Prefer native sidebars and stable split layouts. | Root view and Settings use `NavigationSplitView`; Settings sidebar uses `.listStyle(.sidebar)`. Root sidebar does not explicitly set `.listStyle(.sidebar)`. | Partial | Proposed change: consider applying native sidebar list style to the root sidebar only if it does not harm the current visual character. | Low | Yes |
| Preserve system-adaptive colors unless a custom design is intentional. | Dashboard uses a custom Beacon Wall palette; many settings panels use materials and semantic styles. | Needs discussion | Intentional exception candidate: record Beacon Wall palette and visual identity as approved custom design; still audit contrast/accessibility separately. | Medium | Yes |
| Window chrome customization should preserve drag regions and window affordances. | Current app uses standard window chrome; prior minimal-chrome toggle was removed. | Compliant | No action. | Low | No |
| Large SwiftUI files should be split gradually by responsibility. | `DashboardView.swift` and `PreviewSettingsDebugViews.swift` are large; root and app entry are small. | Partial | Deferred until feature/refactor milestone: split along natural feature seams, but avoid broad visual rewrites or character loss. | Medium | Yes |
| Keep AppKit escape hatches narrow. | AppKit imports exist for color/web/mail/platform needs; no broad NSWindow mutation found. | Compliant | No action. | Low | No |
| Prefer `Logger` / unified logging for useful runtime telemetry. | No app telemetry/logging system found. | Needs discussion | Deferred until diagnostics milestone: add minimal `Logger` categories only for scheduler, sends, source refreshes, and permission/fallback paths. | Medium | Yes |

## UI Character Preservation

| Rule / guidance | Current evidence | Status | Recommended path | Risk | Owner decision needed |
| --- | --- | --- | --- | --- | --- |
| Preserve Beacon Wall character unless there is a real platform problem. | `docs/LIVING_PLAN.md` records Beacon Wall as default dashboard layout; user explicitly likes the current UI and does not want generic Mac styling. | Needs discussion | Proposed decision: record Beacon Wall as intentional custom dashboard style. Compliance work should focus on accessibility, commands, settings structure, and reliability rather than replacing the visual identity. | Medium | Yes |
| Do not turn style guidance into broad UI churn. | Current app has a distinct dashboard, settings cards, and operational panels. | Compliant as a process rule | No immediate UI rewrite. Review each proposed UI compliance change separately. | Low | No |
| Accessibility and keyboard navigation remain valid even for custom UI. | Basic SwiftUI controls and labels exist; no focused accessibility audit was performed. | Partial | Proposed change: run a separate accessibility/keyboard pass before declaring UI compliance complete. | Medium | Yes |

## Not Applicable Or Low-Priority Rule Areas

| Rule / guidance | Current evidence | Status | Recommended path | Risk | Owner decision needed |
| --- | --- | --- | --- | --- | --- |
| Tauri/web frontend rules. | Ready Room is native SwiftPM SwiftUI, not Tauri. | Not applicable | No action. | Low | No |
| Windows platform rules. | Ready Room currently targets macOS only. | Not applicable | No action unless Windows support is introduced. | Low | No |
| Migration/format safety for irreversible migrations. | Current audit does not add or change formats. YAML/JSON app data exists. | Not applicable for audit | Revisit before changing stored formats. | Medium | No |
| AI inference rule for new AI behavior. | Audit does not change AI behavior. Existing docs say AI is optional and deterministic fallback remains the trustworthy path. | Not applicable for audit | Revisit when Foundation Models/Ollama behavior changes. | Medium | No |

## Suggested Discussion Order

1. Approve or reject README/LICENSE/distribution wording changes.
2. Decide whether the unused notification usage string should be removed now.
3. Decide whether calendar permission should stay refresh-triggered until setup exists, or move into an explicit permission flow sooner.
4. Decide whether to record Beacon Wall/custom dashboard styling as an intentional exception to generic macOS visual guidance.
5. Decide whether to add the Build macOS Apps local run script and Codex Run button config.
6. Decide how much native desktop affordance work to schedule: command menus, keyboard shortcuts, dedicated Settings scene, accessibility pass.
7. Decide whether large SwiftUI file splitting is worth doing soon or should wait for feature-driven refactors.

## Verification Notes

No build is required for this audit-only artifact. For later implementation passes, use:

```bash
swift test
./scripts/build_app.sh
./scripts/create_dmg.sh
```

Manual smoke checklist for later implementation:

- App opens to Dashboard with Beacon Wall character intact.
- Sidebar navigation still works.
- Settings/configuration screens preserve existing behavior.
- Calendar, weather, news, and sender status messages remain honest.
- README and status docs match actual distribution/signing behavior.
