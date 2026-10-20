import 'package:flutter/material.dart';

import 'package:ghar360/core/widgets/paper/paper_scroll_page.dart';
import 'package:ghar360/core/widgets/paper/scene_header_sliver.dart';
import 'package:ghar360/features/profile/presentation/widgets/paper_parts.dart';

/// A profile sub-page: the slim skyline header with back, then [children]
/// on one white sheet, at most [maxWidth] wide. [identifier] is the screen's
/// Semantics identifier and the key of its scroll view.
class ProfileSheetPage extends StatelessWidget {
  const ProfileSheetPage({
    super.key,
    required this.title,
    required this.identifier,
    required this.children,
    this.maxWidth = 640,
  });

  final String title;
  final String identifier;
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Semantics(
      identifier: identifier,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = paperGutter(constraints.maxWidth, maxWidth);
          return PaperScrollPage(
            key: ValueKey(identifier),
            header: SceneHeaderSliver(
              title: title,
              scene: PaperSceneSpec.skyline(),
              seed: identifier,
            ),
            padding: EdgeInsets.fromLTRB(side, 12, side, 32 + MediaQuery.paddingOf(context).bottom),
            slivers: [
              SliverToBoxAdapter(
                // Ink of the rows paints on this layer, above the sheet.
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

/// A section title on a sheet, in the display face.
class SheetSectionTitle extends StatelessWidget {
  const SheetSectionTitle(this.text, {super.key, this.top = 28});

  final String text;

  /// Space above the title.
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: top, bottom: 8),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.headlineSmall),
    ),
  );
}
