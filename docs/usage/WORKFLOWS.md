# Current workflows and safety limits

**Source-derived guide, not runtime-verified instructions.** App builds are currently blocked; see [setup](../development/SETUP.md) and [baseline](../app-review/BASELINE.md). Use synthetic accounts and a dedicated simulator when validating these flows. For completeness/status, see [feature inventory](../app-review/FEATURES.md).

## Accounts and setup

1. The router starts at the account list. Opening it dispatches `fetchAccounts`, reads saved Keychain records, and may restore the current account.
2. Create an account, edit its name, and configure Kimai server/username/password through its account detail. Saving configuration is not proof of server authentication.
3. Selecting an account switches the local SQLite file to `businessToGo_<account identifier>.sqlite`, marks the current account, and triggers Kimai setup/sync.
4. The demo/setup assistant uses a demo account and guides creating a customer, project, activity, and time entry. It is not a guarantee of isolated demo storage: current ID allocation can collide with real accounts.
5. Taiga account fields are retained for planned project-management work; saving them does not provide an implemented backlog/Kanban integration.

**Authentication warning:** the existing app sends legacy `X-AUTH-USER`/`X-AUTH-TOKEN`. Latest Kimai expects Bearer API tokens. Do not enter a real password expecting validated login, or assume a token in the existing field fixes compatibility. A separately approved migration is required.

## Customers, projects, activities

- The Projects tab is the management area: start from customers, select a customer to view its projects, then project details/activities.
- Create/edit callbacks save local records. Deleting a customer with projects or a project with activities requests a blocking popup; other deletes ask confirmation.
- Previously synced customer/project/activity deletion is generally represented by visibility changes, while new unsynced records can be removed locally. This is not a universal server-delete API.
- Local creation of related offline records is **not yet safe to promise**: ID remapping is disabled. Use synthetic records until fixed/tested.

## Time entry

- Today routes customer → project → time-entry form; choose an activity, start/end dates, then Save.
- The management/report sheet also edits project/activity/description and can leave the end unset. “Stop” reveals an end-time control; it is not verified pause/resume timer support.
- Saved local timestamps currently conflict with parsing/API formats. Missing or incorrect report durations may be a date-format defect rather than lost server data.

## Reports

- Reports provides day/week/month/year and project selection, calendar navigation, entry editing/deletion, totals and charts.
- Day/week lists and totals use filtered timesheets. Month/year grouped rows currently use an unfiltered, appearance-time snapshot; non-week pie values are placeholders.
- Do not use these unverified reports for billing without comparing server data. Open-ended records use the current time when calculating duration.

## Offline and sync

- Local CRUD uses SQLite/change tracking. App login/sync reads local state before fetching remote data; the header exposes sync/retry status.
- Automatic connectivity-driven sync is not established. Do not rely on closing/reopening or toggling connectivity to safely flush queued work.
- Failure does not guarantee unchanged local data: downstream fetch errors can be treated as empty snapshots, and partial uploads can be repeated. Avoid repeatedly pressing sync to “repair” missing records.
- If data appears missing, stop additional sync/reset, preserve the container/logs safely, and compare with the server before deciding a recovery action. Do not upload private logs to public issues.

## Logout, delete and reset

- Logout clears the current-account selection and app Kimai/integration state and routes to accounts; it is not intended to delete saved accounts or all local data.
- Removing an account deletes credentials and a named database, but the current adapter may also remove the active database. Do not validate on personal data.
- Account reset can remove all accessible generic-password Keychain entries; database reset can remove all app Documents contents. **Neither is a safe troubleshooting action today.**
- Before approved destructive work, preserve the relevant app container/database and use a synthetic simulator/account. Treat credential backups as secrets; do not add them to git.

## Debug, Taiga and widget

- Keep remote logging disabled: Codable state/actions can contain credentials. Local Pulse logs may contain sensitive request data; redaction remains unverified.
- Mock-mode preferences are read at app initialization; changing the toggle is not a verified live dependency switch.
- Taiga is intentionally partial. Project links and full project-management journeys await separate implementation.
- Widget and Live Activity are generated examples, not maintained time-tracking surfaces yet. Their future development remains planned.
