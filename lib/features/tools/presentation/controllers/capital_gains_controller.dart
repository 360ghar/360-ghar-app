import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/bootstrap/provider_policy.dart';
import 'package:ghar360/core/utils/formatters.dart';

class CapitalGainsResult {
  const CapitalGainsResult({
    required this.isLongTerm,
    required this.indexedCost,
    required this.capitalGain,
    required this.taxWithIndexation,
    required this.taxWithoutIndexation,
  });
  final bool isLongTerm;
  final double indexedCost;
  final double capitalGain;
  final double taxWithIndexation;
  final double taxWithoutIndexation;
}

class CapitalGainsState {
  const CapitalGainsState({
    this.purchasePrice = '',
    this.salePrice = '',
    this.improvementCost = '',
    required this.purchaseDate,
    required this.saleDate,
    this.result,
    this.validationKey,
    this.validationField,
  });
  factory CapitalGainsState.initial() {
    final now = DateTime.now();
    return CapitalGainsState(
      purchaseDate: DateTime(now.year - 2, now.month, now.day),
      saleDate: DateTime(now.year, now.month, now.day),
    );
  }
  final String purchasePrice;
  final String salePrice;
  final String improvementCost;
  final DateTime purchaseDate;
  final DateTime saleDate;
  final CapitalGainsResult? result;
  final String? validationKey;
  final String? validationField;
  bool get hasCalculated => result != null;
  bool get isLongTerm => result?.isLongTerm ?? false;
  double get indexedCost => result?.indexedCost ?? 0;
  double get capitalGain => result?.capitalGain ?? 0;
  double get taxWithIndexation => result?.taxWithIndexation ?? 0;
  double get taxWithoutIndexation => result?.taxWithoutIndexation ?? 0;
  CapitalGainsState copyWith({
    String? purchasePrice,
    String? salePrice,
    String? improvementCost,
    DateTime? purchaseDate,
    DateTime? saleDate,
    CapitalGainsResult? result,
    String? validationKey,
    String? validationField,
  }) => CapitalGainsState(
    purchasePrice: purchasePrice ?? this.purchasePrice,
    salePrice: salePrice ?? this.salePrice,
    improvementCost: improvementCost ?? this.improvementCost,
    purchaseDate: purchaseDate ?? this.purchaseDate,
    saleDate: saleDate ?? this.saleDate,
    result: result,
    validationKey: validationKey,
    validationField: validationField,
  );
}

final capitalGainsProvider =
    NotifierProvider.autoDispose<CapitalGainsController, CapitalGainsState>(
      CapitalGainsController.new,
      retry: noProviderRetry,
    );

class CapitalGainsController extends Notifier<CapitalGainsState> {
  @override
  CapitalGainsState build() => CapitalGainsState.initial();
  static final DateTime firstSelectableDate = DateTime(2001, 4);
  static DateTime get lastSelectableDate => _dateOnly(DateTime.now());
  static DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
  static int financialYear(DateTime date) => date.month < 4 ? date.year - 1 : date.year;
  // Official CII table by financial-year starting year:
  // https://www.incometaxindia.gov.in/hi/w/view-all-cii
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
    2025: 376,
    2026: 384,
  };

  static bool isLongTermHolding(DateTime purchase, DateTime sale) {
    final boundary = DateTime(purchase.year, purchase.month + 24, purchase.day);
    return _dateOnly(sale).isAfter(boundary);
  }

  void updateInputs({String? purchasePrice, String? salePrice, String? improvementCost}) {
    if ((purchasePrice == null || purchasePrice == state.purchasePrice) &&
        (salePrice == null || salePrice == state.salePrice) &&
        (improvementCost == null || improvementCost == state.improvementCost)) {
      return;
    }
    state = state.copyWith(
      purchasePrice: purchasePrice,
      salePrice: salePrice,
      improvementCost: improvementCost,
    );
  }

  void setPurchaseDate(DateTime date) => state = state.copyWith(purchaseDate: _dateOnly(date));
  void setSaleDate(DateTime date) => state = state.copyWith(saleDate: _dateOnly(date));
  void calculate() {
    final purchase = double.tryParse(state.purchasePrice.trim()) ?? 0;
    final sale = double.tryParse(state.salePrice.trim()) ?? 0;
    final improvement = state.improvementCost.trim().isEmpty
        ? 0.0
        : double.tryParse(state.improvementCost.trim());
    if (!Formatters.isPositiveFinite(purchase) ||
        !Formatters.isPositiveFinite(sale) ||
        improvement == null ||
        !improvement.isFinite ||
        improvement < 0) {
      state = state.copyWith(
        validationKey: 'please_enter_valid_amounts',
        validationField: !Formatters.isPositiveFinite(purchase)
            ? 'purchasePrice'
            : !Formatters.isPositiveFinite(sale)
            ? 'salePrice'
            : 'improvementCost',
      );
      return;
    }
    if (state.saleDate.isBefore(state.purchaseDate)) {
      state = state.copyWith(validationKey: 'sale_date_must_be_after_purchase_date');
      return;
    }
    if (state.purchaseDate.isBefore(firstSelectableDate) ||
        state.saleDate.isAfter(lastSelectableDate)) {
      state = state.copyWith(validationKey: 'capital_gains_dates_invalid');
      return;
    }
    final longTerm = isLongTermHolding(state.purchaseDate, state.saleDate);
    var indexed = purchase + improvement;
    if (longTerm) {
      final purchaseCii = ciiValues[financialYear(state.purchaseDate)];
      final saleCii = ciiValues[financialYear(state.saleDate)];
      if (purchaseCii == null || saleCii == null) {
        state = state.copyWith(validationKey: 'capital_gains_index_unavailable');
        return;
      }
      indexed = (purchase + improvement) * saleCii / purchaseCii;
    }
    final gain = (sale - indexed).clamp(0.0, double.infinity);
    final unindexedGain = (sale - purchase - improvement).clamp(0.0, double.infinity);
    final indexedTax = gain * (longTerm ? .20 : .30);
    final unindexedTax = longTerm ? unindexedGain * .125 : gain * .30;
    if (![indexed, gain, indexedTax, unindexedTax].every((value) => value.isFinite)) {
      state = state.copyWith(validationKey: 'please_enter_valid_amounts');
      return;
    }
    state = state.copyWith(
      result: CapitalGainsResult(
        isLongTerm: longTerm,
        indexedCost: indexed,
        capitalGain: gain,
        taxWithIndexation: indexedTax,
        taxWithoutIndexation: unindexedTax,
      ),
    );
  }

  void clear() => state = CapitalGainsState.initial();
}
