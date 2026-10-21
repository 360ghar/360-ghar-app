import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';

/// A hand-cut note on the chat sheet. The assistant writes on white card
/// stock that lies a little above the sheet; the reader's words, and the
/// prompts they can send, sit flat on a mint [slip].
class PaperNote extends StatelessWidget {
  const PaperNote({super.key, required this.seed, required this.child, this.slip = false});

  final String seed;
  final Widget child;
  final bool slip;

  /// Deepest cut of a note; the padding clears it on every side.
  static const amp = 2.0;

  static ShapeBorder shape(BuildContext context, String seed, {bool slip = false}) {
    final design = context.design;
    return CutBorder(
      seed: seed,
      amp: slip ? 1.5 : amp,
      // A note shows its cut by a lip of card edge along the top, where the
      // light falls, and a tight shadow below; a slip lies flat.
      shadows: slip
          ? const []
          : [
              BoxShadow(color: design.sheetLip, offset: const Offset(0, -1.5)),
              ...paperShadows(PaperElevation.low, design.shadowOn(design.surface)),
            ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: slip ? design.slip : design.raised,
        shape: shape(context, seed, slip: slip),
      ),
      child: Padding(
        padding: slip
            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
            : const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: child,
      ),
    );
  }
}

/// The assistant's mark: the onboarding kite, bare, in teal. With [sway] it
/// rocks on its string while the assistant works; it stays still under
/// reduced motion.
class AssistantKite extends StatefulWidget {
  const AssistantKite({super.key, this.size = 22, this.sway = false});

  final double size;
  final bool sway;

  @override
  State<AssistantKite> createState() => _AssistantKiteState();
}

class _AssistantKiteState extends State<AssistantKite> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(AssistantKite oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.sway && !MediaQuery.disableAnimationsOf(context)) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mark = PaperIcon(KnifeIcon.kite, size: widget.size, color: context.design.accent);
    if (!widget.sway) return mark;
    return AnimatedBuilder(
      animation: _controller,
      // The kite turns about its own body, so the tail swings.
      builder: (context, child) => Transform.rotate(
        angle: (Curves.easeInOut.transform(_controller.value) - 0.5) * math.pi / 12,
        alignment: const Alignment(0, -0.35),
        child: child,
      ),
      child: mark,
    );
  }
}
