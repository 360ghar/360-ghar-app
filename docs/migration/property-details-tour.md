# Property details and tour migration

## State and data ownership

`PropertyDetailsView(propertyId:, initialProperty:)` accepts a typed route ID and an optional summary. `propertyDetailsProvider(id)` owns the current account's authoritative listing. It always fetches details; a same-ID summary is only a temporary view seed. A summary from a previous account lease is removed immediately. SQLite caches use the captured environment/account lease and `property:<id>` key, with five-minute freshness and seven-day retention.

Refresh keeps existing detail visible. A failed refresh reports a typed, localized failure with retry and a stale indicator. A missing listing removes its cached detail and booking action. Wrong-ID responses are malformed failures. Generation checks reject results after disposal or A → B → A transitions. Scoped cache eviction cannot remove a current account's data through an old lease.

Favourite actions use `swipeHistoryProvider`; booking uses `visitsProvider` and the durable pending-action contract in [visits.md](visits.md). Guest actions preserve the public listing URL through sign-in. Scroll position, selected section, description expansion, and media controls belong to widgets. No GetX controller, binding, locator, route argument lookup, reactive wrapper, translation, or theme lookup remains in these features.

## Media ownership

`TourView(url:, title:)` validates its typed URL. `TourWebView` owns native configuration, load timers, error/retry state, and generation guards. Configuration failures are caught asynchronously. Old URL callbacks cannot change the replacement page. Widget removal cancels timers and sends `window.stop()`; the platform view is released by Flutter. Background/inactive views request media pause. Optional page chrome changes do not reload the tour. Existing Kuula iframe handshake, load deadlines, late-load recovery, safe navigation, and subresource handling remain covered.

Video controllers are created only when the video sheet opens. A 20-second load deadline reports a localized retry. Closing the sheet cancels the deadline and releases an initialized or initializing native player exactly once. Background and hidden views request pause. External launch failures use a static localized message; raw exceptions, property URLs, response bodies, and titles are not logged by these paths.

## Verification

The focused regression set covers SQLite/provider state, account switching, stale cache, authoritative replacement, shared favourites, booking entry, media, widget sections, theme/language, and native platform fakes. Existing iframe handshake/navigation/error tests were retained. Obsolete GetX argument/binding cases were replaced with typed-route/provider cases. Tests no longer suppress RenderFlex or paint assertions.

Phone 390×844 and tablet 1400×900 detail layouts pass at 200% text size. Info/pricing rows now wrap both columns. Amenities use flexible-height tiles. Hindi/dark detail controls, narrow Hindi invalid-tour UI, and large-text small embedded tour errors are tested.

Evidence logs:
- `/tmp/details-combined-tests.log`: 185 tests passed before the two additional async WebView/accessibility regressions and helper test migration.
- `/tmp/tour-final-tests.log`: 105 tour, WebView, and helper tests passed after those additions.
- `/tmp/details-final-tests.log`: final combined 204 tests passed. `/tmp/details-final-analyze.log`: 13 source/test targets, no issues.

## Remaining device verification

Platform fakes verify lifetime calls and state changes. They do not establish native renderer memory release, background behavior inside cross-origin iframes, actual video playback, external map/share application behavior, or TalkBack/VoiceOver output. Those require the final Android/iOS acceptance run. No production API, booking, account, deployment, or release was used for this migration.
