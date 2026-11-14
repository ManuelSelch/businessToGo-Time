# Review findings

## Executive summary

The app has useful feature/package separation and local change tracking, but is not ready to be treated as a verified latest-iOS/latest-Kimai client. The app build is blocked; source review exposes potential data loss during failed sync, disabled relationship remapping, broad reset operations, and legacy authentication. This is a **static/source-backed review plus build probes**, not a completed runtime or penetration audit.

Evidence is based on `de9e71e`, reviewed 2026-10-25. App-owned paths below are relative to the repository root. External evidence was inspected at the exact workspace-pinned revisions, not at today's default branches. Severity describes impact if the path is exercised, not proof that a user's data has been damaged.

## Current sync update

- The local OfflineSync implementation now fixes F2–F4 and the sync-specific portions of F12/F13/F15; see [current sync architecture](../architecture/SYNC.md) and [verified regressions](../testing/SYNC-REGRESSIONS.md).
- Database deletion/reset is now filename-scoped (the database portion of F5). The separate Keychain remove-all issue, account ID allocation, legacy authentication, secret logging and other non-sync findings are not claimed fixed here.
- The findings below remain the historical source review of the pinned dependency, not a description of the updated local sync engine.

## High-priority findings

### F1 — Fresh-checkout app build was blocked

**Update:** The user chose to remove the unavailable Boarding dependency. A subsequent generic iOS simulator app build succeeded; fresh-checkout and test execution remain unverified.
- **Severity:** HIGH (delivery blocker). **Evidence:** reproduced build/build-for-testing failure; [baseline](BASELINE.md).
- **Location:** `Modules/Boarding` gitlink, `businessToGoTime.xcodeproj/project.pbxproj:1334`, `businessToGoTime/businessToGoTimeApp.swift`.
- **Cause:** Boarding is a mode-160000 entry at `0035f14fd8b0149bbe3272f032c7f6a032a4ad46`, but no `.gitmodules` mapping/source is available. Xcode cannot find `BoardingUI`. The checkout and isolated export both lack its source.
- **Follow-up:** recover original source and correct package/submodule metadata. Preserve onboarding behavior; do not invent a replacement to satisfy imports. Then expose subsequent build blockers.
- **Regression:** fresh-checkout dependency resolution and app/widget/test builds.

### F2 — Fetch errors can become authoritative empty data
- **Severity:** HIGH (data integrity). **Evidence:** confirmed source path, not exercised against a database.
- **Location:** OfflineSync 1.3.9 `RecordService.fetch/sync`, `SyncService.sync`; app `Modules/Kimai/Sources/App/KimaiReducer.swift` sync sequence.
- **Cause:** `RecordService.fetch` converts a thrown fetch error to `[]`. `SyncService` deletes local records absent remotely unless locally marked inserted. A failed project/activity/user/timesheet fetch can therefore delete cached records and lose an ordinary pending update. The customer fetch throws separately and can stop app sync earlier; the risky path requires reaching a subsequent failing stage.
- **Follow-up:** propagate fetch failure and prohibit reconciliation unless a complete remote snapshot was fetched. Distinguish legitimate empty snapshots from transport/auth/decode errors.
- **Regression:** service unit tests for errors; integration with cached records and pending updates followed by HTTP/decode failure must leave records and queues intact.

### F3 — Partial upload retry can duplicate remote records
- **Severity:** HIGH (data integrity). **Evidence:** confirmed source ordering; remote duplication not runtime-reproduced.
- **Location:** OfflineSync 1.3.9 `SyncService.sync`, upload loop and final `for response in synced` loop.
- **Cause:** remote insert/update results accumulate in memory, but changes are acknowledged only after all uploads/merge processing. If a later upload throws, an earlier successful POST remains pending and can be POSTed again on retry. Process termination between a remote success and local acknowledgement poses the same class of risk.
- **Follow-up:** design durable per-operation acknowledgement and clarify server idempotency/reconciliation; merely clearing all changes after failure is unsafe.
- **Regression:** integration scenario with successful first insert, failed second insert, restart/retry, exact request counts and final server/local IDs.

### F4 — Server ID changes do not update related local records
- **Severity:** HIGH (relationship corruption). **Evidence:** disabled code in app and pinned library.
- **Location:** `Modules/Kimai/Sources/Services/KimaiService.swift` relationship map; project/activity/timesheet factories; OfflineSync 1.3.9 `SyncService.sync`.
- **Cause:** relationships are declared in `KeyMappingTable.shared`, but key-mapping injection, `addMapping`, and `updateAllForeignKeys` calls are commented out. A created parent can be deleted/reinserted under its server ID while a child's foreign key retains the local ID.
- **Follow-up:** explicitly wire/test remapping before claiming safe offline creation of a related customer/project/activity/timesheet chain.
- **Regression:** integration fixture where all local IDs differ from server IDs; assert child uploads and persisted references use remapped IDs.

### F5 — Reset/deletion scope exceeds the selected resource
- **Severity:** HIGH (destructive behavior). **Evidence:** confirmed source; deliberately not invoked.
- **Location:** `Modules/Login/Sources/App/LoginReducer.swift` reset/delete cases; LoginService 1.1.3 `KeychainService.live.removeAccounts`; OfflineSync 1.3.9 `Database.live.deleteDB/deleteAllDBs`.
- **Cause:** `removeAccounts` issues `SecItemDelete` for generic passwords without a service filter: all matching accessible items may be removed, not just this app service's accounts. `deleteAllDBs` removes every item in the app Documents directory. `deleteDB(name)` removes the named file and then the captured active database path, even if deleting a different account.
- **Impact:** loss of unrelated accessible credentials, non-database app documents, or another active account's database. This does not imply access to other apps' protected Keychain items.
- **Follow-up:** scope deletions to explicit account/service IDs and known database files; close connections before removal and preserve user confirmation/backup guidance.
- **Regression:** isolated integration tests with unrelated sentinel credentials/files and two accounts; never exercise this adapter on personal data.

### F6 — Account IDs can be reused after deletion
- **Severity:** HIGH (account isolation). **Evidence:** deterministic source construction; runtime scenario pending.
- **Location:** `Components/Login/LoginContainer.swift:21`, `Modules/Login/Sources/Core/Account.swift:5`, `LoginReducer` create/save/login.
- **Cause:** new account ID is `accounts.count`, while Keychain and database names use that ID. Create IDs 0/1/2, delete 1, create again: count 2 reuses existing ID 2. Demo account also uses ID 0.
- **Follow-up:** use stable collision-free identifiers with an explicit compatibility/migration decision for existing account and database keys.
- **Regression:** unit-test identity allocation and integration-test credential/database separation after deleting a non-last account and creating another.

### F7 — Legacy authentication and no credential verification
- **Severity:** HIGH (latest-Kimai compatibility; misleading login). **Evidence:** confirmed app source and official documentation; no installed-server authentication probe.
- **Location:** `Modules/Kimai/Sources/Services/KimaiService.swift:56–73` and `KimaiAuthPlugin.prepare`; `Modules/Login/Sources/UI/KimaiLoginView.swift`; `businessToGoTime/App/AppFeature.swift` login orchestration.
- **Cause:** the plugin sends `X-AUTH-USER` / `X-AUTH-TOKEN`. `login(server:)` constructs a URL, assigns global `KimaiAPI.server`, and returns true without validating credentials. UI labels the credential as Password. Errors saving accounts/authenticating are often ignored with `try?`.
- **Official evidence:** [current API contract](https://www.kimai.org/documentation/rest-api.html) requires `Authorization: Bearer <API token>`. [Removal notice](https://www.kimai.org/en/blog/2026/removing-api-passwords) says API passwords were deprecated 2024-04-07 and removal was scheduled after Q2 2026, no later than July. [Latest release](https://github.com/kimai/kimai/releases/tag/2.70.2) at review time is 2.70.2. The notice alone does not prove which exact installed release rejects legacy headers.
- **Follow-up:** separately approve Bearer-token storage/UI/header migration, server URL validation (including HTTPS and subdirectory paths), actual authentication validation, and user-visible error handling. Never send real credentials to a test fixture or assume inserting a token in the old Password field fixes the wire protocol.
- **Regression:** unit header/URL/error tests, dedicated-server API contract check, E2E success/rejection/recovery.

### F8 — Remote debug state contains account secrets when enabled
- **Severity:** HIGH (conditional privacy risk). **Evidence:** confirmed serialization path; no remote logging was enabled or inspected over the network.
- **Location:** `businessToGoTime/businessToGoTimeApp.swift` monitor wiring; `AppFeature.State.login`; `AccountData.password`; Redux 1.2.14 `MonitorMiddleware.sendInit/sendAction`.
- **Cause:** monitor transmits whole Codable state/actions to its configured WebSocket endpoint when remote logging is enabled. Account records contain credential strings; `showAction` excludes only `.setState`, not secret fields in other actions/state. Debug UI exposes the toggle. Default is false, which limits exposure but does not redact enabled logging.
- **Follow-up:** remove secrets from debug payloads and restrict production remote-debug capabilities. Audit Pulse request/header redaction separately; automatic URLSession capture is enabled, but actual persisted/redacted fields were not established here.
- **Regression:** middleware/serialization tests assert credential values cannot reach captured outbound payloads; E2E test mode must disable remote logging.

## Medium and lower-priority findings

| ID / severity | Evidence / impact | Recommendation / verification |
|---|---|---|
| F9 / MEDIUM | `TimesheetView` and `KimaiTimesheetSheet` save `"\(Date)"` strings, while `KimaiTimesheet.getDate` expects a `T`-separated timestamp with zone. API docs specify local date-time without offset for writes and offset-bearing ISO 8601 for reads. Locally entered records may fail parsing/report inclusion and API validation. | Separate read/write date codecs and explicit timezone policy; unit round trips, one SQLite/HTTP integration round trip, driven report E2E. |
| F10 / MEDIUM | `DateExtension.roundTo15Minutes` only resets seconds; it does not round minutes. `isWeekOfYear` compares calendar year instead of week-based year. | Clarify rounding rule, unit-test 15-minute boundaries and December/January ISO-week cases. |
| F11 / MEDIUM | `ReportsView` computes grouped summary from all timesheets only on appearance; filtered day/week list and totals use a different path. The day pie slices use `value: 10`, and customer summary headers use `00:00`. Month/year pie charts were replaced by filtered time bars. | Document partial reports, unit-test filtered aggregation and updates, E2E change period/project and verify both totals and rows. |
| F12 / MEDIUM | Global `DependencyValues.mode`, mutable static dependencies, `KimaiAPI.server`, and shared router live/mock instance. No cancellation/account-generation guard around ongoing app sync. | Serial isolated test contexts now; inspect overlapping sync/account-switch race before future concurrency changes. Runtime race is a hypothesis, not reproduced. |
| F13 / MEDIUM | `KimaiAPI` defines `validate: Bool`, but Moya 15.0.3 uses `validationType` (defaults to `.none`). Network/PageRequestService decode response bodies without explicit status validation. | Unit-test 401/403/429/500 including decodable bodies, then explicitly model HTTP errors. Cancellation continuations also need tests; underlying requests are not wired to task cancellation here. |
| F14 / MEDIUM | CommonUI references `Bundle.module` but its manifest omits resources; observed Common host-test compilation failure. Scheme UI target is stale; package test discovery is not established. | Scoped package/resource/target fixes and latest-iOS rebuild, not a blanket dependency update. |
| F15 / LOW | `KimaiCustomerService.fetch` returns teams, but sync does not persist them in `teamRepository`; later offline team fetch reads that repository. | Integration test online sync → relaunch/offline teams; decide whether to persist or remove misleading cache path. |
| F16 / INFO | Integration reducer is a no-op, Taiga projects input is empty, service source is excluded/stale; widget/Live Activity contain generated emoji examples. | Keep Taiga explicitly partial and widget planned. Do not test nonexistent project-management/timer features as if implemented. |

## Positive observations

- Feature packages separate Kimai/Login app, core, UI, and service responsibilities; container/projection types expose useful UI wiring boundaries.
- Login's intended database naming is per account; local writes are tracked before sync.
- Moya providers and request-service protocol provide useful controlled-network seams.
- Workspace lockfile pins exact dependency revisions; remote resolution and widget compilation are reproducible with the observed toolchain.
- Unit-test store examples exist, although they do not establish sufficient coverage or isolation.

## Prioritized follow-up

1. Recover build inputs (F1/F14); agree safe test composition before executing stateful scenarios.
2. Protect user data/credentials: F2–F6/F8. Run regression cases only against synthetic storage/accounts.
3. Restore latest-Kimai compatibility and correct dates: F7/F9/F13.
4. Complete the agreed unit/integration/E2E strategy and then address report/calendar correctness (F10/F11/F15).
5. Plan Taiga and real widget behavior separately; defer architectural restructuring unless a current test/fix needs it.

## Review limits

- No runtime journeys, accessibility audit with VoiceOver/Dynamic Type, real-server compatibility tests, concurrency stress tests, migration tests, or dependency CVE scan completed.
- Dependency pin age is not itself a known vulnerability. No assertion is made that dependencies are secure or current.
- Missing Boarding code cannot be reviewed. Integration/RequestFoundation manifest drift requires separate recovery/retirement decisions, not silent deletion.
- Complete S2 runtime acceptance after [baseline blockers](BASELINE.md) are cleared. This document is useful static review output, not a claim S2 is fully complete.

## External source references

Pinned source inspected during review:
- [OfflineSync 1.3.9 sources](https://github.com/ManuelSelch/OfflineSync/tree/24eec6bc27c494f97072d09823fbbd32122ee690/Sources): `Services/RecordService.swift`, `SyncService.swift`, `Local/Database.swift`, `Local/DatabaseRepository.swift`, `Local/TrackTable.swift`.
- [LoginService 1.1.3 KeychainService](https://github.com/ManuelSelch/LoginService/blob/e500ff924a3863aa58b40cd26b6ba1ede96b366c/Sources/LoginService/KeychainService.swift).
- [Redux 1.2.14 monitor](https://github.com/ManuelSelch/Redux/blob/4e608714e6bb6a36173f4531a4ad34168e124e3e/Sources/ReduxDebug/Middlewares/MonitorMiddleware.swift).
- [Dependencies 1.0.0](https://github.com/ManuelSelch/Dependencies/blob/94ac38716591c5c7e0ce512765e649f06df5f8d8/Sources/Dependencies/Dependencies.swift).
- [Moya 15.0.3 TargetType](https://github.com/Moya/Moya/blob/c263811c1f3dbf002be9bd83107f7cdc38992b26/Sources/Moya/TargetType.swift).
