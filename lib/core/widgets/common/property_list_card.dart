import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/design/paper/paper_cut.dart';
import 'package:ghar360/core/presentation/property_labels.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/widgets/common/animated_tap_wrapper.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/common/robust_network_image.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:go_router/go_router.dart';

/// The hero tag of a home's photo. The details gallery uses the same tag, so
/// the photo carries over when a home opens.
String propertyPhotoHeroTag(int id) => 'property-photo-$id';

/// One home in a list, as a listing print: the photo is a print with a
/// hand-cut edge, and the words sit on a white label. [row] puts a small
/// print beside the words (Saved); otherwise the label's cut top edge lies
/// over the foot of the photo (the Explore strip). No box, no chips, no lift.
class PropertyListCard extends StatelessWidget {
  final PropertyModel property;
  final bool isFavourite;
  final bool isUpdating;
  final VoidCallback onFavouriteToggle;

  /// Opens the home. When null, the card pushes the details route.
  final VoidCallback? onTap;

  /// The open or highlighted home: a mint slip under the words.
  final bool selected;
  final bool row;

  const PropertyListCard({
    super.key,
    required this.property,
    required this.isFavourite,
    this.isUpdating = false,
    required this.onFavouriteToggle,
    this.onTap,
    this.selected = false,
    this.row = false,
  });

  /// How far the label climbs over the photo, and the depth of its cut.
  static const double _labelOverlap = 18;
  static const double _cutDepth = 14;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    // Large text gets the full width: the print moves above the words.
    final beside = row && MediaQuery.textScalerOf(context).scale(14) <= 21;
    final label = selected ? design.slip : design.surface;
    final suffix = property.effectivePrice == null
        ? null
        : switch (property.purpose) {
            PropertyPurpose.rent => l10n.text('per_month_short'),
            PropertyPurpose.shortStay => l10n.text('per_day_short'),
            _ => null,
          };
    final area = property.localizedArea(context);
    final facts = [
      l10n.text(property.propertyTypeLabelKey),
      if (property.bedrooms != null)
        l10n.text('bedrooms_short', params: {'count': '${property.bedrooms}'}),
      if (property.bathrooms != null)
        l10n.text('bathrooms_short', params: {'count': '${property.bathrooms}'}),
      if (area.isNotEmpty) area,
    ].join(' · ');
    final quiet = text.bodySmall?.copyWith(color: design.textSecondary);

    // The heart is bare on the label: ink, or a solid brick heart when saved.
    final heart = SizedBox.square(
      dimension: 48,
      child: isUpdating
          ? Center(child: LoadingStates.buttonSpinner(color: design.textSecondary))
          : AnimatedFavoriteIcon(isFavorite: isFavourite, onToggle: onFavouriteToggle, size: 22),
    );

    final words = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: property.localizedPrice(context),
                      children: [if (suffix != null) TextSpan(text: suffix, style: quiet)],
                    ),
                    style: text.headlineSmall,
                  ),
                  Text(
                    property.title,
                    maxLines: beside ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall,
                  ),
                ],
              ),
            ),
            heart,
          ],
        ),
        Text(facts, maxLines: beside ? 2 : 1, overflow: TextOverflow.ellipsis, style: quiet),
        if (property.shortAddressDisplay.isNotEmpty)
          Text(
            property.shortAddressDisplay,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: quiet,
          ),
      ],
    );

    final empty = design.isDark ? design.raised : design.background;
    final print = Hero(
      tag: propertyPhotoHeroTag(property.id),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: CutBorder(seed: 'print-${property.id}', amp: 1.5)),
        child: RobustNetworkImage(
          imageUrl: property.mainImage,
          fit: BoxFit.cover,
          // Width only, so the photo keeps its shape when it is decoded.
          memCacheWidth: beside ? 360 : 600,
          placeholder: ColoredBox(color: empty),
          errorWidget: ColoredBox(
            color: empty,
            child: Center(child: PaperIcon(KnifeIcon.home, size: 28, color: design.textTertiary)),
          ),
        ),
      ),
    );

    final Widget body;
    if (beside) {
      body = DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? design.slip : AppDesign.transparent,
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 104, height: 88, child: print),
              const SizedBox(width: 12),
              Expanded(child: words),
            ],
          ),
        ),
      );
    } else {
      final photo = Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          print,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _labelOverlap,
            child: CustomPaint(
              painter: _LabelEdgePainter(
                seed: 'label-${property.id}',
                sheet: label,
                edge: design.sheetLip,
              ),
            ),
          ),
        ],
      );
      // The label's sides and foot are cut too; they show when it is a slip.
      final sheet = DecoratedBox(
        decoration: ShapeDecoration(
          color: label,
          shape: CutBorder(seed: 'label-${property.id}', amp: 1.5),
        ),
        child: Padding(padding: const EdgeInsets.fromLTRB(8, 0, 2, 8), child: words),
      );
      // In a fixed-height strip the photo takes the height the words leave,
      // so large text never overflows the card.
      body = LayoutBuilder(
        builder: (context, constraints) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (constraints.hasBoundedHeight)
              Expanded(child: photo)
            else
              SizedBox(height: 132, child: photo),
            sheet,
          ],
        ),
      );
    }

    return Semantics(
      button: true,
      selected: selected,
      container: true,
      child: AnimatedTapWrapper(
        key: ValueKey('qa.property.card.${property.id}'),
        onTap: onTap ?? () => context.push(AppRoutes.detailsFor(property.id), extra: property),
        child: body,
      ),
    );
  }
}

/// The label's hand-cut top edge over the foot of the photo. The edge shows
/// 1.5 px proud in the lip tone, so the label's thickness reads; no shadow.
/// The band runs 2 px into the label below, so their seam never shows.
class _LabelEdgePainter extends CustomPainter {
  const _LabelEdgePainter({required this.seed, required this.sheet, required this.edge});

  final String seed;
  final Color sheet;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    const depth = PropertyListCard._cutDepth;
    final band = parsePaperPath(
      cutBandPath(
        seed,
        width: size.width,
        height: depth,
        segments: math.max(6, (size.width / 28).round()),
      ),
      fillType: PathFillType.nonZero,
    )..addRect(Rect.fromLTRB(0, depth - 0.5, size.width, size.height + 2));
    canvas.drawPath(band.shift(const Offset(0, -1.5)), Paint()..color = edge);
    canvas.drawPath(band, Paint()..color = sheet);
  }

  @override
  bool shouldRepaint(_LabelEdgePainter old) =>
      old.seed != seed || old.sheet != sheet || old.edge != edge;
}
