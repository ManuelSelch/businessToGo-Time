# Review and isolated test harness — Design

## Overview

Document the current application without silently repairing product behavior. Restore build inputs first, then prove a small isolated test composition and a driver-based real-app launch. The baseline, findings, architecture and test allocation are written; **production/test implementation awaits approval**. Broader reducer/service scenarios belong to S10/S6–S8, not this harness increment.

## Components

| Package/module | Component | Change | Responsibility |
|---|---|---|---|
| Repository / Xcode project | [Boarding gitlink and project](../../businessToGo.xcodeproj/project.pbxproj) | Changed after source recovery | Restore intended package input without deleting onboarding; align real package product references. |
| Common | [Package.swift](../../Common/Package.swift) | Changed | Declare existing UI asset resources; use iOS simulator test execution rather than inventing a macOS support requirement. |
| App shell | [AppLauncher](../../businessToGo/AppLauncher.swift), [businessToGoApp](../../businessToGo/businessToGoApp.swift) | Changed | Parse a proposed Debug-only test launch configuration before any live store/service creation; explicitly launch real UI for E2E while preserving hosted unit TestApp. |
| App test composition | Proposed `businessToGo/App/Testing` | New, Debug-only | Construct fresh real Kimai services/router/track dependencies, run-owned database and scoped credentials/preferences; force remote logging and request capture off. No driver imports. |
| KimaiServices | [KimaiService](../../Modules/Kimai/Sources/Services/KimaiService.swift), [PageRequestService](../../Modules/Kimai/Sources/Services/PageRequestService.swift) construction seams | Changed, additive | Supply fresh services/Moya providers rather than static factories; preserve injected transport when auth plugins rebuild providers. Current endpoint/auth/date behavior remains unchanged. |
| App tests | Proposed `businessToGoTests/Integration/Support` | New, test-only | Independent integration root/feature drivers, private DI/resource context, one real SQLite round-trip scenario. |
| Xcode UI tests | Proposed `businessToGoUITests/DSL` and actual native test target | New, test-only | Root/feature XCUI drivers, private shared context, bounded assertions and cleanup; replace stale skipped target reference with a real target. |
| Fixture transport | Proposed UI-test-owned loopback HTTP fixture server | New, test-only | Small deterministic HTTP surface for smoke fixtures, request recording and explicit unavailable/error responses; state lives in the runner across app relaunch. No external server or new third-party framework required. |

- One root driver owns a run ID and its private context. Feature drivers borrow context; scenarios see only domain operations/assertions. Integration and UI implementations stay independent.
- A serial integration context saves/restores global DI values and mode, server URL, router and preferences. All effects settle before restoration. Database files and credential namespaces live only for that run; relaunch retains them until final teardown.
- File-backed SQLite can be composed through the external Database value's public mutable closures (starting from a mock value and replacing storage/cleanup closures), with a real SQLite connection held by the context. This exercises real repositories/track/RecordService without invoking destructive `Database.live` cleanup. Declare direct SQLite product visibility where construction needs it; pin the existing resolved revision, not a library upgrade.
- The real scoped Keychain adapter may reuse `live(uniqueService)` for safe set/get/remove-one behavior, but must replace unscoped remove-all and standard-defaults selection closures with namespace-scoped operations. Unsafe external reset/deletion behavior is not exercised on personal resources or presented as fixed.

## Runtime flow

1. The UI root driver creates a unique run, starts its loopback fixture listener with a bounded readiness check, and launches XCUIApplication with validated Debug-only configuration: run ID, fixture scenario and loopback URL. Driver assertions forward the scenario's file/line.
2. AppLauncher selects real UI for that explicit E2E configuration. Test composition runs before the existing global initialization, replaces all relevant dependencies with fresh objects, creates run-scoped file storage/credential/preference namespaces, and forbids remote logging/capture. Missing or malformed requested test configuration fails closed.
3. The real account screen, router, reducer, Kimai services and decoders operate against synthetic fixtures. Injected Moya providers restrict destinations to the fixture listener even after `setPlugins`. Test fixtures never use the hardcoded personal server. App/UI callbacks remain real.
4. The first UI proof asserts the account screen and navigable real UI rather than `TestApp`. The first integration proof writes a customer using actual service/repository/track components, closes/recreates the file connection and services, and reads the row and pending operation back.
5. Drivers settle work, terminate the test app, stop the listener, and delete only run-owned files/credentials. Failure follows the same cleanup path, preserving redacted diagnostics. Relaunch steps deliberately reuse the run ID before final cleanup.

## Contracts & API changes

| Provider → consumer | Current → proposed contract | Compatibility |
|---|---|---|
| Test runner → app startup | No test launch schema → Debug-only validated run ID/scenario/loopback URL and explicit E2E switch | Release app ignores/excludes test configuration; normal startup and hosted unit TestApp remain. Invalid test-mode input cannot select live defaults. |
| Test composition → Kimai services | Static global factories → additive explicit construction with provider/repository collaborators | Normal production defaults unchanged; no Bearer-token or date wire changes in this increment. |
| Provider rebuild → request service | `setPlugins` creates default provider → rebuild retains configured fixture session/host restriction | No test request can silently escape to production. |
| Driver → fixture server | No contract → run-scoped requests/responses and recorded requests | Test-only; minimum endpoints needed for the smoke proof, not a speculative full Kimai emulator. |
| App UI → UI driver | Unstable label-based queries → stable accessibility IDs for exercised controls | Presentation/user behavior unchanged; IDs hidden inside drivers. |
| Test context → persistence | Shared/ambient storage → explicit run-owned file/namespace and strict cleanup allowlist | Production filenames/schema unchanged; existing reset bugs remain tracked separately. |

HTTP loopback allowance must be confined to a Debug/test build configuration, not blanket arbitrary-load permission in release. Unexpected HTTP destinations fail before transport. No public API/schema/auth migration or latest-iOS deployment-target bump is bundled into the harness.

## Decisions & Trade-offs

- Keep XCTest for existing unit/integration targets and XCUITest for E2E; avoid a framework migration while recovering the app. Serial execution is required by custom process-global DI, not merely a preference.
- Use real client services and storage in integration/E2E, replacing external network/credential selection only. A complete fake KimaiService would hide the highest-risk wiring errors.
- Test-runner loopback server avoids a production server dependency and survives app relaunch. Its implementation is narrowly scoped and must reject unsupported requests; it is not compatibility evidence.
- Unit-testability seams for all concrete reducer/service collaborators are documented in [TESTING.md](../testing/TESTING.md) but deferred to the corresponding S10 design/implementation increment. No wholesale protocol/architecture rewrite is needed for the two initial harness proofs.
- Existing server permission covers synthetic compatibility fixtures only. URL, version and account constraints are configured later; no compatibility requests are required for this harness.
- Missing Boarding source blocks app launch validation. Installing/selecting the latest stable Xcode/iOS runtime is a separate environment prerequisite; the installed 26.1 toolchain does not satisfy that verification gate.

## Verification

- Already run: remote dependency resolution passes; widget-only simulator compilation passes; app/build-for-testing fail on Boarding; Common host tests fail before execution. See [baseline](BASELINE.md).
- After approval/recovery: app/widget/latest-iOS test builds, actual test discovery, one real-app driven launch, real SQLite close/reopen with tracked change, fixture decode/persistence, network escape rejection (including provider rebuild), invalid launch configuration, and cleanup after intentional assertion/fixture failure.
- Repeat the two proofs with fresh run IDs and a relaunch using the same ID. Check no personal files/credentials are created/touched and no monitor traffic occurs. Assert async settlement before restoring global dependencies; do not depend on sleep timing.
- Defer broad scenario implementation to S10/S6–S8 and live-server checks to explicit opt-in configuration. Current F2–F9 defects are not waived or silently fixed by harness tests.

## Open Questions

1. **D1:** Where can the intended Boarding source at commit `0035f14fd8b0149bbe3272f032c7f6a032a4ad46` be recovered (repository URL or local copy)? The gitlink has no `.gitmodules` mapping and is empty in this checkout.
