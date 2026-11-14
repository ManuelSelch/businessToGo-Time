# Isolated sync regressions

## App integration suite

- Run the existing manual Pi `sync-regression` suite: hosted XCTest, Debug, iPhone 17 simulator, serial execution. It remains separate from `unit`; no OfflineSync-owned suite is added to the app pipeline.
- [Scenarios](../../businessToGoTimeTests/Management/Kimai/SyncRegressionTests.swift), [driver](../../businessToGoTimeTests/Management/Kimai/Support/SyncRegressionDriver.swift): 36 tests cover concurrent reference fetches and ordered uploads, fetch/pagination failures, revision-aware acknowledgements, collisions, the full relationship chain, stale sheet/picker identities, team persistence, retry/reopening, write failures, cancellation/generation, account binding, and incremental checkpoints.
- Positive controls include complete/empty pagination, ordinary account switching, bounded page concurrency, failed-delta retry and periodic full refresh.
- The original 13 scenarios first reproduced 11 failing cases. They now pass; assertions were retained while adapting to throwing storage APIs. Failed local creates must also throw.

## OfflineSync-owned tests

- Run manually with Bash from the app root, **not through the app pipeline**:

```sh
swift test --package-path '../../../../50 Coding/52 iOS/52.01 Packages/OfflineSync'
```

- The package has 30 tests covering transactional rollback/reopening, concurrent edits/deletes/creates, non-reusable identities, repeated overlap rejection, conflict baselines, delta write revalidation, ambiguous POSTs and confirmed recovery, persisted receipts, HTTP/cancellation behavior, and filename-scoped deletion/reset.
- The interrupted-upload fixture uses an explicit HTTP 429 rejection: safe to retry because creation was rejected. Separate lost-response tests assert that potentially accepted POSTs are **not** repeated.

## Isolation and interpretation

- Fresh UUID temporary directories and SQLite files per scenario; teardown restores global DI and removes only run-owned files. Database-adapter tests inject their own directory, never Documents.
- Scripted remotes have no network implementation. Moya fixtures are stubbed against `.invalid` hosts and cannot silently replace their controlled providers. Delayed fixtures measure outstanding request counts, not arbitrary sleep-based timing.
- Changes/account switches are injected inside awaited operations; coordinator tests use bounded expectations and releasable gates. All tasks are settled before cleanup.
- AppLauncher uses `TestApp` under XCTest, not production account/router/monitor startup. No Keychain, personal server, real account reset, browser automation or device installation is involved.
- Current baseline: all 36 app integration tests and all 30 OfflineSync-owned tests pass. These establish controlled client/storage behavior, not actual Kimai compatibility, end-to-end UI journeys or a real-server performance benchmark.
- Reopening means recreating services/connections within a process, not killing the OS process. Global DI requires serial tests. Local package edits are outside the app's Git fingerprint: rerun tests after changing OfflineSync instead of trusting prior pipeline freshness.
- Final verification also passed `unit` and `report-benchmark` (11 tests). An earlier report run was terminated with SIGTERM in two tests, and one sync run failed to launch with Mach -308; unchanged reruns passed. Existing duplicate Pulse class warnings remain; no cause is inferred from those warnings alone.
- See [sync architecture and remaining server-contract limits](../architecture/SYNC.md).
