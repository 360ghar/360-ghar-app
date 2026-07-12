import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_tokens.dart';
import 'package:ghar360/core/utils/app_spacing.dart';

class PropertyMarkerChip extends StatefulWidget {
  final PropertyModel property;
  final bool isSelected;
  final VoidCallback onTap;
  final String label;

  const PropertyMarkerChip({
    super.key,
    required this.property,
    required this.isSelected,
    required this.onTap,
    required this.label,
  });

  @override
  State<PropertyMarkerChip> createState() => _PropertyMarkerChipState();
}

class _PropertyMarkerChipState extends State<PropertyMarkerChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: AppDurations.markerPulse);
    if (widget.isSelected) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(PropertyMarkerChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _pulseController.repeat();
    } else if (!widget.isSelected && oldWidget.isSelected) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool selected = widget.isSelected;

    final Color bg = selected
        ? AppDesignTokens.brandGold
        : isDark
        ? AppDesignTokens.brandGold.withValues(alpha: 0.25)
        : AppDesignTokens.brandGoldSubtle;
    final Color borderColor = isDark ? AppDesignTokens.darkBorder : AppDesignTokens.neutral300;
    final Color textColor = isDark ? AppDesignTokens.darkTextPrimary : AppDesignTokens.neutral900;

    final semanticLabel = widget.property.title.isNotEmpty
        ? 'property_price_marker_label'.trParams({'property': widget.property.title})
        : 'property_price_marker_label_generic'.tr;

    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: RepaintBoundary(
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Pulse circle (only when selected)
              if (selected)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _MarkerPulsePainter(
                          progress: _pulseController.value,
                          color: AppDesignTokens.brandGold,
                        ),
                      );
                    },
                  ),
                ),
              // Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                constraints: const BoxConstraints(minHeight: 44, minWidth: 44, maxWidth: 120),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: borderColor, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: AppDesignTokens.neutral500.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints a single expanding/fading circle for the marker pulse effect.
class _MarkerPulsePainter extends CustomPainter {
  final double progress;
  final Color color;

  _MarkerPulsePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 2;
    final radius = baseRadius + (baseRadius * 0.6 * progress);
    final opacity = (1.0 - progress) * 0.35;

    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_MarkerPulsePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
