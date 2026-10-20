import 'package:intl/intl.dart';

import 'package:ghar360/core/translations/app_messages.dart';

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

  /// A compact amount, e.g. `₹1.25 Cr`, `₹2.5 L`, `₹85 L`, `₹43,400`.
  ///
  /// [fractionDigits] applies only to the crore/lakh forms; whole rupee
  /// amounts below a lakh are never shown with decimals.
  static String compact(
    num value, {
    int fractionDigits = 2,
    bool withSymbol = true,
    String languageCode = 'en',
  }) {
    final symbol = withSymbol ? '₹' : '';
    final magnitude = value.abs();
    final sign = value < 0 ? '-' : '';

    String unit(String key) => appMessages[languageCode == 'hi' ? 'hi_IN' : 'en_US']![key]!;
    if (magnitude >= _lakh) {
      final lakhs = (magnitude / _lakh).toStringAsFixed(fractionDigits);
      // 99.999 lakh rounds to 100: that is a crore, not "100 L".
      if (magnitude >= _crore || double.parse(lakhs) >= 100) {
        final crores = (magnitude / _crore).toStringAsFixed(fractionDigits);
        return '$sign$symbol${_trim(crores)} ${unit('unit_crore')}';
      }
      return '$sign$symbol${_trim(lakhs)} ${unit('unit_lakh')}';
    }
    return '$sign$symbol${_grouped.format(magnitude.round())}';
  }

  /// `85.0` → `85`, `2.50` → `2.5`: listings write "₹85 L", not "₹85.0 L".
  static String _trim(String amount) =>
      amount.contains('.') ? amount.replaceFirst(RegExp(r'\.?0+$'), '') : amount;

  /// The full amount with Indian digit grouping and no compaction,
  /// e.g. `₹12,50,000`. Use where an exact figure matters more than brevity.
  static String full(num value, {bool withSymbol = true}) {
    final symbol = withSymbol ? '₹' : '';
    final sign = value < 0 ? '-' : '';
    return '$sign$symbol${_grouped.format(value.abs().round())}';
  }
}
