import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_art.dart';
import 'package:ghar360/core/design/paper/paper_cut.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/features/splash/presentation/controllers/splash_controller.dart';
import 'package:ghar360/features/splash/presentation/widgets/gurugram_diorama.dart';

const _pageCount = 3;

/// Onboarding: a paper diorama of Gurugram that grows with each page (the
/// city, then the street with a pin, then a home with a lit window) above a
/// hand-cut sheet with the words and the controls.
class SplashView extends ConsumerStatefulWidget {
  const SplashView({super.key});
  @override
  ConsumerState<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends ConsumerState<SplashView> {
  final _pages = PageController();
  int _step = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _move(int index) {
    if (index < 0 || index >= _pageCount) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(index);
    } else {
      _pages.animateToPage(
        index,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _next() => _step < _pageCount - 1 ? _move(_step + 1) : _complete();

  void _complete() => ref.read(onboardingProvider.notifier).complete();

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final onboarding = ref.watch(onboardingProvider);
    final busy = onboarding.save.isLoading;
    final l10n = context.l10n;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: design.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        key: const ValueKey('qa.splash.screen'),
        backgroundColor: design.background,
        body: Stack(
          children: [
            const Positioned.fill(child: _PaperGround()),
            // Swipes anywhere turn the page; the pages themselves are empty.
            Positioned.fill(
              child: PageView(
                controller: _pages,
                onPageChanged: (index) => setState(() => _step = index),
                children: [for (var i = 0; i < _pageCount; i++) const SizedBox.expand()],
              ),
            ),
            Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(child: GurugramDiorama(pages: _pages)),
                      ),
                      Positioned(
                        top: MediaQuery.paddingOf(context).top + 8,
                        right: 12,
                        child: Semantics(
                          identifier: 'qa.splash.skip',
                          child: TextButton(
                            key: const ValueKey('qa.splash.skip'),
                            onPressed: busy ? null : _complete,
                            child: Text(l10n.text('skip')),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Large text on a short screen: the sheet may scroll, up to
                // two thirds of the height. Otherwise it passes swipes through.
                Builder(
                  builder: (context) {
                    final screen = MediaQuery.sizeOf(context).height;
                    final sheet = _OnboardingSheet(
                      pages: _pages,
                      step: _step,
                      busy: busy,
                      failed: onboarding.save.hasError,
                      onBack: () => _move(_step - 1),
                      onNext: _next,
                    );
                    if (MediaQuery.textScalerOf(context).scale(10) <= 13 && screen >= 640) {
                      return sheet;
                    }
                    return ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: screen * 2 / 3),
                      child: SingleChildScrollView(child: sheet),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The page itself: plain paper with grain, under the scene.
class _PaperGround extends StatelessWidget {
  const _PaperGround();

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return RepaintBoundary(
      child: CustomPaint(painter: _GroundPainter(design.tone(PaperTone.sky), design.grain)),
    );
  }
}

class _GroundPainter extends CustomPainter {
  const _GroundPainter(this.color, this.grain);
  final Color color;
  final Color grain;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
    paintPaperGrain(canvas, Offset.zero & size, grain);
  }

  @override
  bool shouldRepaint(_GroundPainter old) => old.color != color || old.grain != grain;
}

/// The sheet on the road: page tabs, the title and one line, then Back and
/// Next. Its top edge is cut by hand; it lies over the kerb of the scene.
class _OnboardingSheet extends StatelessWidget {
  const _OnboardingSheet({
    required this.pages,
    required this.step,
    required this.busy,
    required this.failed,
    required this.onBack,
    required this.onNext,
  });

  final PageController pages;
  final int step;
  final bool busy;
  final bool failed;
  final VoidCallback onBack;
  final VoidCallback onNext;

  static const _cut = 14.0;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final last = step == _pageCount - 1;
    final nextId = last ? 'qa.splash.get_started' : 'qa.splash.next';
    return CustomPaint(
      painter: _SheetPainter(sheet: design.surface, edge: design.border),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, _cut + 18, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IgnorePointer(child: _PageTabs(step: step)),
                  const SizedBox(height: 16),
                  IgnorePointer(
                    child: AnimatedBuilder(
                      animation: pages,
                      builder: (context, child) {
                        final page = pages.hasClients && pages.positions.length == 1
                            ? pages.page ?? step.toDouble()
                            : step.toDouble();
                        // The words follow the finger a little; they are
                        // never hidden.
                        return Transform.translate(
                          offset: Offset((step - page) * 40, 0),
                          child: child,
                        );
                      },
                      // Sized to the longest page, so the sheet never jumps.
                      child: IndexedStack(
                        index: step,
                        children: [
                          for (var i = 1; i <= _pageCount; i++)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Semantics(
                                  header: true,
                                  child: Text(
                                    l10n.text('onboarding_slide_${i}_title'),
                                    style: text.displaySmall,
                                    maxLines: 2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  l10n.text('onboarding_slide_${i}_desc'),
                                  style: text.bodyLarge?.copyWith(color: design.textSecondary),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (failed) ...[
                    const SizedBox(height: 10),
                    Text(
                      l10n.text('local_save_failed'),
                      style: text.bodyMedium?.copyWith(color: design.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Side by side when they fit; stacked, Next on top, when they do not.
                  OverflowBar(
                    alignment: MainAxisAlignment.spaceBetween,
                    overflowAlignment: OverflowBarAlignment.end,
                    overflowDirection: VerticalDirection.up,
                    overflowSpacing: 4,
                    children: [
                      // Kept in the layout on page 1, so Next never moves.
                      Visibility(
                        visible: step > 0,
                        maintainSize: true,
                        maintainAnimation: true,
                        maintainState: true,
                        child: Semantics(
                          identifier: 'qa.splash.back',
                          child: TextButton(
                            key: const ValueKey('qa.splash.back'),
                            onPressed: busy || step == 0 ? null : onBack,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const PaperIcon(KnifeIcon.arrowLeft, size: 18),
                                const SizedBox(width: 6),
                                Text(l10n.text('back')),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Semantics(
                        identifier: nextId,
                        child: FilledButton(
                          key: ValueKey(nextId),
                          onPressed: busy ? null : onNext,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(l10n.text(last ? 'get_started' : 'next')),
                              const SizedBox(width: 8),
                              PaperIcon(last ? KnifeIcon.check : KnifeIcon.arrowRight, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
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

/// Three card-stock tabs; the current one is gold and longer.
class _PageTabs extends StatelessWidget {
  const _PageTabs({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final instant = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: context.l10n.text(
        'page_of',
        params: {'current': '${step + 1}', 'total': '$_pageCount'},
      ),
      child: Row(
        children: [
          for (var i = 0; i < _pageCount; i++)
            AnimatedContainer(
              duration: instant ? Duration.zero : const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(right: 6),
              width: i == step ? 28 : 12,
              height: 6,
              decoration: BoxDecoration(
                color: i == step ? design.buttonPrimary : design.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}

class _SheetPainter extends CustomPainter {
  const _SheetPainter({required this.sheet, required this.edge});
  final Color sheet;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    final band = parsePaperPath(
      cutBandPath(
        'onboarding',
        width: size.width,
        height: _OnboardingSheet._cut,
        segments: math.max(8, (size.width / 28).round()),
      ),
      fillType: PathFillType.nonZero,
    )..addRect(Rect.fromLTWH(0, _OnboardingSheet._cut - 0.5, size.width, size.height));
    canvas.drawPath(band.shift(const Offset(0, -2)), Paint()..color = edge);
    canvas.drawPath(band, Paint()..color = sheet);
  }

  @override
  bool shouldRepaint(_SheetPainter old) => old.sheet != sheet || old.edge != edge;
}
