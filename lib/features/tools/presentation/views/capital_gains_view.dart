import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/api_date_time.dart';
import 'package:ghar360/core/utils/indian_currency.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/features/tools/presentation/controllers/capital_gains_controller.dart';

class CapitalGainsView extends GetView<CapitalGainsController> {
  const CapitalGainsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('qa.tools.capital_gains.screen'),
      backgroundColor: AppDesign.background,
      appBar: AppBar(
        backgroundColor: AppDesign.appBarBackground,
        elevation: 0,
        title: Text(
          'capital_gains'.tr,
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
                color: AppDesign.warningAmber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppDesign.warningAmber, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'capital_gains_disclaimer'.tr,
                      style: TextStyle(fontSize: 12, color: AppDesign.textSecondary),
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
                      'purchase_details'.tr,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppDesign.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'purchase_price'.tr,
                      controller: controller.purchasePriceController,
                      prefix: '₹',
                    ),
                    const SizedBox(height: 16),
                    _buildDateField(
                      context: context,
                      label: 'purchase_date'.tr,
                      fieldKey: 'qa.tools.capital_gains.purchase_date',
                      value: controller.purchaseDate,
                      onPicked: controller.setPurchaseDate,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'improvement_cost'.tr,
                      controller: controller.improvementCostController,
                      prefix: '₹',
                      hint: 'optional'.tr,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: AppDesign.cardBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'sale_details'.tr,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppDesign.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'sale_price'.tr,
                      controller: controller.salePriceController,
                      prefix: '₹',
                    ),
                    const SizedBox(height: 16),
                    _buildDateField(
                      context: context,
                      label: 'sale_date'.tr,
                      fieldKey: 'qa.tools.capital_gains.sale_date',
                      value: controller.saleDate,
                      onPicked: controller.setSaleDate,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Obx(() {
              if (controller.validationError.value.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ErrorStates.inlineError(message: controller.validationError.value),
              );
            }),
            SizedBox(
              width: double.infinity,
              child: Semantics(
                label: 'qa.tools.capital_gains.calculate',
                identifier: 'qa.tools.capital_gains.calculate',
                child: FilledButton(
                  key: const ValueKey('qa.tools.capital_gains.calculate'),
                  onPressed: controller.calculate,
                  child: Text('calculate_tax'.tr),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Obx(() {
              if (!controller.hasCalculated.value) {
                return const SizedBox.shrink();
              }
              return _buildResults();
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

  /// A tap target styled exactly like the number inputs above it, opening
  /// Flutter's built-in [showDatePicker].
  Widget _buildDateField({
    required BuildContext context,
    required String label,
    required String fieldKey,
    required Rx<DateTime> value,
    required ValueChanged<DateTime> onPicked,
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
        Obx(
          () => InkWell(
            key: ValueKey(fieldKey),
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: value.value,
                firstDate: CapitalGainsController.firstSelectableDate,
                lastDate: CapitalGainsController.lastSelectableDate,
              );
              if (picked != null) {
                onPicked(picked);
              }
            },
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppDesign.inputBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      formatDisplayDate(value.value),
                      style: TextStyle(color: AppDesign.textPrimary, fontSize: 16),
                    ),
                  ),
                  Icon(Icons.calendar_today_outlined, size: 18, color: AppDesign.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResults() {
    return Card(
      color: AppDesign.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'tax_calculation'.tr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppDesign.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: controller.isLongTerm.value
                        ? AppDesign.successGreen.withValues(alpha: 0.1)
                        : AppDesign.accentOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    controller.isLongTerm.value ? 'long_term'.tr : 'short_term'.tr,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: controller.isLongTerm.value
                          ? AppDesign.successGreen
                          : AppDesign.accentOrange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildResultRow(
              'indexed_cost'.tr,
              IndianCurrency.compact(controller.indexedCost.value),
            ),
            const SizedBox(height: 8),
            _buildResultRow(
              'capital_gain_amount'.tr,
              IndianCurrency.compact(controller.capitalGain.value),
            ),
            const Divider(height: 24),
            if (controller.isLongTerm.value) ...[
              Text(
                'tax_options'.tr,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppDesign.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              _buildTaxOption(
                'with_indexation'.tr,
                '20%',
                controller.taxWithIndexation.value,
                controller.taxWithIndexation.value <= controller.taxWithoutIndexation.value,
              ),
              const SizedBox(height: 8),
              _buildTaxOption(
                'without_indexation'.tr,
                '12.5%',
                controller.taxWithoutIndexation.value,
                controller.taxWithoutIndexation.value < controller.taxWithIndexation.value,
              ),
            ] else ...[
              _buildResultRow(
                'estimated_tax'.tr,
                IndianCurrency.compact(controller.taxWithIndexation.value),
                isHighlight: true,
              ),
              const SizedBox(height: 8),
              Text(
                'short_term_tax_note'.tr,
                style: TextStyle(fontSize: 12, color: AppDesign.textTertiary),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppDesign.accentBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'exemptions_available'.tr,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppDesign.accentBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'section_54_info'.tr,
                    style: TextStyle(fontSize: 12, color: AppDesign.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
            color: AppDesign.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildTaxOption(String label, String rate, double amount, bool isRecommended) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isRecommended ? AppDesign.successGreen : AppDesign.border,
          width: isRecommended ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppDesign.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('($rate)', style: TextStyle(fontSize: 12, color: AppDesign.textTertiary)),
                  ],
                ),
                if (isRecommended)
                  Text(
                    'recommended'.tr,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppDesign.successGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            IndianCurrency.compact(amount),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isRecommended ? AppDesign.successGreen : AppDesign.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
