import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/responsive.dart';
import 'package:ghar360/core/widgets/common/max_content_width.dart';

class AuthPremiumShell extends StatelessWidget {
  const AuthPremiumShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onBack,
    this.footer,
    this.chips = const <String>[],
  });

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onBack;
  final Widget? footer;
  final List<String> chips;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    // On tablet/desktop widths the whole centered column (wordmark, title,
    // glass card, chips, footer) is capped so it doesn't stretch edge-to-edge.
    // `null` on compact → MaxContentWidth is a full-bleed no-op (phone unchanged).
    final contentWidthCap = context.isTabletWidth ? 520.0 : null;

    return Scaffold(
      backgroundColor: AppDesign.overlayDark,
      body: Stack(
        children: [
          Positioned.fill(child: _buildBackgroundImage()),
          Positioned.fill(child: _buildGradientOverlay()),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: MaxContentWidth(
                            maxWidth: contentWidthCap,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 24),
                                _buildWordmark(),
                                const SizedBox(height: 20),
                                _buildTitle(theme),
                                const SizedBox(height: 40),
                                _buildGlassCard(theme),
                                const SizedBox(height: 24),
                                if (chips.isNotEmpty) ...[
                                  _buildChips(theme),
                                  const SizedBox(height: 16),
                                ],
                                if (footer != null) _buildFooter(theme),
                                SizedBox(height: bottomPadding + 16),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    if (onBack == null) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
        child: IconButton(
          onPressed: onBack,
          icon: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppDesign.overlayDark.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, color: AppDesign.overlayLight, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundImage() {
    return Image.asset(
      'assets/images/auth_hero.jpg',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppDesign.editorialWarm.withValues(alpha: 0.6),
                AppDesign.editorialWarm.withValues(alpha: 0.8),
                const Color(0xFF3D3027),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppDesign.overlayDark.withValues(alpha: 0.2),
            AppDesign.overlayDark.withValues(alpha: 0.35),
            AppDesign.overlayDark.withValues(alpha: 0.5),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildWordmark() {
    return Text(
      'app_name'.tr,
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w400,
        color: AppDesign.overlayLight,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildTitle(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: AppDesign.overlayLight,
          height: 1.25,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  Widget _buildGlassCard(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            decoration: BoxDecoration(
              color: AppDesign.overlayLight.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppDesign.overlayLight.withValues(alpha: 0.18), width: 1),
            ),
            child: Theme(
              data: _buildGlassTheme(theme),
              child: DefaultTextStyle(
                style: const TextStyle(color: AppDesign.overlayLight),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  ThemeData _buildGlassTheme(ThemeData base) {
    final white70 = AppDesign.overlayLight.withValues(alpha: 0.7);
    final white50 = AppDesign.overlayLight.withValues(alpha: 0.5);
    final white25 = AppDesign.overlayLight.withValues(alpha: 0.25);

    return base.copyWith(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppDesign.overlayLight.withValues(alpha: 0.08),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: white25, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: white25, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: white50, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade300, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade300, width: 2),
        ),
        hintStyle: TextStyle(color: white50, fontSize: 15),
        labelStyle: TextStyle(color: white70, fontSize: 15),
        floatingLabelStyle: TextStyle(color: white70, fontSize: 13),
        prefixIconColor: white70,
        suffixIconColor: white70,
        iconColor: white70,
      ),
      textTheme: base.textTheme.copyWith(
        bodyLarge: base.textTheme.bodyLarge?.copyWith(color: AppDesign.overlayLight),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(color: white70),
        bodySmall: base.textTheme.bodySmall?.copyWith(color: white50),
        labelLarge: base.textTheme.labelLarge?.copyWith(color: AppDesign.overlayLight),
        labelMedium: base.textTheme.labelMedium?.copyWith(color: white70),
        labelSmall: base.textTheme.labelSmall?.copyWith(color: white50),
        titleLarge: base.textTheme.titleLarge?.copyWith(color: AppDesign.overlayLight),
        titleMedium: base.textTheme.titleMedium?.copyWith(color: AppDesign.overlayLight),
        titleSmall: base.textTheme.titleSmall?.copyWith(color: white70),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppDesign.primaryYellow;
          }
          return AppDesign.overlayLight.withValues(alpha: 0.2);
        }),
        checkColor: WidgetStateProperty.all(AppDesign.textDark),
        side: BorderSide(color: white25, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: white70,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppDesign.overlayLight,
          side: BorderSide(color: white25, width: 1.5),
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppDesign.primaryYellow,
          foregroundColor: AppDesign.textDark,
          disabledBackgroundColor: AppDesign.primaryYellow.withValues(alpha: 0.5),
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: AppDesign.primaryYellow,
          foregroundColor: AppDesign.textDark,
          disabledBackgroundColor: AppDesign.primaryYellow.withValues(alpha: 0.5),
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppDesign.primaryYellow,
        linearMinHeight: 6,
      ),
    );
  }

  Widget _buildChips(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: chips
            .map(
              (chip) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppDesign.overlayLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppDesign.overlayLight.withValues(alpha: 0.18),
                    width: 1,
                  ),
                ),
                child: Text(
                  chip,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppDesign.overlayLight.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: DefaultTextStyle(
        style: TextStyle(
          color: AppDesign.overlayLight.withValues(alpha: 0.6),
          fontSize: 12,
          height: 1.5,
        ),
        textAlign: TextAlign.center,
        child: footer!,
      ),
    );
  }
}

class AuthInlineError extends StatelessWidget {
  const AuthInlineError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    if (message.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: Colors.red.shade300),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.red.shade200,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
