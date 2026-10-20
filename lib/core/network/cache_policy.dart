import 'package:ghar360/core/network/etag_cache.dart';

/// The server marks authenticated property responses `Cache-Control: private, no-store`. The
/// client must honour that itself, so a decoded response carries its cache rule to the feature
/// that would store it. The mark lives beside the object (an [Expando]) so a model keeps its
/// JSON shape, and a model built in code is cacheable.
final _noStore = Expando<bool>('Cache-Control: no-store');

/// Marks [value] when [headers] say `no-store`. Returns [value] either way.
T markCachePolicy<T extends Object>(T value, Map<String, String> headers) {
  if (ETagCache.isNoStore(headers)) _noStore[value] = true;
  return value;
}

/// True when the response that [value] was read from said `no-store`: do not write it to disk,
/// and delete a stored copy.
bool isNoStoreResponse(Object value) => _noStore[value] == true;
