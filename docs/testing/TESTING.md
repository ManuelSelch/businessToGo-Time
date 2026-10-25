# Test strategy and inventory

Reviewed at `de9e71e`, 2026-10-25. This is the **S5 allocation/design deliverable**, not an implemented test harness. See [proposed design](../app-review/DESIGN.md) for approval gates and [baseline](../app-review/BASELINE.md) for actual command results. No test execution passed: app test build and the Common host test build failed before execution.

## Suite boundaries

| Suite | Real system under test | Replaced/controlled boundary | Purpose |
|---|---|---|---|
| Unit | One reducer, middleware behavior, app service, codec or calculation | Collaborators replaced by small doubles; explicit scheduler/time where needed | Most branches, success/error handling and business rules |
| Integration | A few real app/library components, real SQLite or isolated credential adapter | HTTP controlled; fresh global DI; synthetic data only | Contracts that mocked unit tests cannot establish |
| XCUITest E2E | Actual app UI, routing, reducers and services in a simulator | Dedicated storage/credentials, deterministic local HTTP server | Critical user journeys using root/feature drivers |
| Opt-in compatibility | Actual HTTP/service contract against configured real Kimai | Synthetic restricted account and run-owned fixtures | Detect API/auth/date/pagination drift not represented by local fixtures |

- A reducer test that calls actual services and SQLite is **integration**, even inside a `Tests/CoreTests` folder. A service test using fake network/storage collaborators is **unit**; a service test using real storage is integration.
- E2E with controlled HTTP is end-to-end through the **client app**, not proof that the real server accepts the requests. Keep compatibility checks separate.
- No mandatory full-server integration suite for every CRUD branch, UI tests for every date combination, or tests reproducing all external library internals.

## Existing tests and discovery

- App target: `businessToGoTests/Management/Kimai/TestKimaiReducer.swift`, one `testTeamSelected` method that actually saves a customer. Test naming/assertion/action expectations need review.
- Kimai package: three methods in `Tests/CoreTests/KimaiTests.swift`: team selection, save and delete. Save/delete invoke real service/database behavior under global mock defaults; they are not established pure reducer unit tests.
- Common, NetworkFoundation, RequestFoundation, Intro and Login test files contain six `testExample` methods in total, with no meaningful behavior assertions found by source inspection. Login's folder/target named `UITests` is a package XCTest target importing LoginUI, **not** an XCUITest application runner.
- Total discoverable source methods in the reviewed checkout: ten (four Kimai/app examples, six template methods). Runtime test discovery/count is unverified.
- `businessToGo.xctestplan` names only the app test target. The shared scheme retains a skipped, absent `businessToGoUITests` native target. There is no active E2E suite or integration driver layer.
- Boarding source/tests cannot be inspected because its gitlink source is missing. Validate every package target after build recovery rather than assuming the root scheme covers them.

## Reducer and UI projection allocation

All entries below are planned unless explicitly described above as existing examples. Production paths are relative to repository root.

| Owner / unit | Primary coverage and controlled collaborators |
|---|---|
| `businessToGo/App/AppFeature` | Unit: action delegation/lifting, login/offline selection, sync trigger, logout/reset state, popup/settings/intro routes. Fake Kimai facade, credential adapter and router. |
| `Modules/Login/.../LoginFeature` | Unit: fetch/restore/create/save/delete, current-account selection, logout/reset, demo delegate, dependency failures. Spy database/credential closures; do not touch real Keychain. Identity allocation in LoginContainer needs a small testable rule seam before pure unit testing. |
| `Modules/Kimai/.../KimaiFeature` | Unit: CRUD dispatch, visibility/delete guards/popups, local reload, change-state updates, sync stage order/status/success/failure. Fake per-entity services and bounded effect completion. Existing concrete dependencies require the proposed seam. |
| `Components/Report/Domain/ReportFeature` | Unit: date/project/type selection, previous/next year, month navigation, calendar edge cases. Fixed calendar/clock inputs rather than ambient Date/Calendar. |
| `Modules/Intro/.../IntroFeature` | Unit: first-run preference consumed once, expected delegate/no-op. Isolated preference adapter. |
| `Modules/Debug/.../DebugFeature` | Unit: state/preference updates for remote logging and mock mode. Spy preference adapter. Test app restart semantics separately; do not assert toggle changes global mode immediately. |
| `Modules/Integration/.../IntegrationFeature` | Unit characterization: current `onConnect` is no-op. Do not write tests claiming persistence or Taiga API behavior; feature completion is separate work. |
| Boarding | Unknown until source recovered; inventory reducer/overlay behavior then. |
| `Foundation/RequestFoundation/.../RequestFeature` | Legacy candidate, not active app reducer. First resolve whether to repair/reuse or explicitly retire; no invented active coverage. |
| Login/Kimai/Today/Management/Report/Settings/Assistant components | Unit: `State.from` projections and lifted action mapping, including reset/logout/delete delegates. These are ViewModel adapters, not extra middleware/reducers. |
| `ReportsView` / `ReportViewModel`, `DateExtension`, `KimaiTimesheet`, `MyFormatter` | Unit: selection filtering, grouped totals, time strings, open entries, week-based years, DST, midnight, rounding and invalid dates. UI-owned calculations need minimal extraction/injection before testing without a UI. |

## Middleware allocation

There is **one configured middleware**: external `MonitorMiddleware.handle`, created by `businessToGoApp`; reducers currently own most effects.

- App unit tests: reset/jump-to mapping in `businessToGoApp.onAction`, `.setState` exclusion in `showAction`, remote logging default-off and outbound secret-redaction contract after a separately approved fix.
- Pinned Redux middleware contract: updated-state/action observation, emissions back to store, disabled logging produces no outbound requests, bounded subscription settlement. Real remote sockets are forbidden in ordinary suites.
- A fake monitor/socket boundary is needed to test enabled transmission safely; the library currently constructs its own private client. Do not enable production middleware just to obtain test coverage. An external injection seam/fix needs its own approved change if enabled-path tests require it.
- No other middleware was found in app registration. Inventory newly recovered Boarding code, but do not create artificial middleware layers to satisfy the test plan.

## Service and adapter allocation

| App-owned service / boundary | Unit coverage | Integration coverage retained |
|---|---|---|
| `KimaiService` | Model-type/create-vs-update dispatch, auth configuration, URL validation and login result/error behavior via collaborators | App facade + real record services wired to isolated SQLite/controlled HTTP |
| `KimaiCustomerService` | Customer DTO/team mapping/deduplication, ID allocation, tracked CRUD delegation, fetch/sync errors; fake repositories/request service | Real repository/track/customer sync and team reload after reopening |
| `KimaiProjectService` factory | Table/endpoint/plugin/delete-policy wiring using inspectable factory inputs or request spies | Real RecordService relationship chain; not a duplicate generic CRUD suite |
| `KimaiActivityService` factory | Project/global activity payload policy and no-remote-delete wiring | Relationship chain above |
| `KimaiTimesheetService` factory | PageRequestService selection, endpoint/delete wiring | Persisted timestamps, deletion and sync retry |
| `KimaiUserService` factory | Fetch-only endpoint policy / unsupported writes | Initial fetch into isolated DB, reused in sync smoke coverage |
| `PageRequestService` | 1/0/multiple pages; header absence/malformed values; page failure; 204; decode/transport/status failures; plugin replacement preserves controlled provider; cancellation where supported | One multi-page HTTP → decoder → persisted state path, not every permutation |
| `KimaiAPI` / `KimaiAuthPlugin` | Paths/methods/query/body/null/boolean/date contracts, header values and server selection. Characterize legacy headers separately from modern compatibility acceptance | Optional server contract check after auth migration; no production credential fixture |
| `NetworkFoundation.Network` | Decode and transport/status failures with stub Moya provider | Add only if actually used in a critical composition; avoid duplicate generic HTTP tests |
| LoginServices Keychain DI adapter | Requested service namespace, configuration and error forwarding using credential double | Real isolated Keychain set/get/select/logout/delete contract where safe; unsafe remove-all requires fix first |
| `UserDefaultService` / `UserDefaultWrapper` | Default/malformed/round-trip values via private suite, no global standard defaults | Relaunch persistence in E2E; not a separate large integration suite |
| IntegrationService | Excluded/stale source, not an active service. Characterize only after an explicit recovery/feature decision | Future Taiga scope, not an invented current integration |

External OfflineSync repository/track/sync, LoginService and Redux helpers are **collaborators**, not new app-owned services. Their app-visible contracts are tested through the focused integration/contract scenarios below; substantive fixes should also have tests in their owning repositories. No blanket demand to unit-test every transitive third-party type.

## Why integration tests are still necessary

| Scenario | Bug missed by isolated unit mocks | Why E2E alone is insufficient | Assertions |
|---|---|---|---|
| I1 — Persist and reopen | Reflected schema/Codable arrays/timestamps/track queue do not round-trip | UI often hides queue/schema state and can accidentally show cached state | Recreate connection/services; verify rows, fields and queued operations from storage |
| I2 — Related offline creates and remapping | Parent server ID changes are not propagated to child persisted references or uploads (F4) | A UI list can look correct while foreign keys are wrong | Customer/project/activity/timesheet IDs deliberately differ remotely; inspect child payloads and stored references |
| I3 — Failed fetch and interrupted upload retry | Adapter swallows errors; durable queue acknowledgement differs from mocked orchestration (F2/F3) | UI status does not reveal lost rows or repeated remote POSTs | Cached/pending rows survive failure; successful uploads not duplicated after restart; queue acknowledgement exact |
| I4 — Account/server/credential isolation | Shared DI, ID collisions or deletion use the wrong DB/Keychain namespace (F5/F6/F12) | Secret/cache crossover and deletion of inactive accounts are hard to observe comprehensively | Two accounts/servers, reopen/switch/delete, unrelated sentinel files/credentials survive |

I1 includes one paginated decoding→persistence path and a timestamp round trip; do not create a parallel “all services together” suite. A mock-server-only test cannot establish current Kimai compatibility; keep opt-in compatibility checks.

## Driver-based E2E journeys

| Scenario | Driver surface / intended observation |
|---|---|
| E1 — First use and account configuration | `app.accounts`, `app.setup`: intro/assistant, synthetic account config, real main tabs rather than TestApp |
| E2 — Login outcome and session | `app.accounts`: accept/reject/recover, restore selected account, switch accounts, logout |
| E3 — Time entry and reports | `app.projects`, `app.timesheets`, `app.reports`: create/edit entry, select period/project, verify totals and rows; nil-end/stop only where implemented |
| E4 — Offline persistence and recovery | Save while local server is unavailable, terminate/relaunch same run namespace, restore rows, reconnect/sync, verify user-visible state |
| E5 — Failure and delete UX | Controlled server failure, visible retry/recovery, confirmation/dependency-blocked deletion; no real account reset |

Widget work here is compile/readiness only. Future widget timeline/shared-store/Live Activity tests require actual time-tracking behavior. Taiga E2E is limited to existing configuration and explicitly partial presentation; no backlog/Kanban completion scenarios yet.

Drivers expose lowerCamelCase domain operations and assertions, forwarding file/line. Scenarios never refer to accessibility IDs, launch arguments, HTTP paths, sleeps, teardown mechanics or low-level XCUI queries. UI and integration drivers have separate implementations/private contexts; share fixture vocabulary only, not an artificial common base class.

## Proposed isolation and execution policy

- Global DI means in-process suites run serially with full save/restore of mode/dependencies, fresh router/services/track state, and settled effects before teardown. Separate simulator/app processes isolate E2E runs; do not enable parallel testing until proven safe.
- Test mode is explicit and Debug-only, configured before store/service initialization. It launches the real app with real services, run-owned SQLite files, scoped credential storage and a loopback HTTP allowlist. It forces remote monitor/Pulse capture off. Missing/invalid configuration fails closed, never defaults to the hardcoded personal endpoint.
- Moya's `setPlugins` rebuilds providers. Controlled transport must survive that rebuild or tests can escape to real networking.
- No fixed sleeps. Bounded condition waits and captured requests provide deterministic completion/failure diagnostics. A run ID owns all created resources and cleanup, including on failure; relaunch keeps the same run ID until final teardown.
- Unit cases should not be forced through the existing TestStore if its asynchronous send/receive behavior obscures completion. Verify pinned TestStore semantics first; prefer direct reducer/effect observation where appropriate.

## Compatibility tests on the owner's server

Permission is granted to use **synthetic accounts/data on an existing real server**, not to delete/reset or mutate unrelated data. No server request was made during review.

- Required configuration: HTTPS URL, installed Kimai version, dedicated restricted test token/account, run-owned fixture naming/ID manifest, cleanup allowlist. Keep secrets outside git/log artifacts.
- Record the actual server version beside latest release 2.70.2 (review-time reference); if older, report that compatibility result accurately rather than calling it latest-version validation.
- Before writes, preflight account identity/permissions and use only owned fixtures. Cleanup deletes only recorded test-created IDs; never call global database/account reset or enumerate-and-delete by broad name match.
- Opt-in only, outside normal PR test runs. Include auth validation, customer/project/activity/timesheet API contract, permissions, pagination and timestamp conversion after migration is approved/implemented.
- Existing legacy authentication is a known blocker, not a reason to weaken latest-Kimai acceptance. Shared-server permissions may prevent safe automated write tests; report that limit and use a disposable instance if required later.

## Commands and acceptance status

- [Baseline commands](../app-review/BASELINE.md#commands-and-actual-outcomes) and [setup](../development/SETUP.md) are the only commands exercised during this review.
- No new suite commands, test targets, fixture server, accessibility IDs or drivers are implemented yet. Do not copy a hypothetical `test-unit` command from this document: none is advertised.
- After [design approval](../app-review/DESIGN.md), first prove an isolated real-app launch, one persistent round trip, blocked unexpected networking, failure cleanup and serial reruns (S5). The broader unit/scenario matrix belongs to S10/S6–S8.
- S9 adds the local suite entry point, discovered test plans/targets and optional GitHub Actions execution with pinned runner/Xcode and `.xcresult` output. Provider selection remains a recommendation, not a completed workflow.
