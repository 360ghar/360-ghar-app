import 'dart:async';

import 'package:ghar360/core/data/models/user_model.dart';
import 'package:ghar360/features/profile/data/notification_settings_repository.dart';

/// The backend `NotificationSettings` defaults, with push switched as asked.
UserNotificationSettings serverSettings({bool push = true}) =>
    UserNotificationSettings(pushNotifications: push);

class FakeNotificationSettings implements NotificationSettingsRepository {
  UserNotificationSettings server = serverSettings();

  /// Each write as `(key, value)`. A switch sends only its own key.
  final writes = <(String, bool)>[];
  int reads = 0;
  Object? readError;
  Object? writeError;
  Completer<void>? writeGate;

  @override
  Future<UserNotificationSettings> fetch() async {
    reads++;
    if (readError case final error?) throw error;
    return server;
  }

  @override
  Future<UserNotificationSettings> set(String key, bool value) async {
    writes.add((key, value));
    await writeGate?.future;
    if (writeError case final error?) throw error;
    return server = server.withSwitch(key, value);
  }
}
