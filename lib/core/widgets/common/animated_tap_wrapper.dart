import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';

/// A tap target that dims while pressed. It never moves or scales.
class AnimatedTapWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enableHapticFeedback;

  const AnimatedTapWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enableHapticFeedback = true,
  });

  @override
  State<AnimatedTapWrapper> createState() => _AnimatedTapWrapperState();
}

class _AnimatedTapWrapperState extends State<AnimatedTapWrapper> {
  bool _pressed = false;

  void _press(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  void _handleTap() {
    if (widget.enableHapticFeedback) HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final tappable = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: tappable ? (_) => _press(true) : null,
      onTapUp: tappable ? (_) => _press(false) : null,
      onTapCancel: tappable ? () => _press(false) : null,
      onTap: tappable ? _handleTap : null,
      onLongPress: widget.onLongPress,
      child: AnimatedOpacity(
        opacity: _pressed ? 0.72 : 1,
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : AppDurations.fastest,
        child: widget.child,
      ),
    );
  }
}

/// A bare heart: an outline, or a filled brick heart when saved. It
/// changes colour and shape only.
class AnimatedFavoriteIcon extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onToggle;
  final double size;

  /// Defaults to `context.design.favoriteActive`.
  final Color? activeColor;

  /// Defaults to `context.design.favoriteInactive`.
  final Color? inactiveColor;

  /// Tight shadows for a light heart over a photo.
  final List<Shadow>? shadows;

  const AnimatedFavoriteIcon({
    super.key,
    required this.isFavorite,
    required this.onToggle,
    this.size = 24.0,
    this.activeColor,
    this.inactiveColor,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    // A 48 logical-pixel hit target even when the mark is small.
    final hit = (size + 16).clamp(48.0, 72.0);
    return Semantics(
      button: true,
      label: context.l10n.text(isFavorite ? 'remove_from_favorites' : 'add_to_favorites'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.mediumImpact();
          onToggle();
        },
        child: SizedBox.square(
          dimension: hit,
          child: Center(
            child: PaperIcon(
              isFavorite ? KnifeIcon.heartSolid : KnifeIcon.heart,
              size: size,
              shadows: shadows,
              color: isFavorite
                  ? activeColor ?? context.design.favoriteActive
                  : inactiveColor ?? context.design.favoriteInactive,
            ),
          ),
        ),
      ),
    );
  }
}
