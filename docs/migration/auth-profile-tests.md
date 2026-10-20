# Auth, profile, settings, and shared test migration

The tests now use manual Riverpod providers, a Flutter localization shell, and
injected data/native boundaries. `AppTranslations`, `GetxTestBinding`, and the
GetX lifecycle mock are removed. Their import inventory was empty before removal.
The shared image cache override avoids platform disk/network access unless a test
explicitly supplies another cache.

## Behavior mapping

| Former assertion or capability | Current regression |
| --- | --- |
| Auth controller lifecycle and mutable status | `core/controllers/auth_controller_test.dart`: one SDK session stream; immutable status/user/error; cached offline profile; password/profile gates; account generation rejection; disposal; logout |
| Login, signup, OTP, recovery, native OAuth, profile Skip | Auth form provider and view tests retain validation, loading, cooldown, resend, identifier masking, input retention, and callback behavior. Skip first opens purpose choice without requiring optional personal details; Skip/Continue then saves the selected purpose before account-session deferral. It does not submit an empty profile. Mandatory password setup remains required. Native services are injected; device acceptance stays open. |
| Global theme/locale and Get-driven mixin | Theme/localization provider tests cover persisted state, invalid data defaults, write failure/retry, locale normalization, and system theme. `core/mixins/theme_mixin_test.dart` exercises real context-based Profile components. |
| Profile controller wrapper and binding | Profile reads `authProvider` directly. Profile view tests verify displayed user data, settings/navigation, labeled Assistant access, logout confirmation, and safe failure state. No second authoritative user state exists. |
| Profile/avatar mutations | Edit-profile tests cover local form drafts, date validation, picture selection/upload, failure retention, submitted fields, success navigation, account/disposal guards, and cached session-profile replacement. |
| Password and delete account | Change-password tests cover email/phone verification, wrong password versus offline failure, mismatch, and mutation failure. Privacy view tests cover local password fields and explicit DELETE confirmation/cancel/failure. |
| Feedback and policy pages | Feedback tests cover type/severity, required fields, metadata/tags, full submitted draft, duplicate prevention, account/disposal guard, inline retry, and stable submit dimensions. Policy tests cover loading, markdown, failure retry, supported link schemes, and route title. Help/About retain contact, policy, and package-version behavior. |
| Get route registration and auth middleware | Actual GoRouter registrations and pure `authRedirect` tests cover public/protected routes, onboarding, mandatory gates, intended destination, malformed/unsafe returns, and loop prevention. Repository tests prove container-scoped identity and shared queue injection. |
| PageFilterManager delegation | `page_filter_manager_test.dart` covers normalized global purpose/types, page-only price/search, reset one/all, legacy/new hydration precedence, malformed page isolation, immutable lists, ordered writes, storage failure/retry, and real SQLite restoration. Widget tests own text controllers; query tests own debounce/request invalidation. |
| PageLocationManager geocode/listener/delegation | `location_source_test.dart` covers permission, GPS/IP fallback, geocode formatting/failure/throttle. `location_providers_test.dart` covers visibility, streams, stale requests, manual selection, failure/retry, account switch, and disposal. `page_location_manager_test.dart` adds real SQLite page/account isolation, hydration without GPS, valid coordinates, and GPS-only backend metadata sync. |
| Critical flow using fake ports and queue | `integration/critical_flow_test.dart` uses a real provider session, actual property/swipe repositories, and real SQLite. It checks confirmed discovery → swipe → booking, durable offline swipe ownership through logout/A-B-A, and ambiguous booking reconciliation without a second POST. |
| Push route side effects and weak init assertions | Push tests assert emitted payloads and safe destination policy. Lifecycle tests prove initialization coalescing, stream cancellation, exact initial-message dispatch, stale token rejection, and ownership across interrupted initialization. Firebase init now runs instead of being skipped and checks consent plus idempotence. |
| Shared UI and model assertions | Error/loading/animation/layout/property-feature tests use Flutter localization. Error text is sanitized rather than raw exceptions. `UserModel` copies nested map/list inputs and exposes unmodifiable collections; serializer/copy behavior remains covered. |

Only assertions tied to retired architecture were removed: global registration,
Rx wrappers, pass-through methods, and duplicate no-op checks. Observable validation,
state, persistence, navigation, and failure behavior remains covered at its current
owner. Layout/paint failures are not suppressed.

## Evidence and limits

Focused auth/profile tests previously passed as a 502-test batch; a later storage
failure regression also passed. Fresh shared batches are recorded in the main
[migration checklist](riverpod-checklist.md). Test counts overlap and are not a
full-suite count.

Profile screens have narrow-width, 2x-text, keyboard, and light/dark widget checks.
Real OAuth, notification delivery, camera/gallery permission, voice accessibility,
and installed-release storage upgrade still need native acceptance. Neither
mocked native contracts nor focused test counts establish final coverage or
performance improvement.

The [routing recovery audit](routing-recovery.md) adds actual-router regressions
for public tours, intended destinations, cold/warm link races, foreground visibility,
and account changes while forms or privacy dialogs are open.
