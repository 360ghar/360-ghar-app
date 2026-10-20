import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/navigation/bottom_nav_bar.dart';
import 'package:ghar360/core/widgets/paper/baked_paper_scene.dart';
import 'package:ghar360/core/widgets/paper/folder_tabs.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/core/widgets/paper/paper_scroll_page.dart';
import 'package:ghar360/core/widgets/paper/paper_sheet.dart';
import 'package:ghar360/core/widgets/paper/paper_vignette.dart';
import 'package:ghar360/core/widgets/paper/scene_header_sliver.dart';
import '../helpers/load_app_fonts.dart';

const _seeds = {
  PaperScene.empty: 'liked',
  PaperScene.error: 'visits',
  PaperScene.offline: 'saved',
  PaperScene.notFound: 'route',
  PaperScene.location: 'explainer',
};

const _vignettes = [
  ('calculator', 'tools'),
  ('key', 'tools'),
  ('document', 'tools'),
  ('tower', 'tools'),
  ('home', 'tools'),
  ('plot', 'tools'),
  ('pg', 'purpose'),
];

Widget _app({required bool dark, required Widget child}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dark ? AppDesignTheme.dark() : AppDesignTheme.light(),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(
    body: RepaintBoundary(
      key: const ValueKey('kit'),
      // The page tone, so cut edges and the roofline read as they do in the app.
      child: Builder(
        builder: (context) => ColoredBox(color: context.design.background, child: child),
      ),
    ),
  ),
);

/// A header scene in a band on the page sky, cropped as its header crops it.
class _Band extends StatelessWidget {
  const _Band(this.scene, {this.height = 150});

  final PaperSceneSpec scene;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 380,
    height: height,
    child: ColoredBox(
      color: context.design.background,
      child: BakedPaperScene(
        art: scene.art,
        fit: BoxFit.fitHeight,
        window: Rect.fromLTWH(0, 0, scene.art.width, scene.ground + 20),
        focusX: scene.focusX,
        litCount: scene.litCount,
      ),
    ),
  );
}

/// A phone-width list screen with a scene header, scrolled by [offset].
Widget _screen(double offset) => SizedBox(
  width: 390,
  height: 420,
  child: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(padding: const EdgeInsets.only(top: 47), size: const Size(390, 420)),
      child: Scaffold(
        body: PaperScrollPage(
          controller: ScrollController(initialScrollOffset: offset),
          header: SceneHeaderSliver(
            title: 'Saved',
            scene: PaperSceneSpec.saved(litCount: 7),
            actions: [
              IconButton(onPressed: () {}, icon: const PaperIcon(KnifeIcon.search, size: 22)),
            ],
            tabs: FolderTabs(labels: const ['Liked 12', 'Passed 4'], selected: 0, onSelect: (_) {}),
          ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverList.list(
                children: [
                  for (var i = 0; i < 10; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        '₹${85 + i} L · 3 BHK, Sector ${50 + i}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(loadAppFonts);

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';
    testWidgets('paper kit $theme', (tester) async {
      tester.view.physicalSize = const Size(720, 1010);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(
          dark: dark,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Builder(
              builder: (context) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    children: [
                      for (final entry in _seeds.entries)
                        PaperVignette(entry.key, seed: entry.value, width: 208),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: PaperSheet(
                          seed: 'kit',
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₹85 lakh · Sector 57',
                                style: Theme.of(context).textTheme.headlineLarge,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'गुरुग्राम में 3 BHK · 1,450 sq ft',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 16),
                              FilledButton(onPressed: () {}, child: const Text('Book a visit')),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      // A calculator result on a receipt: the teeth clear the content.
                      DecoratedBox(
                        decoration: ShapeDecoration(
                          color: context.design.surface,
                          shape: ReceiptBorder(
                            seed: 'kit-receipt',
                            shadows: paperShadows(
                              PaperElevation.low,
                              context.design.shadowOn(context.design.background),
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Monthly EMI', style: Theme.of(context).textTheme.labelLarge),
                              const SizedBox(height: 4),
                              Text('₹43,400', style: Theme.of(context).textTheme.displaySmall),
                              const SizedBox(height: 8),
                              Text(
                                'Interest ₹52.1 L · 20 years',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  // Folder tabs: the chosen tab merges with the sheet below.
                  SizedBox(
                    width: 520,
                    child: Column(
                      children: [
                        FolderTabs(
                          labels: const ['Overview', 'Media', 'Specs'],
                          selected: 1,
                          onSelect: (_) {},
                        ),
                        Container(height: 28, color: context.design.surface),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // The roofline strip with the tower over the active tab.
                  SizedBox(
                    width: 390,
                    child: CustomBottomNavigationBar(currentIndex: 2, onTap: (_) {}),
                  ),
                  const SizedBox(height: 24),
                  IconTheme(
                    data: IconThemeData(size: 24, color: Theme.of(context).colorScheme.onSurface),
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [for (final icon in KnifeIcon.values) PaperIcon(icon)],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final size in [18.0, 24.0, 48.0]) ...[
                        PaperIcon(KnifeIcon.kite, size: size, color: context.design.accent),
                        const SizedBox(width: 16),
                      ],
                      Text('elevations: ${PaperElevation.values.map((e) => e.name).join(', ')}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byKey(const ValueKey('kit')),
        matchesGoldenFile('goldens/paper_kit_$theme.png'),
      );
    });

    testWidgets('paper kit scenes $theme', (tester) async {
      tester.view.physicalSize = const Size(840, 1420);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(
          dark: dark,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: [
                    _Band(PaperSceneSpec.saved()),
                    _Band(PaperSceneSpec.saved(litCount: 7)),
                    _Band(PaperSceneSpec.visits()),
                    _Band(PaperSceneSpec.profile()),
                    _Band(PaperSceneSpec.assistant()),
                    _Band(PaperSceneSpec.skyline(), height: 110),
                  ],
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: [
                    for (final (theme, seed) in _vignettes)
                      PaperArtView.vignette(theme, seed: seed, width: 178),
                  ],
                ),
                const SizedBox(height: 24),
                Row(children: [_screen(0), const SizedBox(width: 20), _screen(260)]),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await expectLater(
        find.byKey(const ValueKey('kit')),
        matchesGoldenFile('goldens/paper_kit_scenes_$theme.png'),
      );
    });
  }
}
