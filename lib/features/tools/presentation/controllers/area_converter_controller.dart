import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/bootstrap/provider_policy.dart';

enum AreaUnit {
  sqFt('sq_ft', 1),
  sqM('sq_m', 10.7639),
  sqYards('sq_yards', 9),
  acres('acres', 43560),
  gaj('gaj', 9),
  bigha('bigha', 27000);

  const AreaUnit(this.labelKey, this.squareFeet);
  final String labelKey;
  // Bigha varies by region. The screen states this existing convention.
  final double squareFeet;
}

class AreaConverterState {
  const AreaConverterState({
    this.input = '',
    this.selectedUnit = AreaUnit.sqFt,
    this.conversions = const {},
    this.validationKey,
  });

  final String input;
  final AreaUnit selectedUnit;
  final Map<AreaUnit, double> conversions;
  final String? validationKey;
}

final areaConverterProvider =
    NotifierProvider.autoDispose<AreaConverterController, AreaConverterState>(
      AreaConverterController.new,
      retry: noProviderRetry,
    );

/// Calculation state only. The view owns and disposes its text controller.
class AreaConverterController extends Notifier<AreaConverterState> {
  @override
  AreaConverterState build() => const AreaConverterState();

  void onUnitChanged(AreaUnit? unit) {
    if (unit != null) _convert(state.input, unit);
  }

  void convert(String input) => _convert(input, state.selectedUnit);

  void _convert(String input, AreaUnit unit) {
    final value = double.tryParse(input.trim());
    final squareFeet = value == null ? null : value * unit.squareFeet;
    if (squareFeet == null || !squareFeet.isFinite || squareFeet <= 0) {
      state = AreaConverterState(
        input: input,
        selectedUnit: unit,
        validationKey: input.isEmpty ? null : 'please_enter_valid_area',
      );
      return;
    }
    state = AreaConverterState(
      input: input,
      selectedUnit: unit,
      conversions: Map.unmodifiable({
        for (final target in AreaUnit.values) target: squareFeet / target.squareFeet,
      }),
    );
  }

  void clear() => state = const AreaConverterState();
}
