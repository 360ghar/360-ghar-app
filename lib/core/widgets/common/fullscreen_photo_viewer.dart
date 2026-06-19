import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

/// A reusable, pinch-to-zoom photo gallery built on [PhotoViewGallery].
///
/// Shows a horizontally swipeable set of images with a page indicator and a
/// close button. Open it via [FullScreenPhotoViewer.show]; the same viewer is
/// used by the property detail card and the discover swipe card so there is a
/// single source of truth for fullscreen photo viewing.
class FullScreenPhotoViewer extends StatefulWidget {
  const FullScreenPhotoViewer({super.key, required this.imageUrls, this.initialIndex = 0});

  /// The image URLs to display, in order.
  final List<String> imageUrls;

  /// Index of the image to show first.
  final int initialIndex;

  /// Opens the viewer as a dialog over the current screen.
  static Future<void> show(
    BuildContext context, {
    required List<String> imageUrls,
    int initialIndex = 0,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: AppDesign.shadowColor.withValues(alpha: 0.9),
        child: FullScreenPhotoViewer(imageUrls: imageUrls, initialIndex: initialIndex),
      ),
    );
  }

  @override
  State<FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<FullScreenPhotoViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    final int last = widget.imageUrls.isEmpty ? 0 : widget.imageUrls.length - 1;
    _index = widget.initialIndex < 0
        ? 0
        : (widget.initialIndex > last ? last : widget.initialIndex);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return SizedBox(
        height: math.min(MediaQuery.of(context).size.height * 0.5, 480),
        child: Center(
          child: Text(
            'no_images_available'.tr,
            style: const TextStyle(color: AppDesign.darkTextPrimary),
          ),
        ),
      );
    }

    return SizedBox(
      height: math.min(MediaQuery.of(context).size.height * 0.75, 720),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            PhotoViewGallery.builder(
              itemCount: widget.imageUrls.length,
              pageController: _controller,
              backgroundDecoration: BoxDecoration(
                color: AppDesign.shadowColor.withValues(alpha: 0.9),
              ),
              onPageChanged: (int index) => setState(() => _index = index),
              builder: (BuildContext context, int index) {
                final String url = widget.imageUrls[index];
                return PhotoViewGalleryPageOptions(
                  imageProvider: CachedNetworkImageProvider(url),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2.5,
                  heroAttributes: PhotoViewHeroAttributes(tag: '${identityHashCode(this)}_$index'),
                );
              },
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: AppDesign.darkTextPrimary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            if (widget.imageUrls.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppDesign.shadowColor.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_index + 1}/${widget.imageUrls.length}',
                      style: const TextStyle(
                        color: AppDesign.darkTextPrimary,
                        fontSize: 13,
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
