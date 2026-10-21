import 'package:flutter/widgets.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/paper_art.dart';
import 'package:ghar360/core/design/paper/paper_scene_data.dart';

PaperArtData _city(Set<String> ids) => PaperArtData(
  width: gurugramArt.width,
  height: 640,
  shadow: gurugramArt.shadow,
  layers: [
    for (final layer in gurugramArt.layers)
      if (ids.contains(layer.id)) layer,
  ],
);

/// The city from the onboarding diorama (sky, clouds, towers, kite, sector
/// blocks) on the sky with grain, painted once into a strip anchored at its
/// base. The sign-in screens use it above their sheet.
class PaperSkylineStrip extends StatelessWidget {
  const PaperSkylineStrip({super.key, this.artTop = 0});

  /// Plain sky kept above the city, for a title or the status bar.
  final double artTop;

  static final _art = _city(const {'sky', 'clouds', 'towers', 'kite', 'blocks'});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: CustomPaint(painter: _SkylinePainter(context.design, _art, sky: true, artTop: artTop)),
    ),
  );
}

class _SkylinePainter extends CustomPainter {
  const _SkylinePainter(this.design, this.art, {required this.sky, this.artTop = 0});

  final AppPalette design;
  final PaperArtData art;
  final bool sky;
  final double artTop;

  @override
  void paint(Canvas canvas, Size size) {
    if (sky) {
      canvas.drawRect(Offset.zero & size, Paint()..color = design.tone(PaperTone.sky));
      paintPaperGrain(canvas, Offset.zero & size, design.grain);
    }
    final top = artTop.clamp(0.0, size.height);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(0, top);
    // The sun starts at row 165 and the kite at 256. On a wide strip keep them
    // whole; the city base then runs on behind the sheet.
    paintPaperArt(
      canvas,
      Size(size.width, size.height - top),
      art,
      design.inks,
      cover: true,
      keepTop: 125,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SkylinePainter old) =>
      old.design.isDark != design.isDark ||
      old.art != art ||
      old.sky != sky ||
      old.artTop != artTop;
}
