# CLAUDE.md

This file describes the implemented application architecture and contributor workflow.
Read the workspace `../CLAUDE.md` for repository boundaries and the personal GitHub
account rule. Use the `github.com-personal` SSH alias for GitHub operations.

## Project overview

360 Ghar is a Flutter property discovery application. It supports Discover swipes,
map/list exploration, saved and passed properties, property details and tours,
visit scheduling, Assistant conversations, profile settings, and property tools.
Manual Riverpod providers own shared state. Flutter widgets own presentation state.
GoRouter owns declarative navigation. See `PRODUCT.md` for product requirements and
`docs/migration/riverpod-checklist.md` for completed verification and remaining native limits.

## Common Development Commands

### Build and Run
```bash
# Run the app in development mode
flutter run

# Run on specific device
flutter run -d ios
flutter run -d android

# Run with specific flavor
flutter run --flavor development
flutter run --flavor production

# Hot reload during development
# Press 'r' in terminal or use IDE hot reload
```

### Code Generation
```bash
# Generate model files (after modifying JSON serializable models)
dart run build_runner build

# Watch for changes and auto-generate
dart run build_runner watch

# Clean generated files
dart run build_runner clean

# Force regenerate with conflict resolution
dart run build_runner build --delete-conflicting-outputs
```

### Testing and Quality
```bash
# Run unit and widget tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Run tests with coverage
flutter test --coverage

# Generate coverage report
genhtml coverage/lcov.info -o coverage/html

# Analyze code for issues
flutter analyze

# Fix lint issues automatically
dart fix --apply

# Format code according to Dart style
dart format .

# Check dependencies for updates
flutter pub outdated

# Update dependencies
flutter pub upgrade
```

### Build for Production
```bash
# Build APK for Android
flutter build apk --release

# Build App Bundle for Google Play
flutter build appbundle --release

# Build for iOS
flutter build ios --release

# Build for web
flutter build web
```

**Store releases must be built with Shorebird** (`shorebird release android` /
`shorebird release ios`) so the binaries can receive OTA patches; shipping a
plain `flutter build` binary to the stores silently breaks code push. See
`docs/shorebird.md` for the release/patch workflow and CI wiring.

### Platform-Specific Setup
```bash
# Clean Flutter build cache
flutter clean

# Get all dependencies (iOS native plugins resolve via Swift Package Manager)
flutter pub get
```

## Architecture

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

Paths follow the existing feature. Do not add empty layers or pass-through
controllers to match a template. Retired bindings and page-service managers have
no replacement compatibility wrapper.

### State and dependency ownership

Use manual `Provider`, `NotifierProvider`, and `AsyncNotifierProvider` declarations.
Do not add generator annotations for providers. `build_runner` remains for JSON
models. State must be immutable, including nested collections received from JSON
or caller-owned lists. Publish a new state value after a change.

Widgets use `ref.watch` for rendered state and `ref.read(provider.notifier)` for
user actions. Select narrow values when a widget does not need the whole state.
Keep text controllers, focus, form keys, scroll controllers, animation, and local
visibility in the widget that owns them. Repositories receive their clients in
constructors; they do not find services, translate text, navigate, or show UI.

The root scope uses `noProviderRetry`. Network transport owns bounded safe read
retries. Mutations need an explicit server replay contract; provider retry must
not submit them again. Record a generation and account scope before asynchronous
work. Reject late results after input changes, account changes, or disposal.
Register timers, streams, clients, and database cleanup with `ref.onDispose` or
the owning widget's `dispose`. Inactive shell branches can remain mounted, so
visibility must stop GPS, prefetch, video, WebView work, and other active resources.

### Startup, session, and routing

`bootstrapAppCore` validates configuration, opens `AppDatabase`, and initializes
Supabase. A failed attempt closes its database and renders a retry screen. The
successful application's provider scope owns the database. Supabase owns credential
storage and token refresh; application tables never store access or refresh tokens.

`authProvider` is the single session owner. It exposes status, user, typed error,
resolving state, mutation state, and stale cached profile state. An offline profile
refresh can retain the matching account's cached profile. A transient missing auth
header must not force logout. Mandatory password setup cannot be skipped. Profile
completion Skip requires persisted purpose and defers completion only for that
account's current session.

`MaterialApp.router` reads `appRouterProvider`. The `StatefulShellRoute` has five
independent branches: Discover, Explore, Saved, Visits, Profile. Assistant has
labeled entries in Discover and Profile. Route declarations and names live in
`core/routes/app_pages.dart` and `app_routes.dart`. Pure `route_policy.dart` owns
redirects, safe intended destinations, public property links, and notification
route mapping. Deep links and notifications enter that same routing policy.

Use `context.push`, `context.go`, and `context.pop` in presentation code. Controllers
do not navigate. Do not add navigation recovery timers or imperatively force a
route from session callbacks. Keep passwords, OTPs, tokens, and user identifiers out
of route URLs and diagnostics. Account-keyed forms remount when the session changes.

### Property queries and durable mutations

`propertyFiltersProvider` owns device preferences. Purpose and property type apply
to all feeds; price, search, and other detailed filters belong to one feed.
`propertyLocationProvider(page)` owns the account-scoped selected area and GPS
lifecycle. `propertyQueryProvider(feed)` owns request identity, content, refresh,
cursor progression, and separate pagination failure. `swipeHistoryProvider` owns
the shared like/pass projection and pending operation review.

Refresh retains usable content. Pagination retry retains rows and scroll position.
Request identity includes account/environment, endpoint/feed, filters, search,
location, sort, limit, and cursor. Reject stale completions. Discover does not
restore a cached server deck that can reintroduce swiped cards.

Discover supports horizontal Like/Pass gestures, explicit accessible Like/Pass
buttons, and details navigation. Vertical card scrolling remains scrolling. There
is no swipe-up, double-tap, or super-like API. Swipe operations are written before
network submission. A pending action has a durable operation ID and visible retry
or discard state. Retry must refer to that same operation and reject superseded
intents.

Visit creation has no verified backend idempotency key or uniqueness contract.
A lost response is `needsReconciliation`, not proof that the booking failed. Do not
automatically replay the POST. Reconcile with authoritative GET results and keep
pending/failed/confirmed states distinct. See `docs/migration/visits.md`.

### Persistence and transport

One `AppDatabase` uses SQLite (`sqflite`) for JSON preferences, account/environment
cache rows, drafts, and actions. Await writes before claiming data is saved. Expose
storage failure and explicit retry separately from network failure. A scope lease
rejects prior account work, including an A → B → A transition.

The importer reads legacy `GetStorage.gs` / `GetStorage.bak` without modifying
those files. It transactionally imports allowed semantic preferences and
quarantines unowned actions. It does not import old property lists, cursors,
loading state, caches, or credentials. Runtime code does not use GetStorage.
See `docs/persistence.md` for schema, migration, retention, and recovery policy.

`core/network/api_client.dart` uses `package:http` and plain `ApiResponse`.
Providers inject auth headers, SQLite ETag storage, HTTP, and SSE clients. Account
changes cancel current work and block late cache writes. Cache clearing deletes
actual records. Booking POST is not marked idempotent.

`imageCacheServiceProvider` owns one image cache manager shared by displayed
images and prefetch. Widgets borrow it and never dispose the shared owner. The
cache has a 200-entry bound and 24-hour stale period; do not claim a byte quota or
fake cache statistics. Tests override it with `ImageTestCache`.

## Theme, localization, and recovery UI

The design system lives in `lib/core/design/`. Use `context.design` for adaptive
palette colors and `Theme.of(context).textTheme` for typography. `AppDesign` supplies
fixed tokens. Never look up theme through a controller or global service locator.
Check contrast in light and dark themes. Flutter owns system brightness changes.

`themeProvider` and `localizationProvider` persist settings through the database.
UI uses `context.l10n.text(key, params: ...)` from `AppLocalizations`. English and
Hindi share the same keys in `core/translations/app_messages.dart`. Add entries to
both maps and test narrow layouts and large text. Data and state layers expose
typed failures; the UI maps those to safe localized messages.

Use `AppToast` for brief top-of-screen feedback. `AppToastHost` owns its Flutter
overlay and timers. Important recoverable errors also need a persistent inline
message and retry control. Do not use a toast as the only record of an unresolved
booking, failed save, or failed page load.

```dart
final session = ref.watch(authProvider);
final label = context.l10n.text('retry');
final color = context.design.textPrimary;
// A user action calls the state owner; it does not find a global service.
await ref.read(authProvider.notifier).retryProfileLoad();
```

Loading placeholders must fit the eventual layout and respect reduced motion.
Retain content during refresh, form drafts during failure, and control dimensions
during submit. Use semantic labels for icon controls. Test 320-pixel width, 2x text,
keyboard insets, safe areas, both themes, and English/Hindi where relevant.

## Environment Configuration

### Environment Files
- **`.env.development` / `.env.production`**: Local-only (gitignored). **Never** package as Flutter assets.
- **Local debug:** `dart run tool/sync_dev_env.dart` then bare `flutter run` (debug map in `lib/core/config/dev_env.g.dart`; do not commit secrets).
- Or inject via `--dart-define` / `--dart-define-from-file` (`./tool/run_with_env.sh` or VS Code `flutterRunAdditionalArgs`).
- Runtime access: `AppConfig.instance` in `lib/core/config/app_config.dart`.

### Required Environment Variables
```bash
# Via dart-define / dart_defines.json (from local .env)
# API Configuration
API_BASE_URL=https://api.360ghar.com
API_TIMEOUT_SECONDS=15  # Optional: override HTTP client timeout

# Supabase Configuration
SUPABASE_URL=your_supabase_project_url_here
SUPABASE_PUBLISHABLE_KEY=your_supabase_publishable_key_here

# Google Places API Key
GOOGLE_PLACES_API_KEY=your_google_places_api_key_here

# App Configuration
DEFAULT_COUNTRY=in
DEBUG_MODE=true
LOG_API_CALLS=true
```

### Platform Support
- **iOS**: Minimum deployment target iOS 15.0
- **Android**: Minimum SDK version 21
- **Web**: Chrome support enabled

## Contributor rules

Keep changes scoped and remove obsolete paths when replacing an API. Do not keep
GetX wrappers, global service locators, parallel authoritative state, or duplicate
HTTP clients. Reuse focused providers and injected repositories. Add an abstraction
only when real call sites need it.

Use two-space indentation, `snake_case.dart` filenames, `UpperCamelCase` types,
and `lowerCamelCase` members. Follow `analysis_options.yaml`. Format the files you
change. Preserve other contributors' uncommitted edits, especially native signing,
release workflows, and Shorebird configuration.

Never log tokens, OAuth secrets, OTPs, passwords, raw profile data, exact coordinates,
or full auth/location URLs. Log safe failure categories and request stages. Never
send real bookings, account deletions, or production writes during verification.

## Testing

`test/` mirrors source features. Use a `ProviderContainer` for state tests and a
`ProviderScope` for widget tests. Override external boundaries: database, repository,
HTTP, native plugins, and image cache. Use `test/helpers/provider_test_app.dart`
for a localized Flutter shell with a test image cache and `AppToastHost`.
Use `test/helpers/auth_test_harness.dart` for session transitions and real SQLite;
feature harnesses provide narrower fixtures.

Preserve observable behavior when retiring architecture-specific tests. Replace
binding registration and mutable-field assertions with provider identity, immutable
state, disposal, and visible UI assertions. Do not suppress render errors or weaken
assertions to accept either success or failure. Tests for disk atomicity and restart
must use `sqflite_common_ffi`; a map fake does not prove durability.

Run focused tests after changes, then the required full suite and analyzer before
completion. Keep the CI coverage gate at 85%. Regenerate JSON files when models
change. Native OAuth, GPS, camera/gallery, maps, video, WebView, notification delivery,
and accessibility checks still require available native targets. Widget platform
fakes do not establish device behavior. Record any blocked native target explicitly.
See the migration checklist for full-suite, coverage, visual and native evidence,
plus remaining device and credential checks; do not infer completion from focused test counts.

## Build troubleshooting

### Model generation

Run `dart run build_runner build --delete-conflicting-outputs` after changing JSON
model structure. Do not hand-edit generated serializers.

### iOS Build Issues
- Ensure Xcode is updated to latest version
- iOS uses Swift Package Manager (no CocoaPods / Podfile). Run `flutter pub get` then
  `flutter build ios --config-only` if packages fail to resolve
- Check iOS deployment target in `ios/Runner.xcodeproj` (currently 15.0)
- **`flutter pub get` breaks Xcode builds.** It regenerates
  `ios/Flutter/ephemeral/.../FlutterGeneratedPluginSwiftPackage/Package.swift` with a
  hardcoded `.iOS("13.0")`, and the Firebase plugin packages require 15.0, so Xcode
  fails with *"requires minimum platform version 15.0 ... but this target supports
  13.0"*. Only `flutter build ios/ipa` raises it back to the project's 15.0. After any
  `flutter pub get` or `flutter clean`, run `./tool/verify_ios_release.sh --fix`
  (fastest, and it leaves `Generated.xcconfig` and your dart-defines alone) or
  `flutter build ios --config-only`, before building or archiving in Xcode.

### Android Build Issues
- Verify Android SDK and build tools are installed
- Check `android/app/build.gradle` for compatibility
- Ensure proper signing configuration

### Provider and lifecycle issues

Inspect the provider state and its scope overrides. Verify a current generation
and scope after every awaited boundary. Check that the owner disposes timers,
streams, media, and clients. An inactive tab can remain mounted. Do not fix a
lifecycle error with a delay, forced rebuild, global registration, or swallowed
exception.

## Key files

| Concern | Path |
| --- | --- |
| Application composition | `lib/main.dart`, `lib/core/bootstrap/` |
| Session and auth dependencies | `lib/core/controllers/auth_controller.dart`, `lib/core/providers/auth_providers.dart` |
| Router and policy | `lib/core/routes/app_pages.dart`, `lib/core/routes/route_policy.dart` |
| Data and caches | `lib/core/network/`, `lib/core/storage/` |
| Product state | `lib/features/properties/application/`, feature presentation controllers |
| Theme and messages | `lib/core/design/`, `lib/core/translations/` |
| Migration evidence | `docs/migration/riverpod-checklist.md`, `docs/persistence.md` |

Use available Dart/Flutter MCP tools when they provide the required operation.
The documented Flutter/Dart CLI commands remain the fallback.
