# Sync safety and performance

- Owners: [Kimai coordinator](../../Modules/Kimai/Sources/Services/KimaiSyncCoordinator.swift), [timesheet checkpoints](../../Modules/Kimai/Sources/Services/TimesheetSyncService.swift), [local OfflineSync package](../development/SETUP.md#local-offlinesync-iteration).
- Verification and scenarios: [sync regression suites](../testing/SYNC-REGRESSIONS.md).

## Data ownership

- SQLite remains authoritative for local edits. Record mutations, pending operations and baselines commit atomically; storage errors throw instead of becoming empty arrays or successful saves.
- Unsynced identities are monotonically decreasing negative integers below the `-1` unsaved sentinel. Server identities are nonnegative. Allocation is persisted, so deleting an in-flight create cannot reuse its ID.
- Each mutation advances the queue revision, including edits to pending inserts. Upload responses acknowledge only the exact revision sent; newer edits/deletes remain queued.
- Server-ID assignment, queue movement and registered foreign-key remapping commit together. Mapping metadata also resolves stale picker/sheet IDs on later edits and creates.
- Customer → project → activity → timesheet references are declared on the models. Fetched teams are persisted for offline use.

## Reconciliation and retry

- Transport, status, decoding and pagination failures abort before reconciliation. Missing/malformed page metadata, changing page counts and duplicate result IDs are rejected. An empty zero-page collection is accepted only with an empty body.
- Returned clean records are refreshed; **absence does not authorize cache deletion**, even after a full scan. Visibility, permissions and filters can hide valid rows. Explicit local timesheet deletes remain tombstones until acknowledged.
- Pending edits/deletes are compared with their saved server baseline. Observed competing server changes stop sync as conflicts and retain local work; no implicit local-wins/remote-wins merge is performed. Delta uploads re-fetch the individual pending record before writing.
- Each successful create is journaled and acknowledged independently. A receipt survives a failed local commit/reopen and is applied before another upload.
- A lost POST response is ambiguous: sync stops rather than guessing and duplicating a record. A caller can use `confirmCreatedRecord` only after independently verifying the matching server record; matching by name or blindly retrying is unsafe. There is no new conflict/recovery UI.
- Client-side comparison cannot eliminate a server edit racing between GET and PATCH/DELETE. A strict guarantee requires server-supported conditional mutations/idempotency; it is not claimed here.

## Account lifetime

- One connection-bound lease prevents overlapping entity syncs, including across different service instances. Every await is followed by cancellation/account validation before applying records.
- The app coordinator owns a generation and cancellable task across all entity stages. Login, logout, account changes and active configuration edits invalidate old work. Reducer completion IDs reject stale results and reload current SQLite rows rather than publishing old network arrays.
- Request origins, path prefixes and credentials are immutable per configured provider. Unconfigured targets use a reserved `.invalid` origin, not a personal server. Existing database bindings reject reuse for another server/user; create a separate account instead of mixing caches.
- Database deletion accepts explicit filenames only. Reset receives the known account filenames; it never enumerates Documents. Deleting an inactive database does not delete the active one; failed switches cannot retain the old connection.

## Performance

- Reconciliation uses indexed dictionaries/sets rather than nested linear searches. Clean unchanged rows are not rewritten. Schema setup is cached per connection, merges are batched, and no SQLite transaction spans a network await.
- Timesheet pages request `size=500`, ordered by ID ascending, with at most four subsequent pages in flight. Results are assembled in page order and validated before merging.
- The first two successful scans establish a conservative UTC `modified_after` checkpoint. It advances only after successful local reconciliation, using the **previous** scan's HTTP Date minus one second; device-clock time is never used.
- Checkpoints survive reopening. Failure leaves them unchanged; server-clock rollback forces a full refresh. Missing HTTP Date disables checkpoint advancement. Every twentieth post-initialization scan refreshes full history to limit drift from proxy clock skew and non-cursor pagination.
- Customers (including teams), projects, activities, users and timesheets fetch in parallel under one lease. Reference collections refresh fully; timesheets use the checkpoint described above. All snapshots must arrive before reconciliation; a failed fetch cancels its siblings without starting uploads. Reconciliation and uploads remain ordered by dependency, with timesheets last; their checkpoint advances only after successful reconciliation. No real-server latency improvement is claimed from fixture timings.

## API assumptions and limits

- Query contract checked against Kimai's [TimesheetController](https://github.com/kimai/kimai/blob/main/src/API/TimesheetController.php): maximum page size 500, `orderBy=id`, ascending ordering, and UTC `modified_after` (`YYYY-MM-DDThh:mm:ss`). Unsupported queries fail visibly; there is no legacy query fallback.
- Existing legacy X-AUTH authentication and time-entry date encoding are not migrated by this sync fix. No personal-server requests or production-data recovery/migration were performed.
- Old pending operations without a trustworthy baseline fail closed as conflicts. Already damaged data cannot be reconstructed by these fixes; preserve backups rather than resetting or automatically migrating it.
