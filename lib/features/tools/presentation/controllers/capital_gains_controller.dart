import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:ghar360/core/utils/formatters.dart';

class CapitalGainsController extends GetxController {
  final TextEditingController purchasePriceController = TextEditingController();
  final TextEditingController salePriceController = TextEditingController();
  final TextEditingController improvementCostController = TextEditingController();

  /// Earliest selectable date: the CII table starts at 2001.
  static final DateTime firstSelectableDate = DateTime(2001);

  static DateTime get _today => DateUtils.dateOnly(DateTime.now());

  /// A property cannot be bought or sold in the future.
  static DateTime get lastSelectableDate => _today;

  static DateTime get _defaultPurchaseDate {
    final today = _today;
    return DateTime(today.year - 2, today.month, today.day);
  }

  final Rx<DateTime> purchaseDate = _defaultPurchaseDate.obs;
  final Rx<DateTime> saleDate = _today.obs;
  final RxBool hasCalculated = false.obs;
  final RxString validationError = ''.obs;

  // Results
  final RxBool isLongTerm = false.obs;
  final RxDouble indexedCost = 0.0.obs;
  final RxDouble capitalGain = 0.0.obs;
  final RxDouble taxWithIndexation = 0.0.obs;
  final RxDouble taxWithoutIndexation = 0.0.obs;

  // Cost Inflation Index (CII) values - updated for FY 2024-25
  static const Map<int, int> ciiValues = {
    2001: 100,
    2002: 105,
    2003: 109,
    2004: 113,
    2005: 117,
    2006: 122,
    2007: 129,
    2008: 137,
    2009: 148,
    2010: 167,
    2011: 184,
    2012: 200,
    2013: 220,
    2014: 240,
    2015: 254,
    2016: 264,
    2017: 272,
    2018: 280,
    2019: 289,
    2020: 301,
    2021: 317,
    2022: 331,
    2023: 348,
    2024: 363,
    2025: 363, // Using 2024 value as 2025 not yet announced
  };

  /// Long-term iff the asset was held for STRICTLY MORE than 24 months, by
  /// real date arithmetic. `DateTime` normalises month overflow, so
  /// `month + 24` rolls the year over correctly.
  ///
  /// Boundary: bought 15 Jan 2023, sold 15 Jan 2025 = exactly 24 months =
  /// short-term; sold 16 Jan 2025 = long-term.
  static bool isLongTermHolding(DateTime purchase, DateTime sale) {
    final boundary = DateTime(purchase.year, purchase.month + 24, purchase.day);
    return DateUtils.dateOnly(sale).isAfter(boundary);
  }

  void setPurchaseDate(DateTime date) => purchaseDate.value = DateUtils.dateOnly(date);

  void setSaleDate(DateTime date) => saleDate.value = DateUtils.dateOnly(date);

  void calculate() {
    final purchasePrice = double.tryParse(purchasePriceController.text) ?? 0;
    final salePrice = double.tryParse(salePriceController.text) ?? 0;
    final improvementCost = double.tryParse(improvementCostController.text) ?? 0;

    if (!Formatters.isPositiveFinite(purchasePrice) ||
        !Formatters.isPositiveFinite(salePrice) ||
        !improvementCost.isFinite ||
        improvementCost < 0) {
      validationError.value = 'please_enter_valid_amounts'.tr;
      hasCalculated.value = false;
      return;
    }

    if (saleDate.value.isBefore(purchaseDate.value)) {
      validationError.value = 'sale_date_must_be_after_purchase_date'.tr;
      hasCalculated.value = false;
      return;
    }

    validationError.value = '';

    isLongTerm.value = isLongTermHolding(purchaseDate.value, saleDate.value);

    if (isLongTerm.value) {
      // Long-term capital gains calculation. CII is keyed by the YEAR of each date.
      final purchaseCii = ciiValues[purchaseDate.value.year] ?? 301;
      final saleCii = ciiValues[saleDate.value.year] ?? 363;

      // Indexed cost = Purchase price * (Sale CII / Purchase CII)
      final indexedPurchase = purchasePrice * saleCii / purchaseCii;
      final indexedImprovement = improvementCost * saleCii / purchaseCii;
      indexedCost.value = indexedPurchase + indexedImprovement;

      // Capital gain with indexation
      final gainWithIndexation = salePrice - indexedCost.value;
      capitalGain.value = gainWithIndexation > 0 ? gainWithIndexation : 0;

      // Tax calculation (post Budget 2024)
      // Option 1: 20% with indexation (old regime, grandfathered)
      // Option 2: 12.5% without indexation (new regime)
      taxWithIndexation.value = capitalGain.value * 0.20;

      // Without indexation
      final gainWithoutIndexation = salePrice - purchasePrice - improvementCost;
      taxWithoutIndexation.value = (gainWithoutIndexation > 0 ? gainWithoutIndexation : 0) * 0.125;
    } else {
      // Short-term: Added to income, taxed at slab rates
      // Using 30% as highest slab for estimation
      indexedCost.value = purchasePrice + improvementCost;
      capitalGain.value = salePrice - indexedCost.value;
      if (capitalGain.value < 0) capitalGain.value = 0;

      // Estimate at 30% slab
      taxWithIndexation.value = capitalGain.value * 0.30;
      taxWithoutIndexation.value = capitalGain.value * 0.30;
    }

    hasCalculated.value = true;
  }

  void clear() {
    purchasePriceController.clear();
    salePriceController.clear();
    improvementCostController.clear();
    purchaseDate.value = _defaultPurchaseDate;
    saleDate.value = _today;
    hasCalculated.value = false;
    validationError.value = '';
    isLongTerm.value = false;
    indexedCost.value = 0;
    capitalGain.value = 0;
    taxWithIndexation.value = 0;
    taxWithoutIndexation.value = 0;
  }

  @override
  void onClose() {
    purchasePriceController.dispose();
    salePriceController.dispose();
    improvementCostController.dispose();
    super.onClose();
  }
}
