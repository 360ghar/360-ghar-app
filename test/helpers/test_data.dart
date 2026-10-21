// test/helpers/test_data.dart
//
// Shared test fixtures. Each body holds every key the backend always sends for a `Property`
// (see `docs` fixtures from `tool/api_fixtures.py`); named parameters override single fields.

/// A `Property` body as `GET /properties` sends it. A key that can be empty is null.
Map<String, dynamic> testPropertyJson({
  int id = 100,
  String title = 'Test Property',
  double basePrice = 5000000.0,
  String propertyType = 'house',
  String purpose = 'buy',
  int bedrooms = 3,
  int bathrooms = 2,
  double areaSqft = 1200.0,
  bool isAvailable = true,
  String? mainImageUrl,
  double? latitude,
  double? longitude,
}) {
  return {
    'id': id,
    'owner_id': 7,
    'title': title,
    'description': 'A beautiful test property with modern amenities.',
    'property_type': propertyType,
    'purpose': purpose,
    'status': 'available',
    'base_price': basePrice,
    'latitude': latitude ?? 28.6139,
    'longitude': longitude ?? 77.2090,
    'city': 'New Delhi',
    'state': 'Delhi',
    'country': 'India',
    'full_address': 'Test Address, New Delhi',
    'area_sqft': areaSqft,
    'bedrooms': bedrooms,
    'bathrooms': bathrooms,
    'main_image_url': mainImageUrl ?? 'https://example.com/image1.jpg',
    'is_available': isAvailable,
    'view_count': 42,
    'like_count': 15,
    'interest_count': 8,
    'created_at': '2024-03-10T08:00:00Z',
    'updated_at': '2024-03-11T08:00:00Z',
  };
}

/// A list of [count] property bodies.
List<Map<String, dynamic>> testPropertyJsonList({int count = 5}) {
  return List.generate(
    count,
    (i) => testPropertyJson(
      id: 100 + i,
      title: 'Property ${i + 1}',
      basePrice: 3000000.0 + (i * 1000000),
    ),
  );
}

/// A `CursorPage[Property]` body: all five keys, as the backend always sends them.
Map<String, dynamic> testPropertyPage({
  List<Map<String, dynamic>>? items,
  int count = 5,
  bool hasMore = false,
  String? nextCursor,
  int limit = 20,
  int? total,
}) {
  return {
    'items': items ?? testPropertyJsonList(count: count),
    'next_cursor': nextCursor,
    'has_more': hasMore,
    'limit': limit,
    'total': total,
  };
}
