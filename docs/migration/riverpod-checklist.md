# Riverpod migration checklist

Status: implementation and automated acceptance complete. iOS simulator authentication and fixture journeys pass; remaining native checks and environment limits are recorded below. This tracks the 25 September 2026 request, which replaces the old GetX architecture rules. Source and executable tests take precedence over historical audit reports.

## Baseline and protected work

- Flutter 3.47.4 stable; Dart 3.13.3. `flutter pub get` completed before analysis. SDK resolution changed five lockfile entries and added generated-directory analyzer exclusions.
- `flutter analyze --no-pub`: no issues (11.9 seconds).
- `flutter test --no-pub --coverage --reporter expanded`: 3,700 passed, 2 skipped (128 seconds). Line coverage: 16,673 / 18,945 = **88.01%**. Keep the CI **85%** gate unchanged.
- `./tool/verify_ios_release.sh --fix`: passed; generated SwiftPM minimum is iOS 15.0. Run this after each dependency resolution.
- Pre-existing changes: `.github/workflows/build.yml`, `CLAUDE.md`, release checklist, dSYM RCA, iOS project, `pubspec.yaml`, symbol-upload/verification scripts; new iOS release workflow, Shorebird guide/config, binary dSYM script. Preserve these. No releases, pushes, or production writes are authorized by this migration.
- Available: iPhone 17e simulator (iOS 27), connected iPhone, macOS, Chrome. No Android device was listed. Native checks used the simulator, not the personal device. The true pre-migration `HEAD` (`aa839932e85752755a11aa5de33970327cb226c9`) was built separately in `/tmp/360ghar-baseline-native`. Its [verified phone-entry capture](screenshots/phone-entry-before-ios.png) replaces the old unknown-preinstalled-version image. The [capture flow](../verification/native-evidence/baseline-capture.xml) passed in 13 seconds. [Build provenance](../verification/baseline-native-build.md) and [machine-readable comparison](../verification/baseline-provenance.json) record unchanged product source and isolated configuration/build adjustments.

## Decisions

Use manual `Provider`, `NotifierProvider`, and `AsyncNotifierProvider` declarations. Use immutable state, constructor-injected data services, `ref.onDispose` ownership, and generation/account checks after async work. Set the root scope retry to `noProviderRetry`; HTTP owns bounded read retries. A provider declaration with `retry: null` alone uses the Riverpod default and does not disable retries. Mutations need an explicit safe replay contract. Observe Riverpod's paused inactive-tab listeners and stop hidden media/streams deliberately.

Use `MaterialApp.router` and `StatefulShellRoute` for five branches: Discover, Explore, Saved, Visits, Profile. Assistant remains a named, labeled destination. Authentication/onboarding redirects preserve safe intended routes and require no navigation timers.

Use one application SQLite database for preferences, scoped cached responses, drafts, and durable actions. Supabase owns credentials and refresh. Keep image bytes in one bounded image cache. Import valid legacy preferences transactionally; quarantine unowned legacy actions. Do not replay visit creation automatically: backend inspection found overlap checks, but no durable idempotency key or database uniqueness contract.

Flutter localizations keep English/Hindi parity through one message catalog. UI uses `context.l10n` and `context.design`; errors carry typed keys, never translated text from data services. Keep `AppToast` at the top with Flutter overlay ownership.

References: [Riverpod 3 migration](https://riverpod.dev/docs/3.0_migration), [experimental persistence limits](https://riverpod.dev/docs/concepts2/offline), [stateful shell](https://pub.dev/documentation/go_router/latest/go_router/StatefulShellRoute-class.html).

## Implementation and acceptance

| Priority | Increment | Status and evidence |
| --- | --- | --- |
| P0 | Baseline and protected native/release work | Baseline above; original changes retained. Dependency resolution and SPM verification completed. |
| P0 | HTTP and typed failures | Implemented. HTTP/auth/ETag/SSE tests cover refresh, cancellation, deduplication, bounded read retries, actual cache clear, malformed responses and safe diagnostics. See [data boundaries](data-boundaries-diagnostics.md). |
| P0 | SQLite and legacy migration | Implemented. `test/core/storage/app_database_test.dart` covers transactions, interrupted/corrupt migration, write failure, account leases, expiry and cache limits. [Persistence policy](../persistence.md) documents retained values and quarantined actions. |
| P1 | Image cache | Implemented. One provider-owned manager, actual eviction, bounded prefetch/decode and reduced-motion fades. Image/widget tests and real decoded-photo visual tests pass. |
| P0 | Riverpod, localization and themes | Implemented. Manual immutable providers, explicit retry policy, scoped disposal, English/Hindi parity, context theme access and top-position Flutter toast host. GetX/GetStorage removed from source, tests, manifest and lockfile. |
| P0 | Startup, session and routes | Implemented. Actual Supabase partial-init cleanup and timeout ownership, account-switch mutation guards, safe public/intended destinations, five shell branches and inactive-page effects are tested. See [routing recovery](routing-recovery.md). |
| P0 | Property queries and saved state | Implemented. Focused filters/location/query/swipe owners; cursor, refresh, stale-response and account tests pass. Discover, Explore and Saved expose manual location selection and GPS retry before property loading, and retain content on later GPS failure. See [query mapping](property-query-tests.md), [Discover/Saved mapping](discover-saved-tests.md) and [swipe recovery](swipe-recovery.md). |
| P0 | Visits and pending actions | Implemented. Durable operation ownership, explicit confirmation/pending/failure, retained refresh content, reconciliation and discard are tested. No automatic booking replay. See [Visits evidence](visits.md). |
| P0 | Assistant | Implemented. Provider/controller/view tests distinguish history failure from empty data, preserve drafts/interrupted messages, and cancel stale conversation/account streams. |
| P1 | Settings, tools and support | Implemented. Failed persistence retry, retained inputs, validation, policies, feedback and shared session data are tested. See [auth/profile mapping](auth-profile-tests.md). |
| P1 | Shared recovery UI and accessibility | Automated checks pass for narrow/large-text/keyboard/tablet layouts, both themes and reduced motion. Real-font visual evidence is recorded below. Native VoiceOver/TalkBack and platform integration checks remain separate. |
| P0 | Final verification | Latest full suite: 3,390 passed, zero skips/failures; 91.67% coverage. Analyzer and formatting are clean; final iOS and Android debug builds pass. Seven iOS auth flows, one multi-screen fixture flow and Saved refresh failure/retry flows pass. Remaining native acceptance is recorded below. |

## Screen and state evidence

“Automated verified” means the listed provider/widget tests passed. It does not
mean that a real OAuth service, push provider, GPS receiver, native map, camera,
WebView or store build was verified. File paths below are relative to `test/`.

| Journey | Verified behavior and concrete test mapping | Remaining native boundary |
| --- | --- | --- |
| Startup/onboarding | `main_bootstrap_test.dart`: storage/config failure, retry ownership, actual SDK session-store failure and timeout. `features/splash/presentation/{controllers,views}/splash_*_test.dart`: skip/finish, persistence and responsive layout. | iOS Maestro next/finish and skip flows pass. Installed-release data upgrade remains unverified. |
| Authentication | `core/controllers/auth_controller_test.dart` and `features/auth/presentation/`: all identifier/password/OTP/recovery forms, resend, offline profile, mandatory password gate, duplicate-submit and A→B→A rejection. Delayed unregister cannot sign out/delete a replacement account. `features/auth/presentation/widgets/auth_premium_shell_test.dart` verifies keyboard dismissal without losing input or submitting. | Seven iOS auth flows pass with a loopback fixture, including invalid-password and successful login. Google/Apple OAuth and SMS/email delivery still need authorized credentials. |
| Profile completion | `features/auth/presentation/profile_completion_view_test.dart`: required fields, purpose before Skip, persistence failure, stable loading controls. `features/profile/presentation/views/edit_profile_view_test.dart`: retained edits, avatar mutation and upload failure. | Camera/gallery permission and real upload behavior remain unverified. |
| Discover | `features/discover/presentation/{controllers,views,widgets}/`: initial/content/empty/error states, explicit and gesture Like/Pass, rapid/concurrent actions, rollback, low-deck paging and no restored swiped cards. [Behavior mapping](discover-saved-tests.md). | iOS fixture feed renders. Physical-device gesture/frame performance is not claimed. |
| Explore | `features/explore/presentation/views/explore_view_test.dart` plus provider/widget tests: map/list state, search, retained partial failure, location recovery and large-text controls. [Visual matrix](../verification/property-visual-review.md). | iOS fixture journey renders the actual MapLibre surface with synthetic GPS. Physical GPS and permission-setting behavior remain unverified; widget visuals still label their fake canvas. |
| Filters/location | `features/location/application/{location_source,location_providers}_test.dart`, `core/controllers/page_{filter,location}_manager_test.dart`: permission recovery, manual selection, scope, hydration, debounce, stale results, storage failure and visibility-owned streams. `core/widgets/common/property_location_recovery_test.dart` uses real location/query providers for manual recovery, GPS retry before fetch, retained content, and English/Hindi 320px/2x controls across all three feeds. | Simulator synthetic GPS is verified. Physical GPS, actual permission settings and platform geocoding remain unverified. |
| Saved/Passed | `features/likes/presentation/`, `features/properties/application/` and `core/controllers/page_*_test.dart`: independent segments/search, shared projection, retained refresh/pagination failures, pending retry/discard and stale server merges. [Swipe recovery](swipe-recovery.md). | iOS fixture journey verifies both segments and details navigation. Stopping the fixture server retains Saved content with a refresh error; restarting it and tapping Retry recovers. Production account/backend behavior is not claimed. |
| Property details | `features/property_details/presentation/{controllers,views}/`: same-ID summary seed, authoritative load, stale cache, deleted listing eviction, wrong-ID rejection and guest action return. [Details evidence](property-details-tour.md). | iOS fixture details and tour navigation pass. Real backend listings, external maps/share and booking submission remain separate checks. |
| Media/tours | `features/tour/`, `core/utils/webview_helper_test.dart`, `features/property_details/presentation/widgets/property_video_lifecycle_test.dart`: URL validation, timeout/retry, late callback rejection, image/video failure and hidden/disposed resource calls. | iOS native WebView renders loopback HTML and returns to details. External tour/iframe, video/background behavior and native memory release remain unverified. |
| Visits | `features/visits/`, `core/controllers/offline_queue_service_test.dart` and `integration/critical_flow_test.dart`: loading/content/empty/stale, retained refresh and page retry, agent partial failure, UTC validation, duplicate prevention, durable unresolved request and GET-only reconciliation. [Visits evidence](visits.md). | iOS fixture scheduled/past navigation passes. Real booking/contact actions need authorized non-production fixtures; production writes are not permitted. |
| Assistant | `features/assistant/presentation/{controllers,views,bindings}/`: history loading/empty/failure, draft persistence and retry, interrupted stream, conversation/account switch and provider disposal. | End-to-end authenticated backend streaming remains unverified. |
| Profile/settings | `features/profile/presentation/` and `core/controllers/{theme,localization}_controller_test.dart`: English/Hindi, light/dark/system, local write retry, password/delete confirmation, account-keyed form/dialog reset and logout failure. [Behavior mapping](auth-profile-tests.md). | iOS fixture Profile→Preferences navigation passes. Device accessibility announcements and real account settings sync remain unverified. |
| Support | Profile Help/About/feedback/policy tests cover navigation, required fields, submission failure/retained draft, markdown retry, safe URLs and package version. | Real mail/dialer/browser and feedback submission need native fixtures. |
| Calculators/checklists | `features/tools/presentation/{controllers,views}/`: all calculator inputs/formulas, validation, theme/layout, persisted checklist migration, failed-write retry and provider lifecycle. | No native integration dependency; real device visual review is separate. |

## Adapter and test migration

`main.dart` uses `MaterialApp.router` and provider-owned composition. Bindings,
`PageStateService` managers, the old dashboard controller, auth navigation service,
and navigation recovery timers are retired. An import check preceded source removal.

GetX translation/test adapters and obsolete binding-wiring assertions were removed
or replaced with provider isolation/lifecycle assertions. Useful product behavior
was migrated to its current owner; this is not a claim that every old test file or
assertion remained unchanged. The mapping documents above record those replacements.
Runtime and test import/API scans found no GetX/GetStorage dependency. References
to legacy GetStorage filenames and importer fixtures remain intentionally; they do
not load that package. The read-only importer is separate from runtime storage.

## Automated verification

| Check | Result and scope |
| --- | --- |
| Baseline full suite | 3,700 passed, 2 skipped; 88.01% coverage. This is the pre-migration checkpoint, not the final result. |
| Earlier migrated full suite | 3,212 passed, zero skips; 16,555 / 18,276 lines = 90.58%. Log: `/tmp/360ghar-full-tests-1.log`. |
| Latest full suite | 3,390 passed, zero skipped, zero failed in 124 seconds after the final Visits color adjustment. Includes actual-SDK bootstrap, delayed-unregister, auth keyboard and location recovery regressions. Log: `/tmp/360ghar-final-tests-4.log`. Final coverage: **17,035 / 18,582 lines = 91.67%** across 235 instrumented files. The CI 85% gate is byte-identical to `HEAD`. |
| Static analysis | No issues, 14.3 seconds. Log: `/tmp/360ghar-final-analyze-3.log`. |
| Formatting and whitespace | 476 files checked, zero changes in 3.52 seconds; `git diff --check` clean. Log: `/tmp/360ghar-final-format-check-4.log`. |
| Core integration | `integration/critical_flow_test.dart` uses a real provider session, actual repositories and SQLite for discovery→swipe→booking, offline ownership across logout/A→B→A, and ambiguous booking reconciliation without a second POST. |
| Final recovery increments | Auth controller 45 tests; bootstrap 14 tests; auth shell/phone batch 13 tests; property location/view batch 136 tests, including 13 new location recovery cases. Logs: `/tmp/auth-unregister-account-regressions.log`, `/tmp/bootstrap-sdk-recovery-tests.log`, `/tmp/auth-keyboard-dismissal-tests.log`, `/tmp/location-recovery-focused-tests.log`. These cases also appear in the latest full-suite log. |

Focused counts in feature evidence overlap the full suite and must not be summed.
The former skipped Firebase initialization test now executes with an injected core
platform. Push tests cover callback delivery, subscription cleanup and delayed
initialization/token ownership. These checks do not prove delivery from Firebase.

## Visual and interaction evidence

[Property visual review](../verification/property-visual-review.md) records
36 screen cases with **38 real-font image comparisons**, all passing without
updating baselines. The [gallery](../verification/property-visuals.html) shows
Discover, Explore and Saved in content/loading/retained refresh failure states,
light/dark themes, 390px English at 1x text and 320px Hindi at 2x text. Real local
photos decode through the injected image cache; only the native map canvas is fake.
Representative images were inspected and layout, contrast and reduced-motion
findings were fixed. Other feature widget tests cover keyboard and tablet layouts.

Three [interaction workloads](../verification/property-interaction-workload.md)
record horizontal drag, compact Discover card scroll and Saved list scroll using
production widgets and bundled fonts. The [raw observations](../verification/property-interaction-workload.json)
include host wall time, rebuild counts and decoded-image cache bytes. They are
controlled debug widget-test observations, not device FPS, touch latency, total
process memory or before/after improvement measurements.

The [iOS debug startup trace](../verification/ios-startup-info.json) records
1.180805 seconds to the first framework frame and 1.759959 seconds to the first
rasterized frame. This is one simulator observation; no startup improvement or
release-performance claim is made.

The iOS fixture journey also captured [phone entry](screenshots/phone-entry-after-ios.png),
[Discover](screenshots/discover-after-ios.png), [Explore](screenshots/explore-after-ios.png),
[Saved](screenshots/saved-after-ios.png), [details](screenshots/details-after-ios.png),
[native WebView](screenshots/tour-after-ios.png), [Visits](screenshots/visits-after-ios.png),
[Profile](screenshots/profile-after-ios.png), and [Preferences](screenshots/preferences-after-ios.png).
The stopped-server check adds [Saved refresh failure](screenshots/saved-refresh-failure-ios.png)
and [recovery after Retry](screenshots/saved-refresh-recovered-ios.png).
These are simulator captures with synthetic account/listing data. They complement
the widget visual matrix; they do not establish physical-device accessibility or performance.
The verified `HEAD` phone-entry capture includes the original automatically opened
keyboard. The [matching final-build capture](screenshots/phone-entry-keyboard-after-ios.png)
keeps the keyboard visible; the other after image shows the screen after dismissal.
The [native gallery](../verification/native-visuals.html) presents the before/after
comparison and final fixture journey. The [final verification report](../verification/riverpod-final-verification.md)
collects the evidence and remaining environment limits.

## Native builds and remaining acceptance

| Check | Current result |
| --- | --- |
| iOS simulator debug build | Passed after final source synchronization, including the Visits color adjustment: Xcode 25.9 seconds. Log: `/tmp/360ghar-final-ios-build-6.log`. |
| Android debug APK | Initial build passed in 641.1 seconds; final warm rerun passed in 20.1 seconds. Logs: `/tmp/360ghar-final-android-build.log` and `/tmp/360ghar-final-android-build-5.log`. No Android device is available. |
| Android tooling messages | Existing Gradle 8.14 / AGP 8.11.1 / Kotlin 2.2.20 future-deprecation warnings and Flutter's SDK `2147483647` fallback diagnostic did not fail either build. No SDK value was changed to that diagnostic integer. |
| Maestro auth | **7/7 pass, 195 seconds**, on iPhone 17e / iOS 27: onboarding next/finish, onboarding Skip, phone validation, signup validation, invalid password, password recovery validation and successful fixture login. [Auth XML](../verification/native-evidence/auth-suite.xml). Keyboard dismissal taps a static title and retains input. |
| Maestro fixture journey | **1 flow passes, 59 seconds** on the final build. Onboarding/login→Discover→actual MapLibre Explore with synthetic GPS→Saved/Passed→details→native WebView→Visits→Profile→Preferences. [Final fixture XML](../verification/native-evidence/fixture-smoke.xml), from `/tmp/360ghar-native-fixture-smoke-5.xml`. The loopback server owns synthetic data and in-memory mutations; this does not verify production authentication or backend behavior. |
| Native refresh failure/retry | **Two flows pass** on iOS: stopped-server Saved refresh retains content and shows its error (10 seconds); after restart, Retry clears the error and restores the normal state (3 seconds). [Failure-state XML](../verification/native-evidence/refresh-failure.xml), [recovery XML](../verification/native-evidence/refresh-recovery.xml). The successful rerun supersedes the first incomplete failure assertion. |
| Credentials and device integrations | Google/Apple OAuth, SMS/email and push delivery, physical GPS/permission recovery, camera/gallery, external tour/video/background behavior, installed-release data upgrade and VoiceOver/TalkBack remain unverified. No Android device is available. Mocks/builds and synthetic simulator checks do not close these checks. |

- [x] Riverpod migration and GetX/GetStorage adapter/dependency removal verified.
- [x] Latest full suite passes with 91.67% coverage and the unchanged 85% gate; behavior mappings and architecture docs updated.
- [x] Real-font visuals, interaction workloads, native builds and passing iOS auth/fixture/refresh-recovery journeys are recorded; credential/device limits remain explicit.
- [x] Replaced the unverified before image with a true `HEAD` build capture and recorded source/configuration provenance.
- [ ] Verify credential-dependent integrations and physical-device/installed-release acceptance when those environments are available.

No release, production write, push or store publication is authorized by this
verification. Existing iOS, Shorebird, signing and release workflow work remains
protected as recorded in the baseline inventory.
