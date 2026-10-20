import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/map/mini_map_view.dart';
import 'package:ghar360/core/presentation/property_labels.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/widgets/common/robust_network_image.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/core/widgets/property/property_facts.dart';

/// The scrollable half of a swipe card below the photo. Dense and flat:
/// highlights, the facts, amenities, description, the 360° tour and the map.
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
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final design = context.design;
    final features = property.features ?? const [];
    return ColoredBox(
      color: design.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (features.isNotEmpty) ...[
              SectionTitle(l10n.text('highlights')),
              for (final feature in features.take(6))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PaperIcon(KnifeIcon.star, size: 16, color: design.accent),
                      const SizedBox(width: 10),
                      Expanded(child: Text(feature, style: text.bodyMedium)),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
            ],
            SectionTitle(l10n.text('property_details')),
            FactGrid(facts: keyFacts(context, property)),
            const SizedBox(height: 16),
            FactRows(facts: _secondaryFacts(context)),
            const SizedBox(height: AppSpacing.lg),
            if (property.hasAmenities) ...[
              SectionTitle(l10n.text('amenities')),
              AmenityList(
                amenities: property.amenitiesData,
                max: 8,
                moreLabel: (hidden) => l10n.text('more_amenities', params: {'count': '$hidden'}),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            _ExpandableDescription(description: property.description),
            const SizedBox(height: AppSpacing.lg),
            if (property.virtualTourUrl?.isNotEmpty == true) ...[
              SectionTitle(l10n.text('virtual_tour_title')),
              _TourPreview(property: property),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (property.hasLocation) ...[
              SectionTitle(
                l10n.text('location'),
                trailing: TextButton(
                  onPressed: () => _openDirections(context, property),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text(l10n.text('get_directions'))),
                      const SizedBox(width: 6),
                      const PaperIcon(KnifeIcon.arrowUpRight, size: 16),
                    ],
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
                child: SizedBox(
                  height: 180,
                  child: MiniMapView(latitude: property.latitude!, longitude: property.longitude!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Fact> _secondaryFacts(BuildContext context) {
    final l10n = context.l10n;
    return [
      Fact(
        KnifeIcon.building,
        l10n.text(property.propertyTypeLabelKey),
        l10n.text('property_type'),
      ),
      Fact(KnifeIcon.rupee, l10n.text(property.purposeTranslationKey), l10n.text('purpose')),
      if (property.genderPreferenceTranslationKey case final key?)
        Fact(KnifeIcon.guests, l10n.text(key), l10n.text('gender_preference')),
      if (property.sharingTypeTranslationKey case final key?)
        Fact(KnifeIcon.sofa, l10n.text(key), l10n.text('room_type')),
      if (property.localizedAge(context).isNotEmpty)
        Fact(KnifeIcon.age, property.localizedAge(context), l10n.text('age')),
      if (property.distanceKm != null)
        Fact(KnifeIcon.locate, property.localizedDistance(context), l10n.text('distance')),
      if (property.shortAddressDisplay.isNotEmpty)
        Fact(KnifeIcon.pin, property.shortAddressDisplay, l10n.text('location')),
      if (property.builderName?.isNotEmpty == true)
        Fact(KnifeIcon.briefcase, property.builderName!, l10n.text('builder')),
    ];
  }
}

/// The numbers of a home, shared by the swipe card and the details screen.
List<Fact> keyFacts(BuildContext context, PropertyModel property) {
  final l10n = context.l10n;
  return [
    if (property.bedrooms != null)
      Fact(KnifeIcon.bed, '${property.bedrooms}', l10n.text('bedrooms')),
    if (property.bathrooms != null)
      Fact(KnifeIcon.bath, '${property.bathrooms}', l10n.text('bathrooms')),
    if (property.areaSqft != null)
      Fact(KnifeIcon.area, property.localizedArea(context), l10n.text('area')),
    if (property.parkingSpaces != null)
      Fact(KnifeIcon.parking, '${property.parkingSpaces}', l10n.text('parking')),
    if (property.localizedFloor(context).isNotEmpty)
      Fact(KnifeIcon.floor, property.localizedFloor(context), l10n.text('floor')),
    if (property.balconies != null)
      Fact(KnifeIcon.balcony, '${property.balconies}', l10n.text('balconies')),
  ];
}

/// The main photo with the 360° mark; opens the tour full screen.
class _TourPreview extends StatelessWidget {
  const _TourPreview({required this.property});
  final PropertyModel property;

  static const _onPhoto = [Shadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(0, 1))];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const ink = Color(0xFFFFFFFF);
    return Semantics(
      button: true,
      label: context.l10n.text('tap_to_load_virtual_tour'),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.tour, extra: property.virtualTourUrl),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          child: SizedBox(
            height: 200,
            child: Stack(
              fit: StackFit.expand,
              children: [
                RobustNetworkImage(
                  imageUrl: property.mainImage,
                  fit: BoxFit.cover,
                  memCacheWidth: 800,
                  memCacheHeight: 400,
                ),
                const ColoredBox(color: Color(0x66000000)),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PaperIcon(KnifeIcon.tour, size: 44, color: ink, shadows: _onPhoto),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.text('tap_to_load_virtual_tour'),
                        style: text.labelLarge?.copyWith(color: ink, shadows: _onPhoto),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.text('fullscreen_mode'),
                        style: text.labelSmall?.copyWith(
                          color: ink.withValues(alpha: .85),
                          shadows: _onPhoto,
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
    );
  }
}

/// About five lines, with read more and read less.
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
    final raw = widget.description?.trim() ?? '';
    final hasDescription = raw.isNotEmpty;
    final text = hasDescription ? raw : context.l10n.text('no_description_available');
    final canCollapse = hasDescription && raw.length > _expandThresholdChars;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(context.l10n.text('description')),
        Text(
          text,
          maxLines: canCollapse && !_expanded ? _collapsedLines : null,
          overflow: canCollapse && !_expanded ? TextOverflow.ellipsis : TextOverflow.visible,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: context.design.textSecondary,
            height: 1.55,
          ),
        ),
        if (canCollapse)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
              minimumSize: const Size(44, 44),
              alignment: Alignment.centerLeft,
            ),
            child: Text(context.l10n.text(_expanded ? 'read_less' : 'read_more')),
          ),
      ],
    );
  }
}

Future<void> _openDirections(BuildContext context, PropertyModel property) async {
  final url = Uri.parse(
    'https://www.google.com/maps/dir/?api=1'
    '&destination=${property.latitude},${property.longitude}&travelmode=driving',
  );
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  } else {
    if (!context.mounted) return;
    AppToast.warning(
      context.l10n.text('unable_to_open_maps'),
      context.l10n.text('check_device_settings'),
    );
  }
}
