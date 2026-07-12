import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/features/tools/presentation/controllers/loan_eligibility_controller.dart';

class LoanEligibilityView extends GetView<LoanEligibilityController> {
  const LoanEligibilityView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('qa.tools.loan_eligibility.screen'),
      backgroundColor: AppDesign.background,
      appBar: AppBar(
        backgroundColor: AppDesign.appBarBackground,
        elevation: 0,
        title: Text(
          'loan_eligibility'.tr,
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
                      label: 'monthly_income'.tr,
                      controller: controller.incomeController,
                      prefix: '₹',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'your_age'.tr,
                      controller: controller.ageController,
                      suffix: 'years'.tr,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'existing_emi'.tr,
                      controller: controller.existingEmiController,
                      prefix: '₹',
                      hint: 'optional'.tr,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'credit_score'.tr,
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
                            value: controller.creditScore.value,
                            min: 300,
                            max: 900,
                            divisions: 60,
                            activeColor: AppDesign.primaryYellow,
                            inactiveColor: AppDesign.inputBackground,
                            label: controller.creditScore.value.toInt().toString(),
                            onChanged: (value) => controller.creditScore.value = value,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '300',
                                style: TextStyle(fontSize: 12, color: AppDesign.textTertiary),
                              ),
                              Text(
                                controller.creditScore.value.toInt().toString(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppDesign.primaryYellow,
                                ),
                              ),
                              Text(
                                '900',
                                style: TextStyle(fontSize: 12, color: AppDesign.textTertiary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'interest_rate'.tr,
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
                            value: controller.interestRate.value,
                            min: 6.0,
                            max: 15.0,
                            divisions: 90,
                            activeColor: AppDesign.primaryYellow,
                            inactiveColor: AppDesign.inputBackground,
                            label: '${controller.interestRate.value.toStringAsFixed(1)}%',
                            onChanged: (value) => controller.interestRate.value = value,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '6%',
                                style: TextStyle(fontSize: 12, color: AppDesign.textTertiary),
                              ),
                              Text(
                                '${controller.interestRate.value.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppDesign.primaryYellow,
                                ),
                              ),
                              Text(
                                '15%',
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
                label: 'qa.tools.loan_eligibility.calculate',
                identifier: 'qa.tools.loan_eligibility.calculate',
                child: FilledButton(
                  key: const ValueKey('qa.tools.loan_eligibility.calculate'),
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
                        'eligibility_result'.tr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppDesign.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildResultRow(
                        'max_loan_amount'.tr,
                        '₹${_formatCurrency(controller.maxLoanAmount.value)}',
                        isHighlight: true,
                      ),
                      const Divider(height: 24),
                      _buildResultRow(
                        'eligible_emi'.tr,
                        '₹${_formatCurrency(controller.eligibleEmi.value)}/mo',
                      ),
                      const SizedBox(height: 8),
                      _buildResultRow(
                        'max_tenure'.tr,
                        '${controller.maxTenure.value} ${'years'.tr}',
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppDesign.accentBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: AppDesign.accentBlue, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'loan_eligibility_note'.tr,
                                style: const TextStyle(fontSize: 12, color: AppDesign.accentBlue),
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

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? prefix,
    String? suffix,
    String? hint,
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
          keyboardType: TextInputType.number,
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

  Widget _buildResultRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: AppDesign.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 20 : 16,
            fontWeight: FontWeight.w600,
            color: isHighlight ? AppDesign.primaryYellow : AppDesign.textPrimary,
          ),
        ),
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
