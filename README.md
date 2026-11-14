# businessToGo Time

Time-tracking app in the **businessToGo** product family, built with SwiftUI for iOS and backed by Kimai, with local SQLite/change tracking and a Redux-style state model. Development is resuming after a long pause.

## Product identity

- App display name: **businessToGo Time**. Repository/checkout folder: **businessToGo-Time**. Xcode project and shared scheme: **businessToGoTime**.
- Open [businessToGoTime.xcodeproj](businessToGoTime.xcodeproj). GitHub repository: [ManuelSelch/businessToGo-Time](https://github.com/ManuelSelch/businessToGo-Time).
- Bundle identifiers (`de.selch.businessToGo` and its existing extensions) and account database filenames (`businessToGo_<identifier>.sqlite`) remain unchanged; this is a rename, not a new installed app.

## Current status

- **Build status:** the missing Boarding dependency was removed; a generic iOS simulator app build succeeds. App tests and runtime journeys remain unverified.
- **Kimai compatibility needs work:** the app uses deprecated `X-AUTH-*` authentication; current Kimai documents Bearer API tokens.
- **Offline/sync and reporting are partial:** source review found data-integrity and date/reporting defects. Do not assume queued changes, retries or report totals are reliable yet.
- **Taiga is partial:** account configuration/scaffolding exists, not completed project management. Backlog/Kanban work is planned separately.
- **Widget/Live Activity are placeholders:** generated time/emoji examples, not integrated time-tracking features. Continued development is planned.
- Support policy is **latest stable iOS and Kimai only**. This is a target policy, not a claim of verified compatibility.

## Documentation

| Read first | Purpose |
|---|---|
| [Developer setup](docs/development/SETUP.md) | Tooling, dependency access, build commands and safe setup |
| [Build/test baseline](docs/app-review/BASELINE.md) | Actual results, pinned dependencies and unresolved blockers |
| [Feature inventory](docs/app-review/FEATURES.md) | Implemented, partial, placeholder and unverified capabilities |
| [Review findings](docs/app-review/FINDINGS.md) | Prioritized correctness, data-integrity and privacy risks |
| [Current architecture](docs/architecture/ARCHITECTURE.md) | Responsibilities, state, routing, storage and editable flow diagrams |
| [Workflows and safety limits](docs/usage/WORKFLOWS.md) | Source-derived account/time/report/offline workflows and reset warnings |
| [Test strategy](docs/testing/TESTING.md) | Unit inventory, focused integration cases and driver-based XCUITest plan |
| [Requirements and slices](docs/app-review/REQUIREMENTS.md) | Agreed scope and implementation sequence |
| [Proposed harness design](docs/app-review/DESIGN.md) | Approval-required test composition; not implemented yet |

## Safety

- Do not reset real accounts/databases to troubleshoot: current deletion adapters have overly broad scope.
- Keep remote logging disabled; current debug serialization can include credentials.
- Automated tests must use isolated storage and synthetic accounts. Real-server compatibility checks are opt-in and restricted to run-owned synthetic data.
- See the [review limits](docs/app-review/FINDINGS.md#review-limits) before treating this as a completed audit.

## Historical artifacts

[Architecture image](Doc/AppArchitecture.png), [flow diagram](Doc/Flow.pdf), [package graph](PackageDependencies.md) and [state graph](Modules/redux_state.mmd) are retained for context. They include planned features and do not supersede the source-backed current architecture.

Developed by [Manuel Selch](https://manuelselch.de). Integrates with [Kimai](https://www.kimai.org); [Taiga](https://www.taiga.io) support remains planned/partial.
