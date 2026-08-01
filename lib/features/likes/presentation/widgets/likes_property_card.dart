import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/widgets/common/animated_tap_wrapper.dart';
import 'package:ghar360/core/widgets/common/robust_network_image.dart';

class LikesPropertyCard extends StatelessWidget {
  final PropertyModel property;
  final bool isFavourite;
  final bool isUpdating;
  final VoidCallback onFavouriteToggle;

  const LikesPropertyCard({
    super.key,
    required this.property,
    required this.isFavourite,
    this.isUpdating = false,
    required this.onFavouriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedTapWrapper(
      key: ValueKey('qa.likes.card.${property.id}'),
      onTap: () => Get.toNamed(AppRoutes.propertyDetails, arguments: property),
      child: Container(
        decoration: BoxDecoration(
          color: AppDesign.propertyCardBackground,
          borderRadius: BorderRadius.circular(AppBorderRadius.card),
          border: Border.all(color: AppDesign.border.withValues(alpha: 0.3), width: 1),
          boxShadow: AppDesign.getCardShadow(),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 100,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Hero(
                      tag: 'property_image_${property.id}',
                      child: RobustNetworkImage(
                        imageUrl: property.mainImage,
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppBorderRadius.card),
                        ),
                        memCacheWidth: 200,
                        memCacheHeight: 100,
                        placeholder: Container(
                          height: 100,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppDesign.inputBackground,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(AppBorderRadius.card),
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: colorScheme.primary,
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'loading'.tr,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppDesign.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(AppBorderRadius.chip),
                        boxShadow: [
                          BoxShadow(
                            color: AppDesign.shadowColor,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        property.propertyTypeTranslationKey.tr.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.scrim.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: isUpdating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : AnimatedFavoriteIcon(
                              isFavorite: isFavourite,
                              onToggle: onFavouriteToggle,
                              size: 18,
                              activeColor: AppDesign.favoriteActive,
                              inactiveColor: colorScheme.onPrimary,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppDesign.propertyCardText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    property.formattedPrice,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppDesign.propertyCardPrice,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    property.addressDisplay,
                    style: TextStyle(fontSize: 11, color: AppDesign.propertyCardSubtext),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      if (property.bedroomBathroomText.isNotEmpty) ...[
                        Icon(Icons.bed_outlined, size: 12, color: AppDesign.propertyFeatureText),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            property.bedroomBathroomText,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppDesign.propertyFeatureText,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (property.areaText.isNotEmpty) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Icon(Icons.square_foot, size: 12, color: AppDesign.propertyFeatureText),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            property.areaText,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppDesign.propertyFeatureText,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
