import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Formats rupee amounts the way Indian users actually read them.
///
/// Replaces the near-identical `_formatCurrency` helpers that were copied
/// across the calculators and the filter sheet. Those copies shared two bugs:
/// they fell back to a "K" suffix below a lakh (₹43,400 rendered as "43.4K",
/// which is not Indian numbering), and their "Cr"/"L" suffixes were hardcoded
/// English that never translated.
///
/// Thresholds follow normal usage: crore and lakh get the compact suffix,
/// anything smaller is written out in full with Indian digit grouping
/// (`2,50,000`, not `250,000`).
class IndianCurrency {
  const IndianCurrency._();

  static const int _crore = 10000000;
  static const int _lakh = 100000;

  static final NumberFormat _grouped = NumberFormat.decimalPattern('en_IN');

  /// A compact amount, e.g. `₹1.25 Cr`, `₹2.50 L`, `₹43,400`.
  ///
  /// [fractionDigits] applies only to the crore/lakh forms; whole rupee
  /// amounts below a lakh are never shown with decimals.
  static String compact(num value, {int fractionDigits = 2, bool withSymbol = true}) {
    final symbol = withSymbol ? '₹' : '';
    final magnitude = value.abs();
    final sign = value < 0 ? '-' : '';

    if (magnitude >= _crore) {
      final amount = (magnitude / _crore).toStringAsFixed(fractionDigits);
      return '$sign$symbol$amount ${'unit_crore'.tr}';
    }
    if (magnitude >= _lakh) {
      final amount = (magnitude / _lakh).toStringAsFixed(fractionDigits);
      return '$sign$symbol$amount ${'unit_lakh'.tr}';
    }
    return '$sign$symbol${_grouped.format(magnitude.round())}';
  }

  /// The full amount with Indian digit grouping and no compaction,
  /// e.g. `₹12,50,000`. Use where an exact figure matters more than brevity.
  static String full(num value, {bool withSymbol = true}) {
    final symbol = withSymbol ? '₹' : '';
    final sign = value < 0 ? '-' : '';
    return '$sign$symbol${_grouped.format(value.abs().round())}';
  }
}
