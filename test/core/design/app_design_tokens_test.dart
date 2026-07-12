import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/app_design_tokens.dart';

void main() {
  group('AppDesignTokens', () {
    test('brand palette colors have correct values', () {
      expect(AppDesignTokens.brandGold, const Color(0xFFF5B400));
      expect(AppDesignTokens.brandGoldDark, const Color(0xFFE29E00));
      expect(AppDesignTokens.brandGoldLight, const Color(0xFFFFCC3D));
      expect(AppDesignTokens.brandGoldSubtle, const Color(0xFFFBF3D0));
    });

    test('accent colors have correct values', () {
      expect(AppDesignTokens.accentOrange, const Color(0xFFFF7A28));
      expect(AppDesignTokens.accentBlue, const Color(0xFF1E88E5));
      expect(AppDesignTokens.accentGreen, const Color(0xFF2BB673));
    });

    test('editorial and warm colors have correct values', () {
      expect(AppDesignTokens.editorialWarm, const Color(0xFF8C6B52));
      expect(AppDesignTokens.editorialInk, const Color(0xFF8C6B52));
      expect(AppDesignTokens.warmCream, const Color(0xFFF8F5F0));
    });

    test('neutral scale colors have correct values', () {
      expect(AppDesignTokens.neutralWhite, const Color(0xFFFFFFFF));
      expect(AppDesignTokens.neutral50, const Color(0xFFF9FAFB));
      expect(AppDesignTokens.neutral100, const Color(0xFFF1F3F5));
      expect(AppDesignTokens.neutral300, const Color(0xFFCED4DA));
      expect(AppDesignTokens.neutral500, const Color(0xFF6C757D));
      expect(AppDesignTokens.neutral700, const Color(0xFF2B2F36));
      expect(AppDesignTokens.neutral900, const Color(0xFF121417));
    });

    test('dark surface tokens have correct values', () {
      expect(AppDesignTokens.darkSurface, const Color(0xFF171A1F));
      expect(AppDesignTokens.darkSurfaceAlt, const Color(0xFF1F242C));
      expect(AppDesignTokens.darkBorder, const Color(0xFF2C333D));
      expect(AppDesignTokens.darkTextPrimary, const Color(0xFFF5F7FA));
      expect(AppDesignTokens.darkTextSecondary, const Color(0xFFCDD3DB));
      expect(AppDesignTokens.darkTextTertiary, const Color(0xFF8D97A6));
    });

    test('status colors have correct values', () {
      expect(AppDesignTokens.success, const Color(0xFF16A34A));
      expect(AppDesignTokens.warning, const Color(0xFFF59E0B));
      expect(AppDesignTokens.error, const Color(0xFFDC2626));
    });

    test('shadow colors have correct alpha and RGB', () {
      // lightShadow = 0x14000000 (alpha 0x14 = ~8% black)
      expect(AppDesignTokens.lightShadow, const Color(0x14000000));
      // darkShadow = 0x40000000 (alpha 0x40 = ~25% black)
      expect(AppDesignTokens.darkShadow, const Color(0x40000000));
    });
  });

  group('AppDesignOpacity', () {
    test('opacity scale has correct values', () {
      expect(AppDesignOpacity.subtle, 0.08);
      expect(AppDesignOpacity.soft, 0.16);
      expect(AppDesignOpacity.medium, 0.28);
      expect(AppDesignOpacity.strong, 0.48);
    });
  });
}
