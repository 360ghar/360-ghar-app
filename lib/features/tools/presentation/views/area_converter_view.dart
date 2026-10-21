import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/features/tools/presentation/controllers/area_converter_controller.dart';
import 'package:ghar360/features/tools/presentation/widgets/calculator_widgets.dart';

class AreaConverterView extends ConsumerStatefulWidget {
  const AreaConverterView({super.key});

  @override
  ConsumerState<AreaConverterView> createState() => _AreaConverterViewState();
}

class _AreaConverterViewState extends ConsumerState<AreaConverterView> {
  late final TextEditingController _input;

  @override
  void initState() {
    super.initState();
    _input = TextEditingController(text: ref.read(areaConverterProvider).input);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(areaConverterProvider);
    final controller = ref.read(areaConverterProvider.notifier);
    final palette = context.design;
    final l10n = context.l10n;
    return CalculatorScaffold(
      screenKey: 'qa.tools.area_converter.screen',
      title: l10n.text('area_converter'),
      onReset: () {
        _input.clear();
        controller.clear();
      },
      inputs: [
        CalculatorLabel(l10n.text('enter_area')),
        const SizedBox(height: 8),
        Semantics(
          identifier: 'qa.tools.area_converter.input',
          child: TextField(
            key: const ValueKey('qa.tools.area_converter.input'),
            controller: _input,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: l10n.text('enter_value'),
              errorText: state.validationKey == null ? null : l10n.text(state.validationKey!),
              suffixIcon: state.validationKey == null
                  ? null
                  : PaperIcon(KnifeIcon.alert, color: palette.error),
              errorMaxLines: 3,
            ),
            onChanged: controller.convert,
          ),
        ),
        const SizedBox(height: 24),
        CalculatorLabel(l10n.text('select_unit')),
        const SizedBox(height: 8),
        // A choice control: the chosen unit sits on a quiet slip, the rest are
        // plain words. No outline ring and no gold fill.
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final unit in AreaUnit.values)
              ChoiceChip(
                label: Text(l10n.text(unit.labelKey)),
                selected: state.selectedUnit == unit,
                onSelected: (_) => controller.onUnitChanged(unit),
                materialTapTargetSize: MaterialTapTargetSize.padded,
                showCheckmark: false,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                ),
                // Unchosen units are plain words on the sheet, not tinted pills.
                backgroundColor: palette.surface,
                selectedColor: palette.slip,
                labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: state.selectedUnit == unit ? palette.textPrimary : palette.textSecondary,
                  fontWeight: state.selectedUnit == unit ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
          ],
        ),
        if (state.selectedUnit == AreaUnit.bigha) ...[
          const SizedBox(height: 12),
          CalculatorNote(l10n.text('bigha_conversion_note')),
        ],
      ],
      result: state.conversions.isEmpty
          ? null
          : [
              CalculatorSectionTitle(l10n.text('conversions')),
              const SizedBox(height: 8),
              for (final unit in AreaUnit.values)
                CalculatorResultRow(
                  l10n.text(unit.labelKey),
                  _formatNumber(state.conversions[unit]!),
                  valueColor: state.selectedUnit == unit ? palette.accent : null,
                ),
            ],
    );
  }

  String _formatNumber(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(2)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(2)}K';
    return value.toStringAsFixed(value >= 1 ? 2 : 4);
  }
}
