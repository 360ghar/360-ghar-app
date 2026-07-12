import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/app_spacing.dart';

/// Pass / Details / Like controls for the discover deck.
///
/// Pinned to the bottom of the swipe viewport so primary actions stay
/// visible on the first screen without scrolling past the card.
class SwipeCardActionButtons extends StatelessWidget {
  final VoidCallback? onPass;
  final VoidCallback? onDetails;
  final VoidCallback? onLike;
  final bool enabled;

  const SwipeCardActionButtons({
    super.key,
    this.onPass,
    this.onDetails,
    this.onLike,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !enabled,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ActionCircleButton(
              key: const ValueKey('qa.discover.action.pass'),
              icon: Icons.close_rounded,
              color: AppDesign.errorRed,
              semanticLabel: 'passed'.tr,
              size: 56,
              onPressed: onPass,
            ),
            const SizedBox(width: 20),
            _ActionCircleButton(
              key: const ValueKey('qa.discover.action.details'),
              icon: Icons.info_outline_rounded,
              color: AppDesign.primaryYellow,
              semanticLabel: 'view_details'.tr,
              size: 48,
              onPressed: onDetails,
            ),
            const SizedBox(width: 20),
            _ActionCircleButton(
              key: const ValueKey('qa.discover.action.like'),
              icon: Icons.favorite_rounded,
              color: AppDesign.successGreen,
              semanticLabel: 'liked'.tr,
              size: 56,
              onPressed: onLike,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCircleButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String semanticLabel;
  final double size;
  final VoidCallback? onPressed;

  const _ActionCircleButton({
    super.key,
    required this.icon,
    required this.color,
    required this.semanticLabel,
    required this.size,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: AppDesign.darkTextPrimary.withValues(alpha: 0.88),
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: AppDesign.shadowColor,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: color, size: size * 0.42),
          ),
        ),
      ),
    );
  }
}
