import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/bootstrap/provider_policy.dart';
import 'package:ghar360/core/utils/formatters.dart';

class LoanEligibilityResult {
  const LoanEligibilityResult({
    required this.maxLoanAmount,
    required this.maxTenure,
    required this.eligibleEmi,
  });
  final double maxLoanAmount;
  final int maxTenure;
  final double eligibleEmi;
}

class LoanEligibilityState {
  const LoanEligibilityState({
    this.income = '',
    this.age = '',
    this.existingEmi = '',
    this.creditScore = 750,
    this.interestRate = 8.5,
    this.result,
    this.validationKey,
    this.validationField,
  });
  final String income;
  final String age;
  final String existingEmi;
  final double creditScore;
  final double interestRate;
  final LoanEligibilityResult? result;
  final String? validationKey;
  final String? validationField;
  bool get hasCalculated => result != null;
  double get maxLoanAmount => result?.maxLoanAmount ?? 0;
  int get maxTenure => result?.maxTenure ?? 0;
  double get eligibleEmi => result?.eligibleEmi ?? 0;
  LoanEligibilityState copyWith({
    String? income,
    String? age,
    String? existingEmi,
    double? creditScore,
    double? interestRate,
    LoanEligibilityResult? result,
    String? validationKey,
    String? validationField,
  }) => LoanEligibilityState(
    income: income ?? this.income,
    age: age ?? this.age,
    existingEmi: existingEmi ?? this.existingEmi,
    creditScore: creditScore ?? this.creditScore,
    interestRate: interestRate ?? this.interestRate,
    result: result,
    validationKey: validationKey,
    validationField: validationField,
  );
}

final loanEligibilityProvider =
    NotifierProvider.autoDispose<LoanEligibilityController, LoanEligibilityState>(
      LoanEligibilityController.new,
      retry: noProviderRetry,
    );

class LoanEligibilityController extends Notifier<LoanEligibilityState> {
  @override
  LoanEligibilityState build() => const LoanEligibilityState();

  void updateInputs({String? income, String? age, String? existingEmi}) {
    if ((income == null || income == state.income) &&
        (age == null || age == state.age) &&
        (existingEmi == null || existingEmi == state.existingEmi)) {
      return;
    }
    state = state.copyWith(income: income, age: age, existingEmi: existingEmi);
  }

  void calculate() {
    final income = double.tryParse(state.income.trim()) ?? 0;
    final age = state.age.trim().isEmpty ? 30 : int.tryParse(state.age.trim());
    final existingEmi = state.existingEmi.trim().isEmpty
        ? 0.0
        : double.tryParse(state.existingEmi.trim());
    if (!Formatters.isPositiveFinite(income) ||
        existingEmi == null ||
        !existingEmi.isFinite ||
        existingEmi < 0 ||
        age == null ||
        age < 18 ||
        age > 80 ||
        !Formatters.isPositiveFinite(state.interestRate) ||
        !state.creditScore.isFinite ||
        state.creditScore < 300 ||
        state.creditScore > 900) {
      state = state.copyWith(
        validationKey: 'please_enter_valid_amounts',
        validationField: !Formatters.isPositiveFinite(income)
            ? 'income'
            : (age == null || age < 18 || age > 80)
            ? 'age'
            : 'existingEmi',
      );
      return;
    }
    final foir = state.creditScore >= 750
        ? .50
        : state.creditScore >= 700
        ? .45
        : state.creditScore >= 650
        ? .40
        : .35;
    final maxEmi = income * foir - existingEmi;
    if (maxEmi <= 0) {
      state = state.copyWith(
        result: const LoanEligibilityResult(maxLoanAmount: 0, maxTenure: 0, eligibleEmi: 0),
      );
      return;
    }
    final years = (60 - age).clamp(5, 30);
    final rate = state.interestRate / 12 / 100;
    final factor = pow(1 + rate, years * 12);
    final principal = maxEmi * (factor - 1) / (rate * factor);
    if (!principal.isFinite || principal < 0) {
      state = state.copyWith(validationKey: 'please_enter_valid_amounts');
      return;
    }
    state = state.copyWith(
      result: LoanEligibilityResult(
        maxLoanAmount: principal,
        maxTenure: years,
        eligibleEmi: maxEmi,
      ),
    );
  }

  void setCreditScore(double value) {
    final recalculate = state.hasCalculated;
    state = state.copyWith(creditScore: value);
    if (recalculate) calculate();
  }

  void setInterestRate(double value) {
    final recalculate = state.hasCalculated;
    state = state.copyWith(interestRate: value);
    if (recalculate) calculate();
  }

  void clear() => state = const LoanEligibilityState();
}
