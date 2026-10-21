import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/profile/data/notification_settings_repository.dart';
import 'package:ghar360/features/profile/presentation/controllers/preferences_controller.dart';
import '../../../../helpers/c_notification_settings.dart';
import '../../../../helpers/visits_test_support.dart';

void main() {
  late AppDatabase database;
  late FakeNotificationSettings repository;
  late ProviderContainer container;
  setUp(() async {
    database = await visitTestDatabase();
    repository = FakeNotificationSettings();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        storageScopeProvider.overrideWith(() => TestVisitScope(database)),
        notificationSettingsRepositoryProvider.overrideWithValue(repository),
      ],
    );
    container.listen(notificationSettingsProvider, (_, _) {});
  });
  tearDown(() async {
    container.dispose();
    await database.close();
  });
  NotificationSettingsController controller() =>
      container.read(notificationSettingsProvider.notifier);
  NotificationSettingsState state() => container.read(notificationSettingsProvider);
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('reads the backend settings and shows the switches the app owns', () async {
    expect(state().loading, isTrue);
    await settle();
    expect(repository.reads, 1);
    expect(state().loading, isFalse);
    expect(state().toggles, NotificationSettingsRepository.toggles);
    expect(state().valueOf('push_notifications'), isTrue);

    repository.server = serverSettings(push: false);
    await controller().load();
    expect(state().valueOf('push_notifications'), isFalse);
  });

  test('a toggle writes only its own key and does not read first', () async {
    await settle();

    expect(await controller().toggle('push_notifications', false), isTrue);

    expect(repository.reads, 1, reason: 'only the first load reads');
    expect(repository.writes, [('push_notifications', false)]);
    expect(state().valueOf('push_notifications'), isFalse);
    expect(state().valueOf('email_notifications'), isTrue);
    expect(state().saveError, isNull);
  });

  test('the promotional switch is the marketing consent', () async {
    await settle();
    expect(state().valueOf('promotional_emails'), isFalse, reason: 'missing consent is opt-out');

    expect(await controller().toggle('promotional_emails', true), isTrue);

    expect(repository.writes.single, ('promotional_emails', true));
    expect(state().valueOf('promotional_emails'), isTrue);
  });

  test('a failed write puts the switch back and keeps a typed error', () async {
    await settle();
    repository.writeError = NetworkException('offline');

    expect(await controller().toggle('email_notifications', false), isFalse);

    expect(state().valueOf('email_notifications'), isTrue);
    expect(state().saveError, isA<NetworkException>());
    expect(state().savingKey, isNull);
    expect(repository.server.emailNotifications, isTrue);
  });

  test('never writes a key that is not a switch of the app', () async {
    await settle();

    expect(await controller().toggle('property_updates', false), isFalse);
    expect(await controller().toggle('sms_notifications', true), isFalse);
    expect(await controller().toggle('quietHours', true), isFalse);
    expect(repository.writes, isEmpty);
  });

  test('the switch shows the new value while saving and blocks a second write', () async {
    await settle();
    repository.writeGate = Completer<void>();

    final first = controller().toggle('push_notifications', false);
    await settle();
    expect(state().savingKey, 'push_notifications');
    expect(state().valueOf('push_notifications'), isFalse);
    expect(await controller().toggle('email_notifications', false), isFalse);

    repository.writeGate!.complete();
    expect(await first, isTrue);
    expect(repository.writes, hasLength(1));
    expect(state().savingKey, isNull);
  });

  test('a load failure is typed and retry reads again', () async {
    repository.readError = NetworkException('offline');
    await settle();
    expect(state().settings, isNull);
    expect(state().loadError, isA<NetworkException>());

    repository.readError = null;
    await controller().load();
    expect(state().loadError, isNull);
    expect(state().toggles, isNotEmpty);
  });

  test('a late write result after disposal does not publish state', () async {
    await settle();
    repository.writeGate = Completer<void>();
    final pending = controller().toggle('push_notifications', false);
    await settle();
    container.dispose();
    repository.writeGate!.complete();
    expect(await pending, isFalse);
    container = ProviderContainer();
  });
}
