import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:ghar360/core/utils/formatters.dart';

enum AreaUnit { sqFt, sqM, sqYards, acres, gaj, bigha }

class AreaConverterController extends GetxController {
  final TextEditingController inputController = TextEditingController();
  final Rx<AreaUnit> selectedUnit = AreaUnit.sqFt.obs;
  final RxMap<AreaUnit, double> conversions = <AreaUnit, double>{}.obs;

  // Conversion factors to square feet (base unit)
  static const Map<AreaUnit, double> _toSqFt = {
    AreaUnit.sqFt: 1.0,
    AreaUnit.sqM: 10.7639,
    AreaUnit.sqYards: 9.0,
    AreaUnit.gaj: 9.0, // 1 gaj = 1 sq yard = 9 sq ft
    AreaUnit.acres: 43560.0,
    AreaUnit.bigha: 27000.0, // Standard bigha (varies by region, using common value)
  };

  String getUnitLabel(AreaUnit unit) {
    switch (unit) {
      case AreaUnit.sqFt:
        return 'sq_ft'.tr;
      case AreaUnit.sqM:
        return 'sq_m'.tr;
      case AreaUnit.sqYards:
        return 'sq_yards'.tr;
      case AreaUnit.acres:
        return 'acres'.tr;
      case AreaUnit.gaj:
        return 'gaj'.tr;
      case AreaUnit.bigha:
        return 'bigha'.tr;
    }
  }

  void onUnitChanged(AreaUnit? unit) {
    if (unit != null) {
      selectedUnit.value = unit;
      convert();
    }
  }

  void convert() {
    final input = double.tryParse(inputController.text) ?? 0;
    if (!Formatters.isPositiveFinite(input)) {
      conversions.clear();
      return;
    }

    // Convert input to square feet first
    final sqFt = input * _toSqFt[selectedUnit.value]!;

    // Convert to all units
    final Map<AreaUnit, double> results = {};
    for (final unit in AreaUnit.values) {
      results[unit] = sqFt / _toSqFt[unit]!;
    }
    conversions.value = results;
  }

  void clear() {
    inputController.clear();
    selectedUnit.value = AreaUnit.sqFt;
    conversions.clear();
  }

  @override
  void onClose() {
    inputController.dispose();
    super.onClose();
  }
}
