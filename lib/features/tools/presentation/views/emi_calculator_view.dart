import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/paper_art.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/utils/indian_currency.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/features/profile/presentation/widgets/paper_parts.dart';
import 'package:ghar360/features/tools/presentation/controllers/emi_calculator_controller.dart';
import 'package:ghar360/features/tools/presentation/widgets/calculator_widgets.dart';

class EmiCalculatorView extends ConsumerStatefulWidget {
  const EmiCalculatorView({super.key});
  @override
  ConsumerState<EmiCalculatorView> createState() => _EmiCalculatorViewState();
}

class _EmiCalculatorViewState extends ConsumerState<EmiCalculatorView> {
  EmiCalculatorController get controller => ref.read(emiCalculatorProvider.notifier);
  EmiCalculatorState get state => ref.read(emiCalculatorProvider);
  late final TextEditingController _principal;
  late final TextEditingController _rate;
  late final TextEditingController _tenure;

  @override
  void initState() {
    super.initState();
    _principal = TextEditingController(text: state.principal)..addListener(_syncInputs);
    _rate = TextEditingController(text: state.rate)..addListener(_syncInputs);
    _tenure = TextEditingController(text: state.tenure)..addListener(_syncInputs);
  }

  void _syncInputs() =>
      controller.updateInputs(principal: _principal.text, rate: _rate.text, tenure: _tenure.text);
  void _clear() {
    _principal.clear();
    _rate.clear();
    _tenure.clear();
    controller.clear();
  }

  @override
  void dispose() {
    _principal.dispose();
    _rate.dispose();
    _tenure.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(emiCalculatorProvider);
    final l10n = context.l10n;
    final lang = l10n.locale.languageCode;
    String? fieldError(String field) => state.validationField == field
        ? l10n.text(state.validationKey!, params: const {'years': '50'})
        : null;
    return CalculatorScaffold(
      screenKey: 'qa.tools.emi.screen',
      title: l10n.text('emi_calculator'),
      onReset: _clear,
      inputs: [
        CalculatorTextField(
          label: l10n.text('loan_amount'),
          controller: _principal,
          errorText: fieldError('principal'),
          prefix: '₹',
        ),
        const SizedBox(height: 16),
        CalculatorTextField(
          label: l10n.text('interest_rate'),
          controller: _rate,
          errorText: fieldError('rate'),
          suffix: '%',
          hint: l10n.text('annual_rate'),
        ),
        const SizedBox(height: 16),
        CalculatorTextField(
          label: l10n.text('tenure'),
          controller: _tenure,
          errorText: fieldError('tenure'),
          keyboardType: TextInputType.number,
          inputFormatters: [LengthLimitingTextInputFormatter(3)],
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: true, label: Text(l10n.text('years'))),
            ButtonSegment(value: false, label: Text(l10n.text('months'))),
          ],
          selected: {state.tenureInYears},
          showSelectedIcon: false,
          onSelectionChanged: (_) => controller.toggleTenureUnit(),
          // The chosen unit sits on a quiet slip; the outline is the field outline.
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: context.design.slip,
            selectedForegroundColor: context.design.textPrimary,
            foregroundColor: context.design.textSecondary,
            side: BorderSide(color: context.design.fieldBorder),
            // Not the default stadium: a pill is not this system's shape.
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.input),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Semantics(
          identifier: 'qa.tools.emi.calculate',
          child: FilledButton(
            key: const ValueKey('qa.tools.emi.calculate'),
            onPressed: controller.calculate,
            child: Text(l10n.text('calculate')),
          ),
        ),
        if (state.validationKey != null && state.validationField == null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ErrorStates.inlineError(
              message: l10n.text(state.validationKey!, params: const {'years': '50'}),
            ),
          ),
      ],
      result: state.hasCalculated
          ? [
              CalculatorSectionTitle(l10n.text('emi_result')),
              const SizedBox(height: 14),
              CalculatorHeadline(
                label: l10n.text('monthly_emi'),
                value: state.monthlyEmi,
                format: (value) => IndianCurrency.compact(value, languageCode: lang),
                valueKey: const ValueKey('qa.tools.emi.monthly'),
              ),
              const SizedBox(height: 14),
              CalculatorResultRow(
                l10n.text('total_interest'),
                IndianCurrency.compact(state.totalInterest, languageCode: lang),
              ),
              CalculatorResultRow(
                l10n.text('total_payment'),
                IndianCurrency.compact(state.totalPayment, languageCode: lang),
              ),
              const SizedBox(height: 20),
              _buildBreakdownChart(),
            ]
          : null,
    );
  }

  /// Principal against interest as one bar. The shares are written in the
  /// legend, not on the bar, so they stay legible in both themes.
  Widget _buildBreakdownChart() {
    final principal = double.tryParse(_principal.text) ?? 0;
    final interest = state.totalInterest;
    final total = principal + interest;
    if (total == 0) return const SizedBox.shrink();

    final principalPercent = principal / total * 100;
    final interestPercent = interest / total * 100;
    final design = context.design;
    final l10n = context.l10n;
    // Principal is the teal of the app; interest the sandstone card stock
    // (a pale paper at night, where the sandstone is too dark to read).
    final interestTone = design.tone(design.isDark ? PaperTone.highlight : PaperTone.mid);

    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CalculatorLabel(l10n.text('breakdown')),
          const SizedBox(height: 10),
          // Principal fills the cut strip from the start; interest is the rest.
          CutStrip(
            value: principal / total,
            seed: 'emi-breakdown',
            color: design.accent,
            track: interestTone,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 20,
            runSpacing: 6,
            children: [
              _buildLegendItem(
                design.accent,
                l10n.text('principal'),
                '${principalPercent.toStringAsFixed(0)}%',
              ),
              _buildLegendItem(
                interestTone,
                l10n.text('interest'),
                '${interestPercent.toStringAsFixed(0)}%',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, String share) {
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 10,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppBorderRadius.xs / 2),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(label, style: text.bodyMedium?.copyWith(color: context.design.textSecondary)),
        ),
        const SizedBox(width: 6),
        Text(share, style: text.titleSmall),
      ],
    );
  }
}
