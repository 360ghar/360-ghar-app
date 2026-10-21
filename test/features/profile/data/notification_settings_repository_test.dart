import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/features/profile/data/notification_settings_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/api_fixtures.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient api;
  late NotificationSettingsRepository repository;
  setUp(() {
    api = MockApiClient();
    repository = NotificationSettingsRepository(apiClient: api);
  });

  test('reads GET /users/notification-settings without the HTTP cache', () async {
    when(
      () => api.get(
        any(),
        useCache: any(named: 'useCache'),
        dedupe: any(named: 'dedupe'),
      ),
    ).thenAnswer(
      (_) async => ApiResponse(
        statusCode: 200,
        body: apiFixture('users')['notification_settings'],
        headers: const {},
      ),
    );

    final settings = await repository.fetch();

    expect(settings.pushNotifications, isFalse);
    expect(settings.promotionalEmails, isTrue);
    expect(settings.emailNotifications, isTrue);
    verify(() => api.get('/users/notification-settings', useCache: false, dedupe: false)).called(1);
  });

  test('a body with a removed or camelCase key still reads the four switches', () async {
    when(
      () => api.get(
        any(),
        useCache: any(named: 'useCache'),
        dedupe: any(named: 'dedupe'),
      ),
    ).thenAnswer(
      (_) async => const ApiResponse(
        statusCode: 200,
        body: {
          'push_notifications': true,
          'email_notifications': true,
          'sms_notifications': false,
          'promotional_emails': false,
          'quietHours': null,
        },
        headers: {},
      ),
    );

    expect((await repository.fetch()).toJson().keys, UserKeys.notification);
  });

  test('a switch sends only its own key, PUT and idempotent, and reads the answer', () async {
    when(
      () => api.put(
        any(),
        body: any(named: 'body'),
        idempotent: any(named: 'idempotent'),
      ),
    ).thenAnswer(
      (_) async => const ApiResponse(
        statusCode: 200,
        body: {
          'push_notifications': true,
          'email_notifications': true,
          'sms_notifications': false,
          'promotional_emails': true,
        },
        headers: {},
      ),
    );

    final saved = await repository.set('promotional_emails', true);

    expect(saved.promotionalEmails, isTrue);
    verify(
      () => api.put(
        '/users/notification-settings',
        body: {'promotional_emails': true},
        idempotent: true,
      ),
    ).called(1);
  });

  test('the app shows switches for keys the backend declares', () {
    expect(NotificationSettingsRepository.toggles, [
      'push_notifications',
      'email_notifications',
      'promotional_emails',
    ]);
  });
}

/// The four keys of `NotificationSettings`.
abstract final class UserKeys {
  static const notification = [
    'push_notifications',
    'email_notifications',
    'sms_notifications',
    'promotional_emails',
  ];
}
