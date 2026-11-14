# Isolated sync regressions

- Source: [SyncRegressionTests.swift](../../businessToGoTimeTests/Management/Kimai/SyncRegressionTests.swift).
- Run the manual Pi `sync-regression` suite: hosted XCTest, Debug, iPhone 17 simulator, serial execution. The ordinary `unit` suite remains separate.
- Dependencies: [local OfflineSync checkout](../development/SETUP.md#local-offlinesync-iteration), real OfflineSync repositories/tracking/sync, app `PageRequestService`, and customer/project services for relationship tests. No sync implementation fixes are included.

## Isolation

- Each test owns a UUID temporary directory with separate account A/B SQLite files. Teardown releases connections, removes only that directory, and restores the previous global DI mode/database/tracker.
- Scripted remote services have no network implementation. Pagination uses immediately stubbed Moya responses and a reserved `.invalid` host; plugins cannot replace the fixture provider silently.
- AppLauncher runs `TestApp` under XCTest, not the production account/router/monitor startup. No Keychain, personal server, Documents database, account reset or device installation is used.
- Driver methods own storage, controlled responses, failure injection and assertions. SQLite triggers deterministically reject record updates or tracking inserts; no disk-filling or live database corruption.
- Edits and account switches are injected inside awaited request operations after sync captures its input and before responses return. No sleeps or scheduling races are needed.

## Scenarios

- Fetch failure preserves clean cached rows, pending edits and their queue; reports failure without uploads.
- Later-page failure and missing/malformed pagination metadata cannot authorize reconciliation/deletion.
- Complete two-page download persists both pages (positive control).
- Edit during upload survives the older response and remains pending.
- Local/server ID collision preserves both records and acknowledges the uploaded create.
- Customer server-ID reassignment reaches the project upload and persisted relationship, following app sync order.
- Interrupted upload followed by connection/service recreation and retry creates each record exactly once, locally and remotely.
- Failed local merge reports failure and retains the pending edit.
- Failed tracking insert cannot leave a committed untracked local create; assertion reads SQLite directly to avoid swallowed repository read errors.
- Switching accounts inside a fetch cannot write the old account's response into the newly selected database.
- Ordinary account switching and connection recreation retain separate caches (positive control).

## Verified baseline

- 2026-11-14, local OfflineSync sources unchanged from the former 1.3.9 pin: the Pi `sync-regression` suite compiled and executed all 13 tests on iPhone 17 / iOS 26.1, Debug.
- 2 tests passed: complete pagination and ordinary account switching/reopening. 11 tests failed with 23 assertion failures reproducing the unsafe behavior above; no unexpected exceptions. These are behavioral failures, not test scaffolds or compiler errors.
- The Pi `unit` suite passed both standalone and Common simulator jobs. No real-server compatibility tests or UI journeys were run.
- An initial standalone probe encountered a simulator launch error; subsequent pipeline runs executed successfully and reported the regression failures.

## Limits

- Tests assert desired safety, not current accidental behavior. Known defects remain ordinary failing assertions, not skips or expected-failure annotations.
- Scripted remotes prove client behavior, not real Kimai compatibility, server idempotency, authentication or response-loss recovery after an unknown server commit.
- Relationship coverage currently exercises customer → project; activity/timesheet remapping and end-to-end reducer/UI account cancellation remain follow-ups.
- Reopening recreates services/connections within one process, not an OS process crash. Global DI requires serial execution.
