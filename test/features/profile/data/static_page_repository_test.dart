// test/features/profile/data/static_page_repository_test.dart
//
// Unit tests for [StaticPageRepository.fetchPublicPage].
// Injects an API client into the real repository.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ghar360/core/data/models/static_page_model.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/profile/data/static_page_repository.dart';
import '../../../helpers/api_fixtures.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient apiClient;
  late StaticPageRepository repository;

  setUp(() {
    apiClient = MockApiClient();
    repository = StaticPageRepository(apiClient: apiClient);
  });

  void stub(String name, {Object? body, Object? error}) {
    final call = when(
      () => apiClient.get(
        ApiPaths.staticPagePublic(name),
        useCache: any(named: 'useCache'),
        requireAuth: any(named: 'requireAuth'),
        notifyUnauthorized: any(named: 'notifyUnauthorized'),
      ),
    );
    if (error != null) {
      call.thenThrow(error);
    } else {
      call.thenAnswer((_) async => ApiResponse(statusCode: 200, body: body, headers: const {}));
    }
  }

  Map<String, dynamic> pageBody([Map<String, dynamic> overrides = const {}]) => {
    ...asObject(apiFixture('pages')['privacy']),
    ...overrides,
  };

  group('fetchPublicPage', () {
    test('reads a PagePublicResponse body', () async {
      stub('privacy-policy', body: pageBody());

      final page = await repository.fetchPublicPage('privacy-policy');

      expect(page.title, 'Privacy policy');
      expect(page.content, startsWith('# Privacy'));
      expect(page.format, PageFormat.markdown);
      expect(page.uniqueName, 'privacy-policy');
      expect(page.updatedAt, DateTime.utc(2026, 9, 30, 10, 15, 2));
    });

    test('the request needs no sign-in and never ends a session', () async {
      stub('privacy-policy', body: pageBody());

      await repository.fetchPublicPage('privacy-policy');

      verify(
        () => apiClient.get(
          ApiPaths.staticPagePublic('privacy-policy'),
          useCache: true,
          requireAuth: false,
          notifyUnauthorized: false,
        ),
      ).called(1);
    });

    test('a page with no updated_at is valid', () async {
      stub('terms-of-service', body: asObject(apiFixture('pages')['html']));

      final page = await repository.fetchPublicPage('terms-of-service');

      expect(page.updatedAt, isNull);
      expect(page.format, PageFormat.html);
    });

    test('an unknown format reads as null and the page is not rendered', () async {
      stub('privacy-policy', body: pageBody({'format': 'rtf'}));

      final page = await repository.fetchPublicPage('privacy-policy');

      expect(page.format, isNull);
      expect(page.isRenderable, isFalse);
    });

    for (final entry in <String, Object?>{
      'a data envelope': {'data': pageBody()},
      'a bare list': <dynamic>['not', 'a', 'map'],
      'a body with no title': pageBody()..remove('title'),
      'a body with no content': pageBody()..remove('content'),
      'a body with no format': pageBody()..remove('format'),
      'a title that is not a string': pageBody({'title': 7}),
      'an empty body': <String, dynamic>{},
      'a null body': null,
    }.entries) {
      test('${entry.key} is a malformed response, not an invented page', () async {
        stub('privacy-policy', body: entry.value);

        await expectLater(
          repository.fetchPublicPage('privacy-policy'),
          throwsA(isA<ServerException>().having((e) => e.code, 'code', 'MALFORMED_RESPONSE')),
        );
      });
    }

    test('throws NotFoundException on 404', () async {
      stub('missing', error: NotFoundException('Not found'));

      expect(() => repository.fetchPublicPage('missing'), throwsA(isA<NotFoundException>()));
    });

    test('rethrows ServerException on server error', () async {
      stub('about-us', error: ServerException('Internal error', statusCode: 500));

      expect(() => repository.fetchPublicPage('about-us'), throwsA(isA<ServerException>()));
    });

    test('rethrows NetworkException on network error', () async {
      stub('about-us', error: NetworkException('Offline'));

      expect(() => repository.fetchPublicPage('about-us'), throwsA(isA<NetworkException>()));
    });
  });
}
