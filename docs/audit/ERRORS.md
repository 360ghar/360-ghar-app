# Full-platform audit error log

Date: 2026-08-01

## Final status

- `flutter analyze`: clean.
- Before this review: `flutter test` passed with **3736 tests, 2 skipped, 0 failed**.
- Review validation: focused tests passed, `flutter analyze` passed, and a clean full rerun passed with **3737 tests, 2 skipped, 0 failed**. An earlier rerun hit Flutter test-runner temporary-file/sink cleanup errors after 3618 tests; the clean rerun resolved that environment issue.
- The two skips are existing platform/environment-specific tests.

## Resolved during this audit

- Concurrent discover swipes could lose failure feedback or restore stale card state. Pending swipe tracking and user-visible failure handling were made deterministic.
- Likes optimistic favorite updates could race, duplicate taps, or render stale state. Requests are guarded and cards show authoritative loading/state.
- Explore initialization, location updates, map overlays, and optimistic likes could be overwritten by stale async results. Generation/lifecycle guards were added.
- Visits allowed duplicate or invalid/past booking/rescheduling attempts and action layouts could overflow. Validation, retryability, and responsive action layout were improved.
- Tour/media navigation accepted unsafe or invalid URLs. HTTP(S) validation and shared `TourUrl` validation are now used.
- Assistant conversation loads and SSE callbacks could update stale conversations, and malformed payloads could crash parsing. Stream cancellation, generation guards, and defensive parsing were added.
- Profile preference saves could overlap and local persistence was not awaited. Saving state, duplicate-save protection, and awaited writes were added.
- Auth provider-only sign-in could retain a stale identifier hint. The hint is cleared when no identifier is available.
- OTP resend timer state could remain stale after reaching zero. Timer cleanup and immediate resend readiness were fixed.
- Tool calculators accepted non-finite/invalid values in multiple paths. Input and result validation was hardened.
- Response parser lost object identity for unwrapped payloads. Existing object values are now preserved.
- Error-mapper tests were stale after JSON response parsing became supported; expectations now verify parsed messages and field errors.

## Non-errors observed

- Error logs emitted by tests intentionally exercise failure paths and are expected.
- Google Fonts warnings in widget tests are test-environment asset warnings; tests still pass.
- Tour WebView timeout/channel warnings are expected in fake WebView tests.

## Remaining product-risk notes

- Backend-dependent authentication, notifications, maps, OAuth, and WebView behavior still require device/staging validation.
- The audit did not commit or clean the working tree. Pre-existing user changes remain mixed with audit changes by design.
