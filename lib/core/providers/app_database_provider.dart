import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

/// Bootstrap opens storage before runApp; consumers cannot create another copy.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw StateError('Override appDatabaseProvider with the bootstrap database.');
});

Override ownedAppDatabaseOverride(AppDatabase database) => appDatabaseProvider.overrideWith((ref) {
  ref.onDispose(() {
    unawaited(
      database.close().catchError((Object error, StackTrace stack) {
        DebugLogger.warning('Closing local storage failed', error, stack);
      }),
    );
  });
  return database;
});
