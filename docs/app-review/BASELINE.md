# Build and test baseline

## Evidence and completion

- Reviewed revision: `de9e71e` (2026-10-25); no application/test changes during this review.
- Commands ran against a temporary `git archive HEAD` export, not the working checkout. The same Boarding gitlink is empty in the checkout; its absence is not merely an archive limitation.
- **S1 remains blocked**, not complete: app/test builds fail; latest-stable-iOS verification and test execution have not happened. Widget compilation succeeds on the installed SDK.
- No app was launched, user databases/Keychain entries accessed, reset operation invoked, or Kimai server contacted. Public dependency/release sources were accessed.

## Toolchain and targets

| Item | Observed |
|---|---|
| Installed Xcode | 26.1.1, build 17B100 |
| Installed Swift | 6.2.1, swiftlang-6.2.1.4.8 |
| Installed iOS SDK/runtime | 26.1 |
| Available destination used for test-build preparation | iPhone 17, iOS 26.1; UDID `92F281CD-87DD-49AE-80A5-9C1311E31A7F` |
| App / test minimum deployment | iOS 16.0 in project configuration; app also confirmed with `-showBuildSettings` |
| Widget minimum deployment | iOS 17.5 in project configuration |
| Swift language build setting | 5.0; distinct from compiler version |
| Shared scheme | `businessToGo` |
| Native targets | `businessToGo`, `businessToGoTests`, `widgetExtension` |
| Signing | Automatic; checked-in team setting. Simulator probes used `CODE_SIGNING_ALLOWED=NO`; device signing not attempted |
| Host | arm64 macOS; `swift --version` reports target arm64-apple-macosx26.0 |

Support policy is **latest stable iOS/Kimai only**, not the current minimum settings. As checked on 2026-10-25, [Apple's releases page](https://developer.apple.com/news/releases/) lists iOS 27.0.1 (24A446, September 28) and Xcode 27.1 (27A9275, October 15), plus newer RC entries that are not stable releases. These are not installed here. The [Kimai latest-release endpoint](https://api.github.com/repos/kimai/kimai/releases/latest) returns **2.70.2**, published 2026-10-21, `prerelease: false`. These observations are dated, not an evergreen promise; the user's server version is unknown.

## Commands and actual outcomes

Run from an isolated exported source directory; `../packages` and `../DerivedData` are temporary review artifacts.

```sh
xcodebuild -version
swift --version
xcodebuild -showsdks
xcrun simctl list devices available

xcodebuild -resolvePackageDependencies \
  -project businessToGo.xcodeproj -scheme businessToGo \
  -clonedSourcePackagesDirPath ../packages

xcodebuild -project businessToGo.xcodeproj -scheme businessToGo \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ../DerivedData -clonedSourcePackagesDirPath ../packages \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build

xcodebuild -project businessToGo.xcodeproj -scheme businessToGo \
  -destination 'platform=iOS Simulator,id=92F281CD-87DD-49AE-80A5-9C1311E31A7F' \
  -derivedDataPath ../DerivedData -clonedSourcePackagesDirPath ../packages \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build-for-testing

xcodebuild -project businessToGo.xcodeproj -target widgetExtension \
  -configuration Debug -sdk iphonesimulator \
  -clonedSourcePackagesDirPath ../packages -disableAutomaticPackageResolution \
  CODE_SIGNING_ALLOWED=NO build

swift test --package-path Common --scratch-path ../common-build
```

| Check | Result |
|---|---|
| Remote package resolution | Exit 0; pinned remote dependencies fetched, including SSH Router |
| App simulator build | Exit 65: `Missing package product 'BoardingUI'` |
| App build-for-testing | Exit 65: same missing product; no tests executed |
| Widget-only simulator build | Exit 0: `BUILD SUCCEEDED`; warning about active architecture, no runtime/widget-host validation |
| Common standalone macOS test build | Exit 1 before execution: SwiftUI availability errors and `type 'Bundle?' has no member 'module'` |
| Other package suites | Not run; no claim they pass. Current manifests/imports require further build recovery |
| App/UI/runtime journeys | Not run; app build blocked |
| Latest iOS / latest Kimai compatibility | Not run; latest toolchain absent and server not configured |

The Common probe tests host-macOS package buildability, **not** iOS behavior. Its manifest declares only iOS 16, which does not establish a macOS deployment target. `CommonUI` has an asset catalog but no resource processing declaration despite using `Bundle.module`.

## Checkout and package issues

1. `git ls-files --stage` records `Modules/Boarding` as mode `160000`, commit `0035f14fd8b0149bbe3272f032c7f6a032a4ad46`. There is no tracked `.gitmodules`, its directory is empty, and `git submodule status` fails: `no submodule mapping found in .gitmodules for path 'Modules/Boarding'`. Recover the intended source/repository; do not fabricate onboarding APIs or silently delete the feature.
2. The shared scheme also retains a skipped reference to `businessToGoUITests`, but that native target is absent from the project. The active test plan names only `businessToGoTests`; package tests are not an established part of its execution.
3. Integration's service source uses obsolete `DatabaseTable`/`OfflineSync` module names and is outside the manifest's declared target source paths. RequestFoundation similarly contains undeclared external imports and no external package dependencies. These are source/manifest findings, not diagnostics reached by the app build.
4. Package revision ranges are not upgrade instructions. Preserve the workspace lockfile while recovering buildability; standalone package lockfiles may resolve differently.

## Pinned remote dependencies

Source of truth: [workspace Package.resolved](../../businessToGo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved). This table records the resolved baseline, not an upgrade or vulnerability audit.

| Package | Version | Revision prefix |
|---|---|---|
| Alamofire | 5.9.1 | f455c2975872 |
| AnyCodable | 0.6.7 | 862808b2070c |
| Chart | 1.0.4 | 2066bd8a937b |
| Dependencies | 1.0.0 | 94ac38716591 |
| LoginService | 1.1.3 | e500ff924a38 |
| Moya | 15.0.3 | c263811c1f3d |
| OfflineSync | 1.3.9 | 24eec6bc27c4 |
| PopupView | 3.0.5 | 337430278cd6 |
| Pulse | 4.2.7 | 3ac5ee35ab23 |
| PulseLogHandler | 4.0.1 | 7280e980b71a |
| ReactiveSwift | 6.7.0 | c43bae3dac73 |
| Redux | 1.2.14 | 4e608714e6bb |
| Router | 1.0.5 | 1928ddd65d5b |
| RxSwift | 6.7.1 | b06a8c8596e4 |
| SQLite.swift | 0.15.3 | a95fc6df17d1 |
| Starscream | 4.0.8 | c6bfd1af48ef |
| swift-log | 1.6.1 | 9cb486020ebf |
| swiftui-introspect | 1.3.0 | 807f73ce09a9 |
| swiftui-navigation-transitions | 0.13.4 | ad6ecab3f275 |

Full logs remain temporarily under `businessToGo-review-n_ihb2iw` in the host's temporary directory: `resolve.log`, `build.log`, `build-for-testing.log`, `widget-build.log`, `settings.log`, `common-test.log`. They are not committed or durable CI artifacts. The commands and essential results above are the retained evidence.

## Next verification gate

Recover Boarding, agree narrowly scoped build/resource fixes, install/select a current stable toolchain, then rerun app/widget builds, enumerate package schemes/tests, and execute isolated suites. Do not run reset/authentication scenarios on a real user installation. Harness implementation requires [design approval](DESIGN.md); no runtime acceptance criterion is waived by the documentation.
