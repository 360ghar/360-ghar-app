import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/config/app_config.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/widgets/common/robust_network_image.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_section_header.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

/// Horizontal media experience strip — photos, 360°, video, floor plan, street view.
/// No eager WebViews; tours navigate to [AppRoutes.tour] like Discover.
class PropertyMediaHub extends StatelessWidget {
  const PropertyMediaHub({super.key, required this.property, this.googleMapsApiKey});

  final PropertyModel property;
  final String? googleMapsApiKey;

  List<String> get _images {
    final urls = property.galleryImageUrls.isNotEmpty
        ? property.galleryImageUrls
        : [property.mainImage];
    return urls.where((u) => u.trim().isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tiles = <_MediaTileData>[];

    if (property.hasPhotos || _images.isNotEmpty) {
      tiles.add(
        _MediaTileData(
          kind: _MediaKind.photos,
          label: 'photos'.tr,
          icon: Icons.photo_library_rounded,
          thumbnail: _images.isNotEmpty ? _images.first : property.mainImage,
          badge: _images.length > 1 ? '${_images.length}' : null,
        ),
      );
    }
    if (property.hasVirtualTour) {
      tiles.add(
        _MediaTileData(
          kind: _MediaKind.tour,
          label: 'virtual_tour_title'.tr,
          icon: Icons.threesixty,
          thumbnail: property.mainImage,
        ),
      );
    }
    if (property.hasVideos) {
      tiles.add(
        _MediaTileData(
          kind: _MediaKind.video,
          label: 'video_tour'.tr,
          icon: Icons.videocam_rounded,
          thumbnail: property.mainImage,
        ),
      );
    }
    if (property.hasFloorPlan) {
      tiles.add(
        _MediaTileData(
          kind: _MediaKind.floorPlan,
          label: 'floor_plan'.tr,
          icon: Icons.apartment_rounded,
          thumbnail: property.floorPlanImageUrls.firstOrNull ?? property.mainImage,
        ),
      );
    }
    if (property.hasStreetView) {
      final key = googleMapsApiKey ?? AppConfig.instance.googlePlacesApiKey;
      tiles.add(
        _MediaTileData(
          kind: _MediaKind.streetView,
          label: 'street_view'.tr,
          icon: Icons.streetview,
          thumbnail: property.streetViewStaticImage(key) ?? property.mainImage,
        ),
      );
    }

    if (tiles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PropertyDetailsSectionHeader('section_media'.tr),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: tiles.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final tile = tiles[index];
              return _MediaExperienceCard(data: tile, onTap: () => _onTileTap(context, tile.kind));
            },
          ),
        ),
      ],
    );
  }

  void _onTileTap(BuildContext context, _MediaKind kind) {
    switch (kind) {
      case _MediaKind.photos:
        _openFullscreenGallery(context, _images, 0);
      case _MediaKind.tour:
        final url = property.virtualTourUrl;
        if (url != null && url.isNotEmpty) {
          Get.toNamed(AppRoutes.tour, arguments: url);
        }
      case _MediaKind.video:
        final video = property.primaryVideoUrl ?? property.mediaVideoUrls.firstOrNull;
        if (video != null) {
          _openVideoSheet(
            context,
            video,
            property.mediaVideoUrls.where((v) => v != video).toList(),
          );
        }
      case _MediaKind.floorPlan:
        _openFullscreenGallery(context, property.floorPlanImageUrls, 0);
      case _MediaKind.streetView:
        _openStreetView();
    }
  }

  Future<void> _openStreetView() async {
    final urlString = property.streetViewLaunchUrl;
    if (urlString == null) return;
    final uri = Uri.tryParse(urlString);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openFullscreenGallery(BuildContext context, List<String> images, int initialIndex) {
    if (images.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _FullscreenMediaGallery(images: images, initialIndex: initialIndex);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _openVideoSheet(BuildContext context, String videoUrl, List<String> extraVideos) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppDesign.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppBorderRadius.bottomSheet)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppDesign.border,
                    borderRadius: BorderRadius.circular(AppBorderRadius.round),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.videocam_rounded, color: AppDesign.primaryYellow),
                    const SizedBox(width: 8),
                    Text(
                      'video_tour'.tr,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppDesign.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _LazyVideoPlayer(videoUrl: videoUrl, extraVideos: extraVideos),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _MediaKind { photos, tour, video, floorPlan, streetView }

class _MediaTileData {
  const _MediaTileData({
    required this.kind,
    required this.label,
    required this.icon,
    required this.thumbnail,
    this.badge,
  });

  final _MediaKind kind;
  final String label;
  final IconData icon;
  final String thumbnail;
  final String? badge;
}

class _MediaExperienceCard extends StatelessWidget {
  const _MediaExperienceCard({required this.data, required this.onTap});

  final _MediaTileData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppDesign.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppBorderRadius.card),
        child: Ink(
          width: 148,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppBorderRadius.card),
            border: Border.all(color: AppDesign.border.withValues(alpha: 0.75)),
            boxShadow: AppDesign.getCardShadow(),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppBorderRadius.card),
            child: Stack(
              fit: StackFit.expand,
              children: [
                RobustNetworkImage(imageUrl: data.thumbnail, fit: BoxFit.cover),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppDesign.overlayDark.withValues(alpha: 0.1),
                        AppDesign.overlayDark.withValues(alpha: 0.65),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppDesign.primaryYellow,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(data.icon, size: 14, color: AppDesign.buttonText),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          data.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppDesign.overlayLight,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (data.badge != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppDesign.overlayDark.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(AppBorderRadius.round),
                      ),
                      child: Text(
                        data.badge!,
                        style: TextStyle(
                          color: AppDesign.overlayLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

class _LazyVideoPlayer extends StatefulWidget {
  const _LazyVideoPlayer({required this.videoUrl, required this.extraVideos});

  final String videoUrl;
  final List<String> extraVideos;

  @override
  State<_LazyVideoPlayer> createState() => _LazyVideoPlayerState();
}

class _LazyVideoPlayerState extends State<_LazyVideoPlayer> {
  VideoPlayerController? _controller;
  ChewieController? _chewieController;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uri = Uri.parse(widget.videoUrl);
      final controller = VideoPlayerController.networkUrl(uri);
      await controller.initialize();
      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: false,
        looping: false,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
      );
      _controller = controller;
    } catch (e) {
      DebugLogger.error('Video player init failed', e);
      _error = 'video_load_failed'.tr;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: _controller?.value.aspectRatio ?? 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _error != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: TextStyle(color: AppDesign.textSecondary)),
                      TextButton(onPressed: _initialize, child: Text('retry'.tr)),
                    ],
                  )
                : _chewieController != null
                ? Chewie(controller: _chewieController!)
                : Container(color: AppDesign.inputBackground),
          ),
        ),
        if (widget.extraVideos.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.extraVideos
                .map(
                  (url) => ActionChip(
                    label: Text(
                      Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? 'video'.tr,
                      style: TextStyle(color: AppDesign.textPrimary),
                    ),
                    avatar: const Icon(Icons.play_circle_fill, size: 18),
                    onPressed: () => _openExternal(url),
                  ),
                )
                .toList(),
          ),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _openExternal(widget.videoUrl),
            child: Text('open'.tr),
          ),
        ),
      ],
    );
  }
}

class _FullscreenMediaGallery extends StatefulWidget {
  const _FullscreenMediaGallery({required this.images, required this.initialIndex});

  final List<String> images;
  final int initialIndex;

  @override
  State<_FullscreenMediaGallery> createState() => _FullscreenMediaGalleryState();
}

class _FullscreenMediaGalleryState extends State<_FullscreenMediaGallery> {
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
                  heroAttributes: PhotoViewHeroAttributes(tag: 'media_$url'),
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

extension _FirstOrNullMedia<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
