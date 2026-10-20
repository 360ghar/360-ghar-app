# Staff review: 360Ghar app

Scope: the Flutter app (`360-ghar-app`) and its contract with `360ghar-backend`, reviewed during the
Paper Cut Diorama redesign (September 2026). Items are ranked by user impact. Each item is marked
**done** (fixed in this work) or **proposed** (needs a decision or is out of scope).
The API items are detailed in [api-contract.md](api-contract.md).

## Ranked findings

| # | Area | Finding | Status |
|---|---|---|---|
| 1 | Profile | Profile load threw a `TypeError` for any user who saved notification settings on the website: `notification_settings` holds strings and objects, and the app cast every value to `bool` (gap M1). The user could not open Profile at all. | **done**: the app no longer parses the field on the user; contract test with a mixed-type fixture. |
| 2 | Privacy | Owner phone numbers reached the app through `GET /swipes` and the property nested in each visit; visits also carried the full counterparty user (M7). | **done** (backend): masking on `/swipes` and on every visit response, 11 tests. `GET /agents/{id}/visits` is still unmasked: **proposed**. |
| 3 | Settings | Notification toggles were sent to `PUT /users/preferences`, which drops them, and the UI said "saved" (M2). | **done**: read-merge-write on `/users/notification-settings`. |
| 4 | Property media | Every image fell into the gallery and floor plans never showed: the app read `category`/`is_main`, the backend sends `image_category`/`is_main_image` (gap 1). | **done** |
| 5 | Filters | Several amenity filters matched nothing because the hardcoded names differ from backend titles (M3). | **done**: the list comes from `GET /amenities`, cached in SQLite. |
| 6 | Errors | The app ignored error bodies and `Retry-After`: a 429 showed "something went wrong" with no retry, and a 503 with `Retry-After: 30` was retried after 250 ms (M4, R3). The backend also dropped `Retry-After` on route-level 429s (R1). | **done**: typed failures (`RateLimitException`, `ValidationException.fieldErrors`, backend codes), countdown before retry, backoff that respects the header; backend passes `exc.headers`. The 401/403 handlers still drop headers: **proposed**. |
| 7 | Permissions | Push permission was requested on the first frame, over onboarding. Location permission was requested by automatic loads with no context. | **done**: push asks on the first shell route; automatic loads never prompt (IP fallback); a location explainer comes before the OS prompt. |
| 8 | Visible content | `ScrollRevealWidget` started 8 property-detail sections at opacity 0 and ignored reduced motion, so sections could stay invisible. | **done**: deleted; all content is visible without animation. |
| 9 | Visits | "No agent assigned" (404 from `/agents/assigned`) showed an error with retry (M5). A visit with no nested property showed a placeholder built from dead fields. | **done**: quiet "no agent yet" line; localized "Property #id" fallback. |
| 10 | Assistant | Only the newest 100 messages could ever load (bare list, no cursor); the history sheet reloaded from scratch on every open; the SSE `fallback` event was dropped, so a failed partial reply and the fallback model's reply ran together (6a, 6b, M8). Retry after a failed reply resent the prompt even when a tool (for example a booking) had already run. | **done**: backend keyset route `…/messages/page` (uncommitted in the backend; the app falls back to the bare list on 404); older pages on scroll; first page of history cached; `fallback` clears the partial reply; no one-tap resend after a tool ran. |
| 11 | Caching | `useCache: true` did nothing: the backend never sent an `ETag` (gap 7). | **done** (backend): weak ETag + 304 middleware, 13 tests. `ETag` is missing from CORS `expose_headers`, so the web build cannot use it: **proposed**. |
| 12 | Rebuilds | `DiscoverView` and `ExploreView` watched whole provider states, so every card swipe or camera move rebuilt the screen. | **done**: small consumers with `select`. Numbers below. |
| 13 | Images | The next Discover cards decoded only when shown, so a fast swipe showed a blank photo. | **done**: the next two hero images are precached with the same `ResizeImage` size the card uses (a mismatched size would decode twice). |
| 14 | Offline | `connectivity_plus` was a dependency but never used; offline showed generic errors. | **done**: one offline banner above the router; content stays on screen. |
| 15 | Config | `API_TIMEOUT_SECONDS` was documented but never read (R2). | **done**: read by `AppConfig`, bounded 5 to 60 s. |
| 16 | Dead code | Unused API paths and methods, a dead datasource, unused widgets and helpers. | **done**: see [Deleted](#deleted). |
| 17 | Bookings | `POST /visits` has no idempotency key; a replay after a lost response returns 409 (gap 8). The app never replays it and reconciles with `GET /visits`. | **proposed**: `Idempotency-Key` header on the backend. |
| 18 | Paging | Offset cursors on properties, swipes and conversations drift when rows change, so a page can skip or repeat rows (M10). The app dedupes by id. | **proposed**: keyset cursors, as done for messages. |
| 19 | Streaming | SSE has no 401 refresh-and-retry and no idle timeout after headers (M8). | **proposed** |
| 20 | Swipes | Pending swipes retry only when the user taps retry; reconnect does not retry them. | **proposed**: retry on the offline banner's reconnect edge. |
| 21 | CI | CI pins Flutter 3.44.6; local development uses 3.47.4. The goldens were generated on macOS and CI runs them on Ubuntu, where font rasterization differs. | **proposed**: pin one version everywhere, and generate goldens on the CI image (or give golden tests a Linux-only tag). |
| 22 | Hindi | Area, floor, age and distance on the cards and details were built in English by model getters ("1450 sq ft", "Floor 3 of 12"), so a Hindi reader saw English facts. An unknown address showed the English "Unknown Location". The Explore radius read "10.0 km". | **done**: `property_labels.dart` builds each fact from the message catalogue with en_IN grouping ("1,450 sq ft"); an unknown address is hidden; the radius drops a trailing ".0". The English getters are deleted. Two getters mapped the type to message keys; the one used on screen fell back to a lowercase "property", so it is deleted and all five callers use `propertyTypeLabelKey`. |
| 23 | Memory | The onboarding diorama baked 25 layer images, about 60 MB on a 3x phone. | **done**: consecutive layers with the same depth and page are baked together: 11 images, 24 to 29 MB. |
| 24 | Web | Device-token registration read `Platform.localeName` (dart:io), which throws on web, so web registration always failed. | **done**: the locale comes from `PlatformDispatcher`. |
| 25 | Web | The web build compiles, but start-up stops at "Local storage is unavailable": `AppDatabase` uses `sqflite`, which has no web backend. | **done** (approved): `sqflite_common_ffi_web`; SQLite runs as wasm and keeps data across reloads. The image cache keeps its index in memory on web (its JSON index needs `path_provider`). |
| 25a | Web | Assistant replies streamed through `dart:io` `HttpClient`, which throws on web. | **done**: the SSE client uses `package:http`, which streams through `fetch` on web. |
| 25b | Web | The app sends `If-None-Match`, which is not in the backend's CORS `allow_headers`. Today web never has an ETag (the header is not exposed), so nothing fails. | **proposed**: add `If-None-Match` to `allow_headers` together with `ETag` in `expose_headers`. |
| 25c | Images | The app loads Cloudinary originals with no size transform. | **proposed**: request a width-bound variant (`w_…,f_auto,q_auto`). |
| 26 | Backend docs | `docs/openapi.json` is out of date (no `PropertyAgent`, no `/leads`); the route baseline test fails on `/leads`; a property-detail stub test fails. Both failures predate this work. | **proposed** |

## Rebuild measurements

Measured with `test/performance/rebuild_counts_test.dart`, which counts dirty-widget rebuilds with
`debugOnRebuildDirtyWidget`. The fake repository hides a swiped card, as the real one does.

| Scenario | Before | After |
|---|---|---|
| Discover, 5 swipes: dirty builds | 1670 | 1020 |
| Discover, 5 swipes: `DiscoverView` rebuilds | 5 | 0 |
| Explore, 5 camera moves: dirty builds | 1475 | 52 |
| Explore, 5 camera moves: `ExploreView` rebuilds | 5 | 0 |
| Explore, 5 card highlights: dirty builds | 2459 | 344 |
| Explore, 5 card highlights: `PropertyHorizontalList` rebuilds | 5 | 0 |

## Deleted

- API: `ApiPaths.visitById`, `visitsUpcoming`, `visitsPast`, `upload`, `swipesHistory`;
  `SwipesRemoteDatasource`; `getPropertiesByIds` / `fetchPropertiesByIds`; `createProperty`,
  `updateProperty`, `updatePropertyMedia`; `PropertyMediaPayload`.
- Model fields the backend never sends: `filters_applied`, `search_center` (`SearchCenter`),
  `preferred_locations`, `fcmToken`, `notification_settings` on the user, `is_main`, `property_title`,
  `agent_name`, `visit_date`/`visit_time` fallback.
- Widgets and helpers: `ScrollRevealWidget`, `FrostedGlassContainer`, `AnimatedIconButton`,
  `ShakeWidget`, `PaginatedScrollMixin`, `EmbeddedSwipe360Tour`, the `withUnifiedTopBar` extension,
  `ErrorMapper`, `ErrorHandler`, `PasswordValidators`, `NotModifiedException`, `AppDesignOpacity`,
  `LoginStep`, `combineUtcDateAndTime`, `Motion`, unused `LoadingStates` and `ErrorStates` helpers,
  `visits_skeleton_loaders.dart`, `property_details_features.dart`, the property-details section
  header, the `PropertyFilterWidget` class, `PreferenceSync` and its `main.dart` override.
- Model getters that built English text: `areaText`, `floorText`, `ageText`, `distanceText`,
  `imageDescription`, `propertyTypeString`, `purposeString`, `titleInitials`, and the duplicate
  `propertyTypeTranslationKey`.
- Models: `AmenityModel` / `PropertyAmenityModel` / `PropertyAmenityResponse` (the app uses
  `PropertyAmenity`), and the unused `ErrorResponse`, `NotificationSettings`, `PrivacySettings`,
  `LocationUpdate` response models.
- Tokens: the unused semantic spacing, radius and duration tokens (including the 999 px pill radius).
- Messages: 334 keys with no use in the app, from both the English and the Hindi catalogue.
- Dependency: `flutter_staggered_grid_view` (Saved is a list now).
- Assets: the three onboarding JPGs, `auth_hero.jpg`, the Sora font.
