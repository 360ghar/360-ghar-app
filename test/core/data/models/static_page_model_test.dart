import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/static_page_model.dart';

void main() {
  group('StaticPageModel.fromJson', () {
    test('parses JSON with "data" wrapper', () {
      final json = <String, dynamic>{
        'data': {
          'title': 'Privacy Policy',
          'content': '<p>Privacy policy content</p>',
        },
      };

      final model = StaticPageModel.fromJson(json);

      expect(model.title, 'Privacy Policy');
      expect(model.content, '<p>Privacy policy content</p>');
    });

    test('parses JSON without wrapper (direct fields)', () {
      final json = <String, dynamic>{
        'title': 'Terms of Service',
        'content': '<p>Terms content</p>',
      };

      final model = StaticPageModel.fromJson(json);

      expect(model.title, 'Terms of Service');
      expect(model.content, '<p>Terms content</p>');
    });
  });

  group('StaticPageModel.fromDynamic field name resolution', () {
    test('uses "title" field', () {
      final model = StaticPageModel.fromDynamic({'title': 'My Title', 'content': 'Body'});

      expect(model.title, 'My Title');
    });

    test('uses "name" field when title is absent', () {
      final model = StaticPageModel.fromDynamic({'name': 'Page Name', 'content': 'Body'});

      expect(model.title, 'Page Name');
    });

    test('uses "page_title" field when title and name are absent', () {
      final model = StaticPageModel.fromDynamic({'page_title': 'Page Title', 'content': 'Body'});

      expect(model.title, 'Page Title');
    });

    test('uses fallbackTitle when no title field is present', () {
      final model = StaticPageModel.fromDynamic(
        {'content': 'Body'},
        fallbackTitle: 'Default Title',
      );

      expect(model.title, 'Default Title');
    });

    test('uses empty string fallback when no title and no fallbackTitle', () {
      final model = StaticPageModel.fromDynamic({'content': 'Body'});

      expect(model.title, '');
    });

    test('uses "content" field for content', () {
      final model = StaticPageModel.fromDynamic({'title': 'T', 'content': 'Content body'});

      expect(model.content, 'Content body');
    });

    test('uses "html" field when content is absent', () {
      final model = StaticPageModel.fromDynamic({'title': 'T', 'html': '<html></html>'});

      expect(model.content, '<html></html>');
    });

    test('uses "body" field when content and html are absent', () {
      final model = StaticPageModel.fromDynamic({'title': 'T', 'body': 'Body text'});

      expect(model.content, 'Body text');
    });

    test('uses "description" field when content, html, body are absent', () {
      final model = StaticPageModel.fromDynamic({'title': 'T', 'description': 'Desc'});

      expect(model.content, 'Desc');
    });

    test('uses "text" field when content, html, body, description are absent', () {
      final model = StaticPageModel.fromDynamic({'title': 'T', 'text': 'Plain text'});

      expect(model.content, 'Plain text');
    });

    test('resolves fields within "data" wrapper', () {
      final json = <String, dynamic>{
        'data': {'name': 'About Us', 'html': '<p>About</p>'},
      };

      final model = StaticPageModel.fromDynamic(json);

      expect(model.title, 'About Us');
      expect(model.content, '<p>About</p>');
    });
  });

  group('StaticPageModel edge cases', () {
    test('handles null content gracefully', () {
      final model = StaticPageModel.fromDynamic({'title': 'T', 'content': null});

      expect(model.title, 'T');
      expect(model.content, '', reason: 'null content resolves to empty string');
    });

    test('handles all content fields null', () {
      final model = StaticPageModel.fromDynamic({
        'title': 'T',
        'content': null,
        'html': null,
        'body': null,
        'description': null,
        'text': null,
      });

      expect(model.content, '');
    });

    test('handles empty json', () {
      final model = StaticPageModel.fromDynamic({});

      expect(model.title, '');
      expect(model.content, '');
    });

    test('handles empty json with fallbackTitle', () {
      final model = StaticPageModel.fromDynamic({}, fallbackTitle: 'Fallback');

      expect(model.title, 'Fallback');
      expect(model.content, '');
    });

    test('fromJson delegates to fromDynamic with fallbackTitle', () {
      final model = StaticPageModel.fromJson(
        {'data': {'content': 'Body'}},
        fallbackTitle: 'Provided Fallback',
      );

      expect(model.title, 'Provided Fallback');
      expect(model.content, 'Body');
    });
  });

  group('StaticPageModel.toJson', () {
    test('produces title and content keys', () {
      const model = StaticPageModel(title: 'My Page', content: 'Page body');

      final json = model.toJson();

      expect(json['title'], 'My Page');
      expect(json['content'], 'Page body');
    });

    test('toJson roundtrip preserves fields', () {
      const original = StaticPageModel(title: 'About', content: 'About content');

      final json = original.toJson();
      final restored = StaticPageModel.fromJson(json);

      expect(restored.title, original.title);
      expect(restored.content, original.content);
    });
  });
}
