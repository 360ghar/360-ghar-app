import 'package:flutter/widgets.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/widgets/paper/scene_header_sliver.dart';
import 'package:ghar360/core/widgets/paper/sheet_sliver.dart';

/// A list screen on the sky page: the pinned [header], then [slivers] on one
/// white sheet that rises over the header's scene as the list scrolls. The
/// sheet runs to the bottom of the screen when the content is short.
///
/// The scaffold behind it gives the page tone. For pagination, listen to
/// scroll notifications above it; [controller] is optional.
class PaperScrollPage extends StatelessWidget {
  const PaperScrollPage({
    super.key,
    required this.header,
    required this.slivers,
    this.controller,
    this.padding = EdgeInsets.zero,
  });

  final SceneHeaderSliver header;
  final List<Widget> slivers;
  final ScrollController? controller;

  /// Padding of the content inside the sheet.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    controller: controller,
    slivers: [
      header,
      SheetSliver(padding: padding, slivers: slivers),
      SliverFillRemaining(hasScrollBody: false, child: ColoredBox(color: context.design.surface)),
    ],
  );
}
