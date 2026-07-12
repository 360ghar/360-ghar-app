import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.smart_toy_outlined,
          size: 48,
          color: AppDesign.primaryYellow.withValues(alpha: 0.6),
        ),
        const SizedBox(height: 12),
        Text(
          'assistant_greeting'.tr,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: palette.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'assistant_subtitle'.tr,
          style: TextStyle(fontSize: 13, color: palette.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: _prompts.map((key) {
            return _PromptChip(label: key.tr, onTap: () => onPromptTap(key.tr));
          }).toList(),
        ),
      ],
    );
  }
}

class _PromptChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PromptChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.design;

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppDesign.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppDesign.primaryYellow.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppDesign.primaryYellow.withValues(alpha: 0.3)),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: palette.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
