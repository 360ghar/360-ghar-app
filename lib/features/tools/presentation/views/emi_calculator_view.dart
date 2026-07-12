import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/app_design_tokens.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/features/tools/presentation/controllers/emi_calculator_controller.dart';

class EmiCalculatorView extends GetView<EmiCalculatorController> {
  const EmiCalculatorView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('qa.tools.emi.screen'),
      backgroundColor: AppDesign.background,
      appBar: AppBar(
        backgroundColor: AppDesign.appBarBackground,
        elevation: 0,
        title: Text(
          'emi_calculator'.tr,
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
                    _buildTextField(
                      label: 'loan_amount'.tr,
                      controller: controller.principalController,
                      prefix: '₹',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'interest_rate'.tr,
                      controller: controller.rateController,
                      suffix: '%',
                      hint: 'annual_rate'.tr,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            label: 'tenure'.tr,
                            controller: controller.tenureController,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Obx(
                          () => Column(
                            children: [
                              const SizedBox(height: 24),
                              SegmentedButton<bool>(
                                segments: [
                                  ButtonSegment(value: true, label: Text('years'.tr)),
                                  ButtonSegment(value: false, label: Text('months'.tr)),
                                ],
                                selected: {controller.tenureInYears.value},
                                onSelectionChanged: (value) {
                                  controller.toggleTenureUnit();
                                },
                                style: ButtonStyle(
                                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return AppDesign.primaryYellow;
                                    }
                                    return AppDesign.inputBackground;
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: Semantics(
                label: 'qa.tools.emi.calculate',
                identifier: 'qa.tools.emi.calculate',
                child: FilledButton(
                  key: const ValueKey('qa.tools.emi.calculate'),
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
                        'emi_result'.tr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppDesign.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'monthly_emi'.tr,
                              style: TextStyle(fontSize: 14, color: AppDesign.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '₹${_formatCurrency(controller.monthlyEmi.value)}',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppDesign.primaryYellow,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      _buildResultRow(
                        'total_interest'.tr,
                        '₹${_formatCurrency(controller.totalInterest.value)}',
                      ),
                      const SizedBox(height: 12),
                      _buildResultRow(
                        'total_payment'.tr,
                        '₹${_formatCurrency(controller.totalPayment.value)}',
                      ),
                      const SizedBox(height: 16),
                      _buildBreakdownChart(),
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

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? prefix,
    String? suffix,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppDesign.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType ?? const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: AppDesign.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppDesign.textTertiary),
            prefixText: prefix,
            prefixStyle: TextStyle(color: AppDesign.textPrimary),
            suffixText: suffix,
            suffixStyle: TextStyle(color: AppDesign.textSecondary),
            filled: true,
            fillColor: AppDesign.inputBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: AppDesign.textSecondary)),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppDesign.textPrimary),
        ),
      ],
    );
  }

  Widget _buildBreakdownChart() {
    final principal = double.tryParse(controller.principalController.text) ?? 0;
    final interest = controller.totalInterest.value;
    final total = principal + interest;
    if (total == 0) return const SizedBox.shrink();

    final principalPercent = (principal / total * 100);
    final interestPercent = (interest / total * 100);
    final principalFlex = principalPercent.round().clamp(1, 99);
    final interestFlex = interestPercent.round().clamp(1, 99);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'breakdown'.tr,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppDesign.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              Expanded(
                flex: principalFlex,
                child: Container(
                  height: 24,
                  color: AppDesign.accentGreen,
                  alignment: Alignment.center,
                  child: Text(
                    '${principalPercent.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: AppDesignTokens.neutralWhite,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: interestFlex,
                child: Container(
                  height: 24,
                  color: AppDesign.accentOrange,
                  alignment: Alignment.center,
                  child: Text(
                    '${interestPercent.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: AppDesignTokens.neutralWhite,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildLegendItem(AppDesign.accentGreen, 'principal'.tr),
            const SizedBox(width: 16),
            _buildLegendItem(AppDesign.accentOrange, 'interest'.tr),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: AppDesign.textSecondary)),
      ],
    );
  }

  String _formatCurrency(double value) {
    if (value >= 10000000) {
      return '${(value / 10000000).toStringAsFixed(2)} Cr';
    } else if (value >= 100000) {
      return '${(value / 100000).toStringAsFixed(2)} L';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }
}
