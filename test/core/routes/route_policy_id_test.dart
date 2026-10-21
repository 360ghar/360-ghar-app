import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/routes/route_policy.dart';

void main() {
  test('property ids are positive and exact on every platform, web included', () {
    expect(positivePropertyId('42'), 42);
    expect(positivePropertyId(7), 7);
    expect(positivePropertyId('9007199254740991'), 9007199254740991);
    expect(positivePropertyId('9007199254740992'), isNull, reason: 'not exact in JavaScript');
    expect(positivePropertyId('0'), isNull);
    expect(positivePropertyId('-3'), isNull);
    expect(positivePropertyId('abc'), isNull);
    expect(positivePropertyId(null), isNull);
    expect(propertyIdFromPath('/property/12'), 12);
    expect(propertyIdFromPath('/p/12'), 12);
    expect(propertyIdFromPath('/property/12/x'), isNull);
  });
}
