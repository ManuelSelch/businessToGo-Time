# Current architecture

Source-backed view of revision `de9e71e`, reviewed 2026-10-25. This describes **what exists**, including incomplete wiring, not a proposed restructuring. App runtime verification is blocked by [baseline issues](../app-review/BASELINE.md). External behavior was checked against the workspace-pinned sources listed in [findings](../app-review/FINDINGS.md#external-source-references).

## Context and boundaries

```mermaid
flowchart LR
    Person[User] --> App[SwiftUI iOS app]
    App --> KC[Keychain account records]
    App --> UD[UserDefaults preferences and current account]
    App --> DB[Per-account SQLite in app Documents]
    App -->|Legacy X-AUTH headers| Kimai[Kimai HTTP API]
    App -.->|Opt-in full state and actions| Monitor[Remote Redux monitor]
    App --> Logs[Local Pulse request console]
    Widget[Widget and Live Activity examples] --> Template[Time and emoji state]
    Taiga[Taiga configuration scaffolding]
    App --> Taiga
```

- The app is the client; there is no backend server in this repository.
- Taiga configuration exists, but no active Taiga API/project-management implementation was found. The diagram does not imply Taiga network calls.
- Widget/Live Activity have no observed app-state/database sharing path. Their example state is separate.

## Building blocks and dependency map

Arrows below mean imports/dependencies, not runtime invocation order. The map groups related targets; it is intentionally not every transitive SwiftPM edge.

```mermaid
flowchart TD
    Shell[AppLauncher / businessToGoTimeApp / AppFeature]
    Components[App-level Components and Containers]
    Router[Router 1.0.5]
    Redux[Redux / ReduxDebug 1.2.14]
    DI[Dependencies 1.0.0]
    Shell --> Components
    Shell --> Router
    Shell --> Redux
    Shell --> DI
    Components --> LoginApp
    Components --> KimaiApp
    Components --> Intro
    Components --> IntegrationApp
    Components --> DebugApp
    LoginApp --> LoginUI
    LoginApp --> LoginServices
    LoginApp --> LoginCore
    LoginApp --> KimaiServices
    LoginServices --> LoginService[LoginService 1.1.3]
    KimaiApp --> KimaiUI
    KimaiApp --> KimaiServices
    KimaiApp --> KimaiCore
    KimaiUI --> KimaiCore
    KimaiUI --> Chart[Chart 1.0.4]
    KimaiServices --> KimaiCore
    KimaiServices --> NetworkFoundation
    KimaiCore --> OfflineSync[OfflineSyncCore / OfflineSyncServices 1.3.9]
    KimaiServices --> OfflineSync
    OfflineSync --> SQLite[SQLite.swift 0.15.3]
    OfflineSync --> Moya[Moya 15.0.3]
    NetworkFoundation --> Moya
    LoginUI --> Common[CommonCore / CommonUI / CommonServices]
    Intro --> Common
    DebugApp --> Common
    IntegrationApp --> IntegrationCore
    IntegrationCore --> OfflineSync
```

| Owner | Responsibility / source |
|---|---|
| App shell | [AppLauncher](../../businessToGoTime/AppLauncher.swift) chooses production vs unit-test app. [businessToGoTimeApp](../../businessToGoTime/businessToGoTimeApp.swift) initializes capture, DI mode, root store and monitor. |
| App orchestration | [AppFeature](../../businessToGoTime/App/AppFeature.swift) owns root state and dispatches child reducers; coordinates login/sync, logout/reset and global routing. |
| UI composition | [Components](../../Components) contains Login/Kimai/Today/Management/Report/Settings/Assistant projections and containers. Projection types derive state and lift UI actions; they are not independent data stores/services. |
| Kimai | [Package](../../Modules/Kimai/Package.swift) exposes Core, UI, Services, App targets. Core is not fully infrastructure-free: models conform to OfflineSync protocols. Reducer performs orchestration and synchronous service calls. |
| Login | [Package](../../Modules/Login/Package.swift) exposes Core/UI/Services/App; account records depend on external LoginService. Login reducer selects credentials and per-account database. |
| Intro / Debug | Intro displays pages and consumes the first-run preference. Debug reducer writes mock/remote-log preferences. |
| Integration | State and `onConnect` action exist, but reducer is no-op. `Sources/Services/IntegrationService.swift` is not included in declared targets and uses stale APIs. Do not treat it as active persistence. |
| Common / Foundation | Common contains formatting, date helpers, preferences and shared UI resources. CommonUI owns the adaptive teal/mint action color, contrasting action foreground, and compact icon-button dimensions; the app applies the action tint globally. NetworkFoundation supplies a Moya decoding helper. RequestFoundation is legacy/unwired in the inspected app graph with undeclared dependencies. |
| External libraries | Redux/DI supply store/effect/global dependency behavior; OfflineSync owns repository/change tracking/sync; LoginService owns Keychain/current-account adapters. |

The current structure is feature-oriented but not strict clean architecture: app reducers call concrete services, UI contains calculations, CommonCore contains a SwiftUI JSON viewer, and external persistence concerns appear in core models. These are observations, not authorization for a big-bang rewrite.

## State, lifetimes and effects

- `businessToGoTimeApp.store` owns `StoreOf<AppFeature>` for the app lifetime. Root state contains `login`, `kimai`, `integration`, `report`, `intro`, `debug`.
- Kimai state caches customer/project/activity/timesheet/team/user arrays, pending-change arrays, selected team and sync status. SQLite is persistent storage; state arrays are projections/snapshots, not a transactional mirror.
- The Projects tab groups projects under customer rows. Customer and project actions use existing sheets and delete flows; project creation starts with the selected customer. Search retains all projects for matching customers and otherwise only matching projects, while the selected team still filters customers. The Today and Projects views share the folder-row presentation.
- Report state owns selected date/project/period and month names. Filtering/aggregation also exists in `ReportsView`, `ReportViewModel` and model helpers.
- Redux 1.2.14 `Store.send` reduces synchronously, subscribes to the returned Combine effect, then invokes configured middlewares with updated state/action. Emitted actions re-enter `send` on the main queue. `Effect<Action>` is `AnyPublisher<Action, Error>`; `.run` creates a Task inside a Future.
- The only configured middleware is `MonitorMiddleware.handle`. Side effects in Login/Kimai reducers are not separate middleware implementations.
- Dependencies 1.0.0 is a custom global registry, not swift-dependencies' task-local context: `.mode` chooses mutable static live/mock values; property wrappers resolve on access. Many mock/live service values are long-lived static objects. A test store sets global mode to mock but does not provide per-test isolation automatically.
- Router's mock value aliases its live object. Kimai server URL and credential-bearing service instances are mutable shared state. No verified cancellation/generation guard prevents an old sync result from arriving after account selection changes.

## Runtime flows

### Startup and account restoration

```mermaid
sequenceDiagram
    participant Launch as AppLauncher
    participant App as businessToGoTimeApp
    participant Root as AppContainer / router
    participant Login as LoginFeature
    participant Storage as Keychain and SQLite
    participant Parent as AppFeature
    Launch->>App: Normal launch (no XCTestCase class)
    App->>App: Enable URLSession capture; choose DI mode; create store/monitor
    App->>Root: Render accounts root
    Root->>Parent: intro.load on appear
    Parent->>Root: Optional intro sheet via delegate
    Root->>Login: fetchAccounts when account list appears
    Login->>Storage: getAccounts / getCurrentAccount
    opt Current account exists
        Login->>Storage: switchDB(account filename); mark current
        Login->>Parent: delegate.onLogin(account)
        Parent->>Parent: loginKimai(account)
    end
```

If `NSClassFromString("XCTestCase")` is present, AppLauncher opens `TestApp` instead. This supports hosted unit tests but is not a safe E2E launch contract by itself. XCUITest must verify it launched the real UI.

### Login and sync

```mermaid
sequenceDiagram
    participant UI as Account UI
    participant L as LoginFeature
    participant A as AppFeature
    participant K as KimaiService
    participant R as KimaiFeature
    participant S as Customer / Record services
    participant DB as SQLite
    participant API as Kimai API
    UI->>L: login(account identifier)
    L->>DB: Switch per-account connection
    L->>A: delegate.onLogin(account)
    A->>K: setAuth; login(server)
    K->>K: Set global API URL; return true (no auth check)
    A->>R: kimai.sync
    R->>S: Read local records/change queues
    S->>DB: Query repositories
    R->>S: Sync customers, projects, activities, users, timesheets sequentially
    S->>API: Fetch / upload pending changes
    S->>DB: Merge records and acknowledge changes
    alt Thrown sync error
        R->>R: syncFailed (local state may already be changed)
    else Success
        R->>R: synced arrays; status idle; reload change queues
    end
```

- Customer fetch returns customer DTOs and unique teams. Generic record fetch converts failures to empty arrays: the failure branch above is **not** reached for every network failure.
- If no Kimai configuration exists, `loginKimai` reads offline state without remote authentication.
- Logout/reset clears Kimai/integration state and routes to accounts; it does not explicitly cancel all outstanding async work.

### Local edit and delete

```mermaid
sequenceDiagram
    participant UI as Timesheet sheet
    participant C as Component action projection
    participant R as KimaiFeature
    participant S as KimaiService / RecordService
    participant DB as SQLite repository and track table
    UI->>C: saveTapped(model)
    C->>R: timesheet.save(model)
    R->>S: save(model)
    S->>DB: Create or update; track insert/update
    R->>S: Reload records and pending changes
    R->>UI: State publication refreshes view
```

Local saves do not themselves guarantee immediate sync. Delete guards/popups are reducer delegates. Synced customer/project/activity rows are generally hidden via `visible = false`; unsynced inserts can be deleted outright. Timesheets have a remote DELETE endpoint. Do not generalize one deletion policy to all models.

## Storage and schema contracts

| Storage | Current representation / ownership |
|---|---|
| Keychain | LoginService serializes whole `Account` (identifier/name, Kimai/Taiga server/username/password). App adapter uses service string `de.selch`. Remove-all is not service-scoped; see F5. |
| UserDefaults | `currentAccount` string from LoginService; Common wrapper stores Codable Data for `isIntro` (default true), `isMock` and `isRemoteLog` (default false). Most writes use the standard suite, not a test namespace. |
| SQLite file | OfflineSync opens app Documents / `businessToGo_<identifier>.sqlite` when LoginFeature selects an account. Initial live database has no filename/connection. |
| Model tables | `kimai_customers`, `kimai_teams`, `kimai_projects`, `kimai_activities`, `kimai_timesheets`, `kimai_users`. Repositories generate columns using reflection over `Model()`; `id` is primary key, primitive optionals map to nullable columns, other fields default to string columns. Array encoding/decoding relies on SQLite.swift's Codable support; round-trip behavior is unverified. |
| Change tracking | `track` table: id, type, recordID, tableName, timestamp. Local update after insert keeps insert tracking; deleting an unsynced insert clears its tracking. Errors are frequently swallowed. |
| Relationships | Project.customer → customer; Activity.project → project; Timesheet.project/activity → project/activity. Customer teams store team IDs, separate from fetched team DTOs. |
| Mapping | A KeyMappingTable type and app relationships exist, but active sync wiring is commented out. It is not a working foreign-key migration mechanism. |
| Schema evolution | No versioned app schema migration policy established. `CREATE IF NOT EXISTS` plus reflection is not a migration strategy; do not promise old data compatibility. |

### Observed conflict/retry semantics, not guarantees

OfflineSync captures local records and tracked changes, deletes local non-inserts absent in the remote snapshot, uploads tracked changes, merges remote records where no local change blocks them, then acknowledges uploads. This resembles local-write precedence for pending changes and remote refresh for clean records, but lacks a verified conflict/version protocol. ID collisions, missing remapping, missing remote delete methods, swallowed fetch failures and non-durable per-upload acknowledgements make safe conflict resolution/retry **unproven**. See F2–F4.

## HTTP boundary

- [KimaiAPI](../../Modules/Kimai/Sources/Services/KimaiAPI.swift) maps customer/project/activity/timesheet CRUD plus teams/users/me. The actual sync path derives teams from customers; enum cases alone do not establish use.
- GET `/timesheets?page=<n>&user=all` is paginated through `PageRequestService`, reading `X-Total-Pages` from first response. Other collections use generic fetches.
- Generic writes use JSON; timesheet begin/end/description come directly from model strings/optionals. Customer writes hardcode DE/EUR/Europe-Berlin defaults. Optional serialization and latest endpoint permissions need contract tests.
- `KimaiAuthPlugin` adds legacy headers from mutable service credentials. Server is globally mutable, initialized to a personal endpoint in source; tests must override/restrict it before any requests.
- Response decoding uses JSONDecoder; status validation is not configured via Moya's `validationType`. HTTP status, nulls, pagination header representation, cancellation and empty responses need explicit tests.
- Latest Kimai's documented Bearer auth and distinct write/read timestamp formats differ from current behavior. This document does not describe an already-completed migration.

## Historical artifacts and future work

- [Historical architecture image](../../Doc/AppArchitecture.png) includes full Taiga and Management package boundaries absent from this revision.
- [Historical flow PDF](../../Doc/Flow.pdf) includes planned backlog/sprints/Kanban/issues. Parsed text was inspected; screenshot generation failed. It is product intent, not verified behavior.
- [Dependency graph](../../PackageDependencies.md) and [Redux state graph](../../Modules/redux_state.mmd) are retained as historical/generated aids; they are not current runtime lifecycle documentation.
- Future test composition is proposed separately in [DESIGN.md](../app-review/DESIGN.md). Future Taiga/widget features, dependency upgrades, async cancellation changes, schema migration and auth fixes require their own approved implementation scope.
