import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/map/mini_map_view.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/responsive.dart';
import 'package:ghar360/core/utils/share_utils.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/common/scroll_reveal_widget.dart';
import 'package:ghar360/core/widgets/property/property_details_features.dart';
import 'package:ghar360/features/likes/presentation/controllers/likes_controller.dart';
import 'package:ghar360/features/property_details/presentation/controllers/property_details_controller.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_image_gallery.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_info_sections.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_visit_dialog.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_media_hub.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';
import 'package:google_fonts/google_fonts.dart';
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

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LikesController>();
    final visitsController = Get.find<VisitsController>();
    final PropertyModel safeProperty = widget.property;
    final sizeClass = context.windowSizeClass;
    final useTwoPane = sizeClass == WindowSizeClass.expanded || sizeClass == WindowSizeClass.large;

    final body = useTwoPane
        ? _buildTwoPaneBody(context, safeProperty, controller, visitsController)
        : _buildSingleColumnBody(context, safeProperty, controller, visitsController);

    return Semantics(
      label: 'qa.property_details.screen',
      identifier: 'qa.property_details.screen',
      child: Scaffold(
        key: const ValueKey('qa.property_details.screen'),
        backgroundColor: AppDesign.scaffoldBackground,
        body: body,
        // Bottom Action Buttons
        bottomNavigationBar: SafeArea(
          top: false,
          child: _buildBottomBar(context, safeProperty, visitsController),
        ),
      ),
    );
  }

  /// Phone / small-tablet layout: a single scrolling column with the gallery
  /// in a pinned [SliverAppBar]. Pixel-identical to the pre-iPad layout on
  /// [WindowSizeClass.compact]; the only change is the adaptive header height
  /// cap on [WindowSizeClass.medium] so it does not dominate small tablets.
  Widget _buildSingleColumnBody(
    BuildContext context,
    PropertyModel safeProperty,
    LikesController controller,
    VisitsController visitsController,
  ) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    // Cap the header on medium widths so it does not swallow the viewport on
    // small tablets / large phones in landscape. 380px on compact is unchanged.
    final expandedHeight = responsiveValue<double>(
      context,
      compact: 380,
      medium: 380 < screenHeight * 0.4 ? 380 : screenHeight * 0.4,
      fallback: 380,
    );

    return CustomScrollView(
      slivers: [
        // App Bar with Image
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
                  controller.isFavourite(safeProperty.id) ? Icons.favorite : Icons.favorite_border,
                  color: controller.isFavourite(safeProperty.id)
                      ? AppDesign.favoriteActive
                      : AppDesign.textPrimary,
                ),
                onPressed: () {
                  if (controller.isFavourite(safeProperty.id)) {
                    controller.removeFromFavourites(safeProperty.id);
                  } else {
                    controller.addToFavourites(safeProperty.id);
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

        // Property Details Content
        SliverToBoxAdapter(
          child: Container(
            color: AppDesign.scaffoldBackground,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _buildDetailSections(context, safeProperty),
            ),
          ),
        ),
      ],
    );
  }

  /// iPad / tablet layout ([WindowSizeClass.expanded] and [large]): a
  /// master-detail split. The left pane is a sticky media column (image
  /// gallery + action buttons), the right pane scrolls through all detail
  /// sections. Both panes reuse the exact same section builders as the phone
  /// layout, so content and behavior stay identical.
  Widget _buildTwoPaneBody(
    BuildContext context,
    PropertyModel safeProperty,
    LikesController controller,
    VisitsController visitsController,
  ) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    // Cap gallery height so the left pane does not stretch absurdly tall on
    // large iPads. Keeps the media anchored near the top.
    final galleryHeight = (screenHeight * 0.7) < 520.0 ? screenHeight * 0.7 : 520.0;
    // Left media pane width: ~42% of the viewport, capped to keep it from
    // growing too wide on desktop-class widths.
    final screenWidth = MediaQuery.sizeOf(context).width;
    final leftPaneWidth = screenWidth * 0.42 < 460.0 ? screenWidth * 0.42 : 460.0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- Left: sticky media pane ----
            SizedBox(
              width: leftPaneWidth,
              child: Column(
                children: [
                  // Action row (back / favourite / share) — mirrors the phone
                  // SliverAppBar actions so all taps + QA semantics are kept.
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
                              controller.isFavourite(safeProperty.id)
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: controller.isFavourite(safeProperty.id)
                                  ? AppDesign.favoriteActive
                                  : AppDesign.textPrimary,
                            ),
                            onPressed: () {
                              if (controller.isFavourite(safeProperty.id)) {
                                controller.removeFromFavourites(safeProperty.id);
                              } else {
                                controller.addToFavourites(safeProperty.id);
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
                  // Gallery card, rounded to read as a panel on tablet.
                  // Fixed SizedBox (not Expanded) so the gallery honors
                  // `maxHeight` and does not stretch absurdly tall on iPads.
                  SizedBox(
                    height: galleryHeight,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
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
            // ---- Right: scrollable details pane ----
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppDesign.scaffoldBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      // Keep detail text readable on wide panes.
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: _buildDetailSections(context, safeProperty),
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

  /// Shared detail-sections column used by both the single-column and
  /// two-pane layouts. Identical order and spacing as the original phone view.
  Widget _buildDetailSections(BuildContext context, PropertyModel safeProperty) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Price and Title
        ScrollRevealWidget(index: 0, child: _buildPriceTitleSection(context, safeProperty)),
        const SizedBox(height: 24),

        if (safeProperty.hasAnyMedia) ...[
          ScrollRevealWidget(index: 1, child: PropertyMediaBadges(property: safeProperty)),
          const SizedBox(height: 12),
          ScrollRevealWidget(
            index: 2,
            child: PropertyMediaHub(
              property: safeProperty,
              googleMapsApiKey: dotenv.env['GOOGLE_PLACES_API_KEY'],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Property Features
        ScrollRevealWidget(index: 3, child: PropertyDetailsFeatures(property: safeProperty)),
        const SizedBox(height: 24),

        // Description
        ScrollRevealWidget(index: 4, child: _buildDescriptionSection(context, safeProperty)),
        const SizedBox(height: 16),

        // Highlights
        if ((safeProperty.features?.isNotEmpty ?? false))
          ..._buildHighlightsSection(context, safeProperty),
        const SizedBox(height: 24),

        // Property Information
        ScrollRevealWidget(index: 5, child: PropertyDetailsInfoSection(property: safeProperty)),
        const SizedBox(height: 24),

        // Pricing Details
        ScrollRevealWidget(index: 6, child: PropertyDetailsPricingSection(property: safeProperty)),
        const SizedBox(height: 24),

        // Builder Information
        if (safeProperty.builderName?.isNotEmpty == true) ...[
          ScrollRevealWidget(
            index: 7,
            child: PropertyDetailsContactSection(property: safeProperty),
          ),
          const SizedBox(height: 24),
        ],

        // Amenities
        ScrollRevealWidget(index: 8, child: _buildAmenitiesSection(context, safeProperty)),
        const SizedBox(height: 24),

        // Location + Directions
        if (safeProperty.hasLocation) ..._buildLocationSection(context, safeProperty),

        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildPriceTitleSection(BuildContext context, PropertyModel property) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildEditorialChip(context, property.propertyTypeTranslationKey.tr),
            _buildEditorialChip(context, property.listingTranslationKey.tr),
          ],
        ),
        const SizedBox(height: 14),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: property.formattedPrice,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 32,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: AppDesign.textPrimary,
                ),
              ),
              if (property.purpose == PropertyPurpose.rent)
                TextSpan(
                  text: 'per_month_short'.tr,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppDesign.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (property.purpose == PropertyPurpose.shortStay)
                TextSpan(
                  text: 'per_day_short'.tr,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppDesign.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          property.title,
          style: theme.textTheme.titleLarge?.copyWith(
            color: AppDesign.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (property.pricePerSqft != null)
              _buildEditorialChip(context, '₹${property.pricePerSqft!.toStringAsFixed(0)}/sqft'),
            if (property.securityDeposit != null)
              _buildEditorialChip(
                context,
                'security_deposit_amount'.trParams({
                  'amount': property.securityDeposit!.toStringAsFixed(0),
                }),
              ),
            if (property.maintenanceCharges != null)
              _buildEditorialChip(
                context,
                'maintenance_amount'.trParams({
                  'amount': property.maintenanceCharges!.toStringAsFixed(0),
                }),
              ),
          ],
        ),
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
        _buildEditorialSectionHeader(context, 'description'.tr),
        Text(
          description,
          maxLines: canCollapse && !_isDescriptionExpanded ? _collapsedDescriptionLines : null,
          overflow: canCollapse && !_isDescriptionExpanded
              ? TextOverflow.ellipsis
              : TextOverflow.visible,
          style: theme.textTheme.bodyLarge?.copyWith(color: AppDesign.textSecondary, height: 1.7),
        ),
        if (canCollapse) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _isDescriptionExpanded = !_isDescriptionExpanded;
              });
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              alignment: Alignment.centerLeft,
            ),
            child: Text(
              _isDescriptionExpanded ? 'read_less'.tr : 'read_more'.tr,
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppDesign.primaryYellow,
                decoration: TextDecoration.underline,
                decorationColor: AppDesign.primaryYellow,
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildHighlightsSection(BuildContext context, PropertyModel property) {
    return [
      _buildEditorialSectionHeader(context, 'highlights'.tr),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: (property.features ?? [])
            .take(6)
            .map((feature) => _buildEditorialChip(context, feature))
            .toList(),
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _buildAmenitiesSection(BuildContext context, PropertyModel property) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEditorialSectionHeader(context, 'amenities'.tr),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              property.amenities
                  ?.map(
                    (amenity) => _buildEditorialChip(
                      context,
                      amenity.title,
                      leading: amenity.icon != null && amenity.icon!.startsWith('http')
                          ? Image.network(
                              amenity.icon!,
                              width: 16,
                              height: 16,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.check_circle_outline,
                                size: 16,
                                color: AppDesign.textSecondary,
                              ),
                            )
                          : Icon(
                              Icons.check_circle_outline,
                              size: 16,
                              color: AppDesign.textSecondary,
                            ),
                    ),
                  )
                  .toList() ??
              [],
        ),
      ],
    );
  }

  List<Widget> _buildLocationSection(BuildContext context, PropertyModel property) {
    final lat = property.latitude;
    final lng = property.longitude;
    if (lat == null || lng == null) return const [SizedBox.shrink()];

    final theme = Theme.of(context);

    return [
      const SizedBox(height: 8),
      _buildEditorialSectionHeader(context, 'location'.tr),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppDesign.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppDesign.getCardShadow(),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on, color: AppDesign.iconColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                property.shortAddressDisplay,
                style: theme.textTheme.bodyLarge?.copyWith(color: AppDesign.textSecondary),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Container(
        height: 260,
        decoration: BoxDecoration(
          color: AppDesign.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppDesign.getCardShadow(),
          border: Border.all(color: AppDesign.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: MiniMapView(latitude: lat, longitude: lng),
      ),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          key: const ValueKey('qa.property_details.get_directions'),
          onPressed: () => _openGoogleMaps(lat, lng, property.title),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: AppDesign.primaryYellow,
          ),
          child: Text(
            'get_directions'.tr,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppDesign.primaryYellow,
              decoration: TextDecoration.underline,
              decorationColor: AppDesign.primaryYellow,
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
    ];
  }

  Widget _buildBottomBar(
    BuildContext context,
    PropertyModel property,
    VisitsController visitsController,
  ) {
    return Obx(() {
      VisitModel? scheduledVisit;
      for (final v in visitsController.upcomingVisitsList) {
        if (v.propertyId == property.id) {
          scheduledVisit = v;
          break;
        }
      }

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppDesign.surface,
          border: Border(
            top: BorderSide(color: AppDesign.primaryYellow.withValues(alpha: 0.55), width: 0.8),
          ),
          boxShadow: [
            BoxShadow(color: AppDesign.shadowColor, blurRadius: 10, offset: const Offset(0, -5)),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: (() {
            final DateTime? scheduledDate =
                property.userNextVisitDate ?? scheduledVisit?.scheduledDate;
            final bool alreadyScheduled = property.userHasScheduledVisit || scheduledDate != null;

            return alreadyScheduled
                ? _buildScheduledBanner(scheduledDate)
                : _buildScheduleButton(context, property, visitsController);
          })(),
        ),
      );
    });
  }

  Widget _buildScheduledBanner(DateTime? scheduledDate) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: AppDesign.inputBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          top: const BorderSide(color: AppDesign.primaryYellow, width: 1),
          left: BorderSide(color: AppDesign.border.withValues(alpha: 0.65)),
          right: BorderSide(color: AppDesign.border.withValues(alpha: 0.65)),
          bottom: BorderSide(color: AppDesign.border.withValues(alpha: 0.65)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: AppDesign.accentGreen),
          const SizedBox(width: 8),
          Text(
            (() {
              if (scheduledDate != null) {
                final formatted =
                    '${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year}';
                return '${'visit_scheduled'.tr}: $formatted';
              }
              return 'visit_scheduled'.tr;
            })(),
            style: TextStyle(
              color: AppDesign.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleButton(
    BuildContext context,
    PropertyModel property,
    VisitsController visitsController,
  ) {
    return ElevatedButton(
      key: const ValueKey('qa.property_details.schedule_visit'),
      onPressed: () => showBookVisitDialog(context, property, visitsController),
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shadowColor: Colors.transparent,
        backgroundColor: AppDesign.primaryYellow,
        foregroundColor: AppDesign.buttonText,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppDesign.primaryYellowDark.withValues(alpha: 0.45)),
        ),
      ),
      child: Text(
        'schedule_visit'.tr,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppDesign.buttonText,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildEditorialSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.playfairDisplay(
              textStyle: theme.textTheme.headlineSmall?.copyWith(
                color: AppDesign.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(width: 56, height: 1, color: AppDesign.primaryYellow.withValues(alpha: 0.75)),
        ],
      ),
    );
  }

  Widget _buildEditorialChip(BuildContext context, String text, {Widget? leading}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppDesign.inputBackground : AppDesign.warmCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesign.primaryYellow.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 6)],
          Text(
            text,
            style: TextStyle(
              color: isDark ? AppDesign.textPrimary : AppDesign.editorialInk,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorialAppBarButton({required Widget icon, required VoidCallback onPressed}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: AppDesign.surface.withValues(alpha: 0.84),
        shape: BoxShape.circle,
        border: Border.all(color: AppDesign.primaryYellow.withValues(alpha: 0.65), width: 0.9),
      ),
      child: IconButton(onPressed: onPressed, icon: icon, splashRadius: 20),
    );
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
          tooltip: 'Back',
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
          tooltip: 'Back',
          icon: Icon(Icons.arrow_back, color: AppDesign.appBarIcon),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'property_details'.tr,
          style: TextStyle(color: AppDesign.appBarText, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Text(message, style: TextStyle(fontSize: 18, color: AppDesign.textSecondary)),
      ),
    );
  }
}

Future<void> _openGoogleMaps(double latitude, double longitude, String label) async {
  final url = Uri.parse(
    'https://www.google.com/maps/dir/?api=1'
    '&destination=$latitude,$longitude&travelmode=driving',
  );
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  } else {
    AppToast.warning('unable_to_open_maps'.tr, 'check_device_settings'.tr);
  }
}
