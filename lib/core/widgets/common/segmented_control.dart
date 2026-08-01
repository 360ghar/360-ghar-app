import 'package:flutter/material.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/app_spacing.dart';

class SegmentItem {
  final String label;
  final int? badge;
  final String? semanticsLabel;
  final String? semanticsIdentifier;

  const SegmentItem({
    required this.label,
    this.badge,
    this.semanticsLabel,
    this.semanticsIdentifier,
  });
}

class SegmentedControl extends StatelessWidget {
  final int selectedIndex;
  final List<SegmentItem> segments;
  final ValueChanged<int>? onSegmentChanged;

  const SegmentedControl({
    super.key,
    required this.selectedIndex,
    required this.segments,
    this.onSegmentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppDesign.inputBackground,
        borderRadius: BorderRadius.circular(AppBorderRadius.button),
      ),
      child: Row(
        children: List.generate(segments.length, (index) {
          final segment = segments[index];
          final isSelected = index == selectedIndex;
          return Expanded(
            child: _buildSegment(index: index, segment: segment, isSelected: isSelected),
          );
        }),
      ),
    );
  }

  Widget _buildSegment({
    required int index,
    required SegmentItem segment,
    required bool isSelected,
  }) {
    return Semantics(
      button: onSegmentChanged != null,
      selected: isSelected,
      label: segment.semanticsLabel ?? segment.label,
      identifier: segment.semanticsIdentifier,
      child: InkWell(
        onTap: onSegmentChanged == null ? null : () => onSegmentChanged!.call(index),
        borderRadius: BorderRadius.circular(AppBorderRadius.button - 2),
        child: AnimatedContainer(
          duration: AppDurations.tabPill,
          curve: AppCurves.tabPill,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppDesign.primaryYellow : AppDesign.transparent,
            borderRadius: BorderRadius.circular(AppBorderRadius.button - 2),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppDesign.primaryYellow.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  segment.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? AppDesign.buttonText : AppDesign.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (segment.badge != null && segment.badge! > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppDesign.buttonText.withValues(alpha: 0.2)
                        : AppDesign.textTertiary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${segment.badge}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppDesign.buttonText : AppDesign.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
