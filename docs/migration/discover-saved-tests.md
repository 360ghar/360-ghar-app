# Discover and Saved test migration

These tests use Riverpod overrides, real SQLite, and injected repository ports.
They preserve the observable behavior of the former controller/view tests at its
current owner. They do not exercise GetX registration, mutable Rx wrappers, or
navigation side effects from a controller.

| Former behavior | Current regression |
| --- | --- |
| Initial deck, current/next cards, counts and loading/error/empty state | Discover provider tests assert session counts and real query transitions; Discover view and swipe-stack tests assert the visible deck, previews, loading skeleton, error/retry and empty actions. There is no second mutable current-index state. |
| Like/Pass, duplicate gestures, concurrent completion and rollback | Discover controller tests exercise both actions, missing/repeated cards, out-of-order responses, persistence failure, safe rollback and account/disposal rejection. Shared swipe-provider tests cover superseded intent and durable operation ownership. |
| Last-card and low-deck prefetch | Discover tests verify one next-page request at both thresholds, exhausted results, failed prefetch with retained cursor, retry and no restored already-swiped cards after refresh. |
| Filter shortcuts and activation | Controller tests cover canonical purpose/type scope. Location-provider and application-effects tests own GPS/foreground lifecycle. Query tests own cache freshness, forced refresh and stale-response rejection. |
| Saved selection, search, refresh and pagination | Likes controller tests cover both endpoints, same-segment selection, independent search, clear, persistence failure, retained refresh rows, next cursor, legacy segment and account reset. |
| Favorite projection before opening Saved; move/remove rollback | Likes controller tests exercise model-seeded state, supplied property, duplicate submit, successful mutation, rollback and newer local intent versus stale server lists. |
| Display strings and notification feedback | Actual localized views assert Liked/Passed/search, first load, empty, stale, partial failure, retry and sanitized mutation feedback. Text rendering belongs to Flutter localization. |
| Navigation and accessible controls | Actual GoRouter widget harness checks numeric property destinations and the labeled Assistant entry. Explicit Like/Pass buttons use the same ledger as horizontal gestures. Existing card/stack gesture contracts remain tested, including vertical scrolling, gallery taps and embedded-tour interaction. |
| Dependency bindings | Container-isolation tests verify independent state and disposal without a global registry. Repositories and query owners are injected. |

The focused Discover/Saved batch passed 139 tests before the final combined suite.
Layout checks cover 320px, 390px and tablet width, Hindi at 2x text, and both themes.
Paint/layout exceptions are not suppressed. Real-font screen captures are separate
from native map, authentication and media verification.
