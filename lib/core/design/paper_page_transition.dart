import 'package:flutter/material.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';

/// The page transition for Android, web (except on Apple devices), Windows,
/// Linux and Fuchsia: the new page slides in from the trailing edge over the
/// old one, like a sheet laid on top. The old page shifts a quarter of the way
/// to the leading edge. Nothing fades, so content is never hidden. A short
/// paper shadow falls on the old page from the new page's leading edge only.
///
/// With `MediaQuery.disableAnimations`, the page changes in one frame.
class PaperSlideTransitionsBuilder extends PageTransitionsBuilder {
  const PaperSlideTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 350);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);

  static final _curve = CurveTween(curve: Curves.easeInOutCubicEmphasized);
  static final _enter = Tween(begin: const Offset(1, 0), end: Offset.zero).chain(_curve);
  static final _shift = Tween(begin: Offset.zero, end: const Offset(-0.25, 0)).chain(_curve);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final direction = Directionality.of(context);
    final design = context.design;
    // A page that covers the screen hides every edge but the leading one, the
    // only edge over the old page. The `mid` paper shadow is cast there with
    // the fall-off a sheet shows at its foot: its drop distance turned
    // sideways, so the same blur, spread and tint read at that edge.
    final lead = direction == TextDirection.ltr ? -1.0 : 1.0;
    final shadows = [
      for (final shadow in paperShadows(PaperElevation.mid, design.shadowOn(design.background)))
        shadow.copyWith(offset: Offset(shadow.offset.dy * lead, shadow.offset.dy)),
    ];
    return SlideTransition(
      position: secondaryAnimation.drive(_shift),
      textDirection: direction,
      child: SlideTransition(
        position: animation.drive(_enter),
        textDirection: direction,
        child: DecoratedBox(
          decoration: BoxDecoration(boxShadow: shadows),
          child: child,
        ),
      ),
    );
  }
}
