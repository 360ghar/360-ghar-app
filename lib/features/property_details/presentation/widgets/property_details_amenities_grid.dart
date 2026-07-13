import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_section_header.dart';

class PropertyDetailsAmenitiesGrid extends StatefulWidget {
  const PropertyDetailsAmenitiesGrid({super.key, required this.property});

  final PropertyModel property;

  @override
  State<PropertyDetailsAmenitiesGrid> createState() => _PropertyDetailsAmenitiesGridState();
}

class _PropertyDetailsAmenitiesGridState extends State<PropertyDetailsAmenitiesGrid> {
  static const int _collapsedCount = 9;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final amenities = widget.property.amenities ?? const <PropertyAmenity>[];
    if (amenities.isEmpty) return const SizedBox.shrink();

    final canExpand = amenities.length > _collapsedCount;
    final visible = (!_expanded && canExpand)
        ? amenities.take(_collapsedCount).toList()
        : amenities;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PropertyDetailsSectionHeader('amenities'.tr),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visible.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.05,
          ),
          itemBuilder: (context, index) => _AmenityTile(amenity: visible[index]),
        ),
        if (canExpand) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              alignment: Alignment.centerLeft,
              foregroundColor: AppDesign.primaryYellow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _expanded
                      ? 'show_less_amenities'.tr
                      : 'more_amenities'.trParams({
                          'count': '${amenities.length - _collapsedCount}',
                        }),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppDesign.primaryYellow,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: AppDesign.primaryYellow,
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _AmenityTile extends StatelessWidget {
  const _AmenityTile({required this.amenity});

  final PropertyAmenity amenity;

  @override
  Widget build(BuildContext context) {
    final iconUrl = amenity.icon;
    final hasNetworkIcon = iconUrl != null && iconUrl.startsWith('http');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppDesign.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        border: Border.all(color: AppDesign.border.withValues(alpha: 0.75)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (hasNetworkIcon)
            CachedNetworkImage(
              imageUrl: iconUrl,
              width: 22,
              height: 22,
              errorWidget: (_, _, _) =>
                  const Icon(Icons.check_circle_outline, size: 22, color: AppDesign.primaryYellow),
            )
          else
            const Icon(Icons.check_circle_outline, size: 22, color: AppDesign.primaryYellow),
          const SizedBox(height: 8),
          Text(
            amenity.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppDesign.textPrimary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
