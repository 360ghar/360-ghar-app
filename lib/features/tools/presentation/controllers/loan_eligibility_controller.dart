import 'dart:math';

import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:ghar360/core/utils/formatters.dart';

class LoanEligibilityController extends GetxController {
  final TextEditingController incomeController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController existingEmiController = TextEditingController();

  final RxDouble creditScore = 750.0.obs;
  final RxDouble interestRate = 8.5.obs;
  final RxBool hasCalculated = false.obs;
  final RxString validationError = ''.obs;

  // Results
  final RxDouble maxLoanAmount = 0.0.obs;
  final RxInt maxTenure = 0.obs;
  final RxDouble eligibleEmi = 0.0.obs;

  void calculate() {
    final income = double.tryParse(incomeController.text) ?? 0;
    final ageText = ageController.text.trim();
    final age = ageText.isEmpty ? 30 : int.tryParse(ageText);
    final existingEmiText = existingEmiController.text.trim();
    final existingEmi = existingEmiText.isEmpty ? 0 : double.tryParse(existingEmiText);

    if (!Formatters.isPositiveFinite(income) ||
        existingEmi == null ||
        !existingEmi.isFinite ||
        existingEmi < 0 ||
        age == null ||
        age < 18 ||
        age > 80 ||
        !Formatters.isPositiveFinite(interestRate.value)) {
      validationError.value = 'please_enter_valid_amounts'.tr;
      hasCalculated.value = false;
      return;
    }

    validationError.value = '';

    // FOIR (Fixed Obligation to Income Ratio) based on credit score
    double foirPercentage;
    if (creditScore.value >= 750) {
      foirPercentage = 0.50; // 50% for excellent credit
    } else if (creditScore.value >= 700) {
      foirPercentage = 0.45;
    } else if (creditScore.value >= 650) {
      foirPercentage = 0.40;
    } else {
      foirPercentage = 0.35;
    }

    // Calculate eligible EMI
    final maxEmi = income * foirPercentage - existingEmi;
    if (maxEmi <= 0) {
      eligibleEmi.value = 0;
      maxLoanAmount.value = 0;
      maxTenure.value = 0;
      hasCalculated.value = true;
      return;
    }
    eligibleEmi.value = maxEmi;

    // Max tenure based on age (retirement at 60)
    final retirementAge = 60;
    final maxYears = (retirementAge - age).clamp(5, 30);
    maxTenure.value = maxYears;

    // Calculate max loan using EMI formula reverse
    // EMI = P * r * (1+r)^n / ((1+r)^n - 1)
    // P = EMI * ((1+r)^n - 1) / (r * (1+r)^n)
    final monthlyRate = interestRate.value / 12 / 100;
    final months = maxYears * 12;
    final factor = pow(1 + monthlyRate, months);
    final principal = maxEmi * (factor - 1) / (monthlyRate * factor);
    if (!principal.isFinite || principal < 0) {
      validationError.value = 'please_enter_valid_amounts'.tr;
      hasCalculated.value = false;
      return;
    }

    maxLoanAmount.value = principal;
    hasCalculated.value = true;
  }

  void clear() {
    incomeController.clear();
    ageController.clear();
    existingEmiController.clear();
    creditScore.value = 750.0;
    interestRate.value = 8.5;
    hasCalculated.value = false;
    validationError.value = '';
    maxLoanAmount.value = 0;
    maxTenure.value = 0;
    eligibleEmi.value = 0;
  }

  @override
  void onClose() {
    incomeController.dispose();
    ageController.dispose();
    existingEmiController.dispose();
    super.onClose();
  }
}
