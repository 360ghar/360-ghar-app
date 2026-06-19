import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/app_design_tokens.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/core/widgets/common/robust_network_image.dart';
import 'package:ghar360/features/discover/presentation/widgets/property_swipe_card.dart';

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
class PropertySwipeStack extends StatefulWidget {
  final List<PropertyModel> properties;
  final Function(PropertyModel) onSwipeLeft;
  final Function(PropertyModel) onSwipeRight;
  final Function(PropertyModel) onSwipeUp;
  final bool showSwipeInstructions;
  final VoidCallback? onChangeFilters;
  final VoidCallback? onRefresh;

  const PropertySwipeStack({
    super.key,
    required this.properties,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    required this.onSwipeUp,
    this.showSwipeInstructions = false,
    this.onChangeFilters,
    this.onRefresh,
  });

  @override
  State<PropertySwipeStack> createState() => _PropertySwipeStackState();
}

class _PropertySwipeStackState extends State<PropertySwipeStack> with TickerProviderStateMixin {
  late List<PropertyModel> _properties;
  List<PropertyModel>? _pendingProperties;
  late AnimationController _swipeAnimationController;
  late AnimationController _sparklesAnimationController;
  late AnimationController _entranceController;
  late Animation<double> _swipeAnimation;
  late Animation<double> _sparklesAnimation;
  late Animation<double> _entranceScale;

  /// Drag state driven by ValueNotifier — only the transform wrapper
  /// listens to this, so the heavy PropertySwipeCard is never rebuilt
  /// during drag or snap-back.
  final ValueNotifier<_SwipeDragState> _dragNotifier = ValueNotifier(const _SwipeDragState());

  /// Tracks the current snap-back controller so it can be disposed
  /// if the widget is disposed mid-animation.
  AnimationController? _snapController;

  bool _showSparkles = false;
  bool _isSwipingRight = false;
  bool _blockGestures = false;

  @override
  void initState() {
    super.initState();
    _properties = List.from(widget.properties);

    _swipeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _swipeAnimation = CurvedAnimation(parent: _swipeAnimationController, curve: Curves.easeInOut);

    _sparklesAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _sparklesAnimation = CurvedAnimation(
      parent: _sparklesAnimationController,
      curve: Curves.easeOut,
    );

    _entranceController = AnimationController(vsync: this, duration: AppDurations.cardEntrance);
    _entranceScale = Tween<double>(
      begin: 0.93,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _entranceController, curve: AppCurves.cardEntrance));

    _swipeAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_pendingProperties != null) {
          _properties = _pendingProperties!;
          _pendingProperties = null;
        } else if (_properties.isNotEmpty) {
          _properties.removeAt(0);
        }
        _swipeAnimationController.reset();
        _sparklesAnimationController.reset();
        _dragNotifier.value = const _SwipeDragState();
        _showSparkles = false;
        _isSwipingRight = false;
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
    _sparklesAnimationController.dispose();
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
    final drag = _dragNotifier.value;
    _dragNotifier.value = drag.copyWith(isDragging: false);

    final dragDistance = drag.position.dx;
    final dragThreshold = screenSize.width * 0.25;
    final rotationThreshold = 0.3;

    if (dragDistance.abs() > dragThreshold || drag.rotation.abs() > rotationThreshold) {
      if (dragDistance > 0 || drag.rotation > 0) {
        _isSwipingRight = true;
        _showSparkles = true;
        _sparklesAnimationController.forward();
        widget.onSwipeRight(_properties[0]);
      } else {
        widget.onSwipeLeft(_properties[0]);
      }
      // setState once to add sparkles to the widget tree
      setState(() {});
      _swipeAnimationController.forward();
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
    final snapAnimation = CurvedAnimation(parent: controller, curve: Curves.elasticOut);

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

  @override
  Widget build(BuildContext context) {
    if (_properties.isEmpty) {
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

        return GestureDetector(
          onHorizontalDragStart: (details) {
            if (_blockGestures) return;
            _dragNotifier.value = _dragNotifier.value.copyWith(isDragging: true);
          },
          onHorizontalDragUpdate: (details) {
            if (_blockGestures) return;
            final dx = details.primaryDelta ?? 0;
            final newPos = Offset(_dragNotifier.value.position.dx + dx, 0);
            _dragNotifier.value = _SwipeDragState(
              position: newPos,
              rotation: _calculateRotation(newPos, cardSize),
              isDragging: true,
            );
          },
          onHorizontalDragEnd: (details) {
            if (_blockGestures) return;
            _handlePanEnd(details, cardSize);
          },
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Background cards (static during drag — no rebuild needed)
              if (_properties.length > 1)
                Positioned.fill(
                  child: Transform.scale(
                    scale: 0.95,
                    child: Opacity(
                      opacity: 0.8,
                      child: _buildBackgroundPreviewCard(_properties[1]),
                    ),
                  ),
                ),
              if (_properties.length > 2)
                Positioned.fill(
                  child: Transform.scale(
                    scale: 0.9,
                    child: Opacity(
                      opacity: 0.6,
                      child: _buildBackgroundPreviewCard(_properties[2]),
                    ),
                  ),
                ),

              // Top card with drag/swipe transform.
              // Uses Listenable.merge so both drag updates AND swipe
              // animation ticks rebuild only the transform wrapper.
              // The PropertySwipeCard is passed as `child` and never rebuilt.
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _dragNotifier,
                    _swipeAnimationController,
                    _entranceController,
                  ]),
                  child: PropertySwipeCard(
                    property: _properties[0],
                    showSwipeInstructions: widget.showSwipeInstructions,
                    onInteractionStart: () => _blockGestures = true,
                    onInteractionEnd: () => _blockGestures = false,
                  ),
                  builder: (context, cachedCard) {
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
                    final showFeedback = drag.isDragging && (likeProgress > 0 || passProgress > 0);

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
                              children: [
                                cachedCard!,
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

              // Sparkles animation
              if (_showSparkles && _isSwipingRight)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _sparklesAnimation,
                    builder: (context, child) {
                      return IgnorePointer(child: _SparklesWidget(animation: _sparklesAnimation));
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBackgroundPreviewCard(PropertyModel property) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RobustNetworkImage(
            imageUrl: property.mainImage,
            fit: BoxFit.cover,
            placeholder: Container(color: AppDesign.inputBackground),
            errorWidget: Container(
              color: AppDesign.surface,
              alignment: Alignment.center,
              child: Icon(Icons.home_work_outlined, color: AppDesign.textSecondary),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppDesign.transparent, AppDesign.shadowColor.withValues(alpha: 0.7)],
                stops: const [0.6, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  property.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppDesignTokens.neutralWhite,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  property.formattedPrice,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppDesign.primaryYellow,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
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
            if (likeProgress > 0)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppDesign.transparent,
                      AppDesign.successGreen.withValues(alpha: 0.18 * likeProgress),
                    ],
                  ),
                ),
              ),
            if (passProgress > 0)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      AppDesign.transparent,
                      AppDesign.errorRed.withValues(alpha: 0.18 * passProgress),
                    ],
                  ),
                ),
              ),
            Positioned(
              top: 24,
              left: 24,
              child: Opacity(
                opacity: likeProgress,
                child: Transform.rotate(
                  angle: -0.18,
                  child: _buildSwipeDecisionBadge(
                    context,
                    color: AppDesign.successGreen,
                    icon: Icons.favorite_rounded,
                    label: 'liked'.tr.toUpperCase(),
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
                    color: AppDesign.errorRed,
                    icon: Icons.close_rounded,
                    label: 'passed'.tr.toUpperCase(),
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

  Widget _buildSwipeDecisionBadge(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String label,
    required double progress,
  }) {
    final theme = Theme.of(context);
    final scale = 0.92 + 0.08 * progress;

    return Transform.scale(
      scale: scale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppDesign.darkTextPrimary.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.95), width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Sparkles widget for the enthusiasm animation
class _SparklesWidget extends StatelessWidget {
  final Animation<double> animation;

  const _SparklesWidget({required this.animation});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _SparklesPainter(animation.value), size: Size.infinite);
  }
}

class _SparklesPainter extends CustomPainter {
  final double animationValue;

  _SparklesPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppDesign.primaryYellow.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    final sparklePositions = [
      Offset(size.width * 0.2, size.height * 0.3),
      Offset(size.width * 0.8, size.height * 0.2),
      Offset(size.width * 0.6, size.height * 0.5),
      Offset(size.width * 0.3, size.height * 0.7),
      Offset(size.width * 0.7, size.height * 0.8),
      Offset(size.width * 0.1, size.height * 0.6),
      Offset(size.width * 0.9, size.height * 0.4),
      Offset(size.width * 0.4, size.height * 0.2),
    ];

    for (int i = 0; i < sparklePositions.length; i++) {
      final position = sparklePositions[i];
      final delay = i * 0.1;
      final sparkleAnimation = ((animationValue - delay) / (1 - delay)).clamp(0.0, 1.0);

      if (sparkleAnimation > 0) {
        final sparkleSize = 8.0 * sparkleAnimation * (1 - sparkleAnimation * 0.5);
        final sparkleOpacity = (1 - sparkleAnimation).clamp(0.0, 1.0);

        paint.color = AppDesign.primaryYellow.withValues(alpha: sparkleOpacity * 0.8);

        _drawStar(canvas, paint, position, sparkleSize);
      }
    }
  }

  void _drawStar(Canvas canvas, Paint paint, Offset center, double size) {
    final path = ui.Path();
    final outerRadius = size;
    final innerRadius = size * 0.4;

    for (int i = 0; i < 8; i++) {
      final angle = (i * 45) * (3.14159 / 180);
      final radius = i.isEven ? outerRadius : innerRadius;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklesPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
