# Riverpod migration verification

Verification snapshot: **25 September 2026**, Flutter **3.47.4**, Dart **3.13.3**, macOS ARM64. Source and automated checks pass. The isolated iOS fixture journeys below pass; credentialed services and physical-device acceptance remain open. No release was published and no production account, booking, or data write was used.

## Automated results

| Check | Result | Evidence |
| --- | --- | --- |
| Full test suite | **3,390 passed, 0 skipped, 0 failed**, 124s | `/tmp/360ghar-final-tests-4.log` |
| Line coverage | **91.67%**: 17,035 / 18,582 lines across 235 instrumented files | `coverage/lcov.info`; LF/LH totals agree with deduplicated DA records |
| Coverage gate | **85%, unchanged** | [CI workflow](../../.github/workflows/lint.yaml), byte-identical to HEAD during the audit |
| Analyzer | No issues, 14.3s | `/tmp/360ghar-final-analyze-3.log` |
| Formatting | 476 files checked, 0 changed, 3.52s | `/tmp/360ghar-final-format-check-4.log` |
| Code generation | Completed in 41s; 26 outputs | `/tmp/360ghar-codegen.log`; the old `--delete-conflicting-outputs` flag was ignored by the installed builder |
| Critical flow | Three passing cases, **included in the full-suite count** | [critical_flow_test.dart](../../test/integration/critical_flow_test.dart), full test log |
| Source iOS SPM/release configuration checks | Passed | `/tmp/visual-final-spm.log` |

The critical flow covers confirmed discovery → swipe → booking, durable offline swipe ownership through logout/account return, and ambiguous booking reconciliation without another POST. It uses real provider sessions, repositories and SQLite with controlled external dependencies.

The log's application `[E]` diagnostics include intentionally injected failures. The test runner ends with `+3390: All tests passed!` and has no failed or skipped runner cases. Focused batch counts overlap the full run and must not be added to it.

GetX/GetStorage packages are absent from `pubspec.yaml` and `pubspec.lock`. The source/test inventory has no GetX imports, APIs, observables, translation calls, or old test adapters. References to `GetStorage.gs`/`GetStorage.bak` remain only for the legacy JSON-file importer and its migration tests.

The final whitespace check (`git diff --check`) passed. The isolated native copy's product source was byte-synced to this checked source, apart from the excluded configuration described below.

## Test migration accounting

The baseline was **3,700 passed, 2 skipped**, with 88.01% coverage. The migrated suite has a different case structure and code denominator. The lower case count does not by itself prove a loss of behavior or prove equivalence. Assertions for retired global registration, Rx wrappers, forwarding methods and duplicate no-op checks were removed; observable behavior moved to provider, repository, route and widget tests. The old wiring cases do not all remain.

Current ownership and deliberate behavior changes are mapped in [property query tests](../migration/property-query-tests.md), [Discover/Saved tests](../migration/discover-saved-tests.md), [auth/profile/shared tests](../migration/auth-profile-tests.md), [routing recovery](../migration/routing-recovery.md), and [property details/tour](../migration/property-details-tour.md). These mappings, the [migration checklist](../migration/riverpod-checklist.md), and failure-transition assertions are the review evidence; raw test counts are not an assertion inventory.

## Visual and interaction evidence

[The gallery](property-visuals.html) contains **38 PNG comparisons** from 36 visual test cases: actual Discover, Saved and Explore Flutter views in content/loading/retained-failure states, both themes, 390px English at 1x text and 320px Hindi at 2x text. Two extra captures show the compact Discover details action after scrolling during failure. Each capture is 844 logical pixels high at pixel ratio 1. Production design tokens, bundled Manrope/Sora/Noto Sans Devanagari fonts, and decoded local fixture photos are used. Representative PNGs were opened and inspected; details are in the [visual review](property-visual-review.md).

In this widget gallery, Explore's native map canvas is replaced with a labeled test surface. These PNGs are Flutter widget renderer evidence. Actual iOS MapLibre/WebView and shell evidence is recorded separately below; neither set proves physical GPS accuracy or VoiceOver/TalkBack output.

The final text-button contrast correction passed **75 design tests and 36 visual cases** (111 total, `/tmp/text-button-contrast-final-tests.log`). Seven Discover light images were reviewed and updated; SHA-256 checks confirmed the other 31 images were unchanged.

The three [interaction workload cases](property-interaction-workload.md) use real card/list widgets and decoded photos. Each measured window has **30 pointer moves and 30 × 16ms pumps**:

| Workload | Host wall time | Decoded image-cache bytes, before → after | Scroll offset |
| --- | ---: | ---: | ---: |
| Discover horizontal drag | 201.46ms | 1,948,160 → 1,948,160 | 0 → 0 |
| Discover card scroll, Hindi 2x/320px | 170.55ms | 1,597,440 → 1,597,440 | 0 → 209.17 |
| Saved list scroll | 121.33ms | 80,000 → 80,000 | 0 → 240 |

The selected stack/card/hero/details/list-card/image widgets recorded zero rebuilds during each window. Saved scrolling mounted two new list-card and image instances. Counts come from `debugOnRebuildDirtyWidget`; they exclude layout and raster work. Cache bytes are Flutter's decoded-image cache, not process or disk memory. Mount, font/photo loading and pointer release are outside the window; reduced motion is enabled. This single debug run used a shared host under other verification load and preceded the final text-button color correction; timings were not remeasured for that color-only change. It establishes neither device FPS/touch latency nor a before/after speed improvement. [Raw observations](property-interaction-workload.json) retain the exact values and SDK metadata.

## Native build and startup evidence

Both builds used the isolated **`/tmp/360ghar-final-native`** copy and its synthetic `dart_defines.json`. The copy has an empty `dev_env.g.dart`, no `.env`, and a synthetic `GoogleService-Info.plist` required by native Firebase registration. Dart Firebase is disabled. The original production configuration was not used.

| Check | Result | Evidence |
| --- | --- | --- |
| Android debug APK, repeat build | Built in **20.1s** | `/tmp/360ghar-final-android-build-5.log`; isolated `build/app/outputs/flutter-apk/app-debug.apk` |
| iOS simulator debug app, no signing | Built in **25.9s** | `/tmp/360ghar-final-ios-build-6.log`; isolated `build/ios/iphonesimulator/Runner.app` |
| iPhone 17e debug simulator startup trace | First framework frame **1.180805s**; first rasterized frame **1.759959s** | [ios-startup-info.json](ios-startup-info.json), `/tmp/360ghar-startup-trace.log` |

The startup values are one debug simulator observation, not release startup, a device benchmark, or an improvement claim. Successful builds establish compilation of the isolated configuration; they do not establish device integration or release readiness. The source SPM result above is a separate check.

The [native fixture server](../../tool/verification/native_fixture_server.py) binds only `127.0.0.1:54321`. Its account, properties, swipes, visits and support pages are synthetic; mutations stay in process memory. The fixture audit passed 35 route checks and three Dart DTO/session checks (`/tmp/native-fixture-contract-dart.log`). This does not validate production authentication, delivery, backend behavior, or external service credentials.

## Native fixture journey evidence

The successful runs used **Maestro 2.6**, an explicit **iPhone 17e / iOS 27.0** simulator, a private Java user-home directory, and driver port **17017**. This isolation resolved the earlier CLI/driver transport mismatch. See the [Maestro guide](../../.maestro/README.md) for the device, CLI, port and fixture configuration.

| Native run | Result | Evidence |
| --- | --- | --- |
| Auth/onboarding suite | **7 / 7 passed**, 195s | [Auth XML](native-evidence/auth-suite.xml): onboarding Next/Skip, phone/signup/forgot-password validation, invalid password, fixture login; original `/tmp/360ghar-native-auth-suite.xml` |
| Main fixture smoke | **1 top-level flow passed**, 59s | [Fixture smoke XML](native-evidence/fixture-smoke.xml); original `/tmp/360ghar-native-fixture-smoke-5.xml` |
| Retained refresh failure, loopback server stopped | **1 / 1 passed**, 10s | [Refresh failure XML](native-evidence/refresh-failure.xml); original `/tmp/360ghar-native-refresh-failure-2.xml` |
| Refresh recovery, loopback server restarted | **1 / 1 passed**, 3s | [Refresh recovery XML](native-evidence/refresh-recovery.xml); original `/tmp/360ghar-native-refresh-recovery.xml` |

The main flow exercises onboarding/login, all five shell tabs, Liked/Passed, property details, Visits, Profile and Preferences. It renders actual MapLibre tiles with **synthetic Delhi simulator coordinates** and opens the local tour in an **actual native WebView**. This proves the tested simulator path, not physical GPS accuracy, every permission transition, external tour providers, or production authentication.

The refresh checks retain the Saved property and show a recoverable failure after the loopback server stops. After restart, Retry restores the loaded state. These are controlled simulator network-failure and recovery checks; they do not cover all network failures or backend responses.

Ten final native captures are saved under `docs/migration/screenshots/` and have been opened for visual review. [Screenshot SHA-256 records](native-evidence/screenshot-hashes.json) identify the repository artifacts:

| Journey | Captures |
| --- | --- |
| Entry and discovery | [Phone entry](../migration/screenshots/phone-entry-after-ios.png), [Phone entry with keyboard](../migration/screenshots/phone-entry-keyboard-after-ios.png), [Discover](../migration/screenshots/discover-after-ios.png), [Explore](../migration/screenshots/explore-after-ios.png) |
| Saved and property | [Saved](../migration/screenshots/saved-after-ios.png), [Details](../migration/screenshots/details-after-ios.png), [Tour](../migration/screenshots/tour-after-ios.png) |
| Visits and account | [Visits](../migration/screenshots/visits-after-ios.png), [Profile](../migration/screenshots/profile-after-ios.png), [Preferences](../migration/screenshots/preferences-after-ios.png) |

The native run led to fixes for keyboard dismissal, ten native identifiers kept separate from spoken labels, explicit location recovery actions (136-test focused run), labeled 48px Back/Share targets (23-test focused run), readable shared text buttons (111 design/visual tests), and selected Visits tab labels (26 view tests, `/tmp/visits-tab-contrast-tests.log`). The Visits tests retain narrow-layout assertions and check the rendered selected labels in both real app themes against a minimum 4.5 contrast ratio. Those focused counts overlap the full suite. They do not establish complete contrast or assistive-technology compliance.

A genuine pre-migration [phone-entry capture](../migration/screenshots/phone-entry-before-ios.png) now comes from commit `aa839932e85752755a11aa5de33970327cb226c9`. On the dedicated simulator, a clean app/keychain launch, onboarding Skip and phone-entry assertion passed as one flow in 13s ([baseline capture XML](native-evidence/baseline-capture.xml), original `/tmp/360ghar-head-before.xml`). The [baseline build record](baseline-native-build.md) and [machine-readable provenance](baseline-provenance.json) record the synthetic configuration and SDK compatibility adjustments; product/UI source remained at that commit. This replaces the earlier unverified preinstalled-app image. The baseline has automatic input focus and a visible keyboard; compare it with the final keyboard-state capture above. The full-page after image is also retained.

## Reproduce

From the app repository, using the resolved SDK/dependencies:

```sh
dart run build_runner build
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub --coverage --reporter expanded
./tool/verify_ios_release.sh --fix
```

Visual comparisons run with `flutter test --no-pub test/visual/property_screens_golden_test.dart`. The workload command in its linked report writes fresh observations only when explicitly requested. Do not update golden baselines during a verification-only run.

From the prepared isolated native copy, with its **synthetic** configuration:

```sh
cd /tmp/360ghar-final-native
flutter build apk --debug --no-pub --dart-define-from-file=dart_defines.json
flutter build ios --debug --simulator --no-codesign --no-pub --dart-define-from-file=dart_defines.json
flutter run -d "iPhone 17e" --debug --trace-startup --dart-define-from-file=dart_defines.json
```

Run `python3 tool/verification/native_fixture_server.py` from the source repository for loopback fixture journeys. Recreate the documented synthetic configuration before reproducing native checks; do not substitute production credentials. `/tmp` logs and build products are local and can expire; repository PNGs, native XML reports, trace JSON, workload JSON and provenance records retain the main artifacts. No commit or release was requested.

## Pending native acceptance

- Google OAuth, Sign in with Apple, and native push delivery need suitable credentials and device acceptance.
- No Android device/emulator was available for execution; only the APK build is verified.
- Physical GPS accuracy, real-device permission changes and external WebView/tour providers remain unverified. The successful simulator flow uses injected coordinates and a local tour page.
- Installed-release storage upgrade, background media behavior and VoiceOver/TalkBack acceptance remain device checks. The successful fixture journeys do not complete all native acceptance.
