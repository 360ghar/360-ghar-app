import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/utils/share_utils.dart';
import 'package:ghar360/core/widgets/common/robust_network_image.dart';

/// The hero image section of a swipe card, including the property image
/// gallery, gradient overlays, share button, type badge, price/title/specs
/// overlay, and the "view details" / scroll indicator.
class SwipeCardHeroSection extends StatefulWidget {
  final PropertyModel property;
  final VoidCallback? onViewDetails;

  const SwipeCardHeroSection({super.key, required this.property, this.onViewDetails});

  @override
  State<SwipeCardHeroSection> createState() => _SwipeCardHeroSectionState();
}

class _SwipeCardHeroSectionState extends State<SwipeCardHeroSection> {
  late final PageController _pageController;
  int _pageIndex = 0;

  PropertyModel get property => widget.property;

  List<String> get _imageUrls {
    final gallery = property.galleryImageUrls;
    if (gallery.isNotEmpty) return gallery;
    if (property.mainImage.isNotEmpty) return [property.mainImage];
    return const <String>[];
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final heroHeight = math.min(screenSize.height * 0.78, 680.0);
    final memWidth = (screenSize.width * dpr).round().clamp(320, 1600);
    final memHeight = (heroHeight * dpr).round().clamp(480, 2000);
    final images = _imageUrls;

    return SizedBox(
      height: heroHeight,
      child: Stack(
        children: [
          // Main property image(s)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onViewDetails,
              child: images.isEmpty
                  ? Container(
                      color: AppDesign.surface,
                      child: Icon(Icons.home_work_outlined, color: colorScheme.error, size: 48),
                    )
                  : images.length == 1
                  ? RobustNetworkImage(
                      imageUrl: images.first,
                      fit: BoxFit.cover,
                      memCacheWidth: memWidth,
                      memCacheHeight: memHeight,
                      placeholder: _imagePlaceholder(colorScheme),
                      errorWidget: _imageError(colorScheme),
                    )
                  // NeverScrollableScrollPhysics avoids fighting the deck's
                  // horizontal like/pass drag. Users page with chevrons.
                  : PageView.builder(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: images.length,
                      onPageChanged: (i) => setState(() => _pageIndex = i),
                      itemBuilder: (context, index) {
                        return RobustNetworkImage(
                          imageUrl: images[index],
                          fit: BoxFit.cover,
                          memCacheWidth: memWidth,
                          memCacheHeight: memHeight,
                          placeholder: _imagePlaceholder(colorScheme),
                          errorWidget: _imageError(colorScheme),
                        );
                      },
                    ),
            ),
          ),

          // Gradient overlay for text readability
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppDesign.transparent, AppDesign.shadowColor.withValues(alpha: 0.85)],
                    stops: const [0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Gallery chevrons (when multi-image)
          if (images.length > 1) ...[
            if (_pageIndex > 0)
              Positioned(
                left: AppSpacing.sm,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _galleryChevron(
                    icon: Icons.chevron_left_rounded,
                    semanticLabel: 'previous_photo'.tr,
                    onTap: () {
                      _pageController.previousPage(
                        duration: AppDurations.fast,
                        curve: AppCurves.standard,
                      );
                    },
                  ),
                ),
              ),
            if (_pageIndex < images.length - 1)
              Positioned(
                right: AppSpacing.sm,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _galleryChevron(
                    icon: Icons.chevron_right_rounded,
                    semanticLabel: 'next_photo'.tr,
                    onTap: () {
                      _pageController.nextPage(
                        duration: AppDurations.fast,
                        curve: AppCurves.standard,
                      );
                    },
                  ),
                ),
              ),
            Positioned(
              top: 56,
              right: 16,
              child: _photoCountBadge(context, _pageIndex + 1, images.length),
            ),
          ],

          // Share button (44×44 target, light icon on dark overlay)
          Positioned(
            top: 12,
            right: 12,
            child: Semantics(
              button: true,
              label: 'share_property'.tr,
              child: Material(
                color: AppDesign.shadowColor.withValues(alpha: 0.55),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => ShareUtils.shareProperty(property, context: context),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.share, color: AppDesign.darkTextPrimary, size: 20),
                  ),
                ),
              ),
            ),
          ),

          // Property type badge + media badges
          Positioned(
            top: 16,
            left: 16,
            right: 72,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [_typeBadge(context), ..._mediaBadges(context)],
            ),
          ),

          // Property details overlay at bottom
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomOverlay(context)),
        ],
      ),
    );
  }

  Widget _imagePlaceholder(ColorScheme colorScheme) {
    return Container(
      color: AppDesign.inputBackground,
      child: Center(child: CircularProgressIndicator(color: colorScheme.primary)),
    );
  }

  Widget _imageError(ColorScheme colorScheme) {
    return Container(
      color: AppDesign.surface,
      child: Icon(Icons.error, color: colorScheme.error),
    );
  }

  Widget _galleryChevron({
    required IconData icon,
    required VoidCallback onTap,
    required String semanticLabel,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: AppDesign.shadowColor.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: AppDesign.darkTextPrimary, size: 28),
          ),
        ),
      ),
    );
  }

  Widget _photoCountBadge(BuildContext context, int current, int total) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppDesign.shadowColor.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
      ),
      child: Text(
        '$current/$total',
        style: theme.textTheme.labelMedium?.copyWith(
          color: AppDesign.darkTextPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _typeBadge(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppDesign.shadowColor.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.apartment, color: AppDesign.darkTextPrimary, size: 16),
          const SizedBox(width: 6),
          Text(
            property.propertyTypeTranslationKey.tr,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppDesign.darkTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _mediaBadges(BuildContext context) {
    final theme = Theme.of(context);
    final badges = <Widget>[];

    void add(IconData icon, String label) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: AppDesign.shadowColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
            border: Border.all(color: AppDesign.primaryYellow.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: AppDesign.primaryYellow),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppDesign.darkTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final photoCount = _imageUrls.length;
    if (photoCount > 1) {
      add(Icons.photo_library_outlined, '$photoCount');
    }
    if (property.hasVirtualTour) {
      add(Icons.threesixty, '360°');
    }
    if (property.hasVideos || property.hasVideoTour) {
      add(Icons.videocam_outlined, 'video'.tr);
    }
    if (property.hasFloorPlan) {
      add(Icons.apartment, 'floor_plan'.tr);
    }

    return badges;
  }

  Widget _buildBottomOverlay(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppDesign.shadowColor.withValues(alpha: 0.0),
            AppDesign.shadowColor.withValues(alpha: 0.65),
            AppDesign.shadowColor.withValues(alpha: 0.9),
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPriceRow(context),
          const SizedBox(height: 4),
          Text(
            property.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppDesign.darkTextPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: AppDesign.darkTextPrimary.withValues(alpha: 0.7),
                size: 16,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  property.shortAddressDisplay,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppDesign.darkTextPrimary.withValues(alpha: 0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildPrimarySpecs(context),
          const SizedBox(height: 14),
          _buildViewDetailsCta(context),
        ],
      ),
    );
  }

  Widget _buildPriceRow(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppDesign.darkTextPrimary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              children: [
                TextSpan(text: property.formattedPrice),
                if (property.purpose == PropertyPurpose.rent)
                  TextSpan(
                    text: 'per_month_short'.tr,
                    style: TextStyle(
                      color: AppDesign.darkTextPrimary.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (property.purpose == PropertyPurpose.shortStay)
                  TextSpan(
                    text: 'per_day_short'.tr,
                    style: TextStyle(
                      color: AppDesign.darkTextPrimary.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
          ),
          child: Text(
            property.listingTranslationKey.tr,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  /// Primary specs only (BHK, bath, area) to keep the hero readable.
  Widget _buildPrimarySpecs(BuildContext context) {
    final specs = <Widget>[];

    if (property.bedrooms != null) {
      specs.add(
        _buildSpecPill(
          context,
          icon: Icons.bed_outlined,
          label: 'bedrooms_short'.trParams({'count': '${property.bedrooms}'}),
        ),
      );
    }
    if (property.bathrooms != null) {
      specs.add(
        _buildSpecPill(
          context,
          icon: Icons.bathtub_outlined,
          label: 'bathrooms_short'.trParams({'count': '${property.bathrooms}'}),
        ),
      );
    }
    if (property.areaText.isNotEmpty) {
      specs.add(_buildSpecPill(context, icon: Icons.square_foot, label: property.areaText));
    }
    if (specs.isEmpty) {
      specs.add(_buildSpecPill(context, icon: Icons.info_outline, label: 'property_label'.tr));
    }

    return Wrap(spacing: 8, runSpacing: 6, children: specs);
  }

  Widget _buildViewDetailsCta(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Material(
        color: colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppBorderRadius.round),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppBorderRadius.round),
          onTap: widget.onViewDetails,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline_rounded, color: colorScheme.onSurface, size: 16),
                const SizedBox(width: 6),
                Text(
                  'view_details'.tr,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down, color: colorScheme.onSurface, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecPill(BuildContext context, {required IconData icon, required String label}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppDesign.darkTextPrimary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppDesign.darkTextPrimary.withValues(alpha: 0.9)),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppDesign.darkTextPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
