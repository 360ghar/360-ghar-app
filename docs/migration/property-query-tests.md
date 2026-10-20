# Page-state test migration

The former `PageDataLoader` and `PageStateService` tests now exercise public Riverpod providers with injected repository ports and real SQLite. Test files retain their old paths so existing test commands continue to work. Shared fixtures are in `test/helpers/property_query_test_support.dart`. No tests wait for GetX lifecycle setup, bypass UI assertions, or access production services.

## Behavior mapping

| Former group | Current regression coverage |
| --- | --- |
| Foreground loading and endpoint dispatch | `page_data_loader_test.dart`: all four feeds, page size, coordinates, Discover exclusion/cache policy, immutable rows, initial/empty/failure phases |
| Cached data and forced/background refresh | Same file: retained refresh content, completion timing, fresh cache revalidation, stale fallback, expiry, corrupt JSON, disk read/write failure, recovery, 200-row cache bound |
| Request guards and stale generations | Same file: duplicate normal loads, forced refresh superseding old success/failure, filter/location invalidation, A → B → A, disposal and debounce cancellation |
| Pagination and aliases | Same file: Explore/liked/passed append order, overlap dedupe, short or empty first page, empty terminal cursor, cursor cycle, explicit retry, no request while busy, stale pagination after refresh |
| Filter/search delegates | `page_state_service_test.dart`: shared normalized purpose/types, page-specific price/radius/search, reset one/all, Discover search exclusion, clear persistence, ordered saves, disk failure and retry |
| Page initialization and session clearing | Query state and filter tests cover initial immutable state; account transition clears query and swipe data synchronously while device preferences remain. `page_state_model_test.dart` retains model serialization/copy/reset tests. |
| Record swipe, liked/passed list mutations and server merges | `page_state_service_test.dart` shared projection group: explicit supplied property, missing server item, opposite local intent, server catch-up dedupe, feed independence. `property_providers_test.dart`: concurrent properties, per-property order, isolated rollback. |
| Discover removal, reinsert and undo | Shared projection group: exclusion, refresh after undo, one-use undo, failed undo, scoped restart, no deck hydration. `property_providers_test.dart`: swiped card exclusion across refresh and undo. |
| Clear session during swipe/network work | Query and projection groups reject old response/mutation after account transition. Existing provider test also verifies disposal while network work is pending. |
| Legacy transient-field reset and semantic preferences | `page_state_service_migration_test.dart`: real import strips loading flags, rows, cursors, errors, timestamps and view visibility; preserves normalized filters, manual location preference, search, and liked/passed preference; handles one corrupt page. |
| Page selection, search field controller, search visibility and thin aliases | These have no shared data-service owner now. Router and feature widgets own navigation, selected segment, text controllers and visibility; their feature/widget tests cover interaction. Removed method-forwarding and GetX registration assertions do not correspond to current runtime behavior. |

Fresh cached Explore/history data is shown immediately and revalidated. This intentionally replaces the former fresh-cache no-op assertion; the cache no longer suppresses server refresh indefinitely. Discover does not store a deck snapshot. A new generation supersedes an old refresh instead of queuing a second controller-level refresh.

## Defects found and fixed

`PropertyFiltersState` wrapped only its page map. Caller-owned amenities/features/property-ID lists could change current state and queued writes without a provider update; rehydrated lists were also mutable. The state constructor now takes immutable list copies. Both build and update paths use that boundary. Regressions fail on the old implementation and pass with the change.

The legacy importer retained `explore_state.searchQuery`, but `PropertyFilters.build` read only the embedded filters. The provider now restores a legacy search only when no modern snapshot exists for that page. Resetting or clearing modern state cannot resurrect the legacy value.

No change to `property_queries.dart` or `swipe_history.dart` was needed for these regressions.

## Evidence

- `/tmp/filter-immutability-before.log`: confirmed failures for externally mutated and rehydrated lists.
- `/tmp/page-provider-first.log`: confirmed missing legacy search.
- `/tmp/page-provider-third.log`: 78 tests passed across the three migrated files and existing shared property provider suite.
- `/tmp/page-provider-analyze.log`: focused static analysis.
