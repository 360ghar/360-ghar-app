import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghar360/core/config/app_config.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_art.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/presentation/property_labels.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/error_message.dart';
import 'package:ghar360/core/utils/responsive.dart';
import 'package:ghar360/core/utils/share_utils.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/core/widgets/common/inline_retry_banner.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/common/property_list_card.dart';
import 'package:ghar360/core/widgets/common/sign_in_gate.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/core/widgets/paper/paper_skyline.dart';
import 'package:ghar360/core/widgets/paper/sheet_sliver.dart';
import 'package:ghar360/core/widgets/property/property_facts.dart';
import 'package:ghar360/features/properties/application/swipe_history.dart';
import 'package:ghar360/features/property_details/presentation/controllers/property_details_controller.dart';
import 'package:ghar360/features/property_details/presentation/widgets/fullscreen_photo_gallery.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_amenities_grid.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_bottom_bar.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_image_gallery.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_info_sections.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_location_card.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_overview.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_section_nav.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_media_hub.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class PropertyDetailsView extends ConsumerStatefulWidget {
  const PropertyDetailsView({
    super.key,
    required this.propertyId,
    this.initialProperty,
    this.embedded = false,
    this.showBookingBar = true,
  });
  final int propertyId;
  final PropertyModel? initialProperty;

  /// Shown as the detail pane of a list screen: one column, no back button.
  final bool embedded;

  /// False where the host already shows the visit actions (the Visits pane).
  final bool showBookingBar;

  @override
  ConsumerState<PropertyDetailsView> createState() => _PropertyDetailsViewState();
}

class _PropertyDetailsViewState extends ConsumerState<PropertyDetailsView> {
  late final StorageScope _seedScope;
  @override
  void initState() {
    super.initState();
    _seedScope = ref.read(storageScopeProvider);
  }

  @override
  Widget build(BuildContext context) {
    final scope = ref.watch(storageScopeProvider);
    final state = ref.watch(propertyDetailsProvider(widget.propertyId));
    final seed = identical(scope, _seedScope) && widget.initialProperty?.id == widget.propertyId
        ? widget.initialProperty
        : null;
    final property = state.property ?? (state.failure is NotFoundException ? null : seed);
    final retry = ref.read(propertyDetailsProvider(widget.propertyId).notifier).refresh;
    if (property == null) {
      return _PropertyStateScaffold(
        embedded: widget.embedded,
        body: state.busy
            ? LoadingStates.propertyDetailsSkeleton()
            : ErrorStates.genericError(error: state.failure, onRetry: retry, seed: 'details'),
      );
    }
    return _PropertyContentView(
      key: ValueKey(widget.propertyId),
      property: property,
      refreshing: state.busy,
      stale: state.stale,
      failure: state.failure,
      onRetry: retry,
      embedded: widget.embedded,
      showBookingBar: widget.showBookingBar,
    );
  }
}

class _PropertyContentView extends ConsumerStatefulWidget {
  const _PropertyContentView({
    super.key,
    required this.property,
    required this.refreshing,
    required this.stale,
    required this.failure,
    required this.onRetry,
    required this.embedded,
    required this.showBookingBar,
  });
  final bool embedded;
  final bool showBookingBar;
  final bool refreshing;
  final bool stale;
  final AppException? failure;
  final Future<void> Function() onRetry;

  final PropertyModel property;

  @override
  ConsumerState<_PropertyContentView> createState() => _PropertyContentViewState();
}

class _PropertyContentViewState extends ConsumerState<_PropertyContentView> {
  static const int _collapsedDescriptionLines = 5;
  bool _isDescriptionExpanded = false;
  PropertyDetailsSection _activeSection = PropertyDetailsSection.overview;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _overviewKey = GlobalKey();
  final GlobalKey _mediaKey = GlobalKey();
  final GlobalKey _specsKey = GlobalKey();
  final GlobalKey _locationKey = GlobalKey();

  /// Height held over the top of the scroll view (the collapsed header). A
  /// section is current once its top passes under it.
  double _pinned = 0;

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

  List<(PropertyDetailsSection, GlobalKey)> get _sections => [
    (PropertyDetailsSection.overview, _overviewKey),
    if (widget.property.hasAnyMedia) (PropertyDetailsSection.media, _mediaKey),
    (PropertyDetailsSection.specs, _specsKey),
    if (widget.property.hasLocation) (PropertyDetailsSection.location, _locationKey),
  ];

  void _onScroll() {
    if (!mounted || _syncingFromScroll || !_scrollController.hasClients) return;
    final sections = _sections;
    var next = sections.first.$1;
    for (final (id, key) in sections) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      final viewport = box == null ? null : RenderAbstractViewport.maybeOf(box);
      if (box == null || viewport == null || !box.hasSize) continue;
      if (box.localToGlobal(Offset.zero, ancestor: viewport).dy <= _pinned + 48) next = id;
    }
    // A short last section never reaches the top; the end of the page is it.
    final position = _scrollController.position;
    if (position.maxScrollExtent > 0 && position.pixels >= position.maxScrollExtent - 1) {
      next = sections.last.$1;
    }
    if (next != _activeSection) setState(() => _activeSection = next);
  }

  Future<void> _scrollToSection(PropertyDetailsSection section) async {
    final key = switch (section) {
      PropertyDetailsSection.overview => _overviewKey,
      PropertyDetailsSection.media => _mediaKey,
      PropertyDetailsSection.specs => _specsKey,
      PropertyDetailsSection.location => _locationKey,
    };
    final box = key.currentContext?.findRenderObject();
    final viewport = box == null ? null : RenderAbstractViewport.maybeOf(box);
    if (box == null || viewport == null || !_scrollController.hasClients) return;

    setState(() => _activeSection = section);
    final position = _scrollController.position;
    // Overview is the top of the page, so the photo opens again. Other
    // sections stop just under the pinned header (the reveal allows for it).
    final target = section == PropertyDetailsSection.overview
        ? position.minScrollExtent
        : (viewport.getOffsetToReveal(box, 0).offset - AppSpacing.sm).clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          );
    _syncingFromScroll = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      position.jumpTo(target);
    } else {
      await position.animateTo(target, duration: AppDurations.normal, curve: AppCurves.standard);
    }
    if (mounted) _syncingFromScroll = false;
  }

  @override
  Widget build(BuildContext context) {
    final property = widget.property;
    final sizeClass = context.windowSizeClass;
    final useTwoPane =
        !widget.embedded &&
        (sizeClass == WindowSizeClass.expanded || sizeClass == WindowSizeClass.large);
    final bookingBar = !useTwoPane && widget.showBookingBar;

    return Semantics(
      label: context.l10n.text('property_details'),
      identifier: 'qa.property_details.screen',
      child: Scaffold(
        key: const ValueKey('qa.property_details.screen'),
        backgroundColor: context.design.background,
        // The sheet runs on under the booking strip, so the strip's cut edge
        // lies on the sheet instead of a band of sky.
        extendBody: bookingBar,
        body: Builder(
          builder: (context) => Stack(
            children: [
              Positioned.fill(
                child: useTwoPane
                    ? _buildTwoPaneBody(context, property)
                    : _buildSingleColumnBody(context, property),
              ),
              // A thin line at the very top while fresh details load; the
              // layout does not move.
              if (widget.refreshing)
                Positioned(
                  top: MediaQuery.paddingOf(context).top,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    semanticsLabel: context.l10n.text('loading'),
                  ),
                ),
            ],
          ),
        ),
        // Two panes keep the booking bar under the details column instead.
        bottomNavigationBar: bookingBar ? PropertyDetailsBottomBar(property: property) : null,
      ),
    );
  }

  Widget _buildSingleColumnBody(BuildContext context, PropertyModel property) {
    final media = MediaQuery.of(context);
    final hasPhoto = PropertyDetailsImageGallery.imagesOf(property).isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabsHeight = PropertyDetailsSectionNav.heightFor(
          context,
          constraints.maxWidth,
          showMedia: property.hasAnyMedia,
          showLocation: property.hasLocation,
        );
        final minHeight = media.padding.top + _GalleryHeaderDelegate.bar + tabsHeight;
        // The photo takes a little under half the screen; with no photo the
        // paper city fills a short band instead.
        final maxHeight = hasPhoto
            ? math.max(
                minHeight + 120,
                (constraints.maxHeight * 0.45).clamp(240.0, 400.0) + tabsHeight,
              )
            : minHeight + 132;
        _pinned = minHeight;
        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _GalleryHeaderDelegate(
                photo: hasPhoto
                    ? PropertyDetailsImageGallery(
                        property: property,
                        footInset: tabsHeight,
                        // A pane shows a home that its list shows too.
                        heroTag: widget.embedded ? null : propertyPhotoHeroTag(property.id),
                      )
                    : const PaperSkylineStrip(),
                hasPhoto: hasPhoto,
                tabs: _sectionNav(property),
                tabsHeight: tabsHeight,
                top: media.padding.top,
                title: property.title,
                minHeight: minHeight,
                maxHeight: maxHeight,
                reduce: MediaQuery.disableAnimationsOf(context),
                leading: widget.embedded
                    ? null
                    : (overPhoto) => _appBarButton(
                        overPhoto: overPhoto,
                        tooltip: context.l10n.text('back'),
                        icon: KnifeIcon.arrowLeft,
                        onPressed: () => _back(context),
                      ),
                actions: (overPhoto) => [
                  _buildFavouriteButton(property, overPhoto: overPhoto),
                  _appBarButton(
                    overPhoto: overPhoto,
                    tooltip: context.l10n.text('share'),
                    icon: KnifeIcon.share,
                    onPressed: () => ShareUtils.shareProperty(property, context: context),
                  ),
                ],
              ),
            ),
            SheetSliver(
              // The booking strip covers the foot of the sheet.
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.sm,
                AppSpacing.screenPadding,
                media.padding.bottom + AppSpacing.lg,
              ),
              slivers: [SliverToBoxAdapter(child: _buildDetailSections(context, property))],
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: ColoredBox(color: context.design.surface),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTwoPaneBody(BuildContext context, PropertyModel property) {
    final design = context.design;
    final screen = MediaQuery.sizeOf(context);
    final galleryHeight = math.min(screen.height * 0.7, 520.0);
    final leftPaneWidth = math.min(screen.width * 0.42, 460.0);
    final hasPhoto = PropertyDetailsImageGallery.imagesOf(property).isNotEmpty;
    final printShape = CutBorder(seed: 'details-print-${property.id}');
    _pinned = 0;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
        // Both panes are centred as one group, so a wide window shares its
        // spare width between the two outer margins.
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: leftPaneWidth + AppSpacing.lg + 640 + 2 * AppSpacing.screenPadding,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: leftPaneWidth,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          children: [
                            _appBarButton(
                              overPhoto: false,
                              tooltip: context.l10n.text('back'),
                              icon: KnifeIcon.arrowLeft,
                              onPressed: () => _back(context),
                            ),
                            const Spacer(),
                            _buildFavouriteButton(property, overPhoto: false),
                            _appBarButton(
                              overPhoto: false,
                              tooltip: context.l10n.text('share'),
                              icon: KnifeIcon.share,
                              onPressed: () => ShareUtils.shareProperty(property, context: context),
                            ),
                          ],
                        ),
                      ),
                      // The photo is a print laid on the sky.
                      DecoratedBox(
                        decoration: ShapeDecoration(
                          color: design.surface,
                          shape: CutBorder(
                            seed: printShape.seed,
                            shadows: paperShadows(
                              PaperElevation.low,
                              design.shadowOn(design.background),
                            ),
                          ),
                        ),
                        child: ClipPath(
                          clipper: ShapeBorderClipper(shape: printShape),
                          child: hasPhoto
                              ? PropertyDetailsImageGallery(
                                  property: property,
                                  maxHeight: galleryHeight,
                                  heroTag: propertyPhotoHeroTag(property.id),
                                )
                              : SizedBox(
                                  height: galleryHeight * 0.5,
                                  child: const PaperSkylineStrip(),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                // The tabs, the sheet and the booking strip share one centred
                // column, so the tabs line up with the text under them.
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 640 + 2 * AppSpacing.screenPadding,
                      ),
                      child: Column(
                        children: [
                          _sectionNav(property),
                          Expanded(
                            child: ColoredBox(
                              color: design.surface,
                              child: SingleChildScrollView(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.screenPadding,
                                  AppSpacing.sm,
                                  AppSpacing.screenPadding,
                                  AppSpacing.lg,
                                ),
                                child: _buildDetailSections(context, property),
                              ),
                            ),
                          ),
                          if (widget.showBookingBar) PropertyDetailsBottomBar(property: property),
                        ],
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

  Widget _sectionNav(PropertyModel property) => PropertyDetailsSectionNav(
    active: _activeSection,
    showMedia: property.hasAnyMedia,
    showLocation: property.hasLocation,
    onSelect: _scrollToSection,
  );

  Widget _buildDetailSections(BuildContext context, PropertyModel property) {
    final design = context.design;
    final text = Theme.of(context).textTheme;
    final features = property.localizedHighlights(context);
    final agent = property.agent;
    final failure = widget.failure;
    const gap = SizedBox(height: AppSpacing.xl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A failed refresh keeps the listing; the retry scrolls with it so it
        // never takes fixed space from a small screen.
        if (failure != null) ...[
          InlineRetryBanner(
            message: errorMessage(context, failure),
            onRetry: widget.onRetry,
            error: failure,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (widget.stale) ...[
          Row(
            children: [
              PaperIcon(KnifeIcon.clock, size: 16, color: design.textTertiary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.text('property_detail_stale'),
                  style: text.bodySmall?.copyWith(color: design.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        KeyedSubtree(
          key: _overviewKey,
          child: PropertyDetailsOverview(
            property: property,
            onLocationTap: property.hasLocation
                ? () => _scrollToSection(PropertyDetailsSection.location)
                : null,
          ),
        ),
        if (agent != null) ...[gap, PropertyDetailsAgentRow(agent: agent)],
        gap,
        if (property.hasAnyMedia) ...[
          KeyedSubtree(
            key: _mediaKey,
            child: PropertyMediaHub(
              property: property,
              googleMapsApiKey: AppConfig.instance.googlePlacesApiKey,
            ),
          ),
          gap,
        ],
        _buildDescriptionSection(context, property),
        gap,
        if (features.isNotEmpty) ...[
          SectionTitle(context.l10n.text('highlights')),
          for (final feature in features.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: PaperIcon(KnifeIcon.star, size: 16, color: design.accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      feature,
                      style: text.bodyMedium?.copyWith(color: design.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          gap,
        ],
        KeyedSubtree(
          key: _specsKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PropertyDetailsInfoSection(property: property),
              gap,
              PropertyDetailsPricingSection(property: property),
              if (property.builderName?.isNotEmpty == true) ...[
                gap,
                PropertyDetailsContactSection(property: property),
              ],
            ],
          ),
        ),
        if (property.hasAmenities) ...[gap, PropertyDetailsAmenitiesGrid(property: property)],
        if (property.hasLocation) ...[
          gap,
          KeyedSubtree(
            key: _locationKey,
            child: PropertyDetailsLocationCard(
              property: property,
              onOpenDirections: () =>
                  _openInMaps(context, property.latitude!, property.longitude!, property.title),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildDescriptionSection(BuildContext context, PropertyModel property) {
    final raw = property.description?.trim() ?? '';
    final canCollapse = raw.length > 240;
    final collapsed = canCollapse && !_isDescriptionExpanded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(context.l10n.text('description')),
        Text(
          raw.isNotEmpty ? raw : context.l10n.text('no_description_available'),
          maxLines: collapsed ? _collapsedDescriptionLines : null,
          overflow: collapsed ? TextOverflow.ellipsis : TextOverflow.visible,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: context.design.textSecondary),
        ),
        if (canCollapse)
          TextButton(
            onPressed: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    context.l10n.text(_isDescriptionExpanded ? 'read_less' : 'read_more'),
                  ),
                ),
                const SizedBox(width: 4),
                PaperIcon(
                  _isDescriptionExpanded ? KnifeIcon.chevronUp : KnifeIcon.chevronDown,
                  size: 18,
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Single heart, shared by the compact (header) and expanded (two-pane)
  /// layouts — only one of those branches ever builds.
  Widget _buildFavouriteButton(PropertyModel property, {required bool overPhoto}) {
    return Consumer(
      builder: (context, ref, _) {
        final (entryLiked, phase) = ref.watch(
          swipeHistoryProvider.select((history) {
            final entry = history.entries[property.id];
            return (entry?.isLiked, entry?.phase);
          }),
        );
        final liked = entryLiked ?? property.liked;
        return _appBarButton(
          overPhoto: overPhoto,
          tooltip: context.l10n.text(liked ? 'remove_from_favourites' : 'add_to_favourites'),
          icon: liked ? KnifeIcon.heartSolid : KnifeIcon.heart,
          liked: liked,
          onPressed: phase == SwipePhase.submitting
              ? null
              : () async {
                  if (!await requireAccount(context, ref, returnTo: '/property/${property.id}')) {
                    return;
                  }
                  if (!context.mounted) return;
                  final ok = await ref.read(swipeHistoryProvider.notifier).record(property, !liked);
                  if (!context.mounted) return;
                  if (!ok) {
                    AppToast.error(context.l10n.text('error'), context.l10n.text('network_error'));
                  }
                },
        );
      },
    );
  }

  /// A bare knife icon. Over the photo it is light with a tight shadow; on the
  /// page tone it takes the ink colour (a saved heart is brick).
  Widget _appBarButton({
    required bool overPhoto,
    required KnifeIcon icon,
    required VoidCallback? onPressed,
    required String tooltip,
    bool liked = false,
  }) {
    final design = context.design;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(minimumSize: const Size.square(48)),
      icon: PaperIcon(
        icon,
        color: overPhoto ? photoInk : (liked ? design.favoriteActive : design.textPrimary),
        shadows: overPhoto ? onPhoto : null,
      ),
    );
  }
}

/// The top of the details page, pinned: the photo under the status bar with
/// the section tabs cut into its foot. Scrolling, the sheet rises over the
/// photo (it moves at half speed), the photo gives way to the page tone, and
/// the bar keeps the icons, now in ink, and the home's name in Erode. The
/// tabs' lip is the sheet's hand-cut top edge, so the page never ends in a
/// straight line.
class _GalleryHeaderDelegate extends SliverPersistentHeaderDelegate {
  _GalleryHeaderDelegate({
    required this.photo,
    required this.hasPhoto,
    required this.tabs,
    required this.tabsHeight,
    required this.top,
    required this.title,
    required this.minHeight,
    required this.maxHeight,
    required this.reduce,
    required this.leading,
    required this.actions,
  });

  /// Height of the bar under the status bar.
  static const bar = 56.0;

  final Widget photo;
  final bool hasPhoto;
  final Widget tabs;
  final double tabsHeight;
  final double top;
  final String title;
  final double minHeight;
  final double maxHeight;
  final bool reduce;

  /// The bar's buttons, light over the photo or ink on the page tone.
  final Widget Function(bool overPhoto)? leading;
  final List<Widget> Function(bool overPhoto) actions;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final design = context.design;
    final range = maxHeight - minHeight;
    final shrink = shrinkOffset.clamp(0.0, range);
    // The photo gives way over the last one and a half bars of the collapse.
    final fade = math.min(range, bar * 1.5);
    final shown = fade <= 0 ? 0.0 : ((range - shrink) / fade).clamp(0.0, 1.0);
    final overPhoto = hasPhoto && shown > 0.5;
    final lead = leading?.call(overPhoto);
    final buttons = actions(overPhoto);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overPhoto || design.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _SkyPainter(design.background, design.grain)),
          Positioned(
            top: reduce ? -shrink : -shrink * 0.5,
            left: 0,
            right: 0,
            height: maxHeight,
            // A hidden photo takes no taps and flies no hero; with reduced
            // motion no photo flies.
            child: HeroMode(
              enabled: shown > 0.5 && !reduce,
              child: IgnorePointer(
                ignoring: shown < 0.5,
                child: Opacity(opacity: shown, child: photo),
              ),
            ),
          ),
          // The header's last pixel row is the sheet: on fractional device
          // pixels the lip's soft edge otherwise lets a line of photo through.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 2,
            child: ColoredBox(color: design.surface),
          ),
          Positioned(left: 0, right: 0, bottom: 0, height: tabsHeight, child: tabs),
          if (lead != null)
            Positioned(
              top: top,
              left: 4,
              height: bar,
              child: Center(child: lead),
            ),
          Positioned(
            top: top,
            left: lead == null ? 16 : 60,
            right: 12 + 48.0 * buttons.length,
            height: bar,
            // The name repeats the overview's title, so it is not read twice.
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: 1 - shown,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.3,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: top,
            right: 4,
            height: bar,
            child: Row(mainAxisSize: MainAxisSize.min, children: buttons),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _GalleryHeaderDelegate oldDelegate) => true;
}

/// The page tone with its grain, under the photo and the collapsed bar.
class _SkyPainter extends CustomPainter {
  const _SkyPainter(this.sky, this.grain);

  final Color sky;
  final Color grain;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = sky);
    paintPaperGrain(canvas, Offset.zero & size, grain);
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.sky != sky || old.grain != grain;
}

/// Loading and failure with nothing to show yet. A pane has no app bar.
class _PropertyStateScaffold extends StatelessWidget {
  const _PropertyStateScaffold({required this.embedded, required this.body});
  final bool embedded;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.design.background,
      appBar: embedded
          ? null
          : AppBar(
              backgroundColor: context.design.appBarBackground,
              leading: IconButton(
                tooltip: context.l10n.text('back'),
                icon: PaperIcon(KnifeIcon.arrowLeft, color: context.design.appBarIcon),
                onPressed: () => _back(context),
              ),
              title: Text(context.l10n.text('property_details')),
            ),
      body: body,
    );
  }
}

/// Opens the property location in an external maps app with turn-by-turn
/// directions.
Future<void> _openInMaps(
  BuildContext context,
  double latitude,
  double longitude,
  String label,
) async {
  final encodedLabel = Uri.encodeComponent(label);
  final httpsUri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1'
    '&destination=$latitude,$longitude&travelmode=driving',
  );

  if (kIsWeb) {
    try {
      final launched = await launchUrl(httpsUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        if (!context.mounted) return;
        AppToast.warning(
          context.l10n.text('unable_to_open_maps'),
          context.l10n.text('check_device_settings'),
        );
      }
    } catch (e) {
      debugPrint('Property maps launcher failed: ${e.runtimeType}');
      if (!context.mounted) return;
      AppToast.warning(
        context.l10n.text('unable_to_open_maps'),
        context.l10n.text('check_device_settings'),
      );
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
        if (!context.mounted) return;
        AppToast.warning(
          context.l10n.text('unable_to_open_maps'),
          context.l10n.text('check_device_settings'),
        );
      }
    } catch (e) {
      debugPrint('Property maps launcher failed: ${e.runtimeType}');
      if (!context.mounted) return;
      AppToast.warning(
        context.l10n.text('unable_to_open_maps'),
        context.l10n.text('check_device_settings'),
      );
    }
    return;
  }

  final geoUri = Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude($encodedLabel)');
  try {
    final launched = await launchUrl(geoUri, mode: LaunchMode.externalApplication);
    if (launched) return;
  } catch (e) {
    debugPrint('Property maps launcher failed: ${e.runtimeType}');
  }

  try {
    final launched = await launchUrl(httpsUri, mode: LaunchMode.externalApplication);
    if (!launched) {
      if (!context.mounted) return;
      AppToast.warning(
        context.l10n.text('unable_to_open_maps'),
        context.l10n.text('check_device_settings'),
      );
    }
  } catch (e) {
    debugPrint('Property maps launcher failed: ${e.runtimeType}');
    if (!context.mounted) return;
    AppToast.warning(
      context.l10n.text('unable_to_open_maps'),
      context.l10n.text('check_device_settings'),
    );
  }
}

void _back(BuildContext context) {
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  } else {
    context.go(AppRoutes.discover);
  }
}
