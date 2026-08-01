import 'dart:math';

import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:ghar360/core/utils/formatters.dart';

class EmiCalculatorController extends GetxController {
  final TextEditingController principalController = TextEditingController();
  final TextEditingController rateController = TextEditingController();
  final TextEditingController tenureController = TextEditingController();

  /// Longest tenure the calculator accepts, in months (50 years). Beyond a few
  /// hundred months `pow(1+r, n)` overflows to Infinity and the EMI comes out
  /// NaN, which then throws in the widget tree.
  static const int maxTenureMonths = 600;

  final RxBool tenureInYears = true.obs;
  final RxBool hasCalculated = false.obs;
  final RxString validationError = ''.obs;

  // Results
  final RxDouble monthlyEmi = 0.0.obs;
  final RxDouble totalInterest = 0.0.obs;
  final RxDouble totalPayment = 0.0.obs;

  void calculate() {
    final principal = double.tryParse(principalController.text) ?? 0;
    final annualRate = double.tryParse(rateController.text) ?? 0;
    final tenure = int.tryParse(tenureController.text) ?? 0;

    if (!Formatters.isPositiveFinite(principal) ||
        !Formatters.isPositiveFinite(annualRate) ||
        tenure <= 0) {
      validationError.value = 'please_enter_valid_amounts'.tr;
      hasCalculated.value = false;
      return;
    }

    final months = tenureInYears.value ? tenure * 12 : tenure;
    if (months <= 0 || months > maxTenureMonths) {
      validationError.value = 'tenure_max_years'.trParams({'years': '${maxTenureMonths ~/ 12}'});
      hasCalculated.value = false;
      return;
    }

    validationError.value = '';

    final monthlyRate = annualRate / 12 / 100;

    // EMI = P * r * (1+r)^n / ((1+r)^n - 1)
    final factor = pow(1 + monthlyRate, months);
    final emi = principal * monthlyRate * factor / (factor - 1);

    // An extreme rate can still overflow `pow` to Infinity, making the EMI
    // Infinity/Infinity = NaN. Never publish a non-finite result: NaN.round()
    // throws UnsupportedError inside build().
    if (!emi.isFinite) {
      validationError.value = 'please_enter_valid_amounts'.tr;
      hasCalculated.value = false;
      return;
    }

    monthlyEmi.value = emi;
    totalPayment.value = emi * months;
    totalInterest.value = totalPayment.value - principal;
    hasCalculated.value = true;
  }

  void toggleTenureUnit() {
    tenureInYears.value = !tenureInYears.value;
    if (hasCalculated.value) {
      calculate();
    }
  }

  void clear() {
    principalController.clear();
    rateController.clear();
    tenureController.clear();
    tenureInYears.value = true;
    hasCalculated.value = false;
    validationError.value = '';
    monthlyEmi.value = 0;
    totalInterest.value = 0;
    totalPayment.value = 0;
  }

  @override
  void onClose() {
    principalController.dispose();
    rateController.dispose();
    tenureController.dispose();
    super.onClose();
  }
}
