# Developer setup

## Scope and safety

- Support policy: latest stable iOS and Kimai. [Baseline](../app-review/BASELINE.md) records the older toolchain currently installed and failed app-build result.
- Start from a fresh checkout and dedicated simulator. Do not import your real accounts or copy a live app container for tests.
- Do not use account reset/database reset as a setup step: [review findings](../app-review/FINDINGS.md) describe broad deletion behavior.
- Never commit credentials, Keychain exports, database contents, or server tokens.

## Prerequisites

1. macOS with full Xcode selected via `xcode-select`, command-line tools, accepted Xcode license, and a latest-stable-iOS simulator runtime.
2. Git/SwiftPM network access to GitHub dependencies. Router is referenced through `git@github.com:ManuelSelch/Router.git`; configure your SSH identity/access, or explicitly approve a project URL change rather than embedding credentials.
3. For physical devices, choose a development team and provisioning profile appropriate to your account. Simulator baseline builds disable signing; do not change bundle IDs/signing globally to fix a simulator error.

## Inspect before building

```sh
git status --short --branch
git submodule status
xcodebuild -version
swift --version
xcodebuild -showsdks
xcrun simctl list devices available
```


## Resolve and build

Run these in a fresh checkout. `../businessToGoTime-review-artifacts` must be a new scratch directory, not another project's storage.

```sh
mkdir -p ../businessToGoTime-review-artifacts
xcodebuild -resolvePackageDependencies \
  -project businessToGoTime.xcodeproj -scheme businessToGoTime \
  -clonedSourcePackagesDirPath ../businessToGoTime-review-artifacts/packages

xcodebuild -project businessToGoTime.xcodeproj -scheme businessToGoTime \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ../businessToGoTime-review-artifacts/DerivedData \
  -clonedSourcePackagesDirPath ../businessToGoTime-review-artifacts/packages \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
```

The missing Boarding dependency was removed; a generic iOS simulator app build succeeded afterward. This does not verify app launch or test execution.

To build the current worktree and install it on **iPhone Manuel**, connect and unlock the phone, enable Developer Mode, and configure development signing for the app and widget in Xcode. Then run:

```sh
./scripts/install-iphone.sh
```

The script uses a separate derived-data cache per worktree and installs the optimized Release build; it does not launch the app. Installation may replace an existing app with the same bundle identifier. Use synthetic data and review the safety warnings above.

For a widget-only compile check:

```sh
xcodebuild -project businessToGoTime.xcodeproj -target widgetExtension \
  -configuration Debug -sdk iphonesimulator \
  -clonedSourcePackagesDirPath ../businessToGoTime-review-artifacts/packages \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
```

This succeeded with Xcode 26.1.1; it does not verify real time-tracking integration, which is absent from the widget template.

## Running and testing

Open [the Xcode project](../../businessToGoTime.xcodeproj), select the app scheme and a dedicated simulator, and Run **only after build recovery and test-mode isolation**. The app currently selects live/mock dependencies from persisted preferences, not a safe test launch contract. Remote logging must remain disabled.

[Test strategy and target inventory](../testing/TESTING.md) explain what exists and what is proposed. There is no working one-command unit/integration/E2E runner yet. The app's generic simulator build-for-testing succeeds after Boarding removal, but no tests were executed. The earlier `swift test --package-path Common` macOS host build failed; it is not a substitute for iOS simulator tests.

## Compatibility server

The owner permits synthetic accounts/data on an existing real Kimai server. Before any opt-in compatibility run, configure the URL/version, dedicated restricted account/token, and uniquely prefixed fixtures. Verify that no real users/customers/projects can be read or mutated by that account where server permissions allow. Record residual shared-server risks if permissions cannot enforce isolation. Never enable blanket cleanup; delete only IDs created and recorded by the current test run. No compatibility requests were made during this review.

The existing app uses deprecated authentication. A modern API token alone will **not** make its legacy headers into Bearer authentication; see [findings](../app-review/FINDINGS.md#f7--legacy-authentication-and-no-credential-verification).

## Troubleshooting

| Symptom | Meaning / next action |
|---|---|
| Router checkout fails | Check GitHub SSH access; do not place private keys in the repository |
| `Bundle.module` error | CommonUI resource processing is undeclared; requires a scoped manifest fix |
| SwiftUI availability during `swift test` | Host macOS platform is undeclared; use agreed simulator suites after recovery, not blanket availability annotations |
| Skipped/missing UI target | Stale scheme entry is not an implemented XCUITest suite |
| Invalid credentials seem accepted | Current login only sets the API URL; auth is not verified at login |
| Empty local data after sync | Stop further sync/reset, preserve evidence/backups, investigate fetch-error handling before recovery |
