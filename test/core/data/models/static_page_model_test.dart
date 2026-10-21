import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/static_page_model.dart';

Map<String, dynamic> _body({Map<String, dynamic> overrides = const {}}) => {
  'unique_name': 'privacy-policy',
  'title': 'Privacy policy',
  'content': '# Privacy\n\nWe keep little.',
  'format': 'markdown',
  'custom_config': null,
  'view_count': 40,
  'updated_at': '2026-09-30T10:15:02Z',
  ...overrides,
};

void main() {
  group('StaticPageModel.fromJson', () {
    test('reads a PagePublicResponse body', () {
      final model = StaticPageModel.fromJson(_body());

      expect(model.uniqueName, 'privacy-policy');
      expect(model.title, 'Privacy policy');
      expect(model.content, startsWith('# Privacy'));
      expect(model.format, PageFormat.markdown);
      expect(model.updatedAt, DateTime.utc(2026, 9, 30, 10, 15, 2));
    });

    test('updated_at can be null', () {
      expect(StaticPageModel.fromJson(_body(overrides: {'updated_at': null})).updatedAt, isNull);
    });

    test('does not read invented keys such as data, name, html or body', () {
      expect(
        () => StaticPageModel.fromJson({
          'data': {'title': 'T', 'content': 'C'},
          'name': 'N',
          'html': '<p>x</p>',
          'body': 'b',
        }),
        throwsA(anything),
      );
    });

    test('a key the backend always sends is required', () {
      for (final key in ['unique_name', 'title', 'content', 'format', 'updated_at']) {
        final body = _body()..remove(key);
        expect(() => StaticPageModel.fromJson(body), throwsA(anything), reason: 'missing $key');
      }
    });

    test('an unknown format reads as null and is not rendered', () {
      final model = StaticPageModel.fromJson(_body(overrides: {'format': 'rtf'}));

      expect(model.format, isNull);
      expect(model.isRenderable, isFalse);
    });
  });

  group('StaticPageModel.isRenderable', () {
    test('an HTML page with only a Markdown autolink is not treated as markup', () {
      final model = StaticPageModel.fromJson(
        _body(overrides: {'format': 'html', 'content': 'Write to <support@ghar360.com>'}),
      );
      expect(model.isRenderable, isTrue);
    });

    StaticPageModel page(String format, String content) =>
        StaticPageModel.fromJson(_body(overrides: {'format': format, 'content': content}));

    test('renders Markdown', () {
      expect(page('markdown', '# Title').isRenderable, isTrue);
    });

    test('renders an html page whose content is Markdown text', () {
      expect(page('html', '# Title\n\nPlain text').isRenderable, isTrue);
    });

    test('does not render an html page that holds tags', () {
      expect(page('html', '<h1>Title</h1><p>Body</p>').isRenderable, isFalse);
    });

    test('does not render a json page', () {
      expect(page('json', '{"blocks": []}').isRenderable, isFalse);
    });
  });

  group('StaticPageModel.toJson', () {
    test('roundtrip keeps the fields', () {
      final original = StaticPageModel.fromJson(_body());
      final restored = StaticPageModel.fromJson(original.toJson());

      expect(restored.uniqueName, original.uniqueName);
      expect(restored.title, original.title);
      expect(restored.content, original.content);
      expect(restored.format, original.format);
      expect(restored.updatedAt, original.updatedAt);
    });
  });
}
