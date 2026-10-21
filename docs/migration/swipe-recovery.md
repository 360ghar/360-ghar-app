# Swipe recovery and query membership

`SwipeHistory.retryPending(PendingAction)` and `discardPending(PendingAction)` return `Future<bool>`. The immutable `pendingOperations` map exposes each operation's loading, success, or typed error state. Retries require user input; connectivity and startup do not replay requests.

Every swipe intent is saved before its POST. Its stable operation ID, account scope, creation order, attempts, and status remain in SQLite. The newest same-property operation owns retry eligibility, including a crash before older records are marked superseded. Confirmation updates that same operation. A storage failure while saving an ambiguous response keeps its existing pending operation. A failed insert prevents the POST.

Duplicate retry taps share one Future. A retry and a newer same-property action run in order. Provider revision and account-generation checks prevent an old completion from replacing a newer intent, including A → B → A account changes. A failed latest action can be retried after the UI has rolled back to an older summary. A confirmed durable receipt repairs an older pending summary during hydration.

Discard saves the unresolved exclusion before deleting the operation. It does not claim that the server reversed the swipe. Unresolved discarded IDs are stored separately from the bounded recent summaries, so later swipes cannot evict that protection. A draft or delete failure keeps the action available for retry. Discarding an older superseded action does not change a newer restored card.

## Query membership

`PropertyPageState.inputIdentity` records the canonical filter and location inputs that produced a server page. `propertyQueryInputProvider` exposes the current identity without starting a feed request. Swipe entries capture identities only from existing authoritative pages that contain the property.

Discover undo cards appear only under the original Discover inputs. Saved optimistic additions require a known matching input identity. Search, price, type, or location changes therefore cannot inject an unrelated property. Unknown membership waits for a server response. Existing server rows still obey the latest local Like/Pass intent. Confirmed mutations revalidate existing history feeds without creating hidden feeds or replacing newer optimistic intent.

## Verification

`swipe_recovery_test.dart` covers filter and location changes, restart, known and unknown membership, existing-feed refresh, duplicate recovery taps, pending undo, failed latest intent, operation ordering, interrupted-summary recovery, failed discard writes, superseded discard, account changes, and receipt hydration. `swipes_repository_test.dart` uses real SQLite plus a fake transport to verify durability before POST, stable retries, no automatic retries, malformed history failures, latest-created ordering, and storage failures.

Existing query, cache, pagination, and shared projection tests remain in the focused run. One legacy optimistic-insertion fixture now first supplies an authoritative source page; it keeps the same expected result while satisfying the new membership requirement. See `property-query-tests.md` for the old-to-new behavior mapping.

Final focused validation: **127 tests passed** across recovery, repository, property providers, PageDataLoader, PageStateService, and migration regressions. Analyzer: **no issues** across the seven modified source and test targets. Logs: `/tmp/swipe-final-tests.log` and `/tmp/swipe-final-analyze.log`. Tests use local SQLite and injected transports; no production requests.

## Recovery UI evidence

`saved_actions_button_test.dart` uses the real queue, scoped SQLite, and SwipeHistory provider. It verifies pending/failed/superseded controls; excludes visit and confirmed records; coalesces busy retries; preserves unresolved intent on retry/discard failures; removes confirmed/discarded rows; keeps actions accessible when queue reload fails; and clears an open sheet immediately on account change before a blocked new-account read finishes. A late old-account retry cannot return a row to the sheet. Light and dark Hindi layouts at 320px and 2x text keep controls scrollable and at least 48px high.

`property_recovery_banner_test.dart` verifies filter-before-ledger-before-page recovery, visible content during recovery, duplicate-tap protection, failed retry recovery, page refresh guards, stale cache announcements, safe error text, disposal while a retry is pending, and light/dark Hindi 320px 2x text. Filter retry now enters AsyncLoading before either storage result. The widget retains its recovery surface until the pending operation finishes.

UI validation: **40 tests passed** (22 new recovery UI/provider tests plus 18 migrated filter-provider cases), `/tmp/saved-ui-verified.log`. Six edited source/test targets have no analyzer issues, `/tmp/saved-recovery-ui-analyze-final.log`.
