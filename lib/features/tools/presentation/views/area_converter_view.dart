import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/features/tools/presentation/controllers/area_converter_controller.dart';

class AreaConverterView extends GetView<AreaConverterController> {
  const AreaConverterView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('qa.tools.area_converter.screen'),
      backgroundColor: AppDesign.background,
      appBar: AppBar(
        backgroundColor: AppDesign.appBarBackground,
        elevation: 0,
        title: Text(
          'area_converter'.tr,
          style: TextStyle(color: AppDesign.appBarText, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          tooltip: 'back'.tr,
          icon: Icon(Icons.arrow_back, color: AppDesign.iconColor),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppDesign.iconColor),
            onPressed: controller.clear,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: AppDesign.cardBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'enter_area'.tr,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppDesign.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      label: 'qa.tools.area_converter.input',
                      identifier: 'qa.tools.area_converter.input',
                      child: TextField(
                        key: const ValueKey('qa.tools.area_converter.input'),
                        controller: controller.inputController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: AppDesign.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'enter_value'.tr,
                          hintStyle: TextStyle(color: AppDesign.textTertiary),
                          filled: true,
                          fillColor: AppDesign.inputBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (_) => controller.convert(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'select_unit'.tr,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppDesign.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Obx(
                      () => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AreaUnit.values.map((unit) {
                          final isSelected = controller.selectedUnit.value == unit;
                          return ChoiceChip(
                            label: Text(controller.getUnitLabel(unit)),
                            selected: isSelected,
                            onSelected: (_) => controller.onUnitChanged(unit),
                            selectedColor: AppDesign.primaryYellow,
                            backgroundColor: AppDesign.inputBackground,
                            labelStyle: TextStyle(
                              color: isSelected ? AppDesign.buttonText : AppDesign.textPrimary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Obx(() {
              if (controller.conversions.isEmpty) {
                return const SizedBox.shrink();
              }
              return Card(
                color: AppDesign.cardBackground,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'conversions'.tr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppDesign.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...AreaUnit.values.map((unit) {
                        final value = controller.conversions[unit] ?? 0;
                        final isCurrentUnit = controller.selectedUnit.value == unit;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                controller.getUnitLabel(unit),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isCurrentUnit
                                      ? AppDesign.primaryYellow
                                      : AppDesign.textSecondary,
                                  fontWeight: isCurrentUnit ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                              Text(
                                _formatNumber(value),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isCurrentUnit
                                      ? AppDesign.primaryYellow
                                      : AppDesign.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(2)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(2)}K';
    } else if (value >= 1) {
      return value.toStringAsFixed(2);
    } else {
      return value.toStringAsFixed(4);
    }
  }
}
