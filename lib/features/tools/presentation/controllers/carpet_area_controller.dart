import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/bootstrap/provider_policy.dart';
import 'package:ghar360/core/utils/formatters.dart';

class CarpetAreaResult {
  const CarpetAreaResult({
    required this.carpetArea,
    required this.builtUpArea,
    required this.usablePercentage,
  });
  final double carpetArea;
  final double builtUpArea;
  final double usablePercentage;
}

class CarpetAreaState {
  const CarpetAreaState({
    this.superBuiltUp = '',
    this.loadingPercentage = 25,
    this.result,
    this.validationKey,
    this.validationField,
  });
  final String superBuiltUp;
  final double loadingPercentage;
  final CarpetAreaResult? result;
  final String? validationKey;
  final String? validationField;
  bool get hasCalculated => result != null;
  double get carpetArea => result?.carpetArea ?? 0;
  double get builtUpArea => result?.builtUpArea ?? 0;
  double get usablePercentage => result?.usablePercentage ?? 0;
  CarpetAreaState copyWith({
    String? superBuiltUp,
    double? loadingPercentage,
    CarpetAreaResult? result,
    String? validationKey,
    String? validationField,
  }) => CarpetAreaState(
    superBuiltUp: superBuiltUp ?? this.superBuiltUp,
    loadingPercentage: loadingPercentage ?? this.loadingPercentage,
    result: result,
    validationKey: validationKey,
    validationField: validationField,
  );
}

final carpetAreaProvider = NotifierProvider.autoDispose<CarpetAreaController, CarpetAreaState>(
  CarpetAreaController.new,
  retry: noProviderRetry,
);

class CarpetAreaController extends Notifier<CarpetAreaState> {
  @override
  CarpetAreaState build() => const CarpetAreaState();

  void updateInputs({String? superBuiltUp}) {
    if ((superBuiltUp == null || superBuiltUp == state.superBuiltUp)) return;
    state = state.copyWith(superBuiltUp: superBuiltUp);
  }

  void calculate() {
    final area = double.tryParse(state.superBuiltUp.trim()) ?? 0;
    if (!Formatters.isPositiveFinite(area) ||
        !state.loadingPercentage.isFinite ||
        state.loadingPercentage < 0 ||
        state.loadingPercentage > 100) {
      state = state.copyWith(
        validationKey: 'please_enter_valid_amounts',
        validationField: 'superBuiltUp',
      );
      return;
    }
    final builtUp = area / (1 + state.loadingPercentage / 100);
    final carpet = builtUp * .88;
    state = state.copyWith(
      result: CarpetAreaResult(
        builtUpArea: builtUp,
        carpetArea: carpet,
        usablePercentage: carpet / area * 100,
      ),
    );
  }

  void onLoadingChanged(double value) {
    final recalculate = state.hasCalculated;
    state = state.copyWith(loadingPercentage: value);
    if (recalculate) calculate();
  }

  void clear() => state = const CarpetAreaState();
}
