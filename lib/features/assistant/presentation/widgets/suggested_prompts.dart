import 'package:flutter/material.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/features/assistant/presentation/widgets/paper_note.dart';

/// A new chat opens like a conversation: the assistant's greeting on its
/// white note, signed with the kite, and four things the reader can say, on
/// the same mint slips their own words take once sent.
class SuggestedPrompts extends StatelessWidget {
  final void Function(String) onPromptTap;

  const SuggestedPrompts({super.key, required this.onPromptTap});

  static const _prompts = [
    'assistant_prompt_show_properties',
    'assistant_prompt_schedule_visit',
    'assistant_prompt_check_rent',
    'assistant_prompt_maintenance',
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.design;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The opener runs to the same right edge as the slips under it.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(padding: EdgeInsets.only(top: 15), child: AssistantKite()),
              const SizedBox(width: 8),
              Flexible(
                child: PaperNote(
                  seed: 'greeting',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // A display line holds to two lines, also at large text.
                      MediaQuery.withClampedTextScaling(
                        maxScaleFactor: 1.3,
                        child: Semantics(
                          header: true,
                          child: Text(l10n.text('assistant_greeting'), style: text.headlineSmall),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.text('assistant_subtitle'),
                        style: text.bodyMedium?.copyWith(color: palette.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        for (final key in _prompts)
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 0, 16, 8),
            child: _PromptSlip(
              key: ValueKey('qa.assistant.prompt.$key'),
              seed: key,
              label: l10n.text(key),
              onTap: () => onPromptTap(l10n.text(key)),
            ),
          ),
      ],
    );
  }
}

/// A mint slip cut from the same card stock as a sent message.
class _PromptSlip extends StatelessWidget {
  final String seed;
  final String label;
  final VoidCallback onTap;

  const _PromptSlip({super.key, required this.seed, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.design;
    final shape = PaperNote.shape(context, seed, slip: true);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: label,
      onTap: onTap,
      child: Material(
        color: palette.slip,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: palette.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  PaperIcon(KnifeIcon.arrowUpRight, size: 18, color: palette.accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
