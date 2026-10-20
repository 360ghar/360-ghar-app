import 'dart:async';

import 'package:flutter/material.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';

/// Branded cold-start / auth-bootstrap loader that matches the native splash
/// (paper background + centered mark) so the handoff does not feel blank.
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

  static const String logoAsset = 'assets/icons/logo_mark.png';
  static const String logoAssetDark = 'assets/icons/logo_mark_dark.png';

  @override
  State<AppBootLoader> createState() => _AppBootLoaderState();
}

class _AppBootLoaderState extends State<AppBootLoader> {
  Timer? _slowTimer;
  bool _isSlow = false;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final text = Theme.of(context).textTheme;
    final message = widget.message ?? context.l10n.text('loading');

    // Same background and mark as the native splash, so the handoff is seamless.
    return Scaffold(
      backgroundColor: design.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showLogo) ...[
                  Image.asset(
                    design.isDark ? AppBootLoader.logoAssetDark : AppBootLoader.logoAsset,
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        PaperIcon(KnifeIcon.home, size: 72, color: design.accent),
                  ),
                  const SizedBox(height: 28),
                ],
                LoadingStates.buttonSpinner(size: 24, color: design.accent),
                const SizedBox(height: 20),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: text.bodyLarge?.copyWith(color: design.textSecondary),
                ),
                if (_isSlow) ...[
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.text('boot_taking_longer'),
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(color: design.textSecondary),
                  ),
                  if (widget.onRetry != null) ...[
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: const ValueKey('qa.boot.retry'),
                      onPressed: () {
                        setState(() => _isSlow = false);
                        _armSlowTimer();
                        widget.onRetry!();
                      },
                      icon: const PaperIcon(KnifeIcon.retry, size: 18),
                      label: Text(context.l10n.text('retry')),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
