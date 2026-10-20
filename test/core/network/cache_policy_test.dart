import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/unified_property_response.dart';
import 'package:ghar360/core/network/cache_policy.dart';

void main() {
  const page = UnifiedPropertyResponse(items: [], hasMore: false);

  test('a response marked no-store marks its decoded object', () {
    final marked = markCachePolicy(page, {'Cache-Control': 'private, no-store'});

    expect(identical(marked, page), isTrue);
    expect(isNoStoreResponse(page), isTrue);
  });

  test('the header name is matched without case', () {
    const other = UnifiedPropertyResponse(items: [], hasMore: false, limit: 1);
    markCachePolicy(other, {'cache-control': 'NO-STORE'});

    expect(isNoStoreResponse(other), isTrue);
  });

  test('other Cache-Control values, and no header, leave the object cacheable', () {
    const plain = UnifiedPropertyResponse(items: [], hasMore: false, limit: 2);
    const timed = UnifiedPropertyResponse(items: [], hasMore: false, limit: 3);
    markCachePolicy(plain, const {});
    markCachePolicy(timed, {'cache-control': 'private, max-age=60'});

    expect(isNoStoreResponse(plain), isFalse);
    expect(isNoStoreResponse(timed), isFalse);
  });

  test('an object built in code is cacheable', () {
    expect(
      isNoStoreResponse(const UnifiedPropertyResponse(items: [], hasMore: false, limit: 9)),
      isFalse,
    );
  });
}
