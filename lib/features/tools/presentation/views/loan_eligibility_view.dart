import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/indian_currency.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/features/tools/presentation/controllers/loan_eligibility_controller.dart';
import 'package:ghar360/features/tools/presentation/widgets/calculator_widgets.dart';

class LoanEligibilityView extends ConsumerStatefulWidget {
  const LoanEligibilityView({super.key});
  @override
  ConsumerState<LoanEligibilityView> createState() => _LoanEligibilityViewState();
}

class _LoanEligibilityViewState extends ConsumerState<LoanEligibilityView> {
  LoanEligibilityController get controller => ref.read(loanEligibilityProvider.notifier);
  LoanEligibilityState get state => ref.read(loanEligibilityProvider);
  late final TextEditingController _income;
  late final TextEditingController _age;
  late final TextEditingController _existingEmi;

  @override
  void initState() {
    super.initState();
    _income = TextEditingController(text: state.income)..addListener(_syncInputs);
    _age = TextEditingController(text: state.age)..addListener(_syncInputs);
    _existingEmi = TextEditingController(text: state.existingEmi)..addListener(_syncInputs);
  }

  void _syncInputs() =>
      controller.updateInputs(income: _income.text, age: _age.text, existingEmi: _existingEmi.text);
  void _clear() {
    _income.clear();
    _age.clear();
    _existingEmi.clear();
    controller.clear();
  }

  @override
  void dispose() {
    _income.dispose();
    _age.dispose();
    _existingEmi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(loanEligibilityProvider);
    final l10n = context.l10n;
    final lang = l10n.locale.languageCode;
    String? fieldError(String field) => state.validationField == field
        ? l10n.text(state.validationKey!, params: const {'years': '50'})
        : null;
    return CalculatorScaffold(
      screenKey: 'qa.tools.loan_eligibility.screen',
      title: l10n.text('loan_eligibility'),
      onReset: _clear,
      inputs: [
        CalculatorTextField(
          label: l10n.text('monthly_income'),
          controller: _income,
          errorText: fieldError('income'),
          prefix: '₹',
        ),
        const SizedBox(height: 16),
        CalculatorTextField(
          label: l10n.text('your_age'),
          controller: _age,
          errorText: fieldError('age'),
          suffix: l10n.text('years'),
        ),
        const SizedBox(height: 16),
        CalculatorTextField(
          label: l10n.text('existing_emi'),
          controller: _existingEmi,
          errorText: fieldError('existingEmi'),
          prefix: '₹',
          hint: l10n.text('optional'),
        ),
        const SizedBox(height: 24),
        CalculatorSlider(
          label: l10n.text('credit_score'),
          value: state.creditScore,
          min: 300,
          max: 900,
          divisions: 60,
          format: (value) => value.toInt().toString(),
          onChanged: controller.setCreditScore,
        ),
        const SizedBox(height: 16),
        CalculatorSlider(
          label: l10n.text('interest_rate'),
          value: state.interestRate,
          min: 6.0,
          max: 15.0,
          divisions: 90,
          format: (value) => '${value.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}%',
          onChanged: controller.setInterestRate,
        ),
        const SizedBox(height: 24),
        Semantics(
          identifier: 'qa.tools.loan_eligibility.calculate',
          child: FilledButton(
            key: const ValueKey('qa.tools.loan_eligibility.calculate'),
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
              CalculatorSectionTitle(l10n.text('eligibility_result')),
              const SizedBox(height: 14),
              CalculatorHeadline(
                label: l10n.text('max_loan_amount'),
                value: state.maxLoanAmount,
                format: (value) => IndianCurrency.compact(value, languageCode: lang),
                valueKey: const ValueKey('qa.tools.loan_eligibility.max_loan'),
              ),
              const SizedBox(height: 14),
              CalculatorResultRow(
                l10n.text('eligible_emi'),
                '${IndianCurrency.compact(state.eligibleEmi, languageCode: lang)}/mo',
              ),
              CalculatorResultRow(
                l10n.text('max_tenure'),
                '${state.maxTenure} ${l10n.text('years')}',
              ),
              const SizedBox(height: 16),
              CalculatorNote(l10n.text('loan_eligibility_note')),
            ]
          : null,
    );
  }
}
