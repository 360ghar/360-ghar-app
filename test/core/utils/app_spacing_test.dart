import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/utils/app_spacing.dart';

void main() {
  group('AppSpacing', () {
    test('spacing scale values are correct', () {
      expect(AppSpacing.xxs, 2.0);
      expect(AppSpacing.xs, 4.0);
      expect(AppSpacing.sm, 8.0);
      expect(AppSpacing.md, 16.0);
      expect(AppSpacing.lg, 24.0);
      expect(AppSpacing.xl, 32.0);
      expect(AppSpacing.xxl, 48.0);
    });

    test('common padding values are correct', () {
      expect(AppSpacing.cardPadding, 16.0);
      expect(AppSpacing.screenPadding, 20.0);
      expect(AppSpacing.listItemSpacing, 12.0);
      expect(AppSpacing.sectionSpacing, 24.0);
    });

    test('spacing scale is monotonically increasing', () {
      expect(AppSpacing.xxs, lessThan(AppSpacing.xs));
      expect(AppSpacing.xs, lessThan(AppSpacing.sm));
      expect(AppSpacing.sm, lessThan(AppSpacing.md));
      expect(AppSpacing.md, lessThan(AppSpacing.lg));
      expect(AppSpacing.lg, lessThan(AppSpacing.xl));
      expect(AppSpacing.xl, lessThan(AppSpacing.xxl));
    });

    test('cardPadding equals md', () {
      expect(AppSpacing.cardPadding, AppSpacing.md);
    });

    test('sectionSpacing equals lg', () {
      expect(AppSpacing.sectionSpacing, AppSpacing.lg);
    });
  });

  group('AppBorderRadius', () {
    test('border radius scale values are correct', () {
      expect(AppBorderRadius.xs, 4.0);
      expect(AppBorderRadius.sm, 8.0);
      expect(AppBorderRadius.md, 12.0);
      expect(AppBorderRadius.lg, 16.0);
      expect(AppBorderRadius.xl, 20.0);
      expect(AppBorderRadius.xxl, 24.0);
      expect(AppBorderRadius.round, 999.0);
    });

    test('semantic border radius values are correct', () {
      expect(AppBorderRadius.chip, 8.0);
      expect(AppBorderRadius.badge, 8.0);
      expect(AppBorderRadius.button, 12.0);
      expect(AppBorderRadius.card, 16.0);
      expect(AppBorderRadius.input, 12.0);
      expect(AppBorderRadius.dialog, 16.0);
      expect(AppBorderRadius.bottomSheet, 24.0);
      expect(AppBorderRadius.modal, 24.0);
    });

    test('border radius scale is monotonically increasing', () {
      expect(AppBorderRadius.xs, lessThan(AppBorderRadius.sm));
      expect(AppBorderRadius.sm, lessThan(AppBorderRadius.md));
      expect(AppBorderRadius.md, lessThan(AppBorderRadius.lg));
      expect(AppBorderRadius.lg, lessThan(AppBorderRadius.xl));
      expect(AppBorderRadius.xl, lessThan(AppBorderRadius.xxl));
      expect(AppBorderRadius.xxl, lessThan(AppBorderRadius.round));
    });

    test('chip equals sm', () {
      expect(AppBorderRadius.chip, AppBorderRadius.sm);
    });

    test('badge equals sm', () {
      expect(AppBorderRadius.badge, AppBorderRadius.sm);
    });

    test('button equals md', () {
      expect(AppBorderRadius.button, AppBorderRadius.md);
    });

    test('card equals lg', () {
      expect(AppBorderRadius.card, AppBorderRadius.lg);
    });

    test('input equals md', () {
      expect(AppBorderRadius.input, AppBorderRadius.md);
    });

    test('dialog equals lg', () {
      expect(AppBorderRadius.dialog, AppBorderRadius.lg);
    });

    test('bottomSheet equals xxl', () {
      expect(AppBorderRadius.bottomSheet, AppBorderRadius.xxl);
    });

    test('modal equals bottomSheet', () {
      expect(AppBorderRadius.modal, AppBorderRadius.bottomSheet);
    });

    test('round is a large sentinel value for fully circular shapes', () {
      expect(AppBorderRadius.round, greaterThan(100.0));
    });
  });

  group('AppDurations', () {
    test('base duration values are correct', () {
      expect(AppDurations.fastest, const Duration(milliseconds: 100));
      expect(AppDurations.fast, const Duration(milliseconds: 200));
      expect(AppDurations.normal, const Duration(milliseconds: 300));
      expect(AppDurations.slow, const Duration(milliseconds: 400));
      expect(AppDurations.slower, const Duration(milliseconds: 500));
    });

    test('semantic duration values are correct', () {
      expect(AppDurations.pageTransition, const Duration(milliseconds: 300));
      expect(AppDurations.editorialReveal, const Duration(milliseconds: 350));
      expect(AppDurations.tabPill, const Duration(milliseconds: 250));
      expect(AppDurations.markerPulse, const Duration(milliseconds: 1400));
      expect(AppDurations.contentFade, const Duration(milliseconds: 400));
      expect(AppDurations.cardEntrance, const Duration(milliseconds: 350));
      expect(AppDurations.favoriteBurst, const Duration(milliseconds: 500));
    });

    test('base durations are monotonically increasing', () {
      expect(AppDurations.fastest, lessThan(AppDurations.fast));
      expect(AppDurations.fast, lessThan(AppDurations.normal));
      expect(AppDurations.normal, lessThan(AppDurations.slow));
      expect(AppDurations.slow, lessThan(AppDurations.slower));
    });

    test('pageTransition equals normal', () {
      expect(AppDurations.pageTransition, AppDurations.normal);
    });

    test('contentFade equals slow', () {
      expect(AppDurations.contentFade, AppDurations.slow);
    });

    test('favoriteBurst equals slower', () {
      expect(AppDurations.favoriteBurst, AppDurations.slower);
    });

    test('cardEntrance equals editorialReveal', () {
      expect(AppDurations.cardEntrance, AppDurations.editorialReveal);
    });

    test('markerPulse is the longest duration', () {
      expect(AppDurations.markerPulse, greaterThan(AppDurations.slower));
    });
  });

  group('AppCurves', () {
    test('standard curve is easeOutCubic', () {
      expect(AppCurves.standard, Curves.easeOutCubic);
    });

    test('cardEntrance curve is easeOutBack', () {
      expect(AppCurves.cardEntrance, Curves.easeOutBack);
    });

    test('tabPill curve is easeInOut', () {
      expect(AppCurves.tabPill, Curves.easeInOut);
    });

    test('all curves are non-null Curve instances', () {
      expect(AppCurves.standard, isA<Curve>());
      expect(AppCurves.cardEntrance, isA<Curve>());
      expect(AppCurves.tabPill, isA<Curve>());
    });
  });
}
