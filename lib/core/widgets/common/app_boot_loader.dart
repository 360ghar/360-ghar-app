import 'dart:async';

import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/design/app_design_tokens.dart';

/// Branded cold-start / auth-bootstrap loader that matches the native splash
/// (neutral50 background + centered logo) so the handoff does not feel blank.
///
/// After [slowThreshold], shows a recovery message and optional [onRetry].
class AppBootLoader extends StatefulWidget {
  const AppBootLoader({
    super.key,
    this.message,
    this.onRetry,
    this.slowThreshold = const Duration(seconds: 10),
    this.showLogo = true,
  });

  /// Status line under the spinner. Defaults to `loading` translation.
  final String? message;

  /// Shown after [slowThreshold] so the user is not stuck without an action.
  final VoidCallback? onRetry;

  /// How long to wait before offering recovery UI.
  final Duration slowThreshold;

  /// When false, only progress + text are shown (rare).
  final bool showLogo;

  static const String logoAsset = 'assets/icons/splash_logo.png';

  @override
  State<AppBootLoader> createState() => _AppBootLoaderState();
}

class _AppBootLoaderState extends State<AppBootLoader> with SingleTickerProviderStateMixin {
  Timer? _slowTimer;
  bool _isSlow = false;
  late final AnimationController _fadeController;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
    _armSlowTimer();
  }

  @override
  void didUpdateWidget(covariant AppBootLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slowThreshold != widget.slowThreshold) {
      _armSlowTimer();
    }
  }

  void _armSlowTimer() {
    _slowTimer?.cancel();
    _isSlow = false;
    _slowTimer = Timer(widget.slowThreshold, () {
      if (!mounted) return;
      setState(() => _isSlow = true);
    });
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final background = isDark ? AppDesignTokens.neutral900 : AppDesignTokens.neutral50;
    final onSurface = isDark ? AppDesignTokens.darkTextPrimary : AppDesignTokens.neutral900;
    final muted = isDark ? AppDesignTokens.darkTextSecondary : AppDesignTokens.neutral500;
    final message = widget.message ?? 'loading'.tr;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.showLogo) ...[
                    Image.asset(
                      AppBootLoader.logoAsset,
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.home_work_outlined,
                        size: 72,
                        color: AppDesignTokens.brandGold,
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppDesignTokens.brandGold,
                      backgroundColor: AppDesignTokens.brandGold.withValues(alpha: 0.15),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: onSurface.withValues(alpha: 0.75),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                  if (_isSlow) ...[
                    const SizedBox(height: 12),
                    Text(
                      'boot_taking_longer'.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted, fontSize: 13, height: 1.35),
                    ),
                    if (widget.onRetry != null) ...[
                      const SizedBox(height: 20),
                      TextButton.icon(
                        key: const ValueKey('qa.boot.retry'),
                        onPressed: () {
                          setState(() => _isSlow = false);
                          _armSlowTimer();
                          widget.onRetry!();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text('retry'.tr),
                        style: TextButton.styleFrom(
                          foregroundColor: AppDesignTokens.neutral900,
                          backgroundColor: AppDesignTokens.brandGold,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
