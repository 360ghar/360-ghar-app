import 'package:flutter/widgets.dart';

/// Coarse window-size classes used to drive responsive layout decisions.
///
/// Breakpoints (width in logical pixels):
///   - [compact]  : < 600  (phones in portrait)
///   - [medium]   : 600–840 (small tablets / phones in landscape)
///   - [expanded] : 840–1200 (tablets, iPad portrait)
///   - [large]    : >= 1200 (iPad landscape, desktop)
enum WindowSizeClass { compact, medium, expanded, large }

/// Breakpoint thresholds (logical px). Kept as plain constants so the mapping
/// can be unit-tested without a [BuildContext].
const double kCompactBreakpoint = 600;
const double kMediumBreakpoint = 840;
const double kExpandedBreakpoint = 1200;

/// Maximum content widths per class. On [compact] the content fills the
/// available width ([double.infinity]); on wider classes the content is
/// capped so lines of text remain readable.
const Map<WindowSizeClass, double> kContentMaxWidths = {
  WindowSizeClass.compact: double.infinity,
  WindowSizeClass.medium: 600,
  WindowSizeClass.expanded: 840,
  WindowSizeClass.large: 960,
};

/// Pure function that maps a width in logical pixels to a [WindowSizeClass].
/// Extracted from [ResponsiveContext] so it can be exercised in unit tests
/// without a widget tree.
WindowSizeClass windowSizeClassForWidth(double width) {
  if (width >= kExpandedBreakpoint) return WindowSizeClass.large;
  if (width >= kMediumBreakpoint) return WindowSizeClass.expanded;
  if (width >= kCompactBreakpoint) return WindowSizeClass.medium;
  return WindowSizeClass.compact;
}

/// Picks a value for the given [WindowSizeClass], walking down to the nearest
/// defined lower band when the exact band is null. [fallback] is required and
/// used when no band matches (including [WindowSizeClass.compact]).
///
/// Example:
/// ```dart
/// final padding = responsiveValue<double>(context,
///   compact: 16, medium: 24, fallback: 32);
/// ```
T responsiveValue<T>(
  BuildContext context, {
  T? compact,
  T? medium,
  T? expanded,
  T? large,
  required T fallback,
}) {
  return responsiveValueForClass(
    context.windowSizeClass,
    compact: compact,
    medium: medium,
    expanded: expanded,
    large: large,
    fallback: fallback,
  );
}

/// Class-based variant of [responsiveValue] — testable without [BuildContext].
///
/// Resolution order: the value for [sizeClass] wins if defined; otherwise we
/// walk down to the nearest *smaller* class that has a value. Mirrors the
/// "adapt by nearest smaller" semantics used by Material 3 window-size
/// classes. [fallback] is returned only when no relevant band is defined.
T responsiveValueForClass<T>(
  WindowSizeClass sizeClass, {
  T? compact,
  T? medium,
  T? expanded,
  T? large,
  required T fallback,
}) {
  // Ordered small → large so we can slice the candidates below the current
  // class while preserving descending resolution order.
  const ordered = [
    WindowSizeClass.compact,
    WindowSizeClass.medium,
    WindowSizeClass.expanded,
    WindowSizeClass.large,
  ];
  final values = {
    WindowSizeClass.compact: compact,
    WindowSizeClass.medium: medium,
    WindowSizeClass.expanded: expanded,
    WindowSizeClass.large: large,
  };

  final startIndex = ordered.indexOf(sizeClass);
  // Walk from the current class down to the smallest, returning the first
  // non-null value.
  for (var i = startIndex; i >= 0; i--) {
    final candidate = values[ordered[i]];
    if (candidate != null) return candidate;
  }
  return fallback;
}

/// Convenience accessors for responsive layout decisions.
extension ResponsiveContext on BuildContext {
  /// The window-size class for the current [MediaQuery] width.
  WindowSizeClass get windowSizeClass => windowSizeClassForWidth(MediaQuery.sizeOf(this).width);

  /// True for [medium] and above (tablets and larger).
  ///
  /// Named `isTabletWidth` (not `isTablet`) because GetX already ships a
  /// `context.isTablet` via its `ContextExtensionss`; this one is anchored to
  /// this file's breakpoints. Prefer [windowSizeClass] for finer decisions.
  bool get isTabletWidth => windowSizeClass.index >= WindowSizeClass.medium.index;

  /// True only for [large] (desktop-class widths). See [isTabletWidth].
  bool get isDesktopWidth => windowSizeClass == WindowSizeClass.large;

  /// Recommended maximum width for readable line content, based on the
  /// current window-size class. See [kContentMaxWidths].
  double get contentMaxWidth => kContentMaxWidths[windowSizeClass]!;
}
