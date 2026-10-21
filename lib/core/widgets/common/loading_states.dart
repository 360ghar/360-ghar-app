import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/design/paper/paper_cut.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:shimmer/shimmer.dart';

/// Loading placeholders. Each skeleton has the shape of the screen it stands
/// in for, appears only after [Skeleton.delay], and stops its sheen when the
/// user asks for reduced motion.
class LoadingStates {
  LoadingStates._();

  /// The Discover deck: the top card on a white sheet, its photo cut where
  /// the label sheet lies over it, the label's lines, two deck edges behind,
  /// and the Pass and Like buttons, laid out like the real deck.
  static Widget swipeCardSkeleton() =>
      const Skeleton(paper: _Deck(paper: true), child: _Deck(paper: false));

  /// Saved rows: a small print and three lines, like `PropertyListCard(row:)`.
  static Widget propertyRowsSkeleton({int itemCount = 6}) => Skeleton(
    paper: const SkeletonSheet(),
    child: ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      itemCount: itemCount,
      itemBuilder: (_, index) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 104, height: 88, cutSeed: 'row-$index'),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  const SkeletonBox(width: 96, height: 20),
                  const SizedBox(height: 10),
                  SkeletonBox(width: index.isEven ? 180 : 140, height: 14),
                  const SizedBox(height: 8),
                  const SkeletonBox(width: 160, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  /// Saved homes: a grid of photo cards.
  static Widget responsiveGridSkeleton({int crossAxisCount = 2, int itemCount = 6}) => Skeleton(
    child: GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.78,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: itemCount,
      itemBuilder: (_, _) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: SkeletonBox(radius: 14)),
          SizedBox(height: 10),
          SkeletonBox(height: 18, width: 96),
          SizedBox(height: 6),
          SkeletonBox(height: 14),
        ],
      ),
    ),
  );

  /// Property details: photo, title, price, facts and description.
  static Widget propertyDetailsSkeleton() => Skeleton(
    paper: const SkeletonSheet(),
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // The body sheet's cut lip lies over the foot of the photo.
        const SkeletonBox(height: 300, radius: 0, cutSeed: 'details', cutFoot: true),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox(height: 28, width: 220),
              const SizedBox(height: 10),
              const SkeletonBox(height: 16, width: 160),
              const SizedBox(height: 20),
              Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    const Expanded(child: SkeletonBox(height: 48)),
                    if (i < 2) const SizedBox(width: 12),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              for (final width in [double.infinity, double.infinity, 240.0]) ...[
                SkeletonBox(height: 14, width: width),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  /// Visits: each row a visit pass: the date stub, a column of punched
  /// holes, then the title, time, price and the reschedule button.
  static Widget visitsSkeleton({int itemCount = 4}) => Skeleton(
    paper: const SkeletonSheet(),
    child: ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 28),
      itemBuilder: (_, _) => const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Column(
              children: [
                SkeletonBox(width: 32, height: 30),
                SizedBox(height: 6),
                SkeletonBox(width: 30, height: 12),
                SizedBox(height: 4),
                SkeletonBox(width: 24, height: 10),
              ],
            ),
          ),
          SizedBox(width: 8),
          _Perforation(),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 18, width: 180),
                SizedBox(height: 8),
                SkeletonBox(height: 14, width: 140),
                SizedBox(height: 6),
                SkeletonBox(height: 12, width: 110),
                SizedBox(height: 14),
                SkeletonBox(height: 44, width: 120, radius: 12),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  /// Profile: avatar and name, then menu rows.
  static Widget profileSkeleton({int rows = 6}) => Skeleton(
    paper: const SkeletonSheet(),
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        const Row(
          children: [
            SkeletonBox(width: 64, height: 64, radius: 32),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(height: 22, width: 160),
                  SizedBox(height: 8),
                  SkeletonBox(height: 14, width: 120),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        for (var i = 0; i < rows; i++) ...[
          const Row(
            children: [
              SkeletonBox(width: 24, height: 24),
              SizedBox(width: 16),
              Expanded(child: SkeletonBox(height: 16)),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ],
    ),
  );

  /// Assistant history: title and date per conversation.
  static Widget conversationListSkeleton({int itemCount = 6}) => Skeleton(
    paper: const SkeletonSheet(),
    child: ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 18),
      itemBuilder: (_, index) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(height: 16, width: index.isEven ? 220 : 170),
          const SizedBox(height: 6),
          const SkeletonBox(height: 12, width: 90),
        ],
      ),
    ),
  );

  /// A text page (policy, about): a heading and paragraphs.
  static Widget documentSkeleton() => Skeleton(
    paper: const SkeletonSheet(),
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        const SkeletonBox(height: 26, width: 200),
        const SizedBox(height: 20),
        for (var paragraph = 0; paragraph < 3; paragraph++) ...[
          for (final width in [double.infinity, double.infinity, double.infinity, 200.0]) ...[
            SkeletonBox(height: 14, width: width),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
        ],
      ],
    ),
  );

  /// A thin teal bar over the map while homes load; the map stays usable.
  static Widget mapLoadingOverlay(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: Semantics(
      liveRegion: true,
      label: context.l10n.text('loading_properties'),
      child: const LinearProgressIndicator(minHeight: 3),
    ),
  );

  /// Progress inside a button or next to a label. The only spinner in the app.
  static Widget buttonSpinner({double size = 18, Color? color, String? semanticsLabel}) => Builder(
    builder: (context) => SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color ?? DefaultTextStyle.of(context).style.color,
        semanticsLabel: semanticsLabel ?? context.l10n.text('loading'),
      ),
    ),
  );
}

/// Wraps a skeleton: waits [delay] before it shows (fast loads never flash a
/// placeholder), announces "loading" once, and stops the sheen under reduced
/// motion. The layout keeps its size while hidden.
///
/// Blocks are the page tone (the sky) on a white sheet by day, and a light
/// step on the sheet at night, with a lighter sheen. [paper] is drawn under
/// the blocks and appears with them: the sheet they sit on, or the deck.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.child, this.paper});

  final Widget child;

  /// Paper under the blocks, filled to the size of [child].
  final Widget? paper;

  static const delay = Duration(milliseconds: 150);

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> {
  Timer? _timer;
  var _shown = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(Skeleton.delay, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final still = MediaQuery.disableAnimationsOf(context);
    final base = design.isDark
        ? Color.lerp(design.surface, AppDesign.overlayLight, 0.06)!
        : design.background;
    final Widget blocks = Shimmer.fromColors(
      baseColor: base,
      highlightColor: Color.lerp(base, AppDesign.overlayLight, design.isDark ? 0.08 : 0.75)!,
      period: const Duration(milliseconds: 1400),
      enabled: !still,
      child: widget.child,
    );
    return Semantics(
      container: true,
      liveRegion: true,
      label: context.l10n.text('loading'),
      excludeSemantics: true,
      child: Opacity(
        opacity: _shown ? 1 : 0,
        child: TickerMode(
          enabled: !still,
          child: widget.paper == null
              ? blocks
              : Stack(
                  fit: StackFit.passthrough,
                  children: [
                    Positioned.fill(child: widget.paper!),
                    blocks,
                  ],
                ),
        ),
      ),
    );
  }
}

/// The punched holes of a visit pass, between the stub and the body.
class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var hole = 0; hole < 5; hole++)
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: SkeletonBox(width: 6, height: 6, radius: 3),
        ),
    ],
  );
}

/// The white sheet a skeleton sits on, so its blocks read on any page.
class SkeletonSheet extends StatelessWidget {
  const SkeletonSheet({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(color: context.design.surface);
}

/// One placeholder block. Inside a [Skeleton] the sheen colours it.
///
/// With [cutSeed] the block is a print with a hand-cut edge; with [cutFoot]
/// only its foot is cut, where a label or body sheet lies over it.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    this.height,
    this.radius = 8,
    this.cutSeed,
    this.cutFoot = false,
  });

  final double width;
  final double? height;
  final double radius;
  final String? cutSeed;
  final bool cutFoot;

  @override
  Widget build(BuildContext context) {
    final seed = cutSeed;
    if (seed == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF000000),
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }
    return SizedBox(
      width: width,
      height: height,
      child: cutFoot
          ? ClipPath(
              clipper: _CutFootClipper(seed),
              child: const ColoredBox(color: Color(0xFF000000)),
            )
          : DecoratedBox(
              decoration: ShapeDecoration(
                color: const Color(0xFF000000),
                shape: CutBorder(seed: seed, amp: 1.5),
              ),
            ),
    );
  }
}

/// A rect whose foot is the hand-cut top edge of the sheet that lies over it.
class _CutFootClipper extends CustomClipper<Path> {
  const _CutFootClipper(this.seed);

  final String seed;

  static const _depth = 14.0;

  @override
  Path getClip(Size size) {
    final over = parsePaperPath(
      cutBandPath(
        seed,
        width: size.width,
        height: _depth,
        segments: math.max(6, (size.width / 28).round()),
      ),
      fillType: PathFillType.nonZero,
    ).shift(Offset(0, size.height - _depth));
    return Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), over);
  }

  @override
  bool shouldReclip(_CutFootClipper old) => old.seed != seed;
}

/// The deck in two layers that share one layout: [paper] draws the sheets
/// (two deck edges turned a little behind the top card, and the two
/// buttons); otherwise the blocks.
class _Deck extends StatelessWidget {
  const _Deck({required this.paper});

  final bool paper;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final shadow = design.shadowOn(design.background);
    Widget sheet(Color color, String seed, PaperElevation elevation) => DecoratedBox(
      decoration: ShapeDecoration(
        color: color,
        shape: CutBorder(seed: seed, amp: 2.5, shadows: paperShadows(elevation, shadow)),
      ),
    );
    Widget edge(Offset offset, double turns, Color color, String seed) => Transform.translate(
      offset: offset,
      child: Transform.rotate(angle: turns, child: sheet(color, seed, PaperElevation.low)),
    );
    final card = paper
        ? Stack(
            fit: StackFit.expand,
            children: [
              edge(const Offset(8, 6), 0.026, design.surface, 'deck-back'),
              edge(const Offset(4, 3), -0.018, design.surface, 'deck-middle'),
              sheet(design.surface, 'deck-top', PaperElevation.mid),
            ],
          )
        : LayoutBuilder(
            builder: (context, constraints) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A print mounted on the card, so the card's edge stays clear
                // of the sky page around it.
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                  child: SkeletonBox(
                    height: constraints.maxHeight * 0.6,
                    radius: 0,
                    cutSeed: 'deck-label',
                    cutFoot: true,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 4, 18, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 132, height: 28),
                      SizedBox(height: 12),
                      SkeletonBox(width: 210, height: 16),
                      SizedBox(height: 8),
                      SkeletonBox(width: 150, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          );
    Widget button(String seed) => paper
        ? sheet(design.surface, seed, PaperElevation.low)
        : const Center(child: SkeletonBox(width: 64, height: 12));
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          // Mirrors the Discover deck: same gutters and gap above the buttons.
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            children: [
              Expanded(child: card),
              const SizedBox(height: 22),
              SizedBox(
                height: 52,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: button('deck-pass')),
                    const SizedBox(width: 12),
                    Expanded(child: button('deck-like')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
