# Property interaction workload

> Evidence note: screenshots, native XML captures and JSON observations cited here are scratch artifacts kept on the verification machine. They are not committed (see `.gitignore`), so links to them do not resolve in a clone.

Recorded on 2026-09-25 with Flutter 3.47.4 / Dart 3.13.3 on the shared macOS ARM64 development host. Raw observations and exact SDK revisions are in [property-interaction-workload.json](property-interaction-workload.json).

This is one debug widget-test run with controlled input and I/O. Wall time measures test work on the host, not frame latency, FPS, touch latency, native startup, or battery use. The host also ran other verification work. There is no before/after speed claim or hardware acceptance threshold. This run preceded the final shared TextButton foreground contrast correction; these timing observations were not remeasured for that color-only change.

## Method

The test pumps the actual `DiscoverView`/`PropertySwipeStack` and `LikesView`/`PropertyListCard` with production theme tokens, bundled Manrope/Sora/Noto Sans Devanagari fonts and the decoded `test/fixtures/images/property_photo.jpg` fixture. Photos are delivered by the injected image cache through real file I/O and Flutter decoding. The image cache starts empty for each case. Measurement starts only after all displayed photos decode. Items share a fixture photo identity so list entries reuse the same decoded thumbnail.

Each window has 30 pointer moves and 30 pumps of 16 ms (480 ms of simulated test time). Horizontal moves are 3 logical pixels; vertical moves are -8 pixels. Mount, font loading, photo decoding, pointer release and snap-back are outside the timed window. The harness disables animations. Horizontal drag stays below the commit threshold and is cancelled after measurement. There are no network requests or platform map surfaces.

`debugOnRebuildDirtyWidget` counts dirty builds. Selected expensive widget counts distinguish initial mounts from rebuilds. This hook does not measure layout or raster cost. `imageCache.currentSizeBytes` reports Flutter decoded-image cache bytes; it is not total process memory or disk cache size.

## Observations

| Workload | Host wall time | Decoded cache bytes before → after | All dirty builds | Scroll offset before → after |
| --- | ---: | ---: | ---: | ---: |
| discover_horizontal_drag | 201.46 ms | 1,948,160 → 1,948,160 | 278 | 0 → 0.00 |
| discover_card_scroll | 170.55 ms | 1,597,440 → 1,597,440 | 16 | 0 → 209.17 |
| saved_list_scroll | 121.33 ms | 80,000 → 80,000 | 402 | 0 → 240.00 |

Each window recorded zero rebuilds of `PropertySwipeStack`, `PropertySwipeCard`, `SwipeCardHeroSection`, `SwipeCardDetailsSection`, `PropertyListCard`, and `RobustNetworkImage`. Saved scrolling mounted two new `PropertyListCard` and two `RobustNetworkImage` instances as they entered the list. The nonzero total includes gesture feedback and scroll-related widgets.

The Discover card-scroll case runs at 320 × 844, Hindi and 2x text. After measurement, it scrolls farther and asserts that the details action is visible and hit-testable. The horizontal case asserts that the top property remains in place and card/hero/details have zero rebuilds. The Saved case asserts that the list offset changes by more than 100 logical pixels.

## Reproduce

```sh
flutter test --no-pub --dart-define=WRITE_INTERACTION_METRICS=true test/performance/property_interaction_workload_test.dart
```

This writes fresh observations to the ignored `build/verification/property-interaction-workload.json`. Normal tests run the assertions without rewriting this report. Native startup traces and device integration results are separate evidence.
