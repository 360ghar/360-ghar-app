import 'dart:convert';
import 'dart:io';

/// A fixture group written by `tool/api_fixtures.py` from the backend's own Pydantic models:
/// `test/fixtures/api/<group>.json`. Tests run from the package root.
Map<String, dynamic> apiFixture(String group) =>
    jsonDecode(File('test/fixtures/api/$group.json').readAsStringSync()) as Map<String, dynamic>;

/// [value] as a JSON object.
Map<String, dynamic> asObject(Object? value) => Map<String, dynamic>.from(value! as Map);

/// The `items` of a `CursorPage` fixture.
List<Map<String, dynamic>> pageItems(Object? page) =>
    (asObject(page)['items'] as List).map(asObject).toList(growable: false);
