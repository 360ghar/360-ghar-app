import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_art.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/utils/image_cache_service.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/common/robust_network_image.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/features/discover/presentation/widgets/property_swipe_card.dart';
import 'package:ghar360/features/discover/presentation/widgets/swipe_card_hero_section.dart';

/// Immutable drag state for the swipe gesture, driven by a [ValueNotifier]
/// so only the transform wrapper rebuilds during drag — not the card content.
@immutable
class _SwipeDragState {
  final Offset position;
  final double rotation;
  final bool isDragging;

  const _SwipeDragState({this.position = Offset.zero, this.rotation = 0, this.isDragging = false});

  _SwipeDragState copyWith({Offset? position, double? rotation, bool? isDragging}) {
    return _SwipeDragState(
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      isDragging: isDragging ?? this.isDragging,
    );
  }
}

/// The swipe stack containing multiple property cards with gesture
/// handling, animations, background preview cards, and sparkle effects.
///
/// Gesture map:
/// - Horizontal drag (stack) → like / pass
/// - Hero tap / View details → [onSwipeUp] (property details)
/// - Vertical scroll → full card details
/// - Gallery chevrons (hero) → change photo only
/// - 360 interaction → block stack gestures via [onInteractionStart]
///
/// Like / Pass use horizontal drag. Semantic custom actions provide a
/// non-drag path for accessibility (screen readers / switch control).
class PropertySwipeStack extends StatefulWidget {
  final List<PropertyModel> properties;
  final Function(PropertyModel) onSwipeLeft;
  final Function(PropertyModel) onSwipeRight;
  final Function(PropertyModel) onSwipeUp;
  final VoidCallback? onChangeFilters;
  final VoidCallback? onRefresh;

  /// True while the next page of properties is in flight. An empty deck then
  /// means "waiting for more", not "catalogue exhausted", so the empty state
  /// must not be shown — it would tell the user there is nothing left and
  /// offer to reset their filters moments before more cards arrive.
  final bool isLoadingMore;

  /// Synchronous last-chance check that the card is still swipeable before the
  /// exit animation commits it. [properties] is copied locally and frozen for
  /// the duration of a drag, so a background refresh landing mid-gesture can
  /// leave the top card absent from the real deck — the swipe would then be
  /// dropped on the floor while the card visibly flies off as a like.
  ///
  /// Must stay synchronous: the exit path runs from gesture callbacks, and
  /// awaiting here would strand the card mid-air with gestures unlocked.
  /// [isRight] is the direction, so a guest can be refused a like and the card
  /// snaps back.
  final bool Function(PropertyModel property, bool isRight)? canSwipe;

  const PropertySwipeStack({
    super.key,
    required this.properties,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    required this.onSwipeUp,
    this.onChangeFilters,
    this.onRefresh,
    this.isLoadingMore = false,
    this.canSwipe,
  });

  @override
  State<PropertySwipeStack> createState() => _PropertySwipeStackState();
}

class _PropertySwipeStackState extends State<PropertySwipeStack> with TickerProviderStateMixin {
  late List<PropertyModel> _properties;
  List<PropertyModel>? _pendingProperties;
  late AnimationController _swipeAnimationController;
  late AnimationController _entranceController;
  late Animation<double> _swipeAnimation;
  late Animation<double> _entranceScale;

  /// Drag state driven by ValueNotifier — only the transform wrapper
  /// listens to this, so the heavy PropertySwipeCard is never rebuilt
  /// during drag or snap-back.
  final ValueNotifier<_SwipeDragState> _dragNotifier = ValueNotifier(const _SwipeDragState());

  /// Stable merge of drag + exit + entrance listenables (created once).
  late final Listenable _transformListenable;

  /// Tracks the current snap-back controller so it can be disposed
  /// if the widget is disposed mid-animation.
  AnimationController? _snapController;

  bool _blockGestures = false;
  bool _isExiting = false;

  /// The next cards whose photos were last prefetched, with the deck height.
  String? _prefetched;

  /// Width of the card area, set by the last layout.
  double _cardWidth = 0;

  /// True while the stack must ignore pan gestures (exit, drag block, anim).
  bool get _gesturesLocked => _blockGestures || _isExiting || _swipeAnimationController.isAnimating;

  @override
  void initState() {
    super.initState();
    _properties = List.from(widget.properties);

    _swipeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _swipeAnimation = CurvedAnimation(parent: _swipeAnimationController, curve: Curves.easeInOut);

    _entranceController = AnimationController(vsync: this, duration: AppDurations.cardEntrance);
    _entranceScale = Tween<double>(
      begin: 0.93,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _entranceController, curve: AppCurves.cardEntrance));

    _transformListenable = Listenable.merge([
      _dragNotifier,
      _swipeAnimationController,
      _entranceController,
    ]);

    _swipeAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_pendingProperties != null) {
          _properties = _pendingProperties!;
          _pendingProperties = null;
        } else if (_properties.isNotEmpty) {
          _properties.removeAt(0);
        }
        _swipeAnimationController.reset();
        _dragNotifier.value = const _SwipeDragState();
        _isExiting = false;
        // setState to rebuild the card deck (next card becomes top card)
        setState(() {});
        // Animate new top card entrance
        _entranceController.forward(from: 0);
      }
    });

    // Animate first card entrance on initial build
    _entranceController.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: cards settle and leave at once. Content never waits on it.
    final still = MediaQuery.disableAnimationsOf(context);
    _swipeAnimationController.duration = still ? Duration.zero : const Duration(milliseconds: 400);
    _entranceController.duration = still ? Duration.zero : AppDurations.cardEntrance;
    if (still) _entranceController.value = 1;
  }

  @override
  void didUpdateWidget(PropertySwipeStack oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_arePropertyListsEqual(widget.properties, oldWidget.properties)) {
      final nextProperties = List<PropertyModel>.from(widget.properties);
      if (_swipeAnimationController.isAnimating || _dragNotifier.value.isDragging) {
        _pendingProperties = nextProperties;
      } else {
        _properties = nextProperties;
        _pendingProperties = null;
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _snapController?.dispose();
    _dragNotifier.dispose();
    _swipeAnimationController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  bool _arePropertyListsEqual(List<PropertyModel> a, List<PropertyModel> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  double _calculateRotation(Offset dragPosition, Size screenSize) {
    final horizontalRatio = dragPosition.dx / (screenSize.width * 0.5);
    final maxRotation = 0.785398; // 45 degrees
    return horizontalRatio * maxRotation * 0.7;
  }

  void _handlePanEnd(DragEndDetails details, Size screenSize) {
    if (_gesturesLocked && !_dragNotifier.value.isDragging) return;

    final drag = _dragNotifier.value;
    _dragNotifier.value = drag.copyWith(isDragging: false);

    final dragDistance = drag.position.dx;
    final dragThreshold = screenSize.width * 0.25;
    const rotationThreshold = 0.3;
    // Velocity-based flick: commit short, fast swipes like dating apps.
    final velocityX = details.velocity.pixelsPerSecond.dx;
    const velocityThreshold = 800.0;
    final shouldCommit =
        dragDistance.abs() > dragThreshold ||
        drag.rotation.abs() > rotationThreshold ||
        velocityX.abs() > velocityThreshold;

    if (shouldCommit) {
      // Prefer velocity when the flick itself crosses the threshold; otherwise
      // use signed drag distance (rotation as tie-breaker near zero).
      final bool isRight;
      if (velocityX.abs() > velocityThreshold && dragDistance.abs() <= dragThreshold) {
        isRight = velocityX > 0;
      } else if (dragDistance.abs() > 0.5) {
        isRight = dragDistance > 0;
      } else {
        isRight = drag.rotation >= 0;
      }
      // Keep the live drag position; shared exit path fires callbacks + anim.
      _beginExitSwipe(isRight: isRight);
    } else {
      _snapBack();
    }
  }

  void _snapBack() {
    _snapController?.dispose();
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _snapController = controller;

    final startDrag = _dragNotifier.value;
    final positionTween = Tween<Offset>(begin: startDrag.position, end: Offset.zero);
    final rotationTween = Tween<double>(begin: startDrag.rotation, end: 0);
    final snapAnimation = CurvedAnimation(parent: controller, curve: AppCurves.standard);

    controller.addListener(() {
      _dragNotifier.value = _SwipeDragState(
        position: positionTween.evaluate(snapAnimation),
        rotation: rotationTween.evaluate(snapAnimation),
      );
    });

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
        if (_snapController == controller) {
          _snapController = null;
        }
      }
    });

    controller.forward();
  }

  void _openDetails() {
    if (_properties.isEmpty || _gesturesLocked) {
      return;
    }
    widget.onSwipeUp(_properties[0]);
  }

  /// Programmatic like/pass for a11y (no drag required).
  ///
  /// Starts the card near the drag-commit threshold (~0.3× width) so the exit
  /// animation still slides off-screen, matching gesture-driven swipes. A full
  /// width seed would place the card already off-screen at animValue=0.
  void _commitSwipe({required bool isRight}) {
    if (_properties.isEmpty || _gesturesLocked) return;
    final startX = (_cardWidth > 0 ? _cardWidth : MediaQuery.sizeOf(context).width) * 0.3;
    _dragNotifier.value = _SwipeDragState(
      position: Offset(isRight ? startX : -startX, 0),
      rotation: isRight ? 0.15 : -0.15,
      isDragging: false,
    );
    _beginExitSwipe(isRight: isRight);
  }

  /// Shared exit for gesture-commit and a11y-commit paths.
  void _beginExitSwipe({required bool isRight}) {
    final card = _properties[0];
    // Last-chance check before the card is committed: if it is no longer in
    // the real deck the swipe would be rejected downstream and lost with no
    // POST, no stats and no feedback, while the card flew off as a like.
    // Bounce it back instead — deliberately before any exit state is set, so
    // gestures stay unlocked and the user can swipe the actual top card.
    if (widget.canSwipe?.call(card, isRight) == false) {
      _rejectSwipe();
      return;
    }
    if (isRight) {
      widget.onSwipeRight(card);
    } else {
      widget.onSwipeLeft(card);
    }
    setState(() => _isExiting = true);
    _swipeAnimationController.forward();
  }

  /// Bounces a card that can no longer be swiped back into the deck.
  ///
  /// The deck only changes under a drag by way of [didUpdateWidget] parking the
  /// new list in [_pendingProperties] (it is drained by the exit animation,
  /// which never runs here). Adopt it now, or the stale card stays on top and
  /// every further swipe attempt is rejected the same way.
  ///
  /// No toast on purpose: this fires when a refresh replaced the deck mid-drag
  /// (nothing failed), not when a swipe failed to save — that error toast is
  /// the controller's job, where the revert actually happened.
  void _rejectSwipe() {
    _snapBack();
    if (_pendingProperties != null) {
      setState(() {
        _properties = _pendingProperties!;
        _pendingProperties = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_properties.isEmpty) {
      // Mid-pagination the deck empties for a moment before the next page
      // lands. Showing "No More Properties" + "Change Filters" here tells the
      // user the catalogue is exhausted and invites them to reset a session
      // that is about to continue.
      // A centered spinner rather than LoadingStates.swipeCardSkeleton(): the
      // card skeleton's fixed internals overflow this slot (it sits inside the
      // deck's 16px padding) on shorter screens. Mirrors the "loading more"
      // row DiscoverView already shows during the initial load.
      if (widget.isLoadingMore) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LoadingStates.buttonSpinner(size: 24, color: context.design.accent),
              const SizedBox(height: 12),
              Text(
                context.l10n.text('loading_more_properties'),
                style: TextStyle(fontSize: 14, color: context.design.textSecondary),
              ),
            ],
          ),
        );
      }
      return ErrorStates.swipeDeckEmpty(
        onRefresh: widget.onRefresh,
        onChangeFilters: widget.onChangeFilters,
      );
    }

    // Wrap the stack in a LayoutBuilder so all swipe math is anchored to the
    // actual card area, not the full screen. On phones cardWidth equals the
    // previous content width (byte-for-bit identical); on tablets it reflects
    // the capped, centered card width so gestures feel correct.
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final cardSize = Size(cardWidth, constraints.maxHeight);
        final dragThreshold = cardWidth * 0.25;
        // Bounded deck height for min-height / scroll math (never 0/∞).
        final deckHeight =
            (constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : MediaQuery.sizeOf(context).height)
                .clamp(1.0, 10000.0);

        final top = _properties[0];
        _cardWidth = cardWidth;
        _prefetchNext(deckHeight, cardWidth);
        return Semantics(
          label: top.title,
          customSemanticsActions: {
            CustomSemanticsAction(label: context.l10n.text('liked')): () =>
                _commitSwipe(isRight: true),
            CustomSemanticsAction(label: context.l10n.text('passed')): () =>
                _commitSwipe(isRight: false),
            CustomSemanticsAction(label: context.l10n.text('view_details')): _openDetails,
          },
          child: GestureDetector(
            onHorizontalDragStart: (details) {
              if (_gesturesLocked) return;
              _dragNotifier.value = _dragNotifier.value.copyWith(isDragging: true);
            },
            onHorizontalDragUpdate: (details) {
              if (_gesturesLocked) return;
              final dx = details.primaryDelta ?? 0;
              final newPos = Offset(_dragNotifier.value.position.dx + dx, 0);
              _dragNotifier.value = _SwipeDragState(
                position: newPos,
                rotation: _calculateRotation(newPos, cardSize),
                isDragging: true,
              );
            },
            onHorizontalDragEnd: (details) {
              if (_gesturesLocked && !_dragNotifier.value.isDragging) return;
              if (_isExiting || _swipeAnimationController.isAnimating) return;
              _handlePanEnd(details, cardSize);
            },
            child: Stack(
              fit: StackFit.expand,
              // No clip: the turned sheets reach into the gutters, and a
              // dragged card is never sliced at the deck's edge.
              clipBehavior: Clip.none,
              children: [
                // The next cards: blank sheets of the city's card stock,
                // turned a little either way so their edges show around the
                // top card, the way a stack of paper lies.
                if (_properties.length > 2)
                  const Positioned.fill(
                    child: _DeckSheet(
                      seed: 'deck-2',
                      day: PaperTone.far,
                      night: PaperTone.far,
                      offset: Offset(-2, 9),
                      angle: -_deckTurn,
                    ),
                  ),
                if (_properties.length > 1)
                  const Positioned.fill(
                    child: _DeckSheet(
                      seed: 'deck-1',
                      day: PaperTone.mid,
                      night: PaperTone.sign,
                      offset: Offset(3, 2),
                      angle: _deckTurn,
                    ),
                  ),

                // Top card + end-of-scroll actions, with drag/swipe transform.
                // AnimatedBuilder rebuilds only the transform wrapper during drag;
                // the scroll deck is passed as `child` and rebuilt only on setState.
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _transformListenable,
                    child: _buildScrollableDeck(cardWidth: cardWidth, deckHeight: deckHeight),
                    builder: (context, cachedScroll) {
                      final drag = _dragNotifier.value;

                      final swipeOffset = drag.isDragging
                          ? Offset(drag.position.dx, 0)
                          : Offset(drag.position.dx * (1 + _swipeAnimation.value * 2), 0);

                      // Rotation "flick" — extra rotation burst in last 20% of exit
                      final double flickMultiplier;
                      if (!drag.isDragging && _swipeAnimation.value > 0.8) {
                        final flickProgress = (_swipeAnimation.value - 0.8) / 0.2;
                        flickMultiplier = 1.0 + flickProgress * 0.3;
                      } else {
                        flickMultiplier = 1.0;
                      }

                      final swipeRotation = drag.isDragging
                          ? drag.rotation
                          : drag.rotation * (1 + _swipeAnimation.value * 2) * flickMultiplier;

                      final likeProgress = (drag.position.dx / dragThreshold).clamp(0.0, 1.0);
                      final passProgress = (-drag.position.dx / dragThreshold).clamp(0.0, 1.0);
                      final showFeedback =
                          drag.isDragging && (likeProgress > 0 || passProgress > 0);

                      // Card entrance scale (0.93→1.0) when becoming top card
                      final entranceScale = _swipeAnimationController.isAnimating
                          ? 1.0
                          : _entranceScale.value;

                      return Transform.scale(
                        scale: entranceScale,
                        child: Transform.translate(
                          offset: swipeOffset,
                          child: Transform(
                            alignment: Alignment.bottomCenter,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateZ(swipeRotation),
                            child: Opacity(
                              opacity: _swipeAnimationController.isAnimating
                                  ? (1 - _swipeAnimation.value)
                                  : 1.0,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // The top card's shadow, cast on the sheet
                                  // below. The scroll view clips the card's
                                  // own shadow at the deck edge.
                                  Positioned.fill(child: _CardShadow(seed: 'card-${top.id}')),
                                  // Fill the deck so scroll constraints stay bounded
                                  // (avoids reassemble/layout hangs from loose stacks).
                                  Positioned.fill(child: cachedScroll!),
                                  if (showFeedback)
                                    _buildSwipeFeedbackOverlay(
                                      context,
                                      likeProgress: likeProgress,
                                      passProgress: passProgress,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Decodes the first photo of the next two cards at the size their hero
  /// will ask for, so a card that comes to the top shows its photo at once.
  void _prefetchNext(double deckHeight, double cardWidth) {
    final next = _properties.skip(1).take(2).toList();
    final key = '${next.map((p) => p.id).join(',')}@$deckHeight@$cardWidth';
    if (next.isEmpty || key == _prefetched) return;
    _prefetched = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final (width, height) = SwipeCardHeroSection.decodeSize(
        context,
        viewportHeight: deckHeight,
        cardWidth: cardWidth,
      );
      final cache = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(imageCacheServiceProvider);
      for (final property in next) {
        final url = property.galleryImageUrls.firstOrNull ?? property.mainImage;
        if (url.isEmpty) continue;
        unawaited(precacheNetworkImage(context, cache, url, width: width, height: height));
      }
    });
  }

  /// The top card in its own scroll view. The card fills the deck viewport;
  /// nothing is painted behind it, so the sheet below shows at its cut edge.
  Widget _buildScrollableDeck({required double cardWidth, required double deckHeight}) {
    return SingleChildScrollView(
      // Keyed so scroll position resets when the top property changes.
      key: ValueKey('discover.scroll.${_properties[0].id}'),
      physics: _blockGestures
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: deckHeight),
        child: Align(
          alignment: Alignment.topCenter,
          child: PropertySwipeCard(
            property: _properties[0],
            viewportHeight: deckHeight,
            cardWidth: cardWidth,
            onTap: _openDetails,
            onInteractionStart: () {
              setState(() => _blockGestures = true);
            },
            onInteractionEnd: () {
              setState(() => _blockGestures = false);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeFeedbackOverlay(
    BuildContext context, {
    required double likeProgress,
    required double passProgress,
  }) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: 24,
              left: 24,
              child: Opacity(
                opacity: likeProgress,
                child: Transform.rotate(
                  angle: -0.18,
                  child: _buildSwipeDecisionBadge(
                    context,
                    color: context.design.accent,
                    icon: KnifeIcon.heartSolid,
                    label: context.l10n.text('liked').toUpperCase(),
                    progress: likeProgress,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 24,
              right: 24,
              child: Opacity(
                opacity: passProgress,
                child: Transform.rotate(
                  angle: 0.18,
                  child: _buildSwipeDecisionBadge(
                    context,
                    color: context.design.favoriteActive,
                    icon: KnifeIcon.close,
                    label: context.l10n.text('passed').toUpperCase(),
                    progress: passProgress,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A rubber stamp pressed on the photo: two ink rules round the decision,
  /// teal for liked and brick for passed, on a slip of paper. No shadow, no
  /// glow: ink lies flat.
  Widget _buildSwipeDecisionBadge(
    BuildContext context, {
    required Color color,
    required KnifeIcon icon,
    required String label,
    required double progress,
  }) {
    final design = context.design;
    return Transform.scale(
      scale: 0.92 + 0.08 * progress,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: design.surface,
          shape: CutBorder(
            seed: 'stamp-$label',
            side: BorderSide(color: color, width: 3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: CutBorder(
                seed: 'stamp-in-$label',
                amp: 1,
                side: BorderSide(color: color, width: 1.2),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PaperIcon(icon, size: 20, color: color),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// How far the sheets under the top card are turned: 1.5 degrees.
const _deckTurn = 1.5 * math.pi / 180;

/// A blank sheet of the deck behind the top card, in the city's card stock
/// ([day] or [night] tone), shifted by [offset] and turned by [angle]. Its
/// cut edge is a shade darker than the sheet, so it holds against city paper
/// of the same tone behind it.
class _DeckSheet extends StatelessWidget {
  const _DeckSheet({
    required this.seed,
    required this.day,
    required this.night,
    required this.offset,
    required this.angle,
  });

  final String seed;
  final PaperTone day;
  final PaperTone night;
  final Offset offset;
  final double angle;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final paper = design.tone(design.isDark ? night : day);
    return IgnorePointer(
      child: Transform.translate(
        offset: offset,
        child: Transform.rotate(
          angle: angle,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: paper,
              shape: CutBorder(
                seed: seed,
                amp: 2.5,
                side: BorderSide(color: Color.lerp(paper, design.shadowOn(paper), 0.22)!),
                shadows: paperShadows(PaperElevation.low, design.shadowOn(design.background)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The top card's outline with its shadow, under the card's scroll view.
class _CardShadow extends StatelessWidget {
  const _CardShadow({required this.seed});

  final String seed;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: design.surface,
          shape: CutBorder(
            seed: seed,
            amp: 2.5,
            shadows: paperShadows(PaperElevation.mid, design.shadowOn(design.tone(PaperTone.mid))),
          ),
        ),
      ),
    );
  }
}
