import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/config/app_config.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/responsive.dart';
import 'package:ghar360/core/utils/share_utils.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/common/scroll_reveal_widget.dart';
import 'package:ghar360/features/likes/presentation/controllers/likes_controller.dart';
import 'package:ghar360/features/property_details/presentation/controllers/property_details_controller.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_amenities_grid.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_bottom_bar.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_image_gallery.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_info_sections.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_location_card.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_overview.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_section_header.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_section_nav.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_media_hub.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class PropertyDetailsView extends GetView<PropertyDetailsController> {
  const PropertyDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final Widget child;
      final Key key;

      if (controller.isLoading.value) {
        key = const ValueKey('loading');
        child = const _PropertyLoadingScaffold();
      } else {
        final errorMessage = controller.errorMessage;
        if (errorMessage != null) {
          key = const ValueKey('error');
          child = _PropertyErrorScaffold(message: errorMessage);
        } else {
          final property = controller.property.value;
          if (property == null) {
            key = const ValueKey('not_found');
            child = _PropertyErrorScaffold(message: 'property_not_found'.tr);
          } else {
            key = const ValueKey('content');
            child = _PropertyContentView(property: property);
          }
        }
      }

      return AnimatedSwitcher(
        duration: AppDurations.contentFade,
        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
        child: KeyedSubtree(key: key, child: child),
      );
    });
  }
}

/// Encapsulates property content rendering.
class _PropertyContentView extends StatefulWidget {
  const _PropertyContentView({required this.property});

  final PropertyModel property;

  @override
  State<_PropertyContentView> createState() => _PropertyContentViewState();
}

class _PropertyContentViewState extends State<_PropertyContentView> {
  static const int _collapsedDescriptionLines = 4;
  bool _isDescriptionExpanded = false;
  PropertyDetailsSection _activeSection = PropertyDetailsSection.overview;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _overviewKey = GlobalKey();
  final GlobalKey _mediaKey = GlobalKey();
  final GlobalKey _specsKey = GlobalKey();
  final GlobalKey _locationKey = GlobalKey();

  bool _syncingFromScroll = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_syncingFromScroll || !mounted) return;
    final sections = <(PropertyDetailsSection, GlobalKey)>[
      (PropertyDetailsSection.overview, _overviewKey),
      if (widget.property.hasAnyMedia) (PropertyDetailsSection.media, _mediaKey),
      (PropertyDetailsSection.specs, _specsKey),
      if (widget.property.hasLocation) (PropertyDetailsSection.location, _locationKey),
    ];

    PropertyDetailsSection? next;
    for (final (id, key) in sections) {
      final ctx = key.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final offset = box.localToGlobal(Offset.zero).dy;
      // Section near top of viewport (below sticky nav ~120px).
      if (offset <= 160) {
        next = id;
      }
    }
    if (next != null && next != _activeSection) {
      setState(() => _activeSection = next!);
    }
  }

  Future<void> _scrollToSection(PropertyDetailsSection section) async {
    final key = switch (section) {
      PropertyDetailsSection.overview => _overviewKey,
      PropertyDetailsSection.media => _mediaKey,
      PropertyDetailsSection.specs => _specsKey,
      PropertyDetailsSection.location => _locationKey,
    };
    final ctx = key.currentContext;
    if (ctx == null) return;

    setState(() => _activeSection = section);
    _syncingFromScroll = true;
    await Scrollable.ensureVisible(
      ctx,
      duration: AppDurations.normal,
      curve: AppCurves.standard,
      alignment: 0.08,
    );
    if (mounted) {
      _syncingFromScroll = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final likesController = Get.find<LikesController>();
    final visitsController = Get.find<VisitsController>();
    final PropertyModel safeProperty = widget.property;
    final sizeClass = context.windowSizeClass;
    final useTwoPane = sizeClass == WindowSizeClass.expanded || sizeClass == WindowSizeClass.large;

    final body = useTwoPane
        ? _buildTwoPaneBody(context, safeProperty, likesController)
        : _buildSingleColumnBody(context, safeProperty, likesController);

    return Semantics(
      label: 'qa.property_details.screen',
      identifier: 'qa.property_details.screen',
      child: Scaffold(
        key: const ValueKey('qa.property_details.screen'),
        backgroundColor: AppDesign.scaffoldBackground,
        body: body,
        bottomNavigationBar: SafeArea(
          top: false,
          child: PropertyDetailsBottomBar(
            property: safeProperty,
            visitsController: visitsController,
          ),
        ),
      ),
    );
  }

  Widget _buildSingleColumnBody(
    BuildContext context,
    PropertyModel safeProperty,
    LikesController likesController,
  ) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final expandedHeight = responsiveValue<double>(
      context,
      compact: 380,
      medium: 380 < screenHeight * 0.4 ? 380 : screenHeight * 0.4,
      fallback: 380,
    );

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverAppBar(
          expandedHeight: expandedHeight,
          pinned: true,
          backgroundColor: AppDesign.appBarBackground,
          leading: _buildEditorialAppBarButton(
            icon: Icon(Icons.arrow_back, color: AppDesign.textPrimary),
            onPressed: Get.back,
          ),
          actions: [
            Obx(
              () => _buildEditorialAppBarButton(
                icon: Icon(
                  likesController.isFavourite(safeProperty.id)
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: likesController.isFavourite(safeProperty.id)
                      ? AppDesign.favoriteActive
                      : AppDesign.textPrimary,
                ),
                onPressed: () {
                  if (likesController.isFavourite(safeProperty.id)) {
                    likesController.removeFromFavourites(safeProperty.id);
                  } else {
                    likesController.addToFavourites(safeProperty.id);
                  }
                },
              ),
            ),
            _buildEditorialAppBarButton(
              icon: Icon(Icons.share, color: AppDesign.textPrimary),
              onPressed: () => ShareUtils.shareProperty(safeProperty, context: context),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: PropertyDetailsImageGallery(property: safeProperty),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _SectionNavHeaderDelegate(
            height: 52,
            child: PropertyDetailsSectionNav(
              active: _activeSection,
              showMedia: safeProperty.hasAnyMedia,
              showLocation: safeProperty.hasLocation,
              onSelect: _scrollToSection,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.md,
              AppSpacing.screenPadding,
              0,
            ),
            child: _buildDetailSections(context, safeProperty),
          ),
        ),
      ],
    );
  }

  Widget _buildTwoPaneBody(
    BuildContext context,
    PropertyModel safeProperty,
    LikesController likesController,
  ) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final galleryHeight = (screenHeight * 0.7) < 520.0 ? screenHeight * 0.7 : 520.0;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final leftPaneWidth = screenWidth * 0.42 < 460.0 ? screenWidth * 0.42 : 460.0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: leftPaneWidth,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 4, 8),
                    child: Row(
                      children: [
                        _buildEditorialAppBarButton(
                          icon: Icon(Icons.arrow_back, color: AppDesign.textPrimary),
                          onPressed: Get.back,
                        ),
                        const Spacer(),
                        Obx(
                          () => _buildEditorialAppBarButton(
                            icon: Icon(
                              likesController.isFavourite(safeProperty.id)
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: likesController.isFavourite(safeProperty.id)
                                  ? AppDesign.favoriteActive
                                  : AppDesign.textPrimary,
                            ),
                            onPressed: () {
                              if (likesController.isFavourite(safeProperty.id)) {
                                likesController.removeFromFavourites(safeProperty.id);
                              } else {
                                likesController.addToFavourites(safeProperty.id);
                              }
                            },
                          ),
                        ),
                        _buildEditorialAppBarButton(
                          icon: Icon(Icons.share, color: AppDesign.textPrimary),
                          onPressed: () => ShareUtils.shareProperty(safeProperty, context: context),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: galleryHeight,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                      child: PropertyDetailsImageGallery(
                        property: safeProperty,
                        maxHeight: galleryHeight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppDesign.scaffoldBackground,
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                ),
                child: Column(
                  children: [
                    PropertyDetailsSectionNav(
                      active: _activeSection,
                      showMedia: safeProperty.hasAnyMedia,
                      showLocation: safeProperty.hasLocation,
                      onSelect: _scrollToSection,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppSpacing.screenPadding),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 640),
                            child: _buildDetailSections(context, safeProperty),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSections(BuildContext context, PropertyModel safeProperty) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KeyedSubtree(
          key: _overviewKey,
          child: ScrollRevealWidget(
            index: 0,
            child: PropertyDetailsOverview(
              property: safeProperty,
              onLocationTap: safeProperty.hasLocation
                  ? () => _scrollToSection(PropertyDetailsSection.location)
                  : null,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sectionSpacing),

        if (safeProperty.hasAnyMedia) ...[
          KeyedSubtree(
            key: _mediaKey,
            child: ScrollRevealWidget(
              index: 1,
              child: PropertyMediaHub(
                property: safeProperty,
                googleMapsApiKey: AppConfig.instance.googlePlacesApiKey,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sectionSpacing),
        ],

        ScrollRevealWidget(index: 2, child: _buildDescriptionSection(context, safeProperty)),
        const SizedBox(height: AppSpacing.md),

        if ((safeProperty.features?.isNotEmpty ?? false))
          ..._buildHighlightsSection(context, safeProperty),

        KeyedSubtree(
          key: _specsKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScrollRevealWidget(
                index: 4,
                child: PropertyDetailsInfoSection(property: safeProperty),
              ),
              const SizedBox(height: AppSpacing.sectionSpacing),
              ScrollRevealWidget(
                index: 5,
                child: PropertyDetailsPricingSection(property: safeProperty),
              ),
              if (safeProperty.builderName?.isNotEmpty == true) ...[
                const SizedBox(height: AppSpacing.sectionSpacing),
                ScrollRevealWidget(
                  index: 6,
                  child: PropertyDetailsContactSection(property: safeProperty),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sectionSpacing),

        ScrollRevealWidget(index: 7, child: PropertyDetailsAmenitiesGrid(property: safeProperty)),

        if (safeProperty.hasLocation) ...[
          const SizedBox(height: AppSpacing.sectionSpacing),
          KeyedSubtree(
            key: _locationKey,
            child: ScrollRevealWidget(
              index: 8,
              child: PropertyDetailsLocationCard(
                property: safeProperty,
                onOpenDirections: () {
                  final lat = safeProperty.latitude;
                  final lng = safeProperty.longitude;
                  if (lat != null && lng != null) {
                    _openInMaps(lat, lng, safeProperty.title);
                  }
                },
              ),
            ),
          ),
        ],

        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildDescriptionSection(BuildContext context, PropertyModel property) {
    final theme = Theme.of(context);
    final String rawDescription = property.description?.trim() ?? '';
    final bool hasDescription = rawDescription.isNotEmpty;
    final bool canCollapse = hasDescription && rawDescription.length > 240;
    final String description = hasDescription ? rawDescription : 'no_description_available'.tr;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PropertyDetailsSectionHeader('description'.tr),
        Text(
          description,
          maxLines: canCollapse && !_isDescriptionExpanded ? _collapsedDescriptionLines : null,
          overflow: canCollapse && !_isDescriptionExpanded
              ? TextOverflow.ellipsis
              : TextOverflow.visible,
          style: theme.textTheme.bodyLarge?.copyWith(color: AppDesign.textSecondary, height: 1.7),
        ),
        if (canCollapse) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: () {
              setState(() => _isDescriptionExpanded = !_isDescriptionExpanded);
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              alignment: Alignment.centerLeft,
              foregroundColor: AppDesign.primaryYellow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isDescriptionExpanded ? 'read_less'.tr : 'read_more'.tr,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppDesign.primaryYellow,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(
                  _isDescriptionExpanded ? Icons.expand_less : Icons.expand_more,
                  color: AppDesign.primaryYellow,
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildHighlightsSection(BuildContext context, PropertyModel property) {
    return [
      PropertyDetailsSectionHeader('highlights'.tr),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: (property.features ?? [])
            .take(6)
            .map((feature) => _buildEditorialChip(context, feature))
            .toList(),
      ),
      const SizedBox(height: AppSpacing.sectionSpacing),
    ];
  }

  Widget _buildEditorialChip(BuildContext context, String text) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppDesign.inputBackground : AppDesign.warmCream,
        borderRadius: BorderRadius.circular(AppBorderRadius.round),
        border: Border.all(color: AppDesign.primaryYellow.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? AppDesign.textPrimary : AppDesign.editorialInk,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEditorialAppBarButton({required Widget icon, required VoidCallback onPressed}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppDesign.surface.withValues(alpha: 0.88),
        shape: BoxShape.circle,
        border: Border.all(color: AppDesign.primaryYellow.withValues(alpha: 0.65), width: 0.9),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: icon,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        splashRadius: 22,
      ),
    );
  }
}

class _SectionNavHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SectionNavHeaderDelegate({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Force full extent so paintExtent never drops below layoutExtent.
    return SizedBox(
      height: maxExtent,
      child: Material(
        color: AppDesign.scaffoldBackground,
        elevation: overlapsContent ? 1 : 0,
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SectionNavHeaderDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}

class _PropertyLoadingScaffold extends StatelessWidget {
  const _PropertyLoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesign.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppDesign.appBarBackground,
        elevation: 0,
        leading: IconButton(
          tooltip: 'back'.tr,
          icon: Icon(Icons.arrow_back, color: AppDesign.appBarIcon),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'property_details'.tr,
          style: TextStyle(color: AppDesign.appBarText, fontWeight: FontWeight.bold),
        ),
      ),
      body: LoadingStates.propertyDetailsSkeleton(),
    );
  }
}

class _PropertyErrorScaffold extends StatelessWidget {
  const _PropertyErrorScaffold({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesign.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppDesign.appBarBackground,
        elevation: 0,
        leading: IconButton(
          tooltip: 'back'.tr,
          icon: Icon(Icons.arrow_back, color: AppDesign.appBarIcon),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'property_details'.tr,
          style: TextStyle(color: AppDesign.appBarText, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppDesign.textSecondary),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(fontSize: 18, color: AppDesign.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Get.find<PropertyDetailsController>().retry(),
                icon: const Icon(Icons.refresh),
                label: Text('retry'.tr),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesign.primaryYellow,
                  foregroundColor: AppDesign.buttonText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the property location in an external maps app with turn-by-turn
/// directions.
Future<void> _openInMaps(double latitude, double longitude, String label) async {
  final encodedLabel = Uri.encodeComponent(label);
  final httpsUri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1'
    '&destination=$latitude,$longitude&travelmode=driving',
  );

  if (kIsWeb) {
    try {
      final launched = await launchUrl(httpsUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        AppToast.warning('unable_to_open_maps'.tr, 'check_device_settings'.tr);
      }
    } catch (e) {
      debugPrint('property_details_view._openInMaps: HTTPS fallback failed: $e');
      AppToast.warning('unable_to_open_maps'.tr, 'check_device_settings'.tr);
    }
    return;
  }

  if (defaultTargetPlatform == TargetPlatform.iOS) {
    final googleMapsApp = Uri.parse(
      'comgooglemaps://?daddr=$latitude,$longitude&directionsmode=driving',
    );
    if (await canLaunchUrl(googleMapsApp)) {
      await launchUrl(googleMapsApp, mode: LaunchMode.externalApplication);
      return;
    }

    final appleMaps = Uri.parse('maps://?daddr=$latitude,$longitude&dirflg=d&q=$encodedLabel');
    if (await canLaunchUrl(appleMaps)) {
      await launchUrl(appleMaps, mode: LaunchMode.externalApplication);
      return;
    }

    try {
      final launched = await launchUrl(httpsUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        AppToast.warning('unable_to_open_maps'.tr, 'check_device_settings'.tr);
      }
    } catch (e) {
      debugPrint('property_details_view._openInMaps: HTTPS fallback failed: $e');
      AppToast.warning('unable_to_open_maps'.tr, 'check_device_settings'.tr);
    }
    return;
  }

  final geoUri = Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude($encodedLabel)');
  try {
    final launched = await launchUrl(geoUri, mode: LaunchMode.externalApplication);
    if (launched) return;
  } catch (e) {
    debugPrint('property_details_view._openInMaps: geo: launch failed, falling back to HTTPS: $e');
  }

  try {
    final launched = await launchUrl(httpsUri, mode: LaunchMode.externalApplication);
    if (!launched) {
      AppToast.warning('unable_to_open_maps'.tr, 'check_device_settings'.tr);
    }
  } catch (e) {
    debugPrint('property_details_view._openInMaps: HTTPS fallback failed: $e');
    AppToast.warning('unable_to_open_maps'.tr, 'check_device_settings'.tr);
  }
}
