import 'package:flutter/widgets.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/paper_art.dart';
import 'package:ghar360/core/design/paper/paper_scene_data.dart';

/// The small paper scenes for screen states.
enum PaperScene {
  /// "Khali plot": nothing here yet.
  empty,

  /// "Tuta board": something failed.
  error,

  /// "Kati patang": the connection dropped.
  offline,

  /// "Sector 404": the page or listing does not exist.
  notFound,

  /// A pin over a home: why the app asks for location.
  location,
}

/// A state scene cut for one screen. [seed] names the screen, so two screens
/// never show the same cut; see `SCENE_SEEDS` in `tool/paper/generate.ts`.
class PaperVignette extends StatelessWidget {
  const PaperVignette(
    this.scene, {
    super.key,
    required this.seed,
    this.width = 220,
    this.semanticLabel,
  });

  final PaperScene scene;
  final String seed;
  final double width;
  final String? semanticLabel;

  static bool hasScene(PaperScene scene, String seed) =>
      paperScenes.containsKey('${scene.name}/$seed');

  /// [seed] when [scene] has a cut for it, otherwise the scene's first cut.
  static String seedFor(PaperScene scene, String seed) => hasScene(scene, seed)
      ? seed
      : paperScenes.keys.firstWhere((key) => key.startsWith('${scene.name}/')).split('/').last;

  static PaperArtData artFor(PaperScene scene, String seed) {
    final art = paperScenes['${scene.name}/$seed'];
    assert(art != null, 'No ${scene.name} scene for seed "$seed". Add it to generate.ts.');
    return art ?? paperScenes.entries.firstWhere((e) => e.key.startsWith('${scene.name}/')).value;
  }

  @override
  Widget build(BuildContext context) =>
      PaperArtView(artFor(scene, seed), width: width, semanticLabel: semanticLabel);
}

/// Any paper art on its hand-cut card at [width] (at most), with the tight
/// paper shadow on the page. Without [semanticLabel] it is decorative.
class PaperArtView extends StatelessWidget {
  const PaperArtView(this.art, {super.key, this.width = 220, this.semanticLabel});

  /// A theme vignette from `paperVignettes` (calculator, key, document,
  /// tower, home, plot, pg). [seed] names the place that shows it (`tools`,
  /// `purpose`); an unknown seed falls back to the theme's first cut.
  factory PaperArtView.vignette(
    String theme, {
    Key? key,
    required String seed,
    double width = 220,
    String? semanticLabel,
  }) {
    final art =
        paperVignettes['$theme/$seed'] ??
        paperVignettes.entries.firstWhere((e) => e.key.startsWith('$theme/')).value;
    return PaperArtView(art, key: key, width: width, semanticLabel: semanticLabel);
  }

  final PaperArtData art;
  final double width;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final picture = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: AspectRatio(
        aspectRatio: art.width / art.height,
        child: RepaintBoundary(child: CustomPaint(painter: _PaperArtPainter(art, design))),
      ),
    );
    final label = semanticLabel;
    return label == null
        ? ExcludeSemantics(child: picture)
        : Semantics(
            label: label,
            image: true,
            child: ExcludeSemantics(child: picture),
          );
  }
}

class _PaperArtPainter extends CustomPainter {
  const _PaperArtPainter(this.art, this.design);

  final PaperArtData art;
  final AppPalette design;

  @override
  void paint(Canvas canvas, Size size) => paintPaperArt(
    canvas,
    size,
    art,
    design.inks,
    grain: design.grain,
    frameShadow: design.shadowOn(design.background),
  );

  @override
  bool shouldRepaint(_PaperArtPainter old) => old.art != art || old.design.isDark != design.isDark;
}
