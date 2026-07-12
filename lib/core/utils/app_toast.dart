import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/app_design_tokens.dart';

class AppToast {
  AppToast._();

  static void _show({
    required String title,
    required String message,
    required Color backgroundColor,
    required Color textColor,
    Duration duration = const Duration(seconds: 3),
    SnackPosition position = SnackPosition.TOP,
    double borderRadius = 8,
    double margin = 12,
    TextButton? mainButton,
  }) {
    final context = Get.overlayContext ?? Get.context;
    if (context == null) return;

    Get.snackbar(
      title,
      message,
      snackPosition: position,
      backgroundColor: backgroundColor,
      colorText: textColor,
      duration: duration,
      borderRadius: borderRadius,
      margin: EdgeInsets.all(margin),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      mainButton: mainButton,
      isDismissible: true,
      dismissDirection: DismissDirection.horizontal,
    );
  }

  static void success(String title, [String? message]) {
    _show(
      title: title,
      message: message ?? '',
      backgroundColor: AppDesign.successGreen,
      // Dark ink on green for WCAG-friendly body contrast.
      textColor: AppDesignTokens.neutral900,
    );
  }

  static void error(String title, [String? message]) {
    _show(
      title: title,
      message: message ?? '',
      backgroundColor: AppDesign.errorRed,
      textColor: AppDesignTokens.neutralWhite,
    );
  }

  static void warning(String title, [String? message]) {
    _show(
      title: title,
      message: message ?? '',
      backgroundColor: AppDesign.warningAmber,
      // Dark ink on amber (white fails contrast on #F59E0B).
      textColor: AppDesignTokens.neutral900,
    );
  }

  static void info(String title, [String? message]) {
    _show(
      title: title,
      message: message ?? '',
      backgroundColor: AppDesign.accentBlue,
      textColor: AppDesignTokens.neutralWhite,
    );
  }

  static void custom({
    required String title,
    required String message,
    required Color backgroundColor,
    Color? textColor,
    Duration duration = const Duration(seconds: 3),
    TextButton? mainButton,
  }) {
    _show(
      title: title,
      message: message,
      backgroundColor: backgroundColor,
      textColor: textColor ?? AppDesign.getContrastColor(backgroundColor),
      duration: duration,
      mainButton: mainButton,
    );
  }
}
