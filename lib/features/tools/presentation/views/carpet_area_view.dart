import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/features/tools/presentation/controllers/carpet_area_controller.dart';

class CarpetAreaView extends GetView<CarpetAreaController> {
  const CarpetAreaView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('qa.tools.carpet_area.screen'),
      backgroundColor: AppDesign.background,
      appBar: AppBar(
        backgroundColor: AppDesign.appBarBackground,
        elevation: 0,
        title: Text(
          'carpet_area_calculator'.tr,
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppDesign.accentBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppDesign.accentBlue, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'carpet_area_info'.tr,
                      style: const TextStyle(fontSize: 13, color: AppDesign.accentBlue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Card(
              color: AppDesign.cardBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'super_built_up_area'.tr,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppDesign.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller.superBuiltUpController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: AppDesign.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'enter_area_sqft'.tr,
                        hintStyle: TextStyle(color: AppDesign.textTertiary),
                        suffixText: 'sq_ft'.tr,
                        suffixStyle: TextStyle(color: AppDesign.textSecondary),
                        filled: true,
                        fillColor: AppDesign.inputBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'loading_percentage'.tr,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppDesign.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Obx(
                      () => Column(
                        children: [
                          Slider(
                            value: controller.loadingPercentage.value,
                            min: 15,
                            max: 40,
                            divisions: 25,
                            activeColor: AppDesign.primaryYellow,
                            inactiveColor: AppDesign.inputBackground,
                            label: '${controller.loadingPercentage.value.toInt()}%',
                            onChanged: controller.onLoadingChanged,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '15%',
                                style: TextStyle(fontSize: 12, color: AppDesign.textTertiary),
                              ),
                              Text(
                                '${controller.loadingPercentage.value.toInt()}%',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppDesign.primaryYellow,
                                ),
                              ),
                              Text(
                                '40%',
                                style: TextStyle(fontSize: 12, color: AppDesign.textTertiary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: Semantics(
                label: 'qa.tools.carpet_area.calculate',
                identifier: 'qa.tools.carpet_area.calculate',
                child: FilledButton(
                  key: const ValueKey('qa.tools.carpet_area.calculate'),
                  onPressed: controller.calculate,
                  child: Text('calculate'.tr),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Obx(() {
              if (controller.validationError.value.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ErrorStates.inlineError(message: controller.validationError.value),
              );
            }),
            Obx(() {
              if (!controller.hasCalculated.value) {
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
                        'area_breakdown'.tr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppDesign.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildAreaCard(
                        'carpet_area'.tr,
                        controller.carpetArea.value,
                        AppDesign.accentGreen,
                        'actual_usable_space'.tr,
                      ),
                      const SizedBox(height: 12),
                      _buildAreaCard(
                        'built_up_area'.tr,
                        controller.builtUpArea.value,
                        AppDesign.accentBlue,
                        'carpet_plus_walls'.tr,
                      ),
                      const SizedBox(height: 12),
                      _buildAreaCard(
                        'super_built_up'.tr,
                        double.tryParse(controller.superBuiltUpController.text) ?? 0,
                        AppDesign.accentOrange,
                        'includes_common_areas'.tr,
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppDesign.primaryYellow.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.pie_chart, color: AppDesign.primaryYellow, size: 32),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'usable_area'.tr,
                                    style: TextStyle(fontSize: 14, color: AppDesign.textSecondary),
                                  ),
                                  Text(
                                    '${controller.usablePercentage.value.toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppDesign.primaryYellow,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildAreaCard(String title, double value, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13, color: AppDesign.textSecondary)),
                Text(subtitle, style: TextStyle(fontSize: 11, color: AppDesign.textTertiary)),
              ],
            ),
          ),
          Text(
            '${value.toStringAsFixed(0)} ${'sq_ft'.tr}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
