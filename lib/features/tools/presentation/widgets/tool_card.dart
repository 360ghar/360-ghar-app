import 'package:flutter/material.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/widgets/common/animated_tap_wrapper.dart';
import 'package:ghar360/core/widgets/paper/paper_sheet.dart';
import 'package:ghar360/core/widgets/paper/paper_vignette.dart';

/// One tool as a white sheet on the sky: its paper vignette mounted on top,
/// the name, one line on what it does. With [row] the vignette sits beside
/// the words (one column at large text).
class ToolCard extends StatelessWidget {
  final String vignette;
  final String title;
  final String description;
  final VoidCallback onTap;
  final String? qaKey;
  final bool row;

  /// Room kept for the name, so the lines under it start level across a row
  /// of cards whose names wrap differently.
  final double titleHeight;

  const ToolCard({
    super.key,
    required this.vignette,
    required this.title,
    required this.description,
    required this.onTap,
    this.qaKey,
    this.row = false,
    this.titleHeight = 0,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final text = Theme.of(context).textTheme;
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: titleHeight),
          child: Text(title, style: text.titleMedium),
        ),
        const SizedBox(height: 4),
        Text(description, style: text.bodySmall?.copyWith(color: design.textSecondary)),
      ],
    );
    final art = PaperArtView.vignette(vignette, seed: 'tools', width: row ? 96 : double.infinity);
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: title,
      hint: description,
      identifier: qaKey,
      onTap: onTap,
      child: AnimatedTapWrapper(
        onTap: onTap,
        child: PaperSheet(
          key: qaKey != null ? ValueKey(qaKey) : null,
          seed: 'tool-$vignette',
          elevation: PaperElevation.low,
          padding: const EdgeInsets.all(12),
          child: row
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    art,
                    const SizedBox(width: 14),
                    Expanded(child: words),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [art, const SizedBox(height: 12), words],
                ),
        ),
      ),
    );
  }
}
