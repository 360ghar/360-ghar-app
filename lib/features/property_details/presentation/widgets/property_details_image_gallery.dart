import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/utils/image_cache_service.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

/// Image gallery shown in the SliverAppBar of the property details page.
/// Supports page swiping, prefetching, and a full-screen PhotoView overlay.
///
/// On tablet widths the gallery is also reused as the sticky left pane of the
/// master-detail layout; in that case a bounded [maxHeight] is supplied so the
/// pane does not stretch to fill the viewport. When [maxHeight] is null (the
/// phone [SliverAppBar] case) the gallery is height-agnostic — the parent
/// decides its height.
class PropertyDetailsImageGallery extends StatefulWidget {
  final PropertyModel property;

  /// Optional hard cap for the gallery height. Used by the two-pane tablet
  /// layout. Null on phones (the [SliverAppBar.expandedHeight] governs).
  final double? maxHeight;

  const PropertyDetailsImageGallery({super.key, required this.property, this.maxHeight});

  @override
  State<PropertyDetailsImageGallery> createState() => _PropertyDetailsImageGalleryState();
}

class _PropertyDetailsImageGalleryState extends State<PropertyDetailsImageGallery> {
  late final PageController _pageController;
  int _current = 0;
  bool _isPrefetching = false;

  List<String> get _images {
    final urls = widget.property.galleryImageUrls.isNotEmpty
        ? widget.property.galleryImageUrls
        : [widget.property.mainImage];
    return urls.where((url) => url.trim().isNotEmpty).toList();
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prefetchImages();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _prefetchImages() async {
    if (_isPrefetching) return;
    _isPrefetching = true;
    for (final url in _images.take(8)) {
      try {
        await ImageCacheService.instance.preloadImage(url);
        if (!mounted) return;
        await precacheImage(CachedNetworkImageProvider(url), context);
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _isPrefetching = false);
    }
  }

  void _openGallery(int initialIndex) {
    final images = _images;
    if (images.isEmpty) return;

    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        barrierColor: AppDesign.overlayDark,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _FullscreenGallery(images: images, initialIndex: initialIndex);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = _images;
    final itemCount = images.isNotEmpty ? images.length : 1;
    final property = widget.property;

    if (images.isEmpty) {
      return Container(
        color: AppDesign.inputBackground,
        child: Center(child: Icon(Icons.image, size: 64, color: AppDesign.disabledColor)),
      );
    }

    final gallery = Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: () => _openGallery(_current),
          child: PageView.builder(
            controller: _pageController,
            itemCount: itemCount,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, index) {
              final url = images[index];
              return CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, _) => Container(
                  color: AppDesign.inputBackground,
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (context, error, stackTrace) => Container(
                  color: AppDesign.inputBackground,
                  child: Icon(Icons.image, size: 50, color: AppDesign.disabledColor),
                ),
              );
            },
          ),
        ),
        // Bottom gradient scrim for chrome readability
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppDesign.overlayDark.withValues(alpha: 0),
                    AppDesign.overlayDark.withValues(alpha: 0.45),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Media badges (360 / video)
        if (property.hasVirtualTour || property.hasVideos)
          Positioned(
            left: 12,
            bottom: 44,
            child: Row(
              children: [
                if (property.hasVirtualTour)
                  const _HeroMediaBadge(icon: Icons.threesixty, label: '360°'),
                if (property.hasVirtualTour && property.hasVideos) const SizedBox(width: 8),
                if (property.hasVideos) _HeroMediaBadge(icon: Icons.videocam, label: 'video'.tr),
              ],
            ),
          ),
        // Page dots
        if (itemCount > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(itemCount.clamp(0, 12), (index) {
                final isActive = index == _current;
                return AnimatedContainer(
                  duration: AppDurations.fast,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppDesign.primaryYellow
                        : AppDesign.overlayLight.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(AppBorderRadius.round),
                  ),
                );
              }),
            ),
          ),
        // Counter
        if (itemCount > 1)
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppDesign.overlayDark.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(AppBorderRadius.round),
              ),
              child: Text(
                '${_current + 1}/$itemCount',
                style: const TextStyle(
                  color: AppDesign.overlayLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );

    final cap = widget.maxHeight;
    if (cap == null) return gallery;
    return SizedBox(height: cap, child: gallery);
  }
}

class _HeroMediaBadge extends StatelessWidget {
  const _HeroMediaBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppDesign.overlayDark.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppBorderRadius.round),
        border: Border.all(color: AppDesign.primaryYellow.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppDesign.primaryYellow),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppDesign.overlayLight,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FullscreenGallery extends StatefulWidget {
  const _FullscreenGallery({required this.images, required this.initialIndex});

  final List<String> images;
  final int initialIndex;

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late int _index;
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesign.overlayDark,
      body: SafeArea(
        child: Stack(
          children: [
            PhotoViewGallery.builder(
              itemCount: widget.images.length,
              pageController: _controller,
              backgroundDecoration: const BoxDecoration(color: AppDesign.overlayDark),
              onPageChanged: (i) => setState(() => _index = i),
              builder: (context, index) {
                final url = widget.images[index];
                return PhotoViewGalleryPageOptions(
                  imageProvider: CachedNetworkImageProvider(url),
                  heroAttributes: PhotoViewHeroAttributes(tag: 'fullscreen_$url'),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2.5,
                );
              },
            ),
            Positioned(
              top: 4,
              left: 8,
              child: Material(
                color: AppDesign.overlayDark.withValues(alpha: 0.45),
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close, color: AppDesign.overlayLight),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            if (widget.images.length > 1)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppDesign.overlayDark.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(AppBorderRadius.round),
                    ),
                    child: Text(
                      '${_index + 1}/${widget.images.length}',
                      style: const TextStyle(
                        color: AppDesign.overlayLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
