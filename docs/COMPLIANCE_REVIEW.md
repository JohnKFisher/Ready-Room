# Ready Room Compliance Review

Audit date: 2026-04-29

This document is the working checklist for bringing Ready Room into alignment with the newly added project rules and the relevant Build macOS Apps guidance. It is intentionally not an approval record by itself. Items marked as proposed changes or intentional exceptions still need explicit owner approval before implementation or decision-log updates.

Default UI bias: preserve Ready Room's current Beacon Wall character. Custom, dashboard-like, or slightly iOS-flavored UI should be treated as an intentional product direction unless it creates a concrete macOS usability, accessibility, reliability, or maintainability problem.

## 0.3.0 Decision Summary

Approved for `0.3.0 (37)`:

- Add MIT licensing and fuller README personal-app, no-support, no-warranty, and Gatekeeper/notarization disclosure.
- Remove the unused notification usage string until notification behavior exists.
- Gate live calendar access behind an explicit Calendars Settings action instead of prompting during automatic refresh.
- Record Beacon Wall/custom dashboard styling and in-app operational Settings as intentional choices.
- Keep the macOS 26 GitHub runner for Swift 6.2.
- Add core desktop commands, local run tooling, sparse refresh/send/storage/calendar telemetry, stricter local feed/folder validation, a small accessibility pass, and mechanical SwiftUI extraction.

Denied or deferred:

- No generic Mac restyle.
- No dedicated native macOS Settings scene in this pass.
- No notification feature implementation.
- No Developer ID signing or notarization setup.
- No macOS deployment-target change.
- No very-strict blocking of localhost/private-network feed URLs.
- No broad SwiftUI rewrite or UI-action telemetry.
- No claim that multi-Mac scheduled-send reliability is fully proven before real two-Mac validation.

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
| Meaningful decisions should be appended to `docs/DECISIONS.md`. | Release workflow, Beacon Wall preservation, in-app operational Settings, macOS 26 runner use, and notification permission removal are recorded. | Compliant | Approved change implemented in 0.3.0. | Low | No |
| `docs/WHERE_WE_STAND.md` should track durable project state. | Status doc is refreshed for `0.3.0 (37)`. | Compliant | Approved change implemented in 0.3.0. | Low | No |
| Audit pass should not implement compliance fixes. | This review only adds the audit document. | Compliant | No action. | Low | No |

## README, Distribution, And Licensing

| Rule / guidance | Current evidence | Status | Recommended path | Risk | Owner decision needed |
| --- | --- | --- | --- | --- | --- |
| Personal/hobby apps should say plainly near the top that outside usefulness is incidental and no support, stability, warranty, or roadmap promise is implied. | `README.md` now includes this language near the top. | Compliant | Approved change implemented in 0.3.0. | Low | No |
| Default license is MIT unless specified otherwise. | `LICENSE` exists with MIT terms and README links to it. | Compliant | Approved change implemented in 0.3.0. | Medium | No |
| Notarization and Gatekeeper limitations must be disclosed honestly with GUI-first steps. | `README.md`, `docs/WHERE_WE_STAND.md`, and release notes disclose ad-hoc signing, no notarization, and System Settings > Privacy & Security > Open Anyway. | Compliant | Approved change implemented in 0.3.0. | Low | No |
| About screen should credit "John Kenneth Fisher" and link to public GitHub page if one exists. | No About screen or custom About scene was found. Public GitHub page existence was not verified during this audit. | Needs discussion | Deferred until feature milestone. | Low | Yes |

## Apple Platform, Permissions, And Privacy

| Rule / guidance | Current evidence | Status | Recommended path | Risk | Owner decision needed |
| --- | --- | --- | --- | --- | --- |
| Use stable reverse-DNS bundle ID under `com.jkfisher`. | `Sources/App/Info.plist` uses `com.jkfisher.readyroom`. | Compliant | No action. | Low | No |
| Avoid private APIs and prefer documented Apple APIs. | EventKit, MapKit, SwiftUI, Keychain Services, NSAppleScript/Mail automation, and URLSession are documented APIs. | Compliant | No action. | Low | No |
| Request permissions as late as possible and handle denied states gracefully. | Calendar access is now requested only from an explicit Calendars Settings action; automatic refresh does not trigger the prompt. | Compliant | Approved change implemented in 0.3.0. | Medium | No |
| Do not modify entitlements or app permissions without approval. | No entitlement file was found. Info.plist keeps Calendar and Apple Events usage strings; notification usage text was removed by approval. | Compliant | Approved change implemented in 0.3.0. | Medium | No |
| Notification permissions should not be implied before notification behavior exists. | Notification usage text is removed until notification behavior exists. | Compliant | Approved change implemented in 0.3.0. | Medium | No |
| Local-first and least-privilege defaults. | Shared/local storage boundary exists; SMTP password is local Keychain-backed; no silent analytics or telemetry found. | Compliant | No action. | Low | No |
| User data writes should be user-initiated and scoped. | Obligations, sender settings, weather/news settings, calendar configurations, storage preferences, send records, and archives are app-owned files; writes are tied to user actions or scheduled send bookkeeping. | Partial | Deferred until setup/hardening milestone: add clearer setup screens and scope explanations before broadening any write behavior. | Medium | Yes |

## Long-Running Work, Sync, And External Inputs

| Rule / guidance | Current evidence | Status | Recommended path | Risk | Owner decision needed |
| --- | --- | --- | --- | --- | --- |
| Long-running work should keep UI responsive and expose liveness. | Refresh and scheduled-send work runs through async tasks; status messages, source health, and sparse telemetry exist. | Partial | 0.3.0 improves observability; richer liveness UI remains deferred. | Medium | Yes |
| Scheduled/time-based actions should prevent duplicates across devices. | Send registry and primary-sender configuration exist; status doc says multi-Mac duplicate-send protection needs real-world validation. | Partial | Deferred until real two-Mac reliability validation. | High | Yes |
| Distinguish unavailable, stale, empty, unauthorized, and unconfigured states. | Source health model supports these states; news stale fallback is explicitly surfaced. | Compliant | No action. | Low | No |
| Treat URLs, feeds, paths, and network responses as untrusted. | Enabled feeds now require absolute `http`/`https` URLs with a host; custom shared folders must be creatable directories. | Partial | Approved local validation implemented; broader external-input audit remains future work. | Medium | Yes |
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
| macOS runner choice should be deliberate and compatible with Swift tools version. | Package uses Swift tools 6.2 and workflows intentionally run `macos-26`; decision is recorded. | Compliant | Approved intentional choice recorded. | Medium | No |
| Do not lower deployment targets or broaden compatibility claims without approval. | `Package.swift` and `Info.plist` target macOS 15.0. README does not make broader claims. | Compliant | No action; discuss before changing target. | Medium | No |

## Build macOS Apps Guidance

| Rule / guidance | Current evidence | Status | Recommended path | Risk | Owner decision needed |
| --- | --- | --- | --- | --- | --- |
| Prefer SwiftPM for package-first macOS projects. | Project is SwiftPM-only with `Package.swift`, library products, executable product, and tests. | Compliant | No action. | Low | No |
| SwiftPM GUI apps should have a stable project-local build/run script and Codex Run button config. | `script/build_and_run.sh` and `.codex/environments/environment.toml` now exist. | Compliant | Approved change implemented in 0.3.0. | Low | No |
| Do not launch SwiftUI/AppKit GUI apps as raw SwiftPM executables for normal app testing. | README now documents the app-bundle run path. | Compliant | Approved change implemented in 0.3.0. | Low | No |
| Main window scene should match launch behavior. | `ReadyRoomApp.swift` uses `WindowGroup("Ready Room")` with sensible default and minimum sizes. | Compliant | No action. | Low | No |
| Settings should normally be a dedicated macOS `Settings` scene, not just a main-window destination. | Current Settings view lives inside the main sidebar and is a substantial in-app configuration surface; intentional choice is recorded. | Compliant by exception | Approved exception recorded; no native Settings scene in 0.3.0. | Low | No |
| Prefer commands, menus, keyboard paths, and toolbars for primary actions. | Core commands and shortcuts now mirror Refresh, Dashboard, Briefing, and Send Now. | Compliant | Approved change implemented in 0.3.0. | Medium | No |
| Prefer native sidebars and stable split layouts. | Root view and Settings use `NavigationSplitView`; both sidebars use native sidebar list style. | Compliant | Approved low-risk accessibility/native adjustment implemented. | Low | No |
| Preserve system-adaptive colors unless a custom design is intentional. | Dashboard uses a custom Beacon Wall palette by approved decision; many settings panels use materials and semantic styles. | Compliant by exception | Approved exception recorded; accessibility audit remains future work. | Medium | No |
| Window chrome customization should preserve drag regions and window affordances. | Current app uses standard window chrome; prior minimal-chrome toggle was removed. | Compliant | No action. | Low | No |
| Large SwiftUI files should be split gradually by responsibility. | One obvious news feed editor row was extracted; larger feature splits remain. | Partial | 0.3.0 performs a small mechanical extraction; broader splitting is deferred. | Medium | Yes |
| Keep AppKit escape hatches narrow. | AppKit imports exist for color/web/mail/platform needs; no broad NSWindow mutation found. | Compliant | No action. | Low | No |
| Prefer `Logger` / unified logging for useful runtime telemetry. | Sparse `Logger` categories now cover refresh, calendar permission, send, and storage paths. | Partial | Approved telemetry scope implemented; no broad UI-action telemetry. | Medium | No |

## UI Character Preservation

| Rule / guidance | Current evidence | Status | Recommended path | Risk | Owner decision needed |
| --- | --- | --- | --- | --- | --- |
| Preserve Beacon Wall character unless there is a real platform problem. | `docs/LIVING_PLAN.md` records Beacon Wall as default dashboard layout; decision log now records it as intentional custom character. | Compliant by exception | Approved exception recorded. | Medium | No |
| Do not turn style guidance into broad UI churn. | Current app has a distinct dashboard, settings cards, and operational panels. | Compliant as a process rule | No immediate UI rewrite. Review each proposed UI compliance change separately. | Low | No |
| Accessibility and keyboard navigation remain valid even for custom UI. | Root sidebar and core toolbar actions gained low-risk accessibility/help affordances; a focused accessibility audit remains future work. | Partial | 0.3.0 includes a basic pass; deeper audit deferred. | Medium | Yes |

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
