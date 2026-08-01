# 360Ghar UX and reliability audit

Date: 2026-08-01

## Scope

The audit covered the full Flutter app surface: 243 Dart source files, 21 feature groups, shared infrastructure, routes, data services, and the existing 83-story feature tracker. Parallel agents reviewed splash/auth, discover/likes, explore/location, visits, property details/tours, assistant, profile/settings, tools, shared UI, core state, network/data services, and notifications/dashboard.

## Verification gate

- Baseline: `flutter analyze` clean; full test suite passed with 3729 tests and 2 skips.
- Final before this review: `flutter analyze` clean; `flutter test` passed with **3736 tests, 2 skips, 0 failures**.
- Post-review: focused tests passed, `flutter analyze` remained clean, and the full suite passed with **3737 tests, 2 skips, 0 failures**.
- Tests added or strengthened for async races, optimistic updates, malformed payloads, timer cleanup, preference save state, and input validation.

## User-story coverage

`docs/feature_tracker.csv` remains the canonical story inventory. The audit agents reviewed the stories for every feature group and validated behavior through existing unit/widget tests plus targeted regression tests. The tracker contains the expected behavior and edge cases; feature-specific fixes are recorded in the changed tests and the error log.

## Main improvements

### Discovery and likes

- Concurrent swipe persistence now keeps failure feedback visible without reviving stale cards.
- Optimistic likes are protected from duplicate taps and stale request failures.
- Card state reflects controller authority and displays update progress.

### Explore and location

- Stale location/initialization requests cannot overwrite newer state.
- Map listeners and overlay projection are disposed and serialized safely.
- Optimistic marker/card updates reconcile correctly after failures.

### Visits

- Duplicate, past, malformed, and invalid booking/rescheduling inputs are rejected.
- Failed initial loads remain retryable instead of trapping the page in a skeleton state.
- Visit actions wrap responsively rather than overflowing on narrow screens.

### Property details and tours

- Tour, video, Street View, and external media launches accept only safe HTTP(S) URLs.
- Invalid media routes fall back safely and remain retry/share capable.

### Assistant

- Conversation switches cancel stale streams and stale loads.
- Transport failures are surfaced instead of silently disappearing.
- Mixed and malformed API payloads are parsed defensively.
- Input is disabled while streaming and keyboard submit is supported.

### Profile and preferences

- Preference saves have explicit loading state and duplicate-save protection.
- Local writes are awaited before reporting success.
- Auth-provider-only sign-in no longer leaves stale identifier hints.

### Tools

- Calculator inputs and computed results reject non-finite, negative, or invalid values.
- Unit/clear behavior is consistent across conversion tools.

### Shared infrastructure

- Response parsing preserves object identity for already-unwrapped maps.
- Network/auth and async lifecycle paths were hardened by the core agents.
- Shared loading/error, dark-theme, responsive, and accessibility surfaces were reviewed.

## De-slop decisions

The aggressive pass removed or simplified only code paths proven redundant by references and tests. The audit favored small, reversible in-place changes over speculative rewrites of the large state/network services. Further consolidation of `PageStateService` and offline infrastructure remains a candidate for a dedicated migration because those services are cross-feature contracts and require staging validation beyond widget tests.

## Remaining risks

- OAuth, push notifications, map SDKs, GPS permissions, backend pagination, and real WebView handshakes need device/staging validation.
- The working tree intentionally contains existing user changes plus audit changes. No commits, resets, cleanup, or destructive Git operations were performed.
- Test logs contain expected error-path logging and fake-WebView timeout warnings; they do not represent failed tests.
