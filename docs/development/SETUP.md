# Developer setup

## Scope and safety

- Support policy: latest stable iOS and Kimai. [Baseline](../app-review/BASELINE.md) records the older toolchain currently installed and failed app-build result.
- Start from a fresh checkout and dedicated simulator. Do not import your real accounts or copy a live app container for tests.
- Do not use account reset/database reset as a setup step: [review findings](../app-review/FINDINGS.md) describe broad deletion behavior.
- Never commit credentials, Keychain exports, database contents, or server tokens.

## Prerequisites

1. macOS with full Xcode selected via `xcode-select`, command-line tools, accepted Xcode license, and a latest-stable-iOS simulator runtime.
2. Git/SwiftPM network access to GitHub dependencies. Router is referenced through `git@github.com:ManuelSelch/Router.git`; configure your SSH identity/access, or explicitly approve a project URL change rather than embedding credentials.
3. Recover the missing Boarding source before expecting the app to build. The repository contains an empty gitlink with no submodule URL mapping. Ordinary `git submodule update --init` cannot repair that metadata.
4. For physical devices, choose a development team and provisioning profile appropriate to your account. Simulator baseline builds disable signing; do not change bundle IDs/signing globally to fix a simulator error.

## Inspect before building

```sh
git status --short --branch
git submodule status
xcodebuild -version
swift --version
xcodebuild -showsdks
xcrun simctl list devices available
```

The submodule command currently fails; this is a known blocker, not a successful setup check.

## Resolve and build

Run these in a fresh checkout. `../businessToGo-review-artifacts` must be a new scratch directory, not another project's storage.

```sh
mkdir -p ../businessToGo-review-artifacts
xcodebuild -resolvePackageDependencies \
  -project businessToGo.xcodeproj -scheme businessToGo \
  -clonedSourcePackagesDirPath ../businessToGo-review-artifacts/packages

xcodebuild -project businessToGo.xcodeproj -scheme businessToGo \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ../businessToGo-review-artifacts/DerivedData \
  -clonedSourcePackagesDirPath ../businessToGo-review-artifacts/packages \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
```

As reviewed, dependency resolution succeeds but the app build fails on missing `BoardingUI`. Do not delete product references just to get past it without recovering or explicitly replacing the feature. Further compilation errors may appear after this first graph blocker.

For a widget-only compile check:

```sh
xcodebuild -project businessToGo.xcodeproj -target widgetExtension \
  -configuration Debug -sdk iphonesimulator \
  -clonedSourcePackagesDirPath ../businessToGo-review-artifacts/packages \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
```

This succeeded with Xcode 26.1.1; it does not verify real time-tracking integration, which is absent from the widget template.

## Running and testing

Open [the Xcode project](../../businessToGo.xcodeproj), select the app scheme and a dedicated simulator, and Run **only after build recovery and test-mode isolation**. The app currently selects live/mock dependencies from persisted preferences, not a safe test launch contract. Remote logging must remain disabled.

[Test strategy and target inventory](../testing/TESTING.md) explain what exists and what is proposed. There is no working one-command unit/integration/E2E runner yet. The app's test-build probe fails before execution; do not report that as a test pass. `swift test --package-path Common` is a macOS host build and currently fails; it is not a substitute for iOS simulator tests.

## Compatibility server

The owner permits synthetic accounts/data on an existing real Kimai server. Before any opt-in compatibility run, configure the URL/version, dedicated restricted account/token, and uniquely prefixed fixtures. Verify that no real users/customers/projects can be read or mutated by that account where server permissions allow. Record residual shared-server risks if permissions cannot enforce isolation. Never enable blanket cleanup; delete only IDs created and recorded by the current test run. No compatibility requests were made during this review.

The existing app uses deprecated authentication. A modern API token alone will **not** make its legacy headers into Bearer authentication; see [findings](../app-review/FINDINGS.md#f7--legacy-authentication-and-no-credential-verification).

## Troubleshooting

| Symptom | Meaning / next action |
|---|---|
| Missing `BoardingUI` | Recover Boarding gitlink source and metadata; see baseline |
| Router checkout fails | Check GitHub SSH access; do not place private keys in the repository |
| `Bundle.module` error | CommonUI resource processing is undeclared; requires a scoped manifest fix |
| SwiftUI availability during `swift test` | Host macOS platform is undeclared; use agreed simulator suites after recovery, not blanket availability annotations |
| Skipped/missing UI target | Stale scheme entry is not an implemented XCUITest suite |
| Invalid credentials seem accepted | Current login only sets the API URL; auth is not verified at login |
| Empty local data after sync | Stop further sync/reset, preserve evidence/backups, investigate fetch-error handling before recovery |
