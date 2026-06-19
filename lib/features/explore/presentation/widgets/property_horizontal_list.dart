import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/app_design_tokens.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/features/explore/presentation/controllers/explore_controller.dart';
import 'package:ghar360/features/explore/presentation/widgets/explore_property_card.dart';

/// The property list for the Explore map.
///
/// Renders as a horizontal card strip (phone/compact) or a vertical list
/// inside a tablet side panel (expanded/large). The horizontal layout is the
/// original design and must stay visually identical on compact widths; the
/// vertical layout is selected via [direction] = [Axis.vertical] from the
/// two-pane tablet shell.
class PropertyHorizontalList extends StatefulWidget {
  final ExploreController controller;

  /// Scroll axis of the list. Defaults to [Axis.horizontal] (phone). The tablet
  /// side panel passes [Axis.vertical].
  final Axis direction;

  const PropertyHorizontalList({
    super.key,
    required this.controller,
    this.direction = Axis.horizontal,
  });

  @override
  State<PropertyHorizontalList> createState() => _PropertyHorizontalListState();
}

class _PropertyHorizontalListState extends State<PropertyHorizontalList> {
  final ScrollController _scrollController = ScrollController();
  Worker? _selectionWorker;
  int? _lastSelectedId;
  Timer? _scrollDebounce;

  // Horizontal card geometry (unchanged from the original layout).
  static const double _itemWidth = 260.0;
  static const double _spacing = 12.0;
  // Vertical list item height — matches ExplorePropertyCard's intrinsic height.
  static const double _verticalItemHeight = 112.0 + 86.0;

  @override
  void initState() {
    super.initState();
    // Listen to selected property changes to auto-scroll
    _selectionWorker = ever(widget.controller.selectedProperty, (PropertyModel? p) {
      if (p == null) return;
      if (_lastSelectedId == p.id) return;
      _lastSelectedId = p.id;
      HapticFeedback.selectionClick();
      _scrollToProperty(p.id);
    });

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _selectionWorker?.dispose();
    _scrollDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToProperty(int propertyId) {
    try {
      final index = widget.controller.properties.indexWhere((e) => e.id == propertyId);
      if (index == -1) return;

      final isVertical = widget.direction == Axis.vertical;
      final itemExtent = isVertical ? _verticalItemHeight : _itemWidth;
      final viewportDimension = _scrollController.position.viewportDimension;

      // Center the selected card in the viewport
      final target = index * (itemExtent + _spacing) - (viewportDimension / 2) + (itemExtent / 2);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollController.animateTo(
          target.clamp(0, _scrollController.position.maxScrollExtent),
          duration: AppDurations.normal,
          curve: AppCurves.standard,
        );
      });
    } catch (e) {
      DebugLogger.warning('Could not scroll to property: $e');
    }
  }

  void _onScroll() {
    // Debounce to avoid spamming highlight updates
    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(const Duration(milliseconds: 80), () {
      try {
        final isVertical = widget.direction == Axis.vertical;
        final itemExtent = isVertical ? _verticalItemHeight : _itemWidth;
        final offset = _scrollController.offset;
        final rawIndex = offset / (itemExtent + _spacing);
        final index = rawIndex.round().clamp(0, widget.controller.properties.length - 1);
        if (widget.controller.properties.isEmpty) return;
        final property = widget.controller.properties[index];
        if (property.id != _lastSelectedId) {
          _lastSelectedId = property.id;
          widget.controller.highlightPropertyFromCard(property);
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final isVertical = widget.direction == Axis.vertical;

    return Obx(() {
      final properties = widget.controller.properties;
      // Force Obx to subscribe to like state changes
      final _ = widget.controller.likedOverrides.entries.toList();
      if (properties.isEmpty) {
        if (isVertical) {
          return SizedBox(
            height: double.infinity,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'no_properties_found'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppDesignTokens.darkTextSecondary
                        : AppDesignTokens.neutral500,
                  ),
                ),
              ),
            ),
          );
        }
        return Container(
          height: 10, // keep minimal footprint when empty
          color: AppDesign.transparent,
        );
      }

      // Vertical list for the tablet side panel.
      if (isVertical) {
        return ListView.separated(
          controller: _scrollController,
          scrollDirection: Axis.vertical,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          itemBuilder: (context, index) => _buildCard(context, properties[index]),
          separatorBuilder: (context, index) => const SizedBox(height: _spacing),
          itemCount: properties.length,
        );
      }

      // Horizontal card strip (original phone layout — visually unchanged).
      return Container(
        height: 220,
        padding: const EdgeInsets.only(bottom: 10),
        child: ListView.separated(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) => _buildCard(context, properties[index]),
          separatorBuilder: (context, index) => const SizedBox(width: _spacing),
          itemCount: properties.length,
        ),
      );
    });
  }

  Widget _buildCard(BuildContext context, PropertyModel property) {
    final isVertical = widget.direction == Axis.vertical;
    final isSelected = widget.controller.selectedProperty.value?.id == property.id;
    final isFavourite = widget.controller.isPropertyLiked(property);

    // The card uses an Expanded content row, so it needs a bounded height on
    // both axes. In the horizontal strip the parent gives it height: 220; in
    // the vertical side panel we constrain it explicitly via SizedBox.
    final card = ExplorePropertyCard(
      property: property,
      isFavourite: isFavourite,
      onFavouriteToggle: () => widget.controller.toggleLike(property),
    );

    final container = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isVertical ? double.infinity : _itemWidth,
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isSelected ? AppDesignTokens.brandGoldSubtle.withValues(alpha: 0.5) : null,
        border: Border.all(
          color: isSelected ? AppDesignTokens.brandGold : AppDesign.transparent,
          width: isSelected ? 1.5 : 0,
        ),
      ),
      child: card,
    );

    if (!isVertical) return container;
    return SizedBox(height: _verticalItemHeight, child: container);
  }
}
