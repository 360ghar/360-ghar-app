import 'package:flutter/widgets.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/indian_currency.dart';
import 'package:intl/intl.dart';

final _grouped = NumberFormat.decimalPattern('en_IN');

/// Display text for a property, in the reader's language. The model keeps
/// numbers only; words and units live here.
extension PropertyLabels on PropertyModel {
  String localizedType(BuildContext context) => context.l10n.text(propertyTypeLabelKey);

  /// The price for the listing's purpose (see [PropertyModel.effectivePrice]), or an empty string
  /// when the backend sent none.
  String localizedPrice(BuildContext context) {
    final price = effectivePrice;
    return price == null
        ? ''
        : IndianCurrency.compact(
            price,
            fractionDigits: 1,
            languageCode: Localizations.localeOf(context).languageCode,
          );
  }

  /// `1,450 sq ft`, grouped the Indian way.
  String localizedArea(BuildContext context) => areaSqft == null
      ? ''
      : context.l10n.text('area_sq_ft', params: {'value': _grouped.format(areaSqft!.round())});

  /// `Floor 4/12`, or `Floor 4` when the building height is not known.
  String localizedFloor(BuildContext context) {
    final floor = floorNumber;
    if (floor == null) return '';
    final total = totalFloors;
    return total == null
        ? context.l10n.text('floor_only', params: {'floor': '$floor'})
        : context.l10n.text('floor_of_total', params: {'floor': '$floor', 'total': '$total'});
  }

  String localizedAge(BuildContext context) => switch (ageOfProperty) {
    null => '',
    0 => context.l10n.text('age_new'),
    1 => context.l10n.text('age_one_year'),
    final years => context.l10n.text('age_years', params: {'count': '$years'}),
  };

  /// `800 m away` under a kilometre, else `4.8 km away`.
  String localizedDistance(BuildContext context) {
    final km = distanceKm;
    if (km == null) return '';
    return km < 1
        ? context.l10n.text('distance_m', params: {'value': (km * 1000).toStringAsFixed(0)})
        : context.l10n.text('distance_km', params: {'value': km.toStringAsFixed(1)});
  }
}
