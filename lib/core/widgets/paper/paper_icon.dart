import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:ghar360/core/design/paper/knife_icons.dart';

/// Draws a [KnifeIcon] like [Icon]: size, colour and opacity come from the
/// nearest [IconTheme] unless given. The mark is bare, with no tile behind it.
class PaperIcon extends StatelessWidget {
  const PaperIcon(this.icon, {super.key, this.size, this.color, this.semanticLabel, this.shadows});

  final KnifeIcon icon;
  final double? size;
  final Color? color;

  /// Tight shadows for a light icon over a photo, as on [Icon].
  final List<Shadow>? shadows;

  /// Read by screen readers. Without it the icon is decorative.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final side = size ?? theme.size ?? 24;
    var ink = color ?? theme.color ?? const Color(0xFF000000);
    final opacity = theme.opacity;
    if (opacity != null && opacity < 1) ink = ink.withValues(alpha: ink.a * opacity);
    // Like [Icon]: a parent that forces a larger box centres the mark; it never stretches it.
    final mark = SizedBox.square(
      dimension: side,
      child: Center(
        // Overflow, as [Icon] does, when the parent's box is smaller than [side].
        child: OverflowBox(
          minWidth: side,
          maxWidth: side,
          minHeight: side,
          maxHeight: side,
          child: SizedBox.square(
            dimension: side,
            child: CustomPaint(painter: _KnifeIconPainter(icon, ink, shadows ?? const [])),
          ),
        ),
      ),
    );
    final label = semanticLabel;
    return label == null
        ? ExcludeSemantics(child: mark)
        : Semantics(
            label: label,
            image: true,
            child: ExcludeSemantics(child: mark),
          );
  }
}

class _KnifeIconPainter extends CustomPainter {
  const _KnifeIconPainter(this.icon, this.color, this.shadows);

  final KnifeIcon icon;
  final Color color;
  final List<Shadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.scale(scale, size.height / 24);
    for (final shadow in shadows) {
      canvas.drawPath(
        icon.path.shift(shadow.offset / scale),
        Paint()
          ..color = shadow.color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blurSigma / scale),
      );
    }
    canvas.drawPath(icon.path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_KnifeIconPainter old) =>
      old.icon != icon || old.color != color || !listEquals(old.shadows, shadows);
}
