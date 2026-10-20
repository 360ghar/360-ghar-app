import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/image_cache_service.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';

class ImageLoadingService {
  static bool isValidUrl(String url) => ImageCacheService.isValidUrl(url);

  static String? getValidImageUrl(String? url) => url != null && isValidUrl(url) ? url : null;
}

/// Displays remote raster and SVG images through the same disk cache.
/// Failed images have an explicit retry; invalid URLs have a static fallback.
class RobustNetworkImage extends ConsumerStatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final ImageCacheService? cacheService;

  const RobustNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.memCacheWidth,
    this.memCacheHeight,
    this.cacheService,
  });

  @override
  ConsumerState<RobustNetworkImage> createState() => _RobustNetworkImageState();
}

class _RobustNetworkImageState extends ConsumerState<RobustNetworkImage> {
  Future<Uint8List?>? _svgBytes;
  int _attempt = 0;
  bool _retrying = false;
  ImageProvider? _decodedProvider;

  ImageCacheService get _cache => widget.cacheService ?? ref.read(imageCacheServiceProvider);

  @override
  void didUpdateWidget(RobustNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageUrl != oldWidget.imageUrl || widget.cacheService != oldWidget.cacheService) {
      _svgBytes = null;
      _retrying = false;
      _attempt++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = ImageLoadingService.getValidImageUrl(widget.imageUrl);
    final image = url == null
        ? _buildError(context, canRetry: false)
        : LayoutBuilder(
            builder: (context, constraints) {
              if (_isSvgUrl(url)) return _buildSvg(context, url);
              final ratio = MediaQuery.devicePixelRatioOf(context);
              final logicalWidth =
                  (widget.width?.isFinite == true ? widget.width : null) ??
                  (constraints.hasBoundedWidth
                      ? constraints.maxWidth
                      : MediaQuery.sizeOf(context).width);
              final logicalHeight =
                  widget.height ?? (constraints.hasBoundedHeight ? constraints.maxHeight : null);
              final decodeWidth = _decodeSize(widget.memCacheWidth, logicalWidth, ratio);
              final decodeHeight = _decodeSize(widget.memCacheHeight, logicalHeight, ratio);
              _decodedProvider = ResizeImage.resizeIfNeeded(
                decodeWidth,
                decodeHeight,
                CachedNetworkImageProvider(url, cacheManager: _cache.cacheManager),
              );
              return CachedNetworkImage(
                key: ValueKey('$url:$_attempt'),
                cacheManager: _cache.cacheManager,
                imageUrl: url,
                width: widget.width,
                height: widget.height,
                fit: widget.fit,
                filterQuality: FilterQuality.medium,
                memCacheWidth: decodeWidth,
                memCacheHeight: decodeHeight,
                fadeOutDuration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 150),
                fadeInDuration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 150),
                placeholder: (context, _) => _buildPlaceholder(context),
                errorWidget: (context, _, _) => _buildError(context, canRetry: true),
              );
            },
          );
    return widget.borderRadius == null
        ? image
        : ClipRRect(borderRadius: widget.borderRadius!, child: image);
  }

  int? _decodeSize(int? explicit, double? logical, double ratio) {
    if (explicit != null) return explicit.clamp(1, 2048);
    if (logical == null || !logical.isFinite || logical <= 0) return null;
    return (logical * ratio).ceil().clamp(1, 2048);
  }

  bool _isSvgUrl(String url) {
    final uri = Uri.parse(url);
    return uri.path.toLowerCase().endsWith('.svg') || uri.queryParameters['format'] == 'svg';
  }

  Widget _buildSvg(BuildContext context, String url) {
    _svgBytes ??= _cache.getImageBytes(url);
    return FutureBuilder<Uint8List?>(
      future: _svgBytes,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return _buildPlaceholder(context);
        final bytes = snapshot.data;
        if (bytes == null) return _buildError(context, canRetry: true);
        return SvgPicture.memory(
          bytes,
          key: ValueKey('$url:$_attempt'),
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          placeholderBuilder: _buildPlaceholder,
          errorBuilder: (context, _, _) => _buildError(context, canRetry: true),
        );
      },
    );
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    final url = widget.imageUrl;
    final attempt = _attempt;
    try {
      await _cache.removeFromCache(url);
      await _decodedProvider?.evict();
      await CachedNetworkImageProvider(url, cacheManager: _cache.cacheManager).evict();
    } catch (_) {
      // Keep the local fallback if storage cannot remove a corrupt entry.
    } finally {
      if (mounted && widget.imageUrl == url && _attempt == attempt) {
        setState(() {
          _retrying = false;
          _svgBytes = null;
          _attempt++;
        });
      }
    }
  }

  Widget _buildPlaceholder(BuildContext context) {
    // A quiet tonal slot; the photo replaces it without a spinner.
    return widget.placeholder ??
        Container(width: widget.width, height: widget.height, color: context.design.slip);
  }

  Widget _buildError(BuildContext context, {required bool canRetry}) {
    if (_retrying) return _buildPlaceholder(context);
    final fallback =
        widget.errorWidget ??
        Container(
          width: widget.width,
          height: widget.height,
          color: context.design.slip,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PaperIcon(
                  canRetry ? KnifeIcon.retry : KnifeIcon.home,
                  color: context.design.textSecondary,
                  size: widget.width != null && widget.width! < 100 ? 20 : 32,
                ),
                if ((widget.width ?? 0) > 100 && (widget.height ?? 200) >= 80) ...[
                  const SizedBox(height: 8),
                  Text(
                    canRetry ? context.l10n.text('retry') : context.l10n.text('property_image'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: context.design.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        );
    if (!canRetry) return fallback;
    return Semantics(
      button: true,
      label: context.l10n.text('retry'),
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _retry, child: fallback),
    );
  }
}

extension RobustNetworkImageExtension on RobustNetworkImage {
  static Widget circular({
    required String imageUrl,
    required double radius,
    Widget? placeholder,
    Widget? errorWidget,
  }) => ClipOval(
    child: RobustNetworkImage(
      imageUrl: imageUrl,
      width: radius * 2,
      height: radius * 2,
      placeholder: placeholder,
      errorWidget: errorWidget,
    ),
  );

  static Widget avatar({
    required String imageUrl,
    double size = 40,
    Widget? placeholder,
    Widget? errorWidget,
  }) => ClipOval(
    child: Builder(
      builder: (context) {
        final fallback = Container(
          width: size,
          height: size,
          color: context.design.inputBackground,
          child: PaperIcon(KnifeIcon.user, color: context.design.textSecondary),
        );
        return RobustNetworkImage(
          imageUrl: imageUrl,
          width: size,
          height: size,
          placeholder: placeholder ?? fallback,
          errorWidget: errorWidget ?? fallback,
        );
      },
    ),
  );
}

/// Starts downloading and decoding [url] at the size a [RobustNetworkImage]
/// with the same [width] and [height] decode sizes will ask for, so the image
/// shows at once when that widget appears (the next Discover card).
Future<void> precacheNetworkImage(
  BuildContext context,
  ImageCacheService cache,
  String url, {
  int? width,
  int? height,
}) async {
  final valid = ImageLoadingService.getValidImageUrl(url);
  if (valid == null) return;
  final uri = Uri.parse(valid);
  if (uri.path.toLowerCase().endsWith('.svg')) return;
  await precacheImage(
    ResizeImage.resizeIfNeeded(
      width?.clamp(1, 2048),
      height?.clamp(1, 2048),
      CachedNetworkImageProvider(valid, cacheManager: cache.cacheManager),
    ),
    context,
    onError: (_, _) {},
  );
}
