import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/app_spacing.dart';

enum PropertyDetailsSection { overview, media, specs, location }

class PropertyDetailsSectionNav extends StatelessWidget {
  const PropertyDetailsSectionNav({
    super.key,
    required this.active,
    required this.onSelect,
    this.showMedia = true,
    this.showLocation = true,
  });

  final PropertyDetailsSection active;
  final ValueChanged<PropertyDetailsSection> onSelect;
  final bool showMedia;
  final bool showLocation;

  @override
  Widget build(BuildContext context) {
    final sections = <({PropertyDetailsSection id, String label})>[
      (id: PropertyDetailsSection.overview, label: 'section_overview'.tr),
      if (showMedia) (id: PropertyDetailsSection.media, label: 'section_media'.tr),
      (id: PropertyDetailsSection.specs, label: 'section_specs'.tr),
      if (showLocation) (id: PropertyDetailsSection.location, label: 'section_location'.tr),
    ];

    return Container(
      color: AppDesign.scaffoldBackground,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < sections.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _SectionChip(
                label: sections[i].label,
                selected: sections[i].id == active,
                onTap: () => onSelect(sections[i].id),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionChip extends StatelessWidget {
  const _SectionChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppDesign.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppBorderRadius.round),
        child: AnimatedContainer(
          duration: AppDurations.tabPill,
          curve: AppCurves.tabPill,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppDesign.primaryYellow : AppDesign.inputBackground,
            borderRadius: BorderRadius.circular(AppBorderRadius.round),
            border: Border.all(
              color: selected
                  ? AppDesign.primaryYellowDark.withValues(alpha: 0.4)
                  : AppDesign.border.withValues(alpha: 0.6),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? AppDesign.buttonText : AppDesign.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
