import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/bootstrap/provider_policy.dart';
import 'package:ghar360/core/utils/formatters.dart';

class EmiCalculatorResult {
  const EmiCalculatorResult({
    required this.monthlyEmi,
    required this.totalInterest,
    required this.totalPayment,
  });
  final double monthlyEmi;
  final double totalInterest;
  final double totalPayment;
}

class EmiCalculatorState {
  const EmiCalculatorState({
    this.principal = '',
    this.rate = '',
    this.tenure = '',
    this.tenureInYears = true,
    this.result,
    this.validationKey,
    this.validationField,
  });
  final String principal;
  final String rate;
  final String tenure;
  final bool tenureInYears;
  final EmiCalculatorResult? result;
  final String? validationKey;
  final String? validationField;
  bool get hasCalculated => result != null;
  double get monthlyEmi => result?.monthlyEmi ?? 0;
  double get totalInterest => result?.totalInterest ?? 0;
  double get totalPayment => result?.totalPayment ?? 0;
  EmiCalculatorState copyWith({
    String? principal,
    String? rate,
    String? tenure,
    bool? tenureInYears,
    EmiCalculatorResult? result,
    String? validationKey,
    String? validationField,
  }) => EmiCalculatorState(
    principal: principal ?? this.principal,
    rate: rate ?? this.rate,
    tenure: tenure ?? this.tenure,
    tenureInYears: tenureInYears ?? this.tenureInYears,
    result: result,
    validationKey: validationKey,
    validationField: validationField,
  );
}

final emiCalculatorProvider =
    NotifierProvider.autoDispose<EmiCalculatorController, EmiCalculatorState>(
      EmiCalculatorController.new,
      retry: noProviderRetry,
    );

class EmiCalculatorController extends Notifier<EmiCalculatorState> {
  @override
  EmiCalculatorState build() => const EmiCalculatorState();

  void updateInputs({String? principal, String? rate, String? tenure}) {
    if ((principal == null || principal == state.principal) &&
        (rate == null || rate == state.rate) &&
        (tenure == null || tenure == state.tenure)) {
      return;
    }
    state = state.copyWith(principal: principal, rate: rate, tenure: tenure);
  }

  static const int maxTenureMonths = 600;
  void calculate() {
    final principal = double.tryParse(state.principal.trim()) ?? 0;
    final annualRate = double.tryParse(state.rate.trim()) ?? 0;
    final tenure = int.tryParse(state.tenure.trim()) ?? 0;
    if (!Formatters.isPositiveFinite(principal) ||
        !Formatters.isPositiveFinite(annualRate) ||
        tenure <= 0) {
      state = state.copyWith(
        validationKey: 'please_enter_valid_amounts',
        validationField: !Formatters.isPositiveFinite(principal)
            ? 'principal'
            : !Formatters.isPositiveFinite(annualRate)
            ? 'rate'
            : 'tenure',
      );
      return;
    }
    final months = state.tenureInYears ? tenure * 12 : tenure;
    if (months <= 0 || months > maxTenureMonths) {
      state = state.copyWith(validationKey: 'tenure_max_years', validationField: 'tenure');
      return;
    }
    final monthlyRate = annualRate / 12 / 100;
    final factor = pow(1 + monthlyRate, months);
    final emi = principal * monthlyRate * factor / (factor - 1);
    final total = emi * months;
    if (!emi.isFinite || !total.isFinite) {
      state = state.copyWith(validationKey: 'please_enter_valid_amounts');
      return;
    }
    state = state.copyWith(
      result: EmiCalculatorResult(
        monthlyEmi: emi,
        totalPayment: total,
        totalInterest: total - principal,
      ),
    );
  }

  void setTenureInYears(bool value) {
    final recalculate = state.hasCalculated;
    state = state.copyWith(tenureInYears: value);
    if (recalculate) calculate();
  }

  void toggleTenureUnit() => setTenureInYears(!state.tenureInYears);
  void clear() => state = const EmiCalculatorState();
}
