import 'dart:async';
import 'dart:math' as math;

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:ghar360/core/config/app_config.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/utils/tour_url.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/common/robust_network_image.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/core/widgets/property/property_facts.dart';
import 'package:ghar360/features/property_details/presentation/widgets/fullscreen_photo_gallery.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_image_gallery.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

/// Horizontal media experience strip — photos, 360°, video, floor plan, street view.
/// No eager WebViews; tours navigate to [AppRoutes.tour] like Discover.
class PropertyMediaHub extends StatelessWidget {
  const PropertyMediaHub({super.key, required this.property, this.googleMapsApiKey});

  final PropertyModel property;
  final String? googleMapsApiKey;

  /// Gallery photos only; floor plans (`image_category == 'floor_plan'`) have their own tile.
  List<String> get _images => PropertyDetailsImageGallery.imagesOf(property);

  @override
  Widget build(BuildContext context) {
    final tiles = <_MediaTileData>[];

    final images = _images;
    if (images.isNotEmpty) {
      tiles.add(
        _MediaTileData(
          kind: _MediaKind.photos,
          label: context.l10n.text('photos'),
          icon: KnifeIcon.camera,
          thumbnail: images.first,
          badge: images.length > 1 ? '${images.length}' : null,
        ),
      );
    }
    if (property.hasVirtualTour) {
      tiles.add(
        _MediaTileData(
          kind: _MediaKind.tour,
          label: context.l10n.text('virtual_tour_title'),
          icon: KnifeIcon.tour,
          thumbnail: property.mainImage,
        ),
      );
    }
    if (property.hasVideos) {
      tiles.add(
        _MediaTileData(
          kind: _MediaKind.video,
          label: context.l10n.text('video_tour'),
          icon: KnifeIcon.video,
          thumbnail: property.mainImage,
        ),
      );
    }
    if (property.hasFloorPlan) {
      tiles.add(
        _MediaTileData(
          kind: _MediaKind.floorPlan,
          label: context.l10n.text('floor_plan'),
          icon: KnifeIcon.floorPlan,
          thumbnail: property.floorPlanImageUrls.first,
        ),
      );
    }
    if (property.hasStreetView) {
      final key = googleMapsApiKey ?? AppConfig.instance.googlePlacesApiKey;
      tiles.add(
        _MediaTileData(
          kind: _MediaKind.streetView,
          label: context.l10n.text('street_view'),
          icon: KnifeIcon.compass,
          thumbnail: property.streetViewStaticImage(key) ?? property.mainImage,
          // A refused or missing Street View still shows the home's photo.
          fallback: property.mainImage,
        ),
      );
    }

    if (tiles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(context.l10n.text('section_media')),
        SizedBox(
          // Photo, gap and the tallest label (one or two lines) at the current
          // text size, so a one-line strip leaves no empty line under it.
          height:
              _MediaExperienceCard.photoHeight +
              8 +
              _MediaExperienceCard.labelHeight(context, tiles),
          // The strip runs on past the page gutter to the screen edge.
          child: ListView.separated(
            clipBehavior: Clip.none,
            scrollDirection: Axis.horizontal,
            itemCount: tiles.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
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
        final url = TourUrl.validate(property.virtualTourUrl);
        if (url != null) {
          context.push(AppRoutes.tour, extra: url);
        } else {
          DebugLogger.warning('Property media hub rejected invalid virtual tour URL');
        }
      case _MediaKind.video:
        final video = property.primaryVideoUrl;
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
        _openStreetView(context);
    }
  }

  Future<void> _openStreetView(BuildContext context) async {
    final urlString = property.streetViewLaunchUrl;
    if (urlString == null) return;
    final validated = TourUrl.validate(urlString);
    if (validated == null) {
      DebugLogger.warning('Property media hub rejected invalid street view URL');
      return;
    }
    final uri = Uri.parse(validated);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
        AppToast.error(context.l10n.text('error'), context.l10n.text('unable_to_open_link'));
      }
    } catch (_) {
      if (context.mounted) {
        AppToast.error(context.l10n.text('error'), context.l10n.text('unable_to_open_link'));
      }
    }
  }

  void _openFullscreenGallery(BuildContext context, List<String> images, int initialIndex) =>
      FullscreenPhotoGallery.open(
        context,
        images: images,
        initialIndex: initialIndex,
        heroTagPrefix: 'media',
      );

  void _openVideoSheet(BuildContext context, String videoUrl, List<String> extraVideos) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PaperIcon(KnifeIcon.video, color: context.design.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.text('video_tour'),
                        style: Theme.of(context).textTheme.titleLarge,
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
    this.fallback,
  });

  final _MediaKind kind;
  final String label;
  final KnifeIcon icon;
  final String thumbnail;
  final String? badge;

  /// Shown when [thumbnail] fails to load.
  final String? fallback;
}

/// A flat thumbnail with its name under it.
class _MediaExperienceCard extends StatelessWidget {
  const _MediaExperienceCard({required this.data, required this.onTap});

  static const double photoHeight = 96;
  static const double width = 148;

  /// Height of the tallest label row of [tiles], at most two lines.
  static double labelHeight(BuildContext context, List<_MediaTileData> tiles) {
    var tallest = 0.0;
    for (final tile in tiles) {
      final painter = TextPainter(
        text: TextSpan(
          text: tile.badge == null ? tile.label : '${tile.label}  ${tile.badge}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 2,
      )..layout(maxWidth: width - 22);
      tallest = math.max(tallest, painter.height);
      painter.dispose();
    }
    return tallest.ceilToDouble() + 2;
  }

  final _MediaTileData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final text = Theme.of(context).textTheme;
    final badge = data.badge;
    // Each thumbnail is a print with a hand-cut edge.
    final print = CutBorder(seed: 'media-${data.kind.name}', amp: 1.5);
    return Semantics(
      button: true,
      // Own ink layer: the white sheet below would hide the press colour.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: print,
          child: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipPath(
                  clipper: ShapeBorderClipper(shape: print),
                  child: SizedBox(
                    height: photoHeight,
                    width: width,
                    child: RobustNetworkImage(
                      imageUrl: data.thumbnail,
                      fit: BoxFit.cover,
                      memCacheWidth: 400,
                      placeholder: ColoredBox(color: design.slip),
                      errorWidget: switch (data.fallback) {
                        final url? when url.isNotEmpty && url != data.thumbnail =>
                          RobustNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            memCacheWidth: 400,
                            placeholder: ColoredBox(color: design.slip),
                            errorWidget: ColoredBox(color: design.slip),
                          ),
                        _ => ColoredBox(color: design.slip),
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PaperIcon(data.icon, size: 16, color: design.accent),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        data.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelLarge,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Text(badge, style: text.labelLarge?.copyWith(color: design.textSecondary)),
                    ],
                  ],
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

class _LazyVideoPlayerState extends State<_LazyVideoPlayer> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  VideoPlayerController? _pendingController;
  Completer<void>? _initializationCancelled;
  Timer? _initializationTimeout;
  ChewieController? _chewieController;
  bool _loading = true;
  String? _error;
  int _initializationGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _initializationGeneration++;
    _initializationTimeout?.cancel();
    final cancellation = _initializationCancelled;
    if (cancellation != null && !cancellation.isCompleted) {
      cancellation.completeError(StateError('Video initialization cancelled'));
    }
    _chewieController?.dispose();
    _disposeVideo(_pendingController);
    _disposeVideo(_controller);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pauseVideo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!TickerMode.valuesOf(context).enabled) _pauseVideo();
  }

  void _disposeVideo(VideoPlayerController? controller) {
    if (controller == null) return;
    if (!identical(_pendingController, controller) && !identical(_controller, controller)) return;
    if (identical(_pendingController, controller)) _pendingController = null;
    if (identical(_controller, controller)) _controller = null;
    unawaited(
      controller.dispose().catchError((Object error) {
        DebugLogger.warning('Video cleanup failed: ${error.runtimeType}');
      }),
    );
  }

  void _pauseVideo() {
    final controller = _controller;
    if (controller == null) return;
    unawaited(
      controller.pause().catchError((Object error) {
        DebugLogger.warning('Video pause failed: ${error.runtimeType}');
      }),
    );
  }

  Future<void> _initialize() async {
    final generation = ++_initializationGeneration;
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    VideoPlayerController? pending;
    try {
      final validated = TourUrl.validate(widget.videoUrl);
      if (validated == null) {
        throw const FormatException('Unsupported video URL scheme');
      }
      final controller = VideoPlayerController.networkUrl(Uri.parse(validated));
      pending = controller;
      _pendingController = controller;
      final cancelled = Completer<void>();
      _initializationCancelled = cancelled;
      _initializationTimeout = Timer(const Duration(seconds: 20), () {
        if (!cancelled.isCompleted) {
          cancelled.completeError(TimeoutException('Video loading timed out'));
        }
      });
      await Future.any([controller.initialize(), cancelled.future]);
      if (!mounted || generation != _initializationGeneration) {
        _disposeVideo(controller);
        return;
      }
      final chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: false,
        looping: false,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
      );
      _chewieController?.dispose();
      _disposeVideo(_controller);
      _chewieController = chewieController;
      _controller = controller;
      pending = null;
      _pendingController = null;
    } catch (error, stack) {
      _disposeVideo(pending);
      _pendingController = null;
      if (!mounted || generation != _initializationGeneration) return;
      DebugLogger.error('Video player init failed: ${error.runtimeType}', null, stack);
      _error = 'video_load_failed';
    } finally {
      _initializationTimeout?.cancel();
      _initializationCancelled = null;
      if (mounted && generation == _initializationGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openExternal(String url) async {
    final validated = TourUrl.validate(url);
    if (validated == null) {
      DebugLogger.warning('Property video link rejected invalid URL');
      return;
    }
    final uri = Uri.parse(validated);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
        AppToast.error(context.l10n.text('error'), context.l10n.text('unable_to_open_link'));
      }
    } catch (_) {
      if (mounted) {
        AppToast.error(context.l10n.text('error'), context.l10n.text('unable_to_open_link'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: _controller?.value.aspectRatio ?? 16 / 9,
          child: ClipPath(
            clipper: const ShapeBorderClipper(shape: CutBorder(seed: 'video', amp: 1.5)),
            child: _loading
                ? const Skeleton(child: SkeletonBox(radius: 0))
                : _error != null
                ? ColoredBox(
                    color: context.design.raised,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: ErrorStates.inlineError(
                        message: context.l10n.text(_error!),
                        onRetry: _initialize,
                      ),
                    ),
                  )
                : _chewieController != null
                ? Chewie(controller: _chewieController!)
                : ColoredBox(color: context.design.raised),
          ),
        ),
        for (final url in widget.extraVideos)
          TextButton(
            onPressed: () => _openExternal(url),
            style: TextButton.styleFrom(alignment: Alignment.centerLeft),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PaperIcon(KnifeIcon.play, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? context.l10n.text('video'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _openExternal(widget.videoUrl),
            child: Text(context.l10n.text('open')),
          ),
        ),
      ],
    );
  }
}
