import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/api_date_time.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/utils/indian_currency.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/features/tools/presentation/controllers/capital_gains_controller.dart';
import 'package:ghar360/features/tools/presentation/widgets/calculator_widgets.dart';

class CapitalGainsView extends ConsumerStatefulWidget {
  const CapitalGainsView({super.key});
  @override
  ConsumerState<CapitalGainsView> createState() => _CapitalGainsViewState();
}

class _CapitalGainsViewState extends ConsumerState<CapitalGainsView> {
  CapitalGainsController get controller => ref.read(capitalGainsProvider.notifier);
  CapitalGainsState get state => ref.read(capitalGainsProvider);
  late final TextEditingController _purchasePrice;
  late final TextEditingController _salePrice;
  late final TextEditingController _improvementCost;

  @override
  void initState() {
    super.initState();
    _purchasePrice = TextEditingController(text: state.purchasePrice)..addListener(_syncInputs);
    _salePrice = TextEditingController(text: state.salePrice)..addListener(_syncInputs);
    _improvementCost = TextEditingController(text: state.improvementCost)..addListener(_syncInputs);
  }

  void _syncInputs() => controller.updateInputs(
    purchasePrice: _purchasePrice.text,
    salePrice: _salePrice.text,
    improvementCost: _improvementCost.text,
  );
  void _clear() {
    _purchasePrice.clear();
    _salePrice.clear();
    _improvementCost.clear();
    controller.clear();
  }

  @override
  void dispose() {
    _purchasePrice.dispose();
    _salePrice.dispose();
    _improvementCost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(capitalGainsProvider);
    final l10n = context.l10n;
    String? fieldError(String field) => state.validationField == field
        ? l10n.text(state.validationKey!, params: const {'years': '50'})
        : null;
    return CalculatorScaffold(
      screenKey: 'qa.tools.capital_gains.screen',
      title: l10n.text('capital_gains'),
      onReset: _clear,
      inputs: [
        CalculatorNote(
          '${l10n.text('capital_gains_disclaimer')}\n\n${l10n.text('capital_gains_assumptions')}',
        ),
        const SizedBox(height: 28),
        CalculatorSectionTitle(l10n.text('purchase_details')),
        const SizedBox(height: 16),
        CalculatorTextField(
          label: l10n.text('purchase_price'),
          controller: _purchasePrice,
          errorText: fieldError('purchasePrice'),
          prefix: '₹',
        ),
        const SizedBox(height: 16),
        _buildDateField(
          context: context,
          label: l10n.text('purchase_date'),
          fieldKey: 'qa.tools.capital_gains.purchase_date',
          value: state.purchaseDate,
          onPicked: controller.setPurchaseDate,
        ),
        const SizedBox(height: 16),
        CalculatorTextField(
          label: l10n.text('improvement_cost'),
          controller: _improvementCost,
          errorText: fieldError('improvementCost'),
          prefix: '₹',
          hint: l10n.text('optional'),
        ),
        const SizedBox(height: 28),
        CalculatorSectionTitle(l10n.text('sale_details')),
        const SizedBox(height: 16),
        CalculatorTextField(
          label: l10n.text('sale_price'),
          controller: _salePrice,
          errorText: fieldError('salePrice'),
          prefix: '₹',
        ),
        const SizedBox(height: 16),
        _buildDateField(
          context: context,
          label: l10n.text('sale_date'),
          fieldKey: 'qa.tools.capital_gains.sale_date',
          value: state.saleDate,
          onPicked: controller.setSaleDate,
        ),
        if (state.validationKey != null && state.validationField == null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: ErrorStates.inlineError(
              message: l10n.text(state.validationKey!, params: const {'years': '50'}),
            ),
          ),
        const SizedBox(height: 24),
        Semantics(
          identifier: 'qa.tools.capital_gains.calculate',
          child: FilledButton(
            key: const ValueKey('qa.tools.capital_gains.calculate'),
            onPressed: controller.calculate,
            child: Text(l10n.text('calculate_tax')),
          ),
        ),
      ],
      result: state.hasCalculated ? [_buildResults()] : null,
    );
  }

  /// A tap target drawn as a themed field, opening Flutter's [showDatePicker].
  Widget _buildDateField({
    required BuildContext context,
    required String label,
    required String fieldKey,
    required DateTime value,
    required ValueChanged<DateTime> onPicked,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CalculatorLabel(label),
        const SizedBox(height: 8),
        Builder(
          builder: (context) => InkWell(
            key: ValueKey(fieldKey),
            borderRadius: BorderRadius.circular(AppBorderRadius.input),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: value,
                firstDate: CapitalGainsController.firstSelectableDate,
                lastDate: CapitalGainsController.lastSelectableDate,
              );
              if (picked != null && context.mounted) {
                onPicked(picked);
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                suffixIcon: PaperIcon(
                  KnifeIcon.calendar,
                  size: 20,
                  color: context.design.textSecondary,
                ),
              ),
              child: Text(
                formatDisplayDate(value),
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: context.design.textPrimary),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResults() {
    final l10n = context.l10n;
    final lang = l10n.locale.languageCode;
    final design = context.design;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CalculatorSectionTitle(l10n.text('tax_calculation')),
        const SizedBox(height: 4),
        Text(
          l10n.text(state.isLongTerm ? 'long_term' : 'short_term'),
          key: const ValueKey('qa.tools.capital_gains.term'),
          style: text.labelLarge?.copyWith(
            color: state.isLongTerm ? design.success : design.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        CalculatorHeadline(
          label: l10n.text('capital_gain_amount'),
          value: state.capitalGain,
          format: (value) => IndianCurrency.compact(value, languageCode: lang),
        ),
        const SizedBox(height: 14),
        CalculatorResultRow(
          l10n.text('indexed_cost'),
          IndianCurrency.compact(state.indexedCost, languageCode: lang),
        ),
        const SizedBox(height: 20),
        if (state.isLongTerm) ...[
          CalculatorLabel(l10n.text('tax_options')),
          const SizedBox(height: 4),
          _buildTaxOption(
            l10n.text('with_indexation'),
            '20%',
            state.taxWithIndexation,
            state.taxWithIndexation <= state.taxWithoutIndexation,
            'qa.tools.capital_gains.tax_with_indexation',
          ),
          _buildTaxOption(
            l10n.text('without_indexation'),
            '12.5%',
            state.taxWithoutIndexation,
            state.taxWithoutIndexation < state.taxWithIndexation,
            'qa.tools.capital_gains.tax_without_indexation',
          ),
        ] else ...[
          CalculatorResultRow(
            l10n.text('estimated_tax'),
            IndianCurrency.compact(state.taxWithIndexation, languageCode: lang),
            isHighlight: true,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.text('short_term_tax_note'),
            style: text.bodySmall?.copyWith(color: design.textSecondary),
          ),
        ],
        const SizedBox(height: 24),
        Text(l10n.text('exemptions_available'), style: text.titleMedium),
        const SizedBox(height: 6),
        Text(
          l10n.text('section_54_info'),
          style: text.bodyMedium?.copyWith(color: design.textSecondary),
        ),
      ],
    );
  }

  /// One way to pay. The lower estimate is said in words and in the status
  /// colour, not with a box or a badge.
  Widget _buildTaxOption(
    String label,
    String rate,
    double amount,
    bool isRecommended,
    String qaKey,
  ) {
    final design = context.design;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.bodyLarge?.copyWith(color: design.textPrimary)),
                Text(rate, style: text.bodySmall?.copyWith(color: design.textSecondary)),
                if (isRecommended)
                  Text(
                    context.l10n.text('lower_estimate'),
                    key: ValueKey('$qaKey.lower'),
                    style: text.labelMedium?.copyWith(color: design.success),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              IndianCurrency.compact(amount, languageCode: context.l10n.locale.languageCode),
              key: ValueKey(qaKey),
              textAlign: TextAlign.end,
              style: text.headlineSmall?.copyWith(
                color: isRecommended ? design.success : design.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
