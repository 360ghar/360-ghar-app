import 'package:flutter/material.dart';

import 'package:ghar360/core/utils/responsive.dart';

/// Centers its [child] horizontally and caps the content width to
/// [BuildContext.contentMaxWidth] (or an explicit [maxWidth] override).
///
/// On [WindowSizeClass.compact] (phone widths) the child fills the available
/// width with no horizontal padding — so wrapping existing full-bleed content
/// is visually a no-op on phones. On tablet/desktop widths the content is
/// constrained and centered, keeping line lengths readable.
///
/// Modeled on [OverflowSafeContainer]. Use it to wrap list/grids, forms, or
/// detail bodies that should not stretch edge-to-edge on wide screens.
///
/// ```dart
/// MaxContentWidth(
///   child: PaginatedGridView<PropertyModel>(...),
/// )
/// ```
class MaxContentWidth extends StatelessWidget {
  final Widget child;

  /// Optional override for the maximum content width. When null the value is
  /// derived from [BuildContext.contentMaxWidth].
  final double? maxWidth;

  const MaxContentWidth({super.key, required this.child, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final limit = maxWidth ?? context.contentMaxWidth;

    // compact → full width, no centering padding.
    if (limit == double.infinity) {
      return child;
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: limit),
        child: child,
      ),
    );
  }
}
