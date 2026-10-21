# Property screen visual verification

[Open the 38-image gallery](property-visuals.html). The gallery was captured before the empty, error and 834px variants were added: the test now generates 68 comparisons (five states, 834px content variants and two after-scroll images), and `property-visuals.html` shows 38 of them. The goldens in `test/visual/goldens/` are the full set. Source images are in `test/visual/goldens/`; test definitions are in `test/visual/property_screens_golden_test.dart`.

## Scope and result

On 2026-09-25, Flutter 3.47.4 rendered the production Discover, Saved and Explore Flutter views with the app's light/dark themes. The matrix contains 36 cases: three screens × content/loading/retained content after refresh failure × two themes × 390px English at 1x text / 320px Hindi at 2x text. All images are 844 logical pixels high at pixel ratio 1. Two additional images show the compact Discover card after scrolling during partial failure.

The tests use a controlled query provider and injected SQLite/image dependencies. Each content capture waits for actual local-file photo decoding and checks that no loading spinner remains. Saved fixtures include the liked state. Font bytes are loaded from the same bundled assets as the app. Explore replaces only the native map canvas with a labeled test surface; Flutter map controls, markers, recovery state and property list are real widgets.

36 visual tests passed with **38 image comparisons**, without updating the baselines. The three interaction workload tests also passed in that run (`/tmp/property-visual-final-verify.log`). A separate run passed 178 design/image/card/details/calculator tests after removal of the Google Fonts dependency (`/tmp/font-consumers-tests.log`). A final Explore regression run passed 136 tests (`/tmp/visual-explore-regression.log`). Targeted static analysis found no issues (`/tmp/visual-final-all-analyze.log`). These logs are local verification outputs, not permanent build artifacts.

## Viewed images and corrections

Representative PNGs were opened and visually inspected, including content on each screen, both themes and sizes, Discover and Explore loading, Saved and Explore retained failure states, and both compact Discover after-scroll views. The gallery makes every generated case available for review.

| Finding | Change and evidence |
| --- | --- |
| Shared light-theme text buttons used gold on white at only 1.84:1 contrast. | The existing neutral900 token gives 18.45:1 on white and 17.66:1 on neutral50. Dark text buttons retain gold (9.48:1 on darkSurface, 8.47:1 on darkSurfaceAlt). Disabled controls retain Flutter styling and remain inactive. |
| Actual Hindi 2x font metrics exceeded Explore's fixed strip-handle height by 3 logical pixels. | The handle now has a 48px minimum height and grows with its text. Compact Explore content/failure images render without overflow. |
| The unselected photo heart used `onPrimary` (near black) against a dark image scrim. | The outline and update spinner use the white overlay token. The selected heart keeps the existing active token. A widget assertion protects the outline token. |
| Cached image fade-out continued when reduced motion was enabled. | Both fades are now zero for reduced motion; a focused regression test checks both durations. |
| A 320px/2x Discover failure banner leaves less room above the card fold. | Both after-scroll images and hit-test assertions show that the details action and property metrics remain reachable. Like/Pass stays visible. |

The final contrast correction changed exactly seven Discover light PNGs: content/loading/partial-failure at both sizes, plus compact partial failure after scrolling. All seven were opened and inspected; pixel differences are confined to the top-bar Assistant text/icon. SHA-256 checks verified the other 31 images were byte-for-byte unchanged (`/tmp/text-button-goldens-changed.json`). The baselines were updated only after reviewing the intended difference. The final comparison run, without updates, passed all 36 visual cases plus 75 design tests (111 total, `/tmp/text-button-contrast-final-tests.log`). Focused analysis also passed (`/tmp/text-button-contrast-analyze.log`).

The compact Saved cards use one column; the 390px layout uses two. Long card titles and addresses use the existing ellipsis. Prices, retry actions and primary controls remain visible. The large text failure banner uses more vertical space by design; the content remains scrollable.

## Fonts and boundaries

[Font provenance and licenses](../../assets/fonts/README.md) cover the bundled Erode (Fontshare) and Noto Serif Devanagari files. The app no longer fetches fonts at runtime. `sources.json` pins source revision and file hashes. The bundled TTFs total 1,815,424 bytes; licenses are bundled.

These are widget screenshots on the macOS Flutter test renderer. They do not prove native MapLibre tile rendering, GPS/permission behavior, OAuth, WebView, push notifications, platform text rendering, or device frame performance. The native canvas is clearly labeled. Shell navigation and other journeys have separate tests and native evidence. No before/after performance improvement is claimed.

## Reproduce

```sh
flutter test --no-pub test/visual/property_screens_golden_test.dart
flutter test --no-pub test/performance/property_interaction_workload_test.dart
```

For an intentional visual change, run `flutter test --no-pub --update-goldens test/visual/property_screens_golden_test.dart`, open the gallery, inspect changed images, and then rerun without `--update-goldens`. See [interaction workload observations](property-interaction-workload.md) for the recorded scroll/drag measurements and their limits.
