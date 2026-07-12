import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/map/mini_map_view.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_section_header.dart';

class PropertyDetailsLocationCard extends StatelessWidget {
  const PropertyDetailsLocationCard({
    super.key,
    required this.property,
    required this.onOpenDirections,
  });

  final PropertyModel property;
  final VoidCallback onOpenDirections;

  @override
  Widget build(BuildContext context) {
    final lat = property.latitude;
    final lng = property.longitude;
    if (lat == null || lng == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PropertyDetailsSectionHeader('location'.tr),
        Container(
          decoration: BoxDecoration(
            color: AppDesign.surface,
            borderRadius: BorderRadius.circular(AppBorderRadius.card),
            border: Border.all(color: AppDesign.border.withValues(alpha: 0.75)),
            boxShadow: AppDesign.getCardShadow(),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 240,
                child: MiniMapView(latitude: lat, longitude: lng),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on_rounded, color: AppDesign.primaryYellow, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            property.shortAddressDisplay,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: AppDesign.textPrimary,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const ValueKey('qa.property_details.open_in_maps'),
                        onPressed: onOpenDirections,
                        icon: const Icon(Icons.directions_rounded, size: 20),
                        label: Text('directions'.tr),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppDesign.buttonText,
                          backgroundColor: AppDesign.primaryYellow,
                          side: BorderSide(
                            color: AppDesign.primaryYellowDark.withValues(alpha: 0.45),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppBorderRadius.button),
                          ),
                          textStyle: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
