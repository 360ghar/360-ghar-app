import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';

/// Shared input field for the tools calculators (EMI, loan eligibility,
/// capital gains). Label above a filled numeric TextField.
class CalculatorTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? prefix;
  final String? suffix;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const CalculatorTextField({
    super.key,
    required this.label,
    required this.controller,
    this.prefix,
    this.suffix,
    this.hint,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
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
          inputFormatters: inputFormatters,
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
}

/// Label/value result row; [isHighlight] renders the value larger in brand
/// yellow (used for the headline result of a calculator).
class CalculatorResultRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;

  const CalculatorResultRow(this.label, this.value, {super.key, this.isHighlight = false});

  @override
  Widget build(BuildContext context) {
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
}
