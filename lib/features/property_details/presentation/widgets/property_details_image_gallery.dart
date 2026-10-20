import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/image_cache_service.dart';
import 'package:ghar360/core/widgets/common/robust_network_image.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/features/property_details/presentation/widgets/fullscreen_photo_gallery.dart';

/// Image gallery shown in the SliverAppBar of the property details page.
/// Supports page swiping, prefetching, and a full-screen PhotoView overlay.
///
/// On tablet widths the gallery is also reused as the sticky left pane of the
/// master-detail layout; in that case a bounded [maxHeight] is supplied so the
/// pane does not stretch to fill the viewport. When [maxHeight] is null (the
/// phone [SliverAppBar] case) the gallery is height-agnostic — the parent
/// decides its height.
class PropertyDetailsImageGallery extends ConsumerStatefulWidget {
  final PropertyModel property;
  final ImageCacheService? cacheService;

  /// Optional hard cap for the gallery height. Used by the two-pane tablet
  /// layout. Null on phones (the [SliverAppBar.expandedHeight] governs).
  final double? maxHeight;

  /// Room kept clear at the foot of the photo (the sheet's tabs lie over
  /// it), so the media marks and the counter sit above it.
  final double footInset;

  /// The photo carries this hero tag, so a listing photo flies into it.
  /// Null where the same home shows twice on one route (a two-pane list).
  final String? heroTag;

  const PropertyDetailsImageGallery({
    super.key,
    required this.property,
    this.maxHeight,
    this.cacheService,
    this.footInset = 0,
    this.heroTag,
  });

  /// The photos the gallery pages through; empty means no photo is shown.
  static List<String> imagesOf(PropertyModel property) {
    final urls = property.galleryImageUrls.isNotEmpty
        ? property.galleryImageUrls
        : [property.mainImage];
    return urls.where(ImageLoadingService.isValidUrl).toSet().toList();
  }

  @override
  ConsumerState<PropertyDetailsImageGallery> createState() => _PropertyDetailsImageGalleryState();
}

class _PropertyDetailsImageGalleryState extends ConsumerState<PropertyDetailsImageGallery> {
  late final PageController _pageController;
  int _current = 0;
  int _prefetchGeneration = 0;
  ImageCacheService get _cache => widget.cacheService ?? ref.read(imageCacheServiceProvider);

  List<String> get _images => PropertyDetailsImageGallery.imagesOf(widget.property);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_prefetchImages());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PropertyDetailsImageGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.property != widget.property) {
      _current = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) _pageController.jumpToPage(0);
      });
      unawaited(_prefetchImages());
    }
  }

  Future<void> _prefetchImages() {
    final generation = ++_prefetchGeneration;
    return _cache.preloadImages(
      _images.skip(_current + 1),
      isCurrent: () => mounted && generation == _prefetchGeneration,
    );
  }

  void _openGallery(int initialIndex) => FullscreenPhotoGallery.open(
    context,
    images: _images,
    initialIndex: initialIndex,
    heroTagPrefix: 'fullscreen',
    cacheService: _cache,
  );

  @override
  Widget build(BuildContext context) {
    final images = _images;
    final property = widget.property;
    final design = context.design;

    final cap = widget.maxHeight;
    if (images.isEmpty) {
      final none = Center(child: PaperIcon(KnifeIcon.camera, size: 32, color: design.textTertiary));
      return cap == null ? none : SizedBox(height: cap, child: none);
    }

    Widget photo(int index) => RobustNetworkImage(
      cacheService: _cache,
      imageUrl: images[index],
      fit: BoxFit.cover,
      // The page tone by day (as the listing prints), raised card at night.
      placeholder: ColoredBox(color: design.isDark ? design.raised : design.background),
    );
    Widget pages = GestureDetector(
      onTap: () => _openGallery(_current),
      child: PageView.builder(
        controller: _pageController,
        itemCount: images.length,
        onPageChanged: (i) {
          setState(() => _current = i);
          unawaited(_prefetchImages());
        },
        itemBuilder: (context, index) => photo(index),
      ),
    );
    if (widget.heroTag case final tag?) {
      // The flight shows the photo on screen, never a second page view.
      pages = Hero(
        tag: tag,
        flightShuttleBuilder: (_, _, _, _, _) => photo(_current.clamp(0, images.length - 1)),
        child: pages,
      );
    }

    // No wash over the photo: light words and marks carry a tight shadow.
    final label = _photoText(Theme.of(context).textTheme.labelLarge);
    final gallery = Stack(
      fit: StackFit.expand,
      children: [
        pages,
        Positioned(
          left: 16,
          right: 16,
          bottom: 14 + widget.footInset,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    if (property.hasVirtualTour) _mediaMark(KnifeIcon.tour, '360°', label),
                    if (property.hasVideos)
                      _mediaMark(KnifeIcon.video, context.l10n.text('video'), label),
                    if (property.hasFloorPlan)
                      _mediaMark(KnifeIcon.floorPlan, context.l10n.text('floor_plan'), label),
                  ],
                ),
              ),
              if (images.length > 1) Text('${_current + 1}/${images.length}', style: label),
            ],
          ),
        ),
      ],
    );

    if (cap == null) return gallery;
    return SizedBox(height: cap, child: gallery);
  }

  Widget _mediaMark(KnifeIcon icon, String text, TextStyle? style) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      PaperIcon(icon, size: 16, color: photoInk, shadows: onPhoto),
      const SizedBox(width: 5),
      Flexible(child: Text(text, style: style)),
    ],
  );
}

TextStyle? _photoText(TextStyle? base) =>
    base?.copyWith(color: photoInk, fontWeight: FontWeight.w700, shadows: onPhoto);
