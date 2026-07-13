// test/features/tools/presentation/bindings/tools_binding_test.dart
//
// Binding tests for the tools feature bindings defined in `tools_binding.dart`:
// [ToolsBinding], [AreaConverterBinding], [LoanEligibilityBinding],
// [EmiCalculatorBinding], [CarpetAreaBinding], [DocumentChecklistBinding], and
// [CapitalGainsBinding]. Each registers a single controller lazily; these
// tests verify the expected controller type is present in the GetX container
// after `dependencies()` runs.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/features/tools/presentation/bindings/tools_binding.dart';
import 'package:ghar360/features/tools/presentation/controllers/area_converter_controller.dart';
import 'package:ghar360/features/tools/presentation/controllers/capital_gains_controller.dart';
import 'package:ghar360/features/tools/presentation/controllers/carpet_area_controller.dart';
import 'package:ghar360/features/tools/presentation/controllers/document_checklist_controller.dart';
import 'package:ghar360/features/tools/presentation/controllers/emi_calculator_controller.dart';
import 'package:ghar360/features/tools/presentation/controllers/loan_eligibility_controller.dart';
import 'package:ghar360/features/tools/presentation/controllers/tools_controller.dart';
import '../../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() => GetxTestBinding.init());
  tearDown(() => GetxTestBinding.reset());

  test('ToolsBinding registers ToolsController', () {
    ToolsBinding().dependencies();
    expect(Get.isRegistered<ToolsController>(), isTrue);
  });

  test('AreaConverterBinding registers AreaConverterController', () {
    AreaConverterBinding().dependencies();
    expect(Get.isRegistered<AreaConverterController>(), isTrue);
  });

  test('LoanEligibilityBinding registers LoanEligibilityController', () {
    LoanEligibilityBinding().dependencies();
    expect(Get.isRegistered<LoanEligibilityController>(), isTrue);
  });

  test('EmiCalculatorBinding registers EmiCalculatorController', () {
    EmiCalculatorBinding().dependencies();
    expect(Get.isRegistered<EmiCalculatorController>(), isTrue);
  });

  test('CarpetAreaBinding registers CarpetAreaController', () {
    CarpetAreaBinding().dependencies();
    expect(Get.isRegistered<CarpetAreaController>(), isTrue);
  });

  test('DocumentChecklistBinding registers DocumentChecklistController', () {
    DocumentChecklistBinding().dependencies();
    expect(Get.isRegistered<DocumentChecklistController>(), isTrue);
  });

  test('CapitalGainsBinding registers CapitalGainsController', () {
    CapitalGainsBinding().dependencies();
    expect(Get.isRegistered<CapitalGainsController>(), isTrue);
  });
}
