# Feature inventory

Reviewed at `de9e71e`, 2026-10-25. **No app workflow is runtime-verified:** [app build is blocked](BASELINE.md). “Partial” means reachable source wiring exists but completeness/correctness is not established. “Placeholder” means example/no-op behavior, not a working product feature. “Unverified” does not imply absent.

| Capability | Status | Source evidence / limits |
|---|---|---|
| Intro | Partial; runtime unverified | `Modules/Intro/Sources/Intro/IntroFeature.swift` supplies pages and first-run flag; `AppContainer` dispatches load and `AppFeature` opens intro sheet. Marketing includes future project management. |
| Setup assistant | Partial; runtime unverified | `Components/Assistant` guides customer → project → activity → timesheet creation. The separate missing Boarding package was removed. |
| Multiple accounts | Partial; isolation defects | `LoginContainer`, `LoginFeature`, `Account`, external KeychainService store/select account records and switch DBs. Count-based ID reuse and reset scope prevent claiming safe multi-account use. |
| Kimai login | Broken validation / legacy auth | `KimaiService.login` returns true after URL construction, no credential probe; plugin uses deprecated headers. Latest-server compatibility unverified. |
| Customers | Partial | `KimaiReducer`, `KimaiCustomerService`, customer sheets/lists: local CRUD, visibility filtering, team filter and project-dependent delete guard. Team cache persistence incomplete. |
| Projects and activities | Partial | `KimaiContainer`, project/activity sheets and RecordService factories: local create/update, visibility deletion and sync wiring. Dependent-ID remapping disabled. |
| Today dashboard | Partial | `TodayContainer` routes customer → project → time entry. `DashboardView` has “Hi Name” and chart over supplied records; not a verified current-week-only dashboard. |
| Time entry | Partial / date defects | `TimesheetView` and `KimaiTimesheetSheet` create/edit times, descriptions and project/activity links; local timestamp format mismatches parser/API. No promise of reliable start/pause/resume timers. |
| Running entries | Partial | Timesheet sheet allows nil end and a Stop control; duration uses `Date.now`. No demonstrated server timer lifecycle, background refresh, or pause/resume implementation. |
| Reports | Partial / placeholders | Date/project selection, day/week list, summary totals and week/month/year bars exist. Grouped month/year summary ignores selection; the day pie uses fixed values. See F11. |
| Local persistence | Partial; data-integrity risks | SQLite repositories and per-account filenames exist through OfflineSync. Persistence/relaunch unverified; no schema migration strategy established. |
| Offline changes | Partial; unsafe sync edge cases | Reducer saves locally and exposes pending changes. Successful login/manual sync reads local data before requesting remote data. No connectivity-triggered automatic resync found in inspected app orchestration. |
| Sync | Partial; data-integrity defects | `KimaiReducer` sequences customer/team → project → activity → user → timesheet. Error swallowing, interrupted retry and disabled mapping prevent claiming safe full offline sync. |
| Settings/logging | Partial; privacy/destruction risks | Settings routes integrations/debug/intro/logout. Debug exposes remote logs, mock flag and database reset; Pulse console exists. Remote state redaction is missing. |
| Taiga account configuration | Partial | AccountData and TaigaLoginView save server/username/password; this is not a verified Taiga login/network client. |
| Kimai ↔ Taiga project links | Placeholder / partial | `IntegrationsView` passes empty Taiga projects; IntegrationFeature reducer returns no effects; excluded service uses stale APIs. |
| Taiga backlog/sprints/Kanban/issues | Not implemented in reviewed source | Present in historical Flow.pdf/product intent, not an active Taiga feature package. Planned future work, not removed scope. |
| Widget | Placeholder; compile verified only | AppIntent timeline displays time/favorite emoji. Widget-only simulator build passes; no app database/shared model access found. |
| Live Activity | Placeholder | Generated emoji/name UI and apple.com widget URL; no observed app initiation/time-tracking state flow. |
| Accessibility / adaptive layouts | Unverified | No runtime VoiceOver, Dynamic Type, contrast or device-size validation performed. Relevant controls include gestures and unlabeled/hidden labels requiring audit. |

## Historical documentation reconciliation

- The original README claimed complete Taiga integration, full offline functionality, automatic resync, and start/pause/stop timers. Those claims exceed current evidence; the README now links this inventory instead.
- [AppArchitecture.png](../../Doc/AppArchitecture.png) was visually inspected. It includes Taiga app/core/services/UI and Management package-style boundaries that do not match the reviewed source tree. Preserve as historical intent, not current architecture.
- [Flow.pdf](../../Doc/Flow.pdf) was parsed as a one-page historical workflow diagram: workspace accounts, customer/project/timesheet views, Scrum/backlog/sprints/Kanban/issues, integrations, settings and debug. Its embedded text is partly garbled; screenshot generation failed. Fine visual details were not independently validated.
- [PackageDependencies.md](../../PackageDependencies.md) contains an un-fenced Mermaid-like target graph; it omits the current app shell and external lifecycle details.
- [Modules/redux_state.mmd](../../Modules/redux_state.mmd) is a historical state list, including Boarding whose source is unavailable. It does not represent runtime ownership of today's `AppFeature.State`.

## Acceptance still outstanding

After build recovery, walk each implemented flow on a dedicated latest-iOS simulator and change status to verified only with recorded evidence. Keep partial Taiga/widget labels until their separate implementations and tests exist.
