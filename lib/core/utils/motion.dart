import 'package:flutter/material.dart';

import 'package:ghar360/core/utils/app_spacing.dart';

/// Respects system "reduce motion" by collapsing durations to zero.
class Motion {
  Motion._();

  static bool reduceMotion(BuildContext context) {
    return MediaQuery.maybeDisableAnimationsOf(context) ??
        MediaQuery.maybeOf(context)?.disableAnimations == true;
  }

  static Duration duration(BuildContext context, Duration normal) {
    return reduceMotion(context) ? Duration.zero : normal;
  }

  static Duration fast(BuildContext context) => duration(context, AppDurations.fast);

  static Duration normal(BuildContext context) => duration(context, AppDurations.normal);

  static Duration contentFade(BuildContext context) =>
      duration(context, AppDurations.contentFade);
}
