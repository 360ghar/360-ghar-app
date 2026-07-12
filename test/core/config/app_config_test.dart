import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/config/app_config.dart';

void main() {
  tearDown(() {
    AppConfig.resetForTest();
  });

  group('AppConfig', () {
    test('initialize with overrides sets values', () {
      AppConfig.initialize(
        overrides: {
          'API_BASE_URL': 'https://example.test',
          'SUPABASE_URL': 'https://supabase.test',
          'SUPABASE_PUBLISHABLE_KEY': 'pub-key',
          'GOOGLE_PLACES_API_KEY': 'places-key',
          'DEBUG_MODE': 'true',
          'LOG_API_CALLS': 'false',
        },
      );

      final config = AppConfig.instance;
      expect(config.apiBaseUrl, 'https://example.test');
      expect(config.supabaseUrl, 'https://supabase.test');
      expect(config.supabasePublishableKey, 'pub-key');
      expect(config.googlePlacesApiKey, 'places-key');
      expect(config.debugMode, isTrue);
      expect(config.logApiCalls, isFalse);
    });

    test('toString does not leak secret material', () {
      AppConfig.initialize(
        overrides: {
          'SUPABASE_URL': 'https://supabase.test',
          'SUPABASE_PUBLISHABLE_KEY': 'super-secret-key',
          'GOOGLE_PLACES_API_KEY': 'places-secret',
        },
      );

      final text = AppConfig.instance.toString();
      expect(text, isNot(contains('super-secret-key')));
      expect(text, isNot(contains('places-secret')));
      expect(text, contains('supabaseConfigured: true'));
      expect(text, contains('placesKeyConfigured: true'));
    });

    test('instance throws before initialize', () {
      AppConfig.resetForTest();
      expect(() => AppConfig.instance, throwsStateError);
    });

    test('analytics and performance default to privacy-off', () {
      AppConfig.initialize(overrides: const {});
      final config = AppConfig.instance;
      expect(config.firebaseAnalytics, isFalse);
      expect(config.firebasePerformance, isFalse);
    });

    test('debugEnv fills keys when overrides and defines are empty', () {
      AppConfig.initialize(
        overrides: const {},
        debugEnv: {
          'SUPABASE_URL': 'https://from-debug-env.test',
          'SUPABASE_PUBLISHABLE_KEY': 'debug-pub-key',
          'API_BASE_URL': 'https://api-from-debug.test',
        },
      );

      final config = AppConfig.instance;
      expect(config.supabaseUrl, 'https://from-debug-env.test');
      expect(config.supabasePublishableKey, 'debug-pub-key');
      expect(config.apiBaseUrl, 'https://api-from-debug.test');
    });

    test('explicit overrides win over debugEnv', () {
      AppConfig.initialize(
        overrides: {
          'SUPABASE_URL': 'https://override.test',
          'SUPABASE_PUBLISHABLE_KEY': 'override-key',
        },
        debugEnv: {
          'SUPABASE_URL': 'https://from-debug-env.test',
          'SUPABASE_PUBLISHABLE_KEY': 'debug-pub-key',
        },
      );

      final config = AppConfig.instance;
      expect(config.supabaseUrl, 'https://override.test');
      expect(config.supabasePublishableKey, 'override-key');
    });
  });
}
