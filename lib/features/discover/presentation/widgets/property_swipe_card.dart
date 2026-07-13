import 'package:flutter/material.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/features/discover/presentation/widgets/swipe_card_details_section.dart';
import 'package:ghar360/features/discover/presentation/widgets/swipe_card_hero_section.dart';

/// A single swipe card displaying a property's hero image at the top
/// and details below. Composes [SwipeCardHeroSection] and
/// [SwipeCardDetailsSection] inside the card chrome only.
///
/// Vertical scroll and Pass/Details/Like actions live in [PropertySwipeStack]
/// so the action bar can sit **after** the card in the scroll trail without
/// being painted inside this rounded surface.
///
/// Gesture map (see also [PropertySwipeStack]):
/// - Hero tap / View details → [onTap] (property details)
/// - Vertical scroll → owned by the stack (card + trailing actions)
/// - Pass / Details / Like live **outside** this card (scroll trail)
/// - Embedded interactive children (e.g. 360 tour) signal via
///   [onInteractionStart]/[onInteractionEnd] so the stack can block deck swipes
class PropertySwipeCard extends StatelessWidget {
  final PropertyModel property;
  final VoidCallback? onTap;
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;

  const PropertySwipeCard({
    super.key,
    required this.property,
    this.onTap,
    this.onInteractionStart,
    this.onInteractionEnd,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppBorderRadius.card),
        boxShadow: [
          BoxShadow(color: AppDesign.shadowColor, blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppBorderRadius.card),
        child: ColoredBox(
          color: colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SwipeCardHeroSection(property: property, onViewDetails: onTap),
              SwipeCardDetailsSection(
                property: property,
                onInteractionStart: onInteractionStart,
                onInteractionEnd: onInteractionEnd,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
