import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/utils/image_cache_service.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

/// Light type and icons over a photo carry one tight shadow instead of a box.
const onPhoto = [Shadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(0, 1))];
const photoInk = Color(0xFFFFFFFF);

/// Fullscreen pinch-zoom photo gallery (page-swipeable) with a close button
/// and an n/total counter. Shared by the property-details image gallery and
/// media hub.
///
/// [heroTagPrefix] must match the Hero tag used by the opening thumbnail
/// ('fullscreen_' for the gallery, 'media_' for the hub).
class FullscreenPhotoGallery extends ConsumerStatefulWidget {
  const FullscreenPhotoGallery({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.heroTagPrefix,
    this.cacheService,
  });

  final List<String> images;
  final int initialIndex;
  final String heroTagPrefix;
  final ImageCacheService? cacheService;

  /// Opens the gallery over the current route with a short fade.
  static void open(
    BuildContext context, {
    required List<String> images,
    required int initialIndex,
    required String heroTagPrefix,
    ImageCacheService? cacheService,
  }) {
    if (images.isEmpty) return;
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : AppDurations.normal;
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: duration,
        reverseTransitionDuration: duration,
        pageBuilder: (context, _, _) => FullscreenPhotoGallery(
          images: images,
          initialIndex: initialIndex,
          heroTagPrefix: heroTagPrefix,
          cacheService: cacheService,
        ),
        transitionsBuilder: (context, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  ConsumerState<FullscreenPhotoGallery> createState() => _FullscreenPhotoGalleryState();
}

class _FullscreenPhotoGalleryState extends ConsumerState<FullscreenPhotoGallery> {
  late int _index;
  late final PageController _controller;
  final Set<String> _retrying = {};
  int _attempt = 0;
  ImageCacheService get _cache => widget.cacheService ?? ref.read(imageCacheServiceProvider);

  @override
  void initState() {
    super.initState();
    _index = widget.images.isEmpty ? 0 : widget.initialIndex.clamp(0, widget.images.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ImageProvider _provider(String url) => ResizeImage.resizeIfNeeded(
    4096,
    null,
    CachedNetworkImageProvider(url, cacheManager: _cache.cacheManager),
  );

  Future<void> _retry(String url) async {
    if (!_retrying.add(url)) return;
    setState(() {});
    try {
      await _cache.removeFromCache(url);
      await _provider(url).evict();
      await CachedNetworkImageProvider(url, cacheManager: _cache.cacheManager).evict();
    } catch (_) {
      // Storage failure keeps recovery within this photo.
    } finally {
      if (mounted) {
        setState(() {
          _retrying.remove(url);
          _attempt++;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppDesign.overlayDark,
      body: SafeArea(
        child: Stack(
          children: [
            if (widget.images.isEmpty)
              const Center(child: PaperIcon(KnifeIcon.camera, size: 40, color: photoInk))
            else
              PhotoViewGallery.builder(
                key: ValueKey(_attempt),
                itemCount: widget.images.length,
                // The night skeleton reads as a photo still on its way.
                loadingBuilder: (context, _) => Theme(
                  data: Theme.of(context).copyWith(brightness: Brightness.dark),
                  child: const Center(
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Skeleton(child: SkeletonBox(radius: 0)),
                    ),
                  ),
                ),
                pageController: _controller,
                backgroundDecoration: const BoxDecoration(color: AppDesign.overlayDark),
                onPageChanged: (i) => setState(() => _index = i),
                builder: (context, index) {
                  final url = widget.images[index];
                  return PhotoViewGalleryPageOptions(
                    imageProvider: _provider(url),
                    errorBuilder: (context, _, _) => Center(
                      child: _retrying.contains(url)
                          ? LoadingStates.buttonSpinner(size: 28, color: photoInk)
                          : IconButton(
                              tooltip: context.l10n.text('retry'),
                              icon: const PaperIcon(
                                KnifeIcon.retry,
                                color: photoInk,
                                size: 32,
                                shadows: onPhoto,
                              ),
                              onPressed: () => _retry(url),
                            ),
                    ),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 2.5,
                    heroAttributes: PhotoViewHeroAttributes(tag: '${widget.heroTagPrefix}_$url'),
                  );
                },
              ),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                icon: const PaperIcon(KnifeIcon.close, color: photoInk, shadows: onPhoto),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                style: IconButton.styleFrom(minimumSize: const Size.square(48)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            if (widget.images.length > 1)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    '${_index + 1}/${widget.images.length}',
                    style: text.labelLarge?.copyWith(
                      color: photoInk,
                      fontWeight: FontWeight.w700,
                      shadows: onPhoto,
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
