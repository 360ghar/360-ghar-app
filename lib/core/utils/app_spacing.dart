import 'package:flutter/material.dart';

/// Standardized spacing constants for consistent UI
class AppSpacing {
  AppSpacing._();

  // Spacing scale
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Common padding values
  static const double screenPadding = 20.0;
  static const double sectionSpacing = 24.0;
}

/// Standardized border radius constants
class AppBorderRadius {
  AppBorderRadius._();

  // Border radius scale
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;

  // Semantic border radius
  static const double button = 12.0;
  static const double card = 16.0;
  static const double input = 12.0;
}

/// Standard durations for animations
class AppDurations {
  AppDurations._();

  static const Duration fastest = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration slower = Duration(milliseconds: 500);
  static const Duration tabPill = Duration(milliseconds: 250);
  static const Duration cardEntrance = Duration(milliseconds: 350);
}

/// Standard curves for animations
class AppCurves {
  AppCurves._();

  static const Curve standard = Curves.easeOutCubic;
  static const Curve cardEntrance = Curves.easeOutBack;
  static const Curve tabPill = Curves.easeInOut;
}
