import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/app_design_tokens.dart';
import 'package:ghar360/core/map/mini_map_view.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/widgets/common/robust_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

/// The scrollable details section below the hero image in a swipe card.
///
/// Order: highlights → property details → amenities → description → 360 → map.
class SwipeCardDetailsSection extends StatelessWidget {
  final PropertyModel property;
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;

  const SwipeCardDetailsSection({
    super.key,
    required this.property,
    this.onInteractionStart,
    this.onInteractionEnd,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((property.features?.isNotEmpty ?? false)) ..._buildHighlights(context),

            _buildPropertyDetailsCard(context),
            const SizedBox(height: AppSpacing.lg),

            if (property.hasAmenities) ..._buildAmenities(context),

            _ExpandableDescription(description: property.description),
            const SizedBox(height: AppSpacing.lg),

            if (property.virtualTourUrl != null && property.virtualTourUrl!.isNotEmpty)
              ..._buildVirtualTour(context),

            if (property.hasLocation) ..._buildLocationSection(context),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, {required IconData icon, required String title}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppDesign.primaryYellow.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppBorderRadius.sm),
          ),
          child: Icon(icon, size: 18, color: AppDesign.primaryYellow),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildHighlights(BuildContext context) {
    final theme = Theme.of(context);

    return [
      _sectionHeader(context, icon: Icons.auto_awesome, title: 'highlights'.tr),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: (property.features ?? [])
            .take(6)
            .map(
              (t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppDesign.accentOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppBorderRadius.round),
                  border: Border.all(color: AppDesign.accentOrange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 16, color: AppDesign.accentOrange),
                    const SizedBox(width: 6),
                    Text(
                      t,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppDesign.accentOrange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: AppSpacing.lg),
    ];
  }

  List<Widget> _buildAmenities(BuildContext context) {
    final theme = Theme.of(context);
    final amenities = property.amenitiesData;
    const maxVisible = 8;

    return [
      _sectionHeader(context, icon: Icons.spa_outlined, title: 'amenities'.tr),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: amenities
            .take(maxVisible)
            .map((amenity) => _AmenityChip(amenity: amenity))
            .toList(),
      ),
      if (amenities.length > maxVisible)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'more_amenities'.trParams({'count': '${amenities.length - maxVisible}'}),
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppDesign.accentBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      const SizedBox(height: AppSpacing.lg),
    ];
  }

  List<Widget> _buildVirtualTour(BuildContext context) {
    final theme = Theme.of(context);

    return [
      _sectionHeader(context, icon: Icons.threesixty, title: 'virtual_tour_title'.tr),
      const SizedBox(height: 8),
      Material(
        color: AppDesign.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          onTap: () {
            Get.toNamed(AppRoutes.tour, arguments: property.virtualTourUrl);
          },
          child: Ink(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              border: Border.all(color: AppDesign.border),
              boxShadow: [
                BoxShadow(
                  color: AppDesign.shadowColor,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RobustNetworkImage(
                    imageUrl: property.mainImage,
                    fit: BoxFit.cover,
                    memCacheWidth: 800,
                    memCacheHeight: 400,
                  ),
                  Container(color: AppDesign.shadowColor.withValues(alpha: 0.45)),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppDesign.primaryYellow,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppDesign.shadowColor,
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.threesixty,
                            color: AppDesignTokens.neutral900,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'tap_to_load_virtual_tour'.tr,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppDesign.darkTextPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'fullscreen_mode'.tr,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppDesign.darkTextPrimary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
    ];
  }

  Widget _buildPropertyDetailsCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final metrics = <_MetricTile>[];
    if (property.bedrooms != null) {
      metrics.add(
        _MetricTile(icon: Icons.bed_outlined, value: '${property.bedrooms}', label: 'bedrooms'.tr),
      );
    }
    if (property.bathrooms != null) {
      metrics.add(
        _MetricTile(
          icon: Icons.bathtub_outlined,
          value: '${property.bathrooms}',
          label: 'bathrooms'.tr,
        ),
      );
    }
    if (property.areaSqft != null) {
      metrics.add(_MetricTile(icon: Icons.square_foot, value: property.areaText, label: 'area'.tr));
    }
    if (property.parkingSpaces != null) {
      metrics.add(
        _MetricTile(
          icon: Icons.local_parking,
          value: '${property.parkingSpaces}',
          label: 'parking'.tr,
        ),
      );
    }
    if (property.floorText.isNotEmpty) {
      metrics.add(
        _MetricTile(icon: Icons.layers_outlined, value: property.floorText, label: 'floor'.tr),
      );
    }
    if (property.balconies != null) {
      metrics.add(
        _MetricTile(
          icon: Icons.balcony_outlined,
          value: '${property.balconies}',
          label: 'balconies'.tr,
        ),
      );
    }

    final secondary = <_DetailFact>[
      _DetailFact(
        icon: Icons.apartment_outlined,
        label: 'property_type'.tr,
        value: property.propertyTypeTranslationKey.tr,
      ),
      _DetailFact(
        icon: Icons.sell_outlined,
        label: 'purpose'.tr,
        value: property.purposeTranslationKey.tr,
      ),
      if (property.genderPreferenceTranslationKey != null)
        _DetailFact(
          icon: Icons.people_outline,
          label: 'gender_preference'.tr,
          value: property.genderPreferenceTranslationKey!.tr,
        ),
      if (property.sharingTypeTranslationKey != null)
        _DetailFact(
          icon: Icons.meeting_room_outlined,
          label: 'room_type'.tr,
          value: property.sharingTypeTranslationKey!.tr,
        ),
      if (property.ageText.isNotEmpty)
        _DetailFact(icon: Icons.calendar_today_outlined, label: 'age'.tr, value: property.ageText),
      if (property.distanceKm != null)
        _DetailFact(
          icon: Icons.near_me_outlined,
          label: 'distance'.tr,
          value: property.distanceText,
        ),
      _DetailFact(
        icon: Icons.location_on_outlined,
        label: 'location'.tr,
        value: property.shortAddressDisplay,
      ),
      if (property.builderName?.isNotEmpty == true)
        _DetailFact(
          icon: Icons.business_outlined,
          label: 'builder'.tr,
          value: property.builderName!,
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        border: Border.all(color: AppDesign.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, icon: Icons.home_work_outlined, title: 'property_details'.tr),
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth >= 360 ? 3 : 2;
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.45,
                  children: metrics
                      .map(
                        (m) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(AppBorderRadius.md),
                            border: Border.all(color: AppDesign.border.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(m.icon, size: 22, color: AppDesign.primaryYellow),
                              const SizedBox(height: 6),
                              Text(
                                m.value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                m.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
          if (secondary.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...secondary.map((fact) => _buildIconDetailRow(context, fact)),
          ],
        ],
      ),
    );
  }

  Widget _buildIconDetailRow(BuildContext context, _DetailFact fact) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(fact.icon, size: 18, color: colorScheme.onSurface.withValues(alpha: 0.55)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fact.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              fact.value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLocationSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return [
      _sectionHeader(context, icon: Icons.map_outlined, title: 'location'.tr),
      const SizedBox(height: 8),
      Container(
        height: 180,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          border: Border.all(color: AppDesign.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: MiniMapView(latitude: property.latitude!, longitude: property.longitude!),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => _openGoogleMaps(property.latitude!, property.longitude!, property.title),
          icon: const Icon(Icons.directions),
          label: Text('get_directions'.tr),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppDesign.primaryYellow)),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
    ];
  }
}

class _MetricTile {
  final IconData icon;
  final String value;
  final String label;

  const _MetricTile({required this.icon, required this.value, required this.label});
}

class _DetailFact {
  final IconData icon;
  final String label;
  final String value;

  const _DetailFact({required this.icon, required this.label, required this.value});
}

/// Collapsible description: ~5 lines with read more / read less.
class _ExpandableDescription extends StatefulWidget {
  final String? description;

  const _ExpandableDescription({required this.description});

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  static const int _collapsedLines = 5;
  static const int _expandThresholdChars = 140;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final raw = widget.description?.trim() ?? '';
    final hasDescription = raw.isNotEmpty;
    final text = hasDescription ? raw : 'no_description_available'.tr;
    final canCollapse = hasDescription && raw.length > _expandThresholdChars;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppDesign.primaryYellow.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppBorderRadius.sm),
              ),
              child: const Icon(Icons.notes_outlined, size: 18, color: AppDesign.primaryYellow),
            ),
            const SizedBox(width: 10),
            Text(
              'description'.tr,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          text,
          maxLines: canCollapse && !_expanded ? _collapsedLines : null,
          overflow: canCollapse && !_expanded ? TextOverflow.ellipsis : TextOverflow.visible,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.7),
            height: 1.5,
          ),
        ),
        if (canCollapse) ...[
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              minimumSize: const Size(44, 44),
              alignment: Alignment.centerLeft,
            ),
            child: Text(
              _expanded ? 'read_less'.tr : 'read_more'.tr,
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppDesign.primaryYellow,
                decoration: TextDecoration.underline,
                decorationColor: AppDesign.primaryYellow,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AmenityChip extends StatelessWidget {
  final PropertyAmenity amenity;

  const _AmenityChip({required this.amenity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconUrl = amenity.icon;
    final hasNetworkIcon =
        iconUrl != null && (iconUrl.startsWith('http://') || iconUrl.startsWith('https://'));

    final Widget leading = hasNetworkIcon
        ? CachedNetworkImage(
            imageUrl: iconUrl,
            width: 16,
            height: 16,
            errorWidget: (_, _, _) =>
                Icon(_amenityIconForTitle(amenity.title), size: 16, color: AppDesign.accentBlue),
          )
        : Icon(_amenityIconForTitle(amenity.title), size: 16, color: AppDesign.accentBlue);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppDesign.accentBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppBorderRadius.round),
        border: Border.all(color: AppDesign.accentBlue.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 6),
          Text(
            amenity.title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppDesign.accentBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _amenityIconForTitle(String title) {
  final t = title.toLowerCase();
  if (t.contains('pool') || t.contains('swim')) return Icons.pool;
  if (t.contains('gym') || t.contains('fitness')) return Icons.fitness_center;
  if (t.contains('park')) return Icons.local_parking;
  if (t.contains('wifi') || t.contains('internet')) return Icons.wifi;
  if (t.contains('security') || t.contains('cctv') || t.contains('guard')) {
    return Icons.security;
  }
  if (t.contains('lift') || t.contains('elevator')) return Icons.elevator;
  if (t.contains('garden') || t.contains('lawn') || t.contains('park ')) {
    return Icons.yard_outlined;
  }
  if (t.contains('power') || t.contains('backup') || t.contains('generator')) {
    return Icons.bolt;
  }
  if (t.contains('club') || t.contains('community')) return Icons.groups_outlined;
  if (t.contains('play') || t.contains('kids') || t.contains('child')) {
    return Icons.child_care_outlined;
  }
  if (t.contains('ac') || t.contains('air')) return Icons.ac_unit;
  if (t.contains('water')) return Icons.water_drop_outlined;
  if (t.contains('pet')) return Icons.pets;
  if (t.contains('furnish')) return Icons.chair_outlined;
  if (t.contains('balcony')) return Icons.balcony_outlined;
  return Icons.check_circle_outline;
}

Future<void> _openGoogleMaps(double latitude, double longitude, String label) async {
  final url = Uri.parse(
    'https://www.google.com/maps/dir/?api=1'
    '&destination=$latitude,$longitude&travelmode=driving',
  );
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  } else {
    AppToast.warning('unable_to_open_maps'.tr, 'check_device_settings'.tr);
  }
}
