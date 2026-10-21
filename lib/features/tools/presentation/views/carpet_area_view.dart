import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/features/tools/presentation/controllers/carpet_area_controller.dart';
import 'package:ghar360/features/tools/presentation/widgets/calculator_widgets.dart';

class CarpetAreaView extends ConsumerStatefulWidget {
  const CarpetAreaView({super.key});
  @override
  ConsumerState<CarpetAreaView> createState() => _CarpetAreaViewState();
}

class _CarpetAreaViewState extends ConsumerState<CarpetAreaView> {
  CarpetAreaController get controller => ref.read(carpetAreaProvider.notifier);
  CarpetAreaState get state => ref.read(carpetAreaProvider);
  late final TextEditingController _superBuiltUp;

  @override
  void initState() {
    super.initState();
    _superBuiltUp = TextEditingController(text: state.superBuiltUp)..addListener(_syncInputs);
  }

  void _syncInputs() => controller.updateInputs(superBuiltUp: _superBuiltUp.text);
  void _clear() {
    _superBuiltUp.clear();
    controller.clear();
  }

  @override
  void dispose() {
    _superBuiltUp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(carpetAreaProvider);
    final l10n = context.l10n;
    final sqFt = l10n.text('sq_ft');
    String area(double value) => '${value.toStringAsFixed(0)} $sqFt';
    return CalculatorScaffold(
      screenKey: 'qa.tools.carpet_area.screen',
      title: l10n.text('carpet_area_calculator'),
      onReset: _clear,
      inputs: [
        CalculatorNote(l10n.text('carpet_area_info')),
        const SizedBox(height: 24),
        CalculatorTextField(
          label: l10n.text('super_built_up_area'),
          controller: _superBuiltUp,
          errorText: state.validationField == 'superBuiltUp'
              ? l10n.text(state.validationKey!, params: const {'years': '50'})
              : null,
          hint: l10n.text('enter_area_sqft'),
          suffix: sqFt,
        ),
        const SizedBox(height: 24),
        CalculatorSlider(
          label: l10n.text('loading_percentage'),
          value: state.loadingPercentage,
          min: 15,
          max: 40,
          divisions: 25,
          format: (value) => '${value.toInt()}%',
          onChanged: controller.onLoadingChanged,
        ),
        const SizedBox(height: 24),
        Semantics(
          identifier: 'qa.tools.carpet_area.calculate',
          child: FilledButton(
            key: const ValueKey('qa.tools.carpet_area.calculate'),
            onPressed: controller.calculate,
            child: Text(l10n.text('calculate')),
          ),
        ),
        if (state.validationKey != null && state.validationField == null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ErrorStates.inlineError(
              message: l10n.text(state.validationKey!, params: const {'years': '50'}),
            ),
          ),
      ],
      result: !state.hasCalculated
          ? null
          : [
              CalculatorSectionTitle(l10n.text('area_breakdown')),
              const SizedBox(height: 14),
              CalculatorHeadline(
                label: l10n.text('usable_area'),
                value: state.usablePercentage,
                format: (value) => '${value.toStringAsFixed(1)}%',
                valueKey: const ValueKey('qa.tools.carpet_area.usable'),
              ),
              const SizedBox(height: 14),
              CalculatorResultRow(
                l10n.text('carpet_area'),
                area(state.carpetArea),
                caption: l10n.text('actual_usable_space'),
                isHighlight: true,
              ),
              CalculatorResultRow(
                l10n.text('built_up_area'),
                area(state.builtUpArea),
                caption: l10n.text('carpet_plus_walls'),
              ),
              CalculatorResultRow(
                l10n.text('super_built_up'),
                area(double.tryParse(_superBuiltUp.text) ?? 0),
                caption: l10n.text('includes_common_areas'),
              ),
            ],
    );
  }
}
