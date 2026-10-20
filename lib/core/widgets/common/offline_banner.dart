import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_cut.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';

/// One app-wide strip under the status bar while the device is offline.
/// [child] keeps the same place in the tree, so going offline never resets
/// navigation or form state.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(isOnlineProvider.select((online) => online.value == false));
    return Column(
      children: [
        if (offline) const _OfflineStrip() else const SizedBox.shrink(),
        Expanded(
          child: MediaQuery.removePadding(context: context, removeTop: offline, child: child),
        ),
      ],
    );
  }
}

class _OfflineStrip extends StatelessWidget {
  const _OfflineStrip();

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return Semantics(
      identifier: 'qa.offline.banner',
      liveRegion: true,
      container: true,
      // An amber slip across the top, its foot hand-cut over the page sky.
      child: CustomPaint(
        key: const ValueKey('qa.offline.banner'),
        painter: _SlipPainter(slip: design.notice, page: design.background),
        // It sits above the routes, so it brings its own text style.
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10 + _cut),
              child: Row(
                children: [
                  PaperIcon(KnifeIcon.wifi, size: 18, color: design.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.l10n.text('offline_banner'),
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: design.textPrimary),
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

/// The deepest point of the slip's cut foot.
const _cut = 8.0;

class _SlipPainter extends CustomPainter {
  const _SlipPainter({required this.slip, required this.page});

  final Color slip;
  final Color page;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = slip;
    canvas.drawRect(Offset.zero & size, Paint()..color = page);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height - _cut + 0.5), fill);
    final foot = parsePaperPath(
      cutBandPath(
        'offline',
        width: size.width,
        height: _cut,
        segments: math.max(8, (size.width / 28).round()),
      ),
      fillType: PathFillType.nonZero,
    );
    // The band's cut runs along its top; turned over, it is the slip's foot.
    canvas
      ..save()
      ..translate(0, size.height)
      ..scale(1, -1)
      ..drawPath(foot, fill)
      ..restore();
  }

  @override
  bool shouldRepaint(_SlipPainter old) => old.slip != slip || old.page != page;
}
