/// Central registry of all `GetStorage` keys used across the app.
///
/// Every raw string literal previously passed to `GetStorage.read/write/
/// remove/hasData` lives here as a single source of truth. The string VALUES
/// are persisted on-device, so they must never change — only their callers
/// reference them through these constants.
///
/// Keys are grouped by domain for discoverability.
abstract final class StorageKeys {
  // ---------------------------------------------------------------------------
  // Filters (global filter propagation in PageFilterManager)
  // ---------------------------------------------------------------------------
  static const String globalPurpose = 'global_purpose';
  static const String globalPropertyTypes = 'global_property_types';

  // ---------------------------------------------------------------------------
  // Page state (per-page snapshots + schema version)
  // ---------------------------------------------------------------------------
  static const String exploreState = 'explore_state';
  static const String discoverState = 'discover_state';
  static const String likesState = 'likes_state';
  static const String pageStateSchemaVersion = 'page_state_schema_version';

  // ---------------------------------------------------------------------------
  // Theme / locale (ThemeController, LocalizationController, main bootstrap)
  // ---------------------------------------------------------------------------
  static const String themeMode = 'themeMode';
  static const String languageCode = 'language_code';
  static const String countryCode = 'country_code';

  // ---------------------------------------------------------------------------
  // Onboarding (SplashController, AuthNavigationService)
  // ---------------------------------------------------------------------------
  static const String hasSeenOnboarding = 'has_seen_onboarding';

  // ---------------------------------------------------------------------------
  // Auth (LastAuthMethodStore)
  // ---------------------------------------------------------------------------
  static const String lastAuthMethod = 'last_auth_method';
  static const String lastAuthIdentifierHint = 'last_auth_identifier_hint';
  static const String lastAuthMethodAt = 'last_auth_method_at';

  // ---------------------------------------------------------------------------
  // App update (AppUpdateController)
  // ---------------------------------------------------------------------------
  static const String skippedAppVersion = 'skipped_app_version';

  // ---------------------------------------------------------------------------
  // Preferences (PreferencesController notification toggles)
  // ---------------------------------------------------------------------------
  static const String pushNotifications = 'pushNotifications';
  static const String emailNotifications = 'emailNotifications';
  static const String similarProperties = 'similarProperties';

  // ---------------------------------------------------------------------------
  // Tools (DocumentChecklistController)
  // ---------------------------------------------------------------------------
  static const String documentChecklist = 'document_checklist';

  // ---------------------------------------------------------------------------
  // ETag cache (EtagCache — composed as `${etagCachePrefix}$key`)
  // ---------------------------------------------------------------------------
  static const String etagCachePrefix = 'etag_cache_';

  // ---------------------------------------------------------------------------
  // Firebase consent gating (FirebaseInitializer)
  // ---------------------------------------------------------------------------
  static const String consentAnalytics = 'consent_analytics';
  static const String consentPerformance = 'consent_performance';
}
