import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/presentation/property_labels.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/utils/share_utils.dart';
import 'package:ghar360/core/widgets/common/property_list_card.dart';
import 'package:ghar360/core/widgets/common/robust_network_image.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/core/widgets/paper/sheet_sliver.dart';

/// Light type and icons over a photo carry one tight shadow instead of a
/// box behind them.
const _onPhoto = [Shadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(0, 1))];
const _photoInk = Color(0xFFFFFFFF);

/// The top of a swipe card: the gallery as a print (what media it has, the
/// photo count and share on the photo), and a white label whose hand-cut top
/// edge overlaps the foot of the photo: price, purpose, name, place, type and
/// size.
class SwipeCardHeroSection extends StatefulWidget {
  final PropertyModel property;
  final VoidCallback? onViewDetails;
  final double? viewportHeight;

  const SwipeCardHeroSection({
    super.key,
    required this.property,
    this.onViewDetails,
    this.viewportHeight,
  });

  /// Decode size for the hero photo; prefetch uses the same numbers so the
  /// decoded image is reused when a card comes to the top.
  static (int, int) decodeSize(BuildContext context, {double? viewportHeight}) {
    final screen = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final height = heroHeight(context, viewportHeight: viewportHeight);
    return ((screen.width * dpr).round().clamp(320, 1600), (height * dpr).round().clamp(480, 2000));
  }

  static double heroHeight(BuildContext context, {double? viewportHeight}) {
    final screen = MediaQuery.sizeOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return math.max(
      viewportHeight ?? math.min(screen.height * 0.78, 680.0),
      textScale > 1.3 ? 440 * textScale : 380.0,
    );
  }

  @override
  State<SwipeCardHeroSection> createState() => _SwipeCardHeroSectionState();
}

class _SwipeCardHeroSectionState extends State<SwipeCardHeroSection> {
  final _pageController = PageController();
  int _pageIndex = 0;

  PropertyModel get property => widget.property;

  List<String> get _imageUrls {
    final gallery = property.galleryImageUrls;
    if (gallery.isNotEmpty) return gallery;
    if (property.mainImage.isNotEmpty) return [property.mainImage];
    return const <String>[];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _page(int delta) => _pageController.animateToPage(
    _pageIndex + delta,
    duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : AppDurations.fast,
    curve: AppCurves.standard,
  );

  @override
  Widget build(BuildContext context) {
    final heroHeight = SwipeCardHeroSection.heroHeight(
      context,
      viewportHeight: widget.viewportHeight,
    );
    final (memWidth, memHeight) = SwipeCardHeroSection.decodeSize(
      context,
      viewportHeight: widget.viewportHeight,
    );
    final images = _imageUrls;
    final l10n = context.l10n;
    final design = context.design;

    Widget photo(String url) => RobustNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: memWidth,
      memCacheHeight: memHeight,
      placeholder: ColoredBox(color: design.raised),
      errorWidget: _missingPhoto(context),
    );

    final media = _whatItHas(context);
    // The print fills what the label leaves; the label's cut top edge lies
    // over the foot of the photo, so the words sit on paper, not on a scrim.
    return SizedBox(
      height: heroHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onViewDetails,
                    child: Hero(
                      tag: propertyPhotoHeroTag(property.id),
                      child: images.isEmpty
                          ? _missingPhoto(context)
                          : images.length == 1
                          ? photo(images.first)
                          // Horizontal drags belong to the deck (like and
                          // pass); the arrows page the photos.
                          : PageView.builder(
                              controller: _pageController,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: images.length,
                              onPageChanged: (i) => setState(() => _pageIndex = i),
                              itemBuilder: (context, index) => photo(images[index]),
                            ),
                    ),
                  ),
                ),
                // A short scrim behind the top line only.
                const Positioned(left: 0, right: 0, top: 0, height: 120, child: _Scrim()),
                if (images.length > 1) ...[
                  if (_pageIndex > 0)
                    Positioned(
                      left: 4,
                      top: 0,
                      bottom: kPaperLip,
                      child: Center(
                        child: _PhotoButton(
                          icon: KnifeIcon.chevronLeft,
                          label: l10n.text('previous_photo'),
                          onTap: () => _page(-1),
                        ),
                      ),
                    ),
                  if (_pageIndex < images.length - 1)
                    Positioned(
                      right: 4,
                      top: 0,
                      bottom: kPaperLip,
                      child: Center(
                        child: _PhotoButton(
                          icon: KnifeIcon.chevronRight,
                          label: l10n.text('next_photo'),
                          onTap: () => _page(1),
                        ),
                      ),
                    ),
                ],
                Positioned(
                  top: 10,
                  left: 20,
                  right: 6,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Wrap(spacing: 14, runSpacing: 6, children: media),
                        ),
                      ),
                      if (images.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 15, right: 2),
                          child: Text(
                            '${_pageIndex + 1}/${images.length}',
                            style: _photoText(Theme.of(context).textTheme.labelMedium),
                          ),
                        ),
                      _PhotoButton(
                        icon: KnifeIcon.share,
                        label: l10n.text('share_property'),
                        onTap: () => ShareUtils.shareProperty(property, context: context),
                      ),
                    ],
                  ),
                ),
                // The label's hand-cut top edge; it runs 2 px into the label
                // below so their seam never shows.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: -2,
                  height: kPaperLip + 2,
                  child: PaperLip(seed: 'label-${property.id}'),
                ),
              ],
            ),
          ),
          _label(context),
        ],
      ),
    );
  }

  Widget _missingPhoto(BuildContext context) => ColoredBox(
    color: context.design.raised,
    child: Center(child: PaperIcon(KnifeIcon.home, size: 48, color: context.design.textTertiary)),
  );

  TextStyle? _photoText(TextStyle? base) =>
      base?.copyWith(color: _photoInk, shadows: _onPhoto, fontWeight: FontWeight.w700);

  /// What media the listing has: bare light icons and words on the photo.
  List<Widget> _whatItHas(BuildContext context) {
    final style = _photoText(Theme.of(context).textTheme.labelMedium);
    Widget item(KnifeIcon icon, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PaperIcon(icon, size: 15, color: _photoInk, shadows: _onPhoto),
        const SizedBox(width: 5),
        Flexible(child: Text(label, style: style)),
      ],
    );
    final l10n = context.l10n;
    return [
      if (_imageUrls.length > 1) item(KnifeIcon.camera, '${_imageUrls.length}'),
      if (property.hasVirtualTour) item(KnifeIcon.tour, '360°'),
      if (property.hasVideos || property.hasVideoTour) item(KnifeIcon.video, l10n.text('video')),
      if (property.hasFloorPlan) item(KnifeIcon.floorPlan, l10n.text('floor_plan')),
    ];
  }

  /// The white label: price in Erode with the purpose, the name, the place
  /// and type, the three numbers people compare first, and the way in.
  Widget _label(BuildContext context) {
    final design = context.design;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final quiet = text.bodyMedium?.copyWith(color: design.textSecondary);
    final suffix = property.effectivePrice == null
        ? null
        : switch (property.purpose) {
            PropertyPurpose.rent => l10n.text('per_month_short'),
            PropertyPurpose.shortStay => l10n.text('per_day_short'),
            _ => null,
          };
    Widget fact(KnifeIcon icon, String label, TextStyle? style) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PaperIcon(icon, size: 17, color: design.accent),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: style)),
      ],
    );
    final strong = text.labelLarge;
    final specs = [
      if (property.bedrooms != null)
        fact(
          KnifeIcon.bed,
          l10n.text('bedrooms_short', params: {'count': '${property.bedrooms}'}),
          strong,
        ),
      if (property.bathrooms != null)
        fact(
          KnifeIcon.bath,
          l10n.text('bathrooms_short', params: {'count': '${property.bathrooms}'}),
          strong,
        ),
      if (property.localizedArea(context).isNotEmpty)
        fact(KnifeIcon.area, property.localizedArea(context), strong),
    ];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: widget.onViewDetails,
      child: ColoredBox(
        color: design.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                // The price is display type: it grows to 1.5x, not 2x, so the
                // name and the numbers keep their room on the label.
                textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5),
                text: TextSpan(
                  style: text.displayMedium,
                  children: [
                    TextSpan(text: property.localizedPrice(context)),
                    if (suffix != null)
                      TextSpan(
                        text: suffix,
                        style: text.titleSmall?.copyWith(color: design.textSecondary),
                      ),
                    TextSpan(
                      text: '  ${l10n.text(property.listingTranslationKey)}',
                      style: text.labelLarge?.copyWith(color: design.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                property.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.titleLarge,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  if (property.shortAddressDisplay.isNotEmpty)
                    fact(KnifeIcon.pin, property.shortAddressDisplay, quiet),
                  fact(KnifeIcon.building, l10n.text(property.propertyTypeLabelKey), quiet),
                ],
              ),
              if (specs.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 18, runSpacing: 6, children: specs),
              ],
              const SizedBox(height: 4),
              TextButton(
                onPressed: widget.onViewDetails,
                style: TextButton.styleFrom(
                  foregroundColor: design.accent,
                  padding: EdgeInsets.zero,
                  alignment: AlignmentDirectional.centerStart,
                  minimumSize: const Size(48, 44),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: Text(l10n.text('view_details'))),
                    const SizedBox(width: 6),
                    const PaperIcon(KnifeIcon.arrowUpRight, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A 48 px photo control: a bare light icon with a tight shadow.
class _PhotoButton extends StatelessWidget {
  const _PhotoButton({required this.icon, required this.label, required this.onTap});

  final KnifeIcon icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onTap,
    iconSize: 24,
    style: IconButton.styleFrom(minimumSize: const Size.square(48)),
    icon: PaperIcon(icon, color: _photoInk, shadows: _onPhoto, semanticLabel: label),
  );
}

/// A short dark wash behind the top line of light icons, fading to clear.
class _Scrim extends StatelessWidget {
  const _Scrim();

  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x59000000), Color(0x00000000)],
        ),
      ),
    ),
  );
}
