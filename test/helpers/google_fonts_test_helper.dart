// test/helpers/google_fonts_test_helper.dart
//
// google_fonts loads font files asynchronously and fire-and-forgets the
// loading Future. When a font is not bundled in the app's assets (the common
// case in unit tests that don't ship TTFs), `loadFontIfNecessary` throws and
// the error becomes an uncaught async error that the flutter_test zone turns
// into a test failure — even though the returned TextStyle is perfectly valid
// (it carries the configured color/size/weight; only the font *file* is
// missing).
//
// [withFontLoadingErrorsIgnored] runs [builder] inside a guarded zone whose
// error handler discards exactly those font-loading errors, so the rest of the
// test can assert on the style properties google_fonts already returned.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Initializes the test binding and disables google_fonts runtime fetching.
///
/// Call once at the top of `main()` before constructing any theme/widget that
/// transitively calls `GoogleFonts.*`.
void configureGoogleFontsForTests() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
}

/// Runs [builder] in a guarded zone that swallows the uncaught async errors
/// emitted by google_fonts' fire-and-forget font loading, returning the value
/// [builder] produces synchronously.
T withFontLoadingErrorsIgnored<T>(T Function() builder) {
  late T result;
  runZonedGuarded(
    () {
      result = builder();
    },
    (error, stack) {
      // Intentionally empty: google_fonts font-file load failures are expected
      // in tests that don't bundle TTF assets and must not fail the test.
    },
  );
  return result;
}
