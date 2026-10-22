import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Widest a modal sheet grows, matching the theme's bottom sheet cap.
const double kSheetMaxWidth = 560;

/// The larger of the left and right safe-area insets.
///
/// The Duo reports its status pill as a right inset for the whole window
/// height, though the pill sits at the top. Centered content that takes only
/// that inset drifts off-center, so it uses this on both sides.
double symmetricSideInset(BuildContext context) {
  final padding = MediaQuery.paddingOf(context);
  return math.max(padding.left, padding.right);
}

/// A [SafeArea] whose side inset is the same on the left and right, for
/// centered compositions (a nav strip, a sheet). Left-aligned columns and top
/// bars keep the one-sided inset of a plain [SafeArea].
class SymmetricSafeArea extends StatelessWidget {
  const SymmetricSafeArea({super.key, this.top = true, this.bottom = true, required this.child});

  final bool top;
  final bool bottom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final side = symmetricSideInset(context);
    return SafeArea(
      left: false,
      right: false,
      top: top,
      bottom: bottom,
      // The inset is spent here, so a nested one does not add it again.
      child: MediaQuery.removePadding(
        context: context,
        removeLeft: true,
        removeRight: true,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: side),
          child: child,
        ),
      ),
    );
  }
}

/// Size limits for a scroll-controlled modal sheet that does not use the
/// route's one-sided safe area: capped in width, and below the status bar.
BoxConstraints sheetConstraints(BuildContext context) => BoxConstraints(
  maxWidth: kSheetMaxWidth,
  maxHeight: MediaQuery.sizeOf(context).height - MediaQuery.paddingOf(context).top,
);
