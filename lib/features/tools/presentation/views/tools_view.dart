import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/core/widgets/paper/scene_header_sliver.dart';
import 'package:ghar360/core/widgets/paper/sheet_sliver.dart';
import 'package:ghar360/features/profile/presentation/widgets/paper_parts.dart';
import 'package:ghar360/features/tools/presentation/views/area_converter_view.dart';
import 'package:ghar360/features/tools/presentation/views/capital_gains_view.dart';
import 'package:ghar360/features/tools/presentation/views/carpet_area_view.dart';
import 'package:ghar360/features/tools/presentation/views/document_checklist_view.dart';
import 'package:ghar360/features/tools/presentation/views/emi_calculator_view.dart';
import 'package:ghar360/features/tools/presentation/views/loan_eligibility_view.dart';
import 'package:ghar360/features/tools/presentation/widgets/tool_card.dart';

class ToolsView extends StatelessWidget {
  const ToolsView({super.key});

  @override
  Widget build(BuildContext context) {
    final tools = [
      ToolItem(
        vignette: 'plot',
        title: context.l10n.text('area_converter'),
        description: context.l10n.text('area_converter_desc'),
        qaKey: 'qa.tools.menu.area_converter',
        destination: const AreaConverterView(),
      ),
      ToolItem(
        vignette: 'key',
        title: context.l10n.text('loan_eligibility'),
        description: context.l10n.text('loan_eligibility_desc'),
        qaKey: 'qa.tools.menu.loan_eligibility',
        destination: const LoanEligibilityView(),
      ),
      ToolItem(
        vignette: 'calculator',
        title: context.l10n.text('emi_calculator'),
        description: context.l10n.text('emi_calculator_desc'),
        qaKey: 'qa.tools.menu.emi_calculator',
        destination: const EmiCalculatorView(),
      ),
      ToolItem(
        vignette: 'home',
        title: context.l10n.text('carpet_area_calculator'),
        description: context.l10n.text('carpet_area_desc'),
        qaKey: 'qa.tools.menu.carpet_area',
        destination: const CarpetAreaView(),
      ),
      ToolItem(
        vignette: 'document',
        title: context.l10n.text('document_checklist'),
        description: context.l10n.text('document_checklist_desc'),
        qaKey: 'qa.tools.menu.document_checklist',
        destination: const DocumentChecklistView(),
      ),
      ToolItem(
        vignette: 'tower',
        title: context.l10n.text('capital_gains'),
        description: context.l10n.text('capital_gains_desc'),
        qaKey: 'qa.tools.menu.capital_gains',
        destination: const CapitalGainsView(),
      ),
    ];

    final l10n = context.l10n;
    return Scaffold(
      key: const ValueKey('qa.tools.screen'),
      backgroundColor: context.design.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final side = paperGutter(constraints.maxWidth, 720, min: 16);
          final inner = constraints.maxWidth - side * 2;
          // Two cards a row on a phone, three from 600 px; one at large text,
          // where a card would be too narrow for its name.
          final fit = ((inner + _gap) / (136 * MediaQuery.textScalerOf(context).scale(1) + _gap))
              .floor();
          final columns = fit.clamp(1, constraints.maxWidth >= 600 ? 3 : 2);
          // The tallest name in a row of cards (inner card width = column - padding).
          final nameWidth = (inner - _gap * (columns - 1)) / columns - 24;
          double nameHeight(Iterable<ToolItem> row) {
            var height = 0.0;
            for (final tool in row) {
              final painter = TextPainter(
                text: TextSpan(text: tool.title, style: Theme.of(context).textTheme.titleMedium),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout(maxWidth: nameWidth);
              height = math.max(height, painter.height);
              painter.dispose();
            }
            return height;
          }

          Widget card(ToolItem tool, {bool row = false, double titleHeight = 0}) => ToolCard(
            vignette: tool.vignette,
            title: tool.title,
            description: tool.description,
            qaKey: tool.qaKey,
            row: row,
            titleHeight: titleHeight,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => tool.destination)),
          );
          return SkySheetsScrollView(
            seed: 'tools-band',
            header: SceneHeaderSliver(
              title: l10n.text('tools_calculators'),
              scene: PaperSceneSpec.skyline(),
              seed: 'tools',
              leading: IconButton(
                tooltip: l10n.text('back'),
                icon: PaperIcon(KnifeIcon.arrowLeft, color: context.design.textPrimary),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            slivers: [
              SheetSliver(
                padding: EdgeInsets.fromLTRB(side, kPaperLip + 2, side, 10),
                slivers: [
                  SliverToBoxAdapter(
                    child: Text(
                      l10n.text('tools_subtitle'),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: context.design.textSecondary),
                    ),
                  ),
                ],
              ),
              const SliverToBoxAdapter(child: SheetFoot(seed: 'tools-foot')),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  side,
                  20,
                  side,
                  32 + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverList.list(
                  children: [
                    for (var start = 0; start < tools.length; start += columns)
                      Padding(
                        padding: const EdgeInsets.only(bottom: _gap),
                        child: columns == 1
                            ? card(tools[start], row: true)
                            // Each row is as tall as its tallest card, so names
                            // and lines start on one line across the row.
                            : IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    for (var i = start; i < start + columns; i++) ...[
                                      if (i > start) const SizedBox(width: _gap),
                                      Expanded(
                                        child: i < tools.length
                                            ? card(
                                                tools[i],
                                                titleHeight: nameHeight(
                                                  tools.skip(start).take(columns),
                                                ),
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static const _gap = 12.0;
}

class ToolItem {
  /// The paper vignette theme (see `PaperArtView.vignette`).
  final String vignette;
  final String title;
  final String description;
  final String? qaKey;
  final Widget destination;

  const ToolItem({
    required this.vignette,
    required this.title,
    required this.description,
    this.qaKey,
    required this.destination,
  });
}
