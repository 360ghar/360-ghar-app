import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/common/inline_retry_banner.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/core/widgets/paper/paper_scroll_page.dart';
import 'package:ghar360/core/widgets/paper/scene_header_sliver.dart';
import 'package:ghar360/features/profile/presentation/widgets/paper_parts.dart';
import 'package:ghar360/features/tools/presentation/controllers/document_checklist_controller.dart';

class DocumentChecklistView extends ConsumerWidget {
  const DocumentChecklistView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(documentChecklistProvider);
    final controller = ref.read(documentChecklistProvider.notifier);
    final l10n = context.l10n;
    final design = context.design;
    final text = Theme.of(context).textTheme;
    final failed =
        state.saveStatus == ChecklistSaveStatus.failed ||
        state.saveStatus == ChecklistSaveStatus.loadFailed;
    final done = state.progress == 1.0;
    return Semantics(
      identifier: 'qa.tools.document_checklist.screen',
      child: Scaffold(
        key: const ValueKey('qa.tools.document_checklist.screen'),
        backgroundColor: design.background,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final side = paperGutter(constraints.maxWidth, 640);
            return PaperScrollPage(
              header: SceneHeaderSliver(
                title: l10n.text('document_checklist'),
                scene: PaperSceneSpec.skyline(),
                seed: 'document-checklist',
                leading: IconButton(
                  tooltip: l10n.text('back'),
                  icon: const PaperIcon(KnifeIcon.arrowLeft),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                actions: [
                  Semantics(
                    identifier: 'qa.tools.document_checklist.reset',
                    child: IconButton(
                      key: const ValueKey('qa.tools.document_checklist.reset'),
                      tooltip: l10n.text('reset'),
                      icon: const PaperIcon(KnifeIcon.retry),
                      onPressed: () => _showResetDialog(context, controller),
                    ),
                  ),
                ],
              ),
              padding: EdgeInsets.only(top: 8, bottom: 32 + MediaQuery.paddingOf(context).bottom),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(side, 0, side, 16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // The strip below announces "Progress, 3/15" once.
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: ExcludeSemantics(
                                child: Text(
                                  l10n.text('progress'),
                                  style: text.labelLarge?.copyWith(color: design.textSecondary),
                                ),
                              ),
                            ),
                            if (state.saveStatus == ChecklistSaveStatus.saving) ...[
                              LoadingStates.buttonSpinner(
                                size: 14,
                                color: design.textSecondary,
                                semanticsLabel: l10n.text('saving'),
                              ),
                              const SizedBox(width: 10),
                            ],
                            ExcludeSemantics(
                              child: Text(
                                '${state.checkedItems}/${state.totalItems}',
                                style: text.headlineMedium?.copyWith(
                                  color: done ? design.success : design.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Semantics(
                          key: const ValueKey('qa.tools.document_checklist.progress'),
                          container: true,
                          label: l10n.text('progress'),
                          value: '${state.checkedItems}/${state.totalItems}',
                          child: CutStrip(
                            value: state.progress,
                            seed: 'document-checklist',
                            color: done ? design.success : design.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (failed)
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: side - 16),
                    sliver: SliverToBoxAdapter(
                      child: InlineRetryBanner(
                        key: const ValueKey('qa.tools.document_checklist.save_failed'),
                        message: l10n.text(
                          state.saveStatus == ChecklistSaveStatus.loadFailed
                              ? 'checklist_load_failed'
                              : 'checklist_save_failed',
                        ),
                        onRetry: state.saveStatus == ChecklistSaveStatus.loadFailed
                            ? controller.retryLoad
                            : controller.retrySave,
                        identifier: 'qa.tools.document_checklist.retry',
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: side),
                  sliver: SliverList.builder(
                    itemCount: state.categories.length,
                    itemBuilder: (context, index) =>
                        _buildCategorySection(context, state.categories[index], controller),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    DocumentCategory category,
    DocumentChecklistController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      // Ink of the rows paints on this layer, above the sheet.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                context.l10n.text(category.titleKey),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 4),
            for (final item in category.items) _buildDocumentItem(context, item, controller),
          ],
        ),
      ),
    );
  }

  /// A real checkbox and the document's name. A ticked row turns quieter; no
  /// strike line, no filled tile behind a tick icon.
  Widget _buildDocumentItem(
    BuildContext context,
    DocumentItem item,
    DocumentChecklistController controller,
  ) {
    final design = context.design;
    final text = Theme.of(context).textTheme;
    return Semantics(
      checked: item.isChecked,
      label: context.l10n.text(item.titleKey),
      hint: context.l10n.text(item.descriptionKey),
      identifier: 'qa.tools.document_checklist.${item.id}',
      excludeSemantics: true,
      onTap: () => controller.toggleItem(item.id),
      child: InkWell(
        onTap: () => controller.toggleItem(item.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The box lines up with the titles; the whole row is the target.
              SizedBox(
                width: 24,
                height: 40,
                child: Checkbox(
                  value: item.isChecked,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  onChanged: (_) => controller.toggleItem(item.id),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.text(item.titleKey),
                        style: text.bodyLarge?.copyWith(
                          color: item.isChecked ? design.textSecondary : design.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        context.l10n.text(item.descriptionKey),
                        style: text.bodySmall?.copyWith(color: design.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context, DocumentChecklistController controller) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.text('reset_checklist')),
        content: Text(context.l10n.text('reset_checklist_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(context.l10n.text('cancel')),
          ),
          Semantics(
            identifier: 'qa.tools.document_checklist.reset_confirm',
            child: FilledButton(
              key: const ValueKey('qa.tools.document_checklist.reset_confirm'),
              onPressed: () {
                controller.resetAll();
                Navigator.of(context).maybePop();
              },
              child: Text(context.l10n.text('reset')),
            ),
          ),
        ],
      ),
    );
  }
}
