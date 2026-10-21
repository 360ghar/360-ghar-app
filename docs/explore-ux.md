# Explore and Saved UX

This page describes the Explore map, the Saved list, the shared property row, the filter sheet, and the location picker. The visual rules come from `docs/design-system.md`.

## Explore

### Layout

| Window width | Layout |
| --- | --- |
| Below 840 px | The map fills the body. A paper sheet with a strip of homes sits over the bottom of the map. A tap on a home pushes the details route. |
| 840 px and wider | The left pane is the map and the strip, as on a phone. The right pane (420 px) shows the open home in `PropertyDetailsView(embedded: true)`. With no home open, the pane shows `ErrorStates.emptyState(seed: 'pane')`. A tap on a home opens it in the pane and does not push a route. |

The rail starts at 600 px (see `DashboardView`). A portrait tablet at 834 px has the rail and one pane.

### Chrome over the map

The controls over the map are paper chrome. Each one is a `PaperSheet` with a cut edge and a low shadow.

| Part | Content |
| --- | --- |
| Map controls (top right) | Zoom in, zoom out, my location (`KnifeIcon.locate`, teal accent), show all homes (`KnifeIcon.map`). Bare icons, 48 px targets. |
| Radius note (top left) | The search radius, for example `10 km radius`. |
| Loading more | A small slip with `LoadingStates.buttonSpinner` and "Loading more properties...". It sits above the list sheet. |
| Empty area | A slip in the middle of the map with the `explore` empty scene and one action, Adjust Filters. The map stays usable around it. |

### List sheet

- The sheet uses `CutBorder(seed: 'explore-list')`. Its sides and bottom sit 4 px past the screen edges, so only the cut top edge shows.
- The handle row shows the count (`2 properties`) and a chevron. There is no drag bar.
- Tap the handle to fold or unfold the sheet. Swipe up to unfold. Swipe down to fold.
- A fold or unfold takes 300 ms (`AppDurations.normal`, `AppCurves.standard`). With reduced motion it is immediate.
- The strip scrolls sideways. Each card is 260 px wide. The card photo takes the height that the words leave, so 2x text does not overflow.

### Map and list sync

| Action | Result |
| --- | --- |
| Scroll the strip | After 80 ms the card nearest the start becomes the highlighted home. Its marker turns marigold. The camera does not move. |
| Tap a marker | The marker turns marigold, the sheet unfolds, and the strip scrolls the card to the middle (300 ms, or at once with reduced motion). A selection haptic plays. |
| Tap a card (two panes) | The card is highlighted on the map and opens in the right pane. |

The highlighted or open card has a pale `slip` fill. There is no border and no glow.

### Markers

A marker is a small price slip (`PropertyMarkerChip`): `CutBorder(seed: 'marker')`, surface fill, ink text. The selected marker has the marigold fill (`buttonPrimary`) with `buttonPrimaryText` and a `mid` paper shadow. Nothing pulses. The tap target stays 48 px. Native MapLibre circles show clusters; a tap on a cluster zooms in by 2.

### State and rebuilds

`ExploreView` watches only the window width. Each part watches the narrow value it draws with `select`:

| Widget | Watches |
| --- | --- |
| `_ExploreBanners` | Refresh, pagination and screen error of the page; location load and save; the map-area search. |
| `_ExploreBody` | Whether a location exists, the location failure, and the empty phase. |
| `_RadiusNote` | The radius of the Explore filter. |
| `_ListSheet` | The folded flag and the item count. |
| `_ExploreCard` | Its own highlight and its own like state. |

`test/performance/rebuild_counts_test.dart` measures dirty builds:

| Workload | Before | After |
| --- | ---: | ---: |
| 5 camera moves | 1475 | 52 |
| 5 card highlights | 2459 | 344 |

## Saved

- Liked and Passed are two tabs in `SegmentedControl`. A pale slip slides under the selected tab. The count shows as text after the label.
- The list is flat: `PropertyListCard(row: true)` rows with the photo beside the words, 4 px apart. There is no grid.
- Empty Liked uses the `liked` scene; empty Passed uses the `passed` scene. Each has one action, Go to Discover.
- A search with no match shows `ErrorStates.searchEmpty` with Clear Search.
- A failed first load shows `ErrorStates.genericError(seed: 'saved')`.
- A failed refresh keeps the rows and shows `InlineRetryBanner` at the top (`qa.likes.content.retry`).
- The next page loads under the rows. A failed next page shows `InlineRetryBanner` as the last row (`qa.likes.content.retry`). The rows and the scroll position stay.
- From 840 px the list is a 380 px left pane and the open home shows in the right pane, as in Explore.

## Property row (`PropertyListCard`)

- Photo, the price in `headlineSmall` (Erode) with `/mo` or `/day` for rent and short stays, the title, the facts as one line of text (`House · 3 BHK · 2 Bath · 1,200 sq ft`), and the area.
- No chips, no border, no shadow, no hover lift. A press dims the card (`AnimatedTapWrapper`); it never scales.
- The heart is a bare icon. On the photo it is light with a tight shadow. Beside the words it is ink (`favoriteInactive`) or brick (`favoriteActive`) when saved. A pending like shows a spinner in its place.
- `onTap` replaces the details route push (used by the detail pane). `selected` lays a `slip` under the row.

## Filter sheet

- `showPropertyFilterBottomSheet(context, pageType:)` opens a theme sheet with the cut paper edge.
- Choices (purpose, property type, amenities) are `ChoiceChip`s with a small radius. Off: a quiet `border` edge. On: a mint `slip` fill and a check. No coloured ring, no pill.
- Actions: Apply is the one `FilledButton`. Clear Filters is a `TextButton`.
- Amenities come from `GET /api/v1/amenities` (public, sorted by title, cached for 24 hours on the backend). The app keeps the list in the SQLite cache (`amenities:v1`, fresh for 1 day, kept for 30 days):
  - A cached list shows at once. A stale list refreshes in the background. A failed refresh keeps the cached list.
  - With no cache, the section shows skeleton choices, then the list. A failed first load shows a retry banner in the amenities section only (`qa.filters.amenities.retry`); the rest of the sheet still works.
  - Filters send titles as `amenities=`. The backend matches them without case. On Apply, a saved title that the backend does not list is dropped, because it would match no home.

## Location picker

- The trigger in the top bar is flat text: a teal pin, the area name, and a chevron. There is no pill.
- The picker is a theme sheet with the cut paper edge. Icons are bare and use the teal accent.
- Failures in the picker are flat lines with an error icon and a retry link below the message.

## Accessibility

- Every control has a 48 px target and a label. The list handle has a button label that says expand or collapse.
- Tabs and rows expose selected state.
- Every screen is tested at 320 px with Hindi, 2x text and the dark theme.
