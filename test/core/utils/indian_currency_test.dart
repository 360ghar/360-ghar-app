import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/utils/indian_currency.dart';

void main() {
  group('IndianCurrency.compact', () {
    test('writes sub-lakh amounts in full with Indian grouping, never as "K"', () {
      // The bug this replaces: a ₹43,400 monthly EMI rendered as "43.4K",
      // which is neither Indian numbering nor translatable.
      expect(IndianCurrency.compact(43400), '₹43,400');
      expect(IndianCurrency.compact(4340), '₹4,340');
      expect(IndianCurrency.compact(999), '₹999');
      expect(IndianCurrency.compact(43400), isNot(contains('K')));
    });

    test('uses lakh and crore suffixes above their thresholds', () {
      expect(IndianCurrency.compact(250000), '₹2.5 L');
      expect(IndianCurrency.compact(12500000), '₹1.25 Cr');
    });

    test('treats the threshold boundaries inclusively', () {
      expect(IndianCurrency.compact(100000), '₹1 L');
      expect(IndianCurrency.compact(99999), '₹99,999');
      expect(IndianCurrency.compact(10000000), '₹1 Cr');
      expect(IndianCurrency.compact(9999999), '₹1 Cr');
      expect(IndianCurrency.compact(8500000, fractionDigits: 1), '₹85 L');
    });

    test('honours fractionDigits and withSymbol', () {
      expect(IndianCurrency.compact(12500000, fractionDigits: 1), '₹1.3 Cr');
      expect(IndianCurrency.compact(250000, withSymbol: false), '2.5 L');
    });

    test('handles zero and negative amounts without mangling the sign', () {
      expect(IndianCurrency.compact(0), '₹0');
      expect(IndianCurrency.compact(-43400), '-₹43,400');
      expect(IndianCurrency.compact(-12500000), '-₹1.25 Cr');
    });

    test('localises the magnitude suffix', () {
      expect(IndianCurrency.compact(12500000, languageCode: 'hi'), '₹1.25 करोड़');
      expect(IndianCurrency.compact(250000, languageCode: 'hi'), '₹2.5 लाख');
      // Grouping is numeric, so it stays identical across locales.
      expect(IndianCurrency.compact(43400, languageCode: 'hi'), '₹43,400');
    });
  });

  group('IndianCurrency.full', () {
    test('never compacts, and groups the Indian way', () {
      expect(IndianCurrency.full(12500000), '₹1,25,00,000');
      expect(IndianCurrency.full(1250000), '₹12,50,000');
      expect(IndianCurrency.full(250000), '₹2,50,000');
      expect(IndianCurrency.full(123456789), '₹12,34,56,789');
      expect(IndianCurrency.full(250000, withSymbol: false), '2,50,000');
    });
  });
}
