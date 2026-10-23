# Repository guidelines

360 Ghar is a Flutter property discovery application. It supports Discover swipes,
map and list exploration, saved and passed properties, property details and tours,
visit scheduling, Assistant conversations, profile settings, and property tools.
Manual Riverpod providers own shared state. Flutter widgets own presentation state.
GoRouter owns declarative navigation. See `PRODUCT.md` for product requirements.

Read the workspace guide (`../AGENTS.md`) for the personal GitHub account rule.
Preserve unrelated uncommitted native and release changes.

## Structure and ownership

```text
lib/
  main.dart                    bootstrap and application ProviderScope
  root.dart                    session resolution and recoverable startup UI
  core/
    bootstrap/                 startup, application effects, provider retry policy
    providers/                 database, network, and authentication composition
    controllers/               session, settings, update, durable queue owners
    data/models/               shared immutable models and JSON serialization
    data/ports/                narrow injected repository contracts
    network/                   ApiClient, ApiResponse, scoped ETag cache, SSE
    storage/                   AppDatabase and read-only legacy importer
    routes/                    GoRouter routes and pure redirect/link policy
    translations/              message catalog and Flutter localization delegate
    design/                    theme data, context palette, design tokens
    widgets/                   reusable presentation components
  features/<feature>/
    application/               focused feature state and query providers
    data/                      constructor-injected repositories and datasources
    presentation/
      controllers/             manual Riverpod Notifiers where applicable
      views/                   ConsumerWidget / ConsumerStatefulWidget screens
      widgets/                 feature widgets
```

Follow the existing paths. Do not add empty layers or pass-through controllers to
match a template. Retired bindings and page-service managers have no compatibility
wrapper.

## State and dependency ownership

Use manual `Provider`, `NotifierProvider`, and `AsyncNotifierProvider` declarations.
Do not add generator annotations for providers. `build_runner` is only for JSON
models. State is immutable, including nested collections from JSON or from callers.
Publish a new state value after each change.

Widgets use `ref.watch` for rendered state and `ref.read(provider.notifier)` for
user actions. Select narrow values when a widget does not need the whole state.
Text, focus, form, scroll, and animation controllers stay in the widget that owns
them. Repositories receive their clients in constructors. They do not find
services, translate text, navigate, or show UI.

The root scope uses `noProviderRetry`. Network transport owns bounded safe read
retries. Mutations need an explicit server replay contract; provider retry must not
submit them again. Record a generation and account scope before asynchronous work.
Reject late results after input changes, account changes, or disposal. Register
timers, streams, clients, and database cleanup with `ref.onDispose` or the owning
widget's `dispose`. Inactive shell branches can stay mounted, so visibility must
stop GPS, prefetch, video, WebView work, and other active resources.

## Startup, session, and routing

`bootstrapAppCore` validates configuration, opens `AppDatabase`, and initializes
Supabase. A failed attempt closes its database and shows a retry screen. The
application's provider scope owns the database. Supabase owns credential storage
and token refresh; application tables never store access or refresh tokens.

`authProvider` is the single session owner. It exposes status, user, typed error,
resolving state, mutation state, and stale cached profile state. An offline profile
refresh can keep the matching account's cached profile. A transient missing auth
header must not force logout. Mandatory password setup cannot be skipped. Profile
completion Skip needs a persisted purpose and defers completion only for that
account's current session.

`MaterialApp.router` reads `appRouterProvider`. The `StatefulShellRoute` has five
branches: Discover, Explore, Saved, Visits, Profile. Route declarations live in
`core/routes/app_pages.dart` and `app_routes.dart`. The pure `route_policy.dart`
owns redirects, safe return destinations, public links, and notification routes.
Deep links and notifications use the same policy.

Guests can browse Discover, Explore, property details, tours, tools, and policy
pages. `protectedPaths` in `route_policy.dart` lists the account-only routes.
`requireAccount` in `lib/core/widgets/common/sign_in_gate.dart` is the one gate for
account actions (like, visits, Assistant, account tabs). Sign-out and account
deletion return to guest Discover.

Presentation code uses `context.push`, `context.go`, and `context.pop`. Controllers
do not navigate. Do not add navigation recovery timers or force a route from session
callbacks. Keep passwords, OTPs, tokens, and user identifiers out of route URLs and
diagnostics. Account-keyed forms remount when the session changes.

## Property queries and durable mutations

`propertyFiltersProvider` owns device preferences. Purpose and property type apply
to all feeds; price, search, and other detailed filters belong to one feed.
`propertyLocationProvider(page)` owns the account-scoped selected area and the GPS
lifecycle. An automatic GPS or IP location outside the service area (`ServiceArea`
in `lib/features/location/application/location_source.dart`), or no automatic
location, starts in Gurugram with a short note. A manual or saved pick is kept.
`propertyQueryProvider(feed)` owns request identity, content, refresh, cursor
progression, and a separate pagination failure. `swipeHistoryProvider` owns the
shared like/pass projection and pending operation review.

Refresh keeps usable content. Pagination retry keeps rows and scroll position.
Request identity includes account and environment, endpoint and feed, filters,
search, location, sort, limit, and cursor. Reject stale completions. Discover does
not restore a cached server deck that can bring back swiped cards.

Discover supports horizontal Like/Pass gestures, accessible Like/Pass buttons, and
details navigation. Vertical card scrolling stays scrolling. There is no swipe-up,
double-tap, or super-like API. Swipe operations are written before the network
call. A pending action has a durable operation ID and a visible retry or discard
state. Retry refers to the same operation and rejects superseded intents. Guest
passes are session-only and never reach the network.

Visit creation has no verified backend idempotency key or uniqueness contract. A
lost response is `needsReconciliation`, not proof that the booking failed. Do not
replay the POST automatically. Reconcile with authoritative GET results and keep
pending, failed, and confirmed states distinct. See `docs/migration/visits.md`.

## Persistence and transport

`AppDatabase` is the one SQLite (`sqflite`) owner. It stores JSON preferences,
account and environment cache rows, drafts, and durable actions. Await writes before
you claim data is saved. Expose storage failure and explicit retry separately from
network failure. A scope lease rejects prior account work, including an A to B to A
transition. Account changes must invalidate scope before cleanup and keep account
ownership of pending actions.

The importer reads legacy `GetStorage.gs` and `GetStorage.bak` without changing
them. It imports allowed preferences in one transaction and quarantines unowned
actions. It does not import old property lists, cursors, loading state, caches, or
credentials. Runtime code does not use GetStorage. It is the only legacy storage
boundary. See [persistence.md](./docs/persistence.md).

`core/network/api_client.dart` uses `package:http` and a plain `ApiResponse`.
Providers inject auth headers, SQLite ETag storage, HTTP, and SSE clients. Account
changes cancel current work and block late cache writes. Cache clearing deletes the
records. Booking POST is not idempotent.

`imageCacheServiceProvider` owns one image cache manager for displayed images and
prefetch. Widgets borrow it and never dispose it. The cache has a 200-entry bound
and a 24-hour stale period; do not claim a byte quota or fake cache statistics.
Tests override it with `ImageTestCache`.

## UI and localization

The design system is in `lib/core/design/`. Use `context.design` for adaptive
palette colors and `Theme.of(context).textTheme` for typography. `AppDesign`
supplies fixed tokens. Never look up the theme through a controller or a global
service locator. Check contrast in light and dark themes.

`themeProvider` and `localizationProvider` persist settings through the database.
UI text uses `context.l10n.text(key, params: ...)`. English and Hindi share the same
keys in `core/translations/app_messages.dart`; add every entry to both maps. Data
and state layers expose typed failures; the UI maps them to safe localized text. Do
not show raw exception text.

Use `AppToast` for brief top-of-screen feedback; `AppToastHost` owns the overlay and
timers. Recoverable load, save, and pending-operation errors also need a persistent
inline message and a retry control. A toast is never the only record of an
unresolved booking, a failed save, or a failed page load.

```dart
final session = ref.watch(authProvider);
final label = context.l10n.text('retry');
final color = context.design.textPrimary;
// A user action calls the state owner; it does not find a global service.
await ref.read(authProvider.notifier).retryProfileLoad();
```

Loading placeholders fit the final layout and respect reduced motion. Keep content
during refresh, form input during failure, and control size during submit. Give
icon controls semantic labels. Check both themes, 320-pixel width, 2x text,
keyboard insets, safe areas, and English and Hindi.

## Environment

- `.env.development` and `.env.production` are local only and gitignored. Never
  package them as Flutter assets.
- Pass configuration as dart-defines: `dart run tool/env_to_dart_defines.dart
  .env.development > .dart_defines.dev.json`, then `--dart-define-from-file`. The
  `.dart_defines*.json` files are gitignored.
- For a bare `flutter run`, `dart run tool/sync_dev_env.dart` fills the debug map in
  `lib/core/config/dev_env.g.dart`. Never commit its secrets.
- Runtime access is `AppConfig.instance` (`lib/core/config/app_config.dart`).
- Keys: `API_BASE_URL` (`https://api.360ghar.com`), `API_TIMEOUT_SECONDS`
  (optional), `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `GOOGLE_PLACES_API_KEY`,
  `GOOGLE_WEB_CLIENT_ID`, `GOOGLE_IOS_CLIENT_ID`, `DEFAULT_COUNTRY`, `DEBUG_MODE`,
  `LOG_API_CALLS`, and the `FIREBASE_*` flags. See `.env.production.example`.
- Authentication uses the Supabase publishable key.
- Platforms: iOS 15.0 and later, Android SDK 21 and later, web (Chrome).

## Commands and checks

1. Resolve dependencies with `flutter pub get`. After `pub get` or `flutter clean`,
   run `./tool/verify_ios_release.sh --fix` before an Xcode build or archive (see
   Build troubleshooting).
2. Format changed files with `dart format <paths>` and run `flutter analyze`.
3. Run focused `flutter test <paths>`, then the full suite with
   `flutter test --coverage`. Keep the CI coverage gate at 85%. Do not bypass
   layout or runtime assertions.
4. Run `dart run build_runner build --delete-conflicting-outputs` when JSON models
   change. Do not hand-edit generated serializers.
5. Golden tests in `test/visual/` are macOS only. Update them with
   `flutter test --update-goldens test/visual/<file>` and review every changed image.

Verification does not authorize a release, a push, or a production write.

## Device checks

Use one common iPhone simulator: `iPhone 18 Pro` on the newest installed iOS
runtime. It already exists. Do not create, clone, erase, or delete simulator
devices, and do not boot more than one simulator.

```bash
dart run tool/env_to_dart_defines.dart .env.development > .dart_defines.dev.json
xcrun simctl uninstall booted com.the360ghar.ghar360   # optional: fresh install
flutter run -d "iPhone 18 Pro" --dart-define-from-file=.dart_defines.dev.json
```

`flutter run` stays in the foreground while the app runs. Take a screenshot from a
second terminal: `xcrun simctl io booted screenshot <file>.png`.

iPad and iPhone Duo layouts are covered by the golden tests in `test/visual/` at
466x678 and 669x951 (iPhone Duo outer and inner), 820x1180 and 1376x1032 (iPad),
and 375x667 (Split View). Do not use extra simulators for them. Xcode 27.1 has no
separate Simulator app, so the simulator runs headless unless you open it from
Xcode.

## Testing

`test/` mirrors source features. Use a `ProviderContainer` for state tests and a
`ProviderScope` for widget tests. Override external boundaries: database,
repository, HTTP, native plugins, and image cache. Use
`test/helpers/provider_test_app.dart` for a localized shell with a test image cache
and `AppToastHost`, and `test/helpers/auth_test_harness.dart` for session changes
with real SQLite. Feature harnesses give narrower fixtures.

Keep observable behavior when you retire architecture-specific tests. Assert
provider identity, immutable state, disposal, and visible UI, not binding
registration or mutable fields. Do not suppress render errors or accept either
success or failure. Disk atomicity and restart tests use `sqflite_common_ffi`; a
map fake does not prove durability.

Native OAuth, GPS, camera and gallery, maps, video, WebView, notification delivery,
and accessibility still need a native target. Widget platform fakes do not prove
device behavior. Record a blocked native check explicitly. See the
[migration checklist](./docs/migration/riverpod-checklist.md) for the full-suite,
coverage, visual, and native evidence, and the remaining device and credential
checks.

## Build troubleshooting

- **iOS packages.** iOS uses Swift Package Manager (no CocoaPods or Podfile). If
  packages fail to resolve, run `flutter pub get`, then
  `flutter build ios --config-only`.
- **SwiftPM minimum platform.** `flutter pub get` and `flutter clean` regenerate
  `FlutterGeneratedPluginSwiftPackage/Package.swift` with `.iOS("13.0")`. Firebase
  needs 15.0, so Xcode fails with "requires minimum platform version 15.0".
  `flutter build ios` or `flutter build ipa` raises it again. Before an Xcode build
  or archive, run `./tool/verify_ios_release.sh --fix`, or
  `flutter build ios --config-only`.
- **Crashlytics and the verify script.** The Xcode Crashlytics phase and
  `./tool/verify_ios_release.sh` need a Crashlytics upload tool: the FlutterFire
  CLI (`dart pub global activate flutterfire_cli`) or the SwiftPM checkout's
  `upload-symbols` under Xcode DerivedData. The manual uploader
  `./tool/upload_ios_symbols.sh` does not use FlutterFire. It needs the SwiftPM
  `upload-symbols`, so archive once in Xcode first.
- **Provider and lifecycle errors.** Inspect the provider state and its scope
  overrides. Check the generation and scope after every awaited boundary. Check that
  the owner disposes timers, streams, media, and clients. Do not fix a lifecycle
  error with a delay, a forced rebuild, a global registration, or a swallowed
  exception.

## Release

Store builds normally use Shorebird (`shorebird release ios` and
`shorebird release android`) so they can receive OTA patches; see
[shorebird.md](./docs/shorebird.md). Build 1.1.0+18 ships as a plain
`flutter build ipa`; Shorebird patches cannot target it. Follow
[RELEASE_IOS.md](./RELEASE_IOS.md) section 6 for that build. Before you submit,
`./tool/prod_contract_probe.sh` must pass.

## Style and security

Use two-space indentation, `snake_case.dart` files, `UpperCamelCase` types, and
`lowerCamelCase` members. Follow `analysis_options.yaml`. Keep changes scoped and
remove obsolete paths when you replace an API. Do not keep GetX wrappers, global
service locators, parallel authoritative state, or duplicate HTTP clients. Add an
abstraction only when real call sites need it.

Never log tokens, OAuth secrets, OTPs, passwords, raw profile data, exact
coordinates, or full auth or location URLs. Log safe failure categories and request
stages. Never send real bookings, account deletions, or production writes during
verification.

## Key files

| Concern | Path |
| --- | --- |
| Application composition | `lib/main.dart`, `lib/core/bootstrap/` |
| Session and auth | `lib/core/controllers/auth_controller.dart`, `lib/core/providers/auth_providers.dart` |
| Router, policy, sign-in gate | `lib/core/routes/app_pages.dart`, `lib/core/routes/route_policy.dart`, `lib/core/widgets/common/sign_in_gate.dart` |
| Data and caches | `lib/core/network/`, `lib/core/storage/` |
| Product state | `lib/features/properties/application/`, feature presentation controllers |
| Theme and messages | `lib/core/design/`, `lib/core/translations/` |
| Release | `RELEASE_IOS.md`, `tool/verify_ios_release.sh`, `tool/prod_contract_probe.sh` |
| Migration evidence | `docs/migration/riverpod-checklist.md`, `docs/persistence.md` |

Use the Dart and Flutter MCP tools when they provide the required operation. The
Flutter and Dart CLI commands are the fallback.
