import 'package:flutter/material.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/features/discover/presentation/widgets/swipe_card_details_section.dart';
import 'package:ghar360/features/discover/presentation/widgets/swipe_card_hero_section.dart';

/// A single swipe card displaying a property's hero image at the top
/// and details below. Composes [SwipeCardHeroSection] and
/// [SwipeCardDetailsSection] inside the card chrome only.
///
/// Vertical scroll is owned by [PropertySwipeStack]. The screen owns the visible Like / Pass controls.
///
/// Gesture map (see also [PropertySwipeStack]):
/// - Hero tap / View details → [onTap] (property details)
/// - Vertical scroll → owned by the stack
/// - Embedded interactive children (e.g. 360 tour) signal via
///   [onInteractionStart]/[onInteractionEnd] so the stack can block deck swipes
class PropertySwipeCard extends StatelessWidget {
  final PropertyModel property;
  final VoidCallback? onTap;
  final double? viewportHeight;
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;

  const PropertySwipeCard({
    super.key,
    required this.property,
    this.onTap,
    this.viewportHeight,
    this.onInteractionStart,
    this.onInteractionEnd,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    // Each home gets its own hand-cut edge. The deck casts its shadow: the
    // card's scroll view would clip one painted here.
    final shape = CutBorder(seed: 'card-${property.id}', amp: 2.5);
    return DecoratedBox(
      decoration: ShapeDecoration(color: design.surface, shape: shape),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SwipeCardHeroSection(
              property: property,
              onViewDetails: onTap,
              viewportHeight: viewportHeight,
            ),
            SwipeCardDetailsSection(
              property: property,
              onInteractionStart: onInteractionStart,
              onInteractionEnd: onInteractionEnd,
            ),
          ],
        ),
      ),
    );
  }
}
