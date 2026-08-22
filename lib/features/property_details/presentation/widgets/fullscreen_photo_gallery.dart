import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

/// Fullscreen pinch-zoom photo gallery (page-swipeable) with a close button
/// and an n/total counter. Shared by the property-details image gallery and
/// media hub.
///
/// [heroTagPrefix] must match the Hero tag used by the opening thumbnail
/// ('fullscreen_' for the gallery, 'media_' for the hub).
class FullscreenPhotoGallery extends StatefulWidget {
  const FullscreenPhotoGallery({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.heroTagPrefix,
  });

  final List<String> images;
  final int initialIndex;
  final String heroTagPrefix;

  @override
  State<FullscreenPhotoGallery> createState() => _FullscreenPhotoGalleryState();
}

class _FullscreenPhotoGalleryState extends State<FullscreenPhotoGallery> {
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
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2.5,
                  heroAttributes: PhotoViewHeroAttributes(tag: '${widget.heroTagPrefix}_$url'),
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
