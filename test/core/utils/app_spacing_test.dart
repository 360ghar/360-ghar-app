import 'package:flutter/animation.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/utils/app_spacing.dart';

void main() {
  test('spacing scale increases', () {
    const scale = [
      AppSpacing.xxs,
      AppSpacing.xs,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.lg,
      AppSpacing.xl,
      AppSpacing.xxl,
    ];
    for (var i = 1; i < scale.length; i++) {
      expect(scale[i], greaterThan(scale[i - 1]));
    }
    expect(AppSpacing.screenPadding, 20.0);
    expect(AppSpacing.sectionSpacing, AppSpacing.lg);
  });

  test('radius scale increases and has no pill radius', () {
    const scale = [
      AppBorderRadius.xs,
      AppBorderRadius.sm,
      AppBorderRadius.md,
      AppBorderRadius.lg,
      AppBorderRadius.xl,
      AppBorderRadius.xxl,
    ];
    for (var i = 1; i < scale.length; i++) {
      expect(scale[i], greaterThan(scale[i - 1]));
    }
    expect(AppBorderRadius.button, AppBorderRadius.md);
    expect(AppBorderRadius.input, AppBorderRadius.md);
    expect(AppBorderRadius.card, AppBorderRadius.lg);
  });

  test('durations increase and semantic durations sit on the scale', () {
    expect(AppDurations.fastest, lessThan(AppDurations.fast));
    expect(AppDurations.fast, lessThan(AppDurations.normal));
    expect(AppDurations.normal, lessThan(AppDurations.slow));
    expect(AppDurations.slow, lessThan(AppDurations.slower));
    expect(AppDurations.tabPill, const Duration(milliseconds: 250));
    expect(AppDurations.cardEntrance, const Duration(milliseconds: 350));
  });

  test('curves', () {
    expect(AppCurves.standard, Curves.easeOutCubic);
    expect(AppCurves.cardEntrance, Curves.easeOutBack);
    expect(AppCurves.tabPill, Curves.easeInOut);
  });
}
